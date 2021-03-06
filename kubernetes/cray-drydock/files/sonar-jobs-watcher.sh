#!/bin/sh -e
#
# MIT License
#
# (C) Copyright 2020, 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# usage: ./sonar-jobs-watcher.sh namespace ...
#
# The MY_NODE_NAME environment variable contains the name of the node this
# instance is running on.
#
# Sonar scans for and detects jobs that have practically completed, but are not marked
# as such due to the Istio sidecar which never exits. If it finds jobs in that state, Sonar
# issues `crictl stop` to the Istio sidecar container to allow the Job to be marked as complete
# For more information on the issue Sonar fixes, see https://github.com/istio/istio/issues/6324

function get_containers() {
    kubectl get pods $1 -n $2 -o jsonpath='{range .status.containerStatuses[*]}{.name},{.state.running.startedAt}{.state.terminated.reason},{.restartCount},{.containerID}{"\n"}{end}'
}

function get_job_pods() {
    kubectl get pods -n $1 -o jsonpath='{range .items[?(@.metadata.ownerReferences[*].kind=="Job")]}{@.metadata.name}{"\n"}{end}' --field-selector=spec.nodeName=${MY_NODE_NAME},status.phase=Running
}

function get_cfs_pods() {
    kubectl get pods -n $1 -l cfsession --no-headers -o custom-columns=":metadata.name" --field-selector=spec.nodeName=${MY_NODE_NAME},status.phase=Running
}

function get_pod_restartpolicy() {
    kubectl get pods $1 -n $2 -o jsonpath='{.spec.restartPolicy}'
}

function check_pods() {
    NAMESPACE=$1
    GET_PODS_FN=$2

    for pod in `$GET_PODS_FN $NAMESPACE`; do
        echo "Checking containers in pod ${pod}"
        all_containers_completed="true"
        proxy_container_id=""

        for container in `get_containers $pod $NAMESPACE;`; do
            IFS="," read name status restart containerID <<EOF
$container
EOF

            # Job spec.template.spec.restartPolicy: Unsupported value: "Always": supported values: "OnFailure", "Never"
            restartpolicy=`get_pod_restartpolicy $pod $NAMESPACE`

            # OnFailure : if container fails to start, the container is re-started until the job backOffLimit is reached.
            # Istio sidecar is killed only if the container Completes - kubernetes will terminate the pod if restarts fails after backOffLimit attempts.
            if [ "$restartpolicy" == "OnFailure" ]; then
                echo "Found pod $pod with restartPolicy '$restartpolicy' and container '$name' with status '$status' and restart '$restart'"
                if [ "$name" != "istio-proxy" ] && [ "$status" != "Completed" ]; then
                    echo "$name is not yet completed";
                    all_containers_completed="false"
                fi;
            # Never : if container fails to start, another job pod is started until the job backOffLimit is reached.
            # Istio sidecar is killed if the container Completes or is in Error or OOMKilled - this allows the job pod to Complete.
            else
                echo "Found pod $pod with restartPolicy '$restartpolicy' and container '$name' with status '$status'"
                if [ "$name" != "istio-proxy" ] && [ "$status" != "Completed" ] && [ "$status" != "Error" ] && [ "$status" != "OOMKilled" ]; then
                    echo "$name is not yet completed";
                    all_containers_completed="false"
                fi;
            fi;

            if [ "$name" == "istio-proxy" ]; then
                proxy_container_id=${containerID#containerd://}
            fi
        done;

      if [ "$all_containers_completed" == "true" ] && [ "$proxy_container_id" != "" ]; then
          echo "All containers of job pod $pod has completed. Killing istio-proxy ($proxy_container_id) to allow job to complete"
          ./crictl stop "$proxy_container_id"
      fi;

    done;
}

function check_job_pods() {
    echo "Checking Job pods on $MY_NODE_NAME in namespace $NAMESPACE"
    check_pods $1 get_job_pods
}

function check_orphaned_cfs_pods() {
    echo "Checking for orphaned CFS pods on $MY_NODE_NAME"
    check_pods services get_cfs_pods
}

NAMESPACES="$@"

while [ 1 ]; do
    unset IFS

    for NAMESPACE in $NAMESPACES; do
        check_job_pods $NAMESPACE
        echo
    done

    sleep 5
    check_orphaned_cfs_pods
    echo

    echo "Done checking for completed jobs. Sleeping for 1 min";
    sleep 60
done
