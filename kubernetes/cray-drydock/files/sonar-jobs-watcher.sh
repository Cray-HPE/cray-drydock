#!/bin/sh
#
# Copyright 2020 Hewlett Packard Enterprise Development LP
#
# usage: ./sonar-jobs-watcher.sh namespace ...
# Sonar scans for and detects jobs that have practically completed, but are not marked
# as such due to Istio sidecar which never exits. If it finds jobs in that state, Sonar
# sends a kill signal to the Istio sidecar container to allow for the Job to be marked as complete
# For more information on the issue Sonar fixes, see https://github.com/istio/istio/issues/6324

function get_containers() {
    kubectl get pods $1 -n $2 -o jsonpath='{range .status.containerStatuses[*]}{.name},{.state.running.startedAt}{.state.terminated.reason},{.restartCount}{"\n"}{end}'
}

function get_pods() {
    kubectl get pods -n $1 -o jsonpath='{range .items[?(@.metadata.ownerReferences[*].kind=="Job")]}{@.metadata.name}{"\n"}{end}' --field-selector=status.phase=Running
}

function get_pod_restartpolicy() {
    kubectl get pods $1 -n $2 -o jsonpath='{.spec.restartPolicy}'
}

while [ $# -gt 0 ]; do
NAMESPACE="$1"
echo "Checking pods in namespace $NAMESPACE"

IFS=$'\n'
for pod in `get_pods $NAMESPACE`; do
    echo "Checking containers in pod ${pod}"
    all_containers_completed="true"

    for container in `get_containers $pod $NAMESPACE;`; do
    IFS="," read name status restart <<EOF
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
    done;

    if [ "$all_containers_completed" == "true" ]; then
    echo "All containers of job pod $pod has completed. Killing istio-proxy to allow job to complete"
    kubectl exec $pod -c istio-proxy -n $NAMESPACE pkill pilot-agent
    fi;

done;

echo
shift
done

echo "Done";
