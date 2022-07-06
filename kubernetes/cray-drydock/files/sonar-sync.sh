#!/bin/sh
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
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
# usage: ./sonar-sync.sh
# Syncs resources from default namespace -> services namespace, single direction sync

function sync_item() {
  item_name="$1"
  source_ns="$2"
  destination_ns="$3"
  if kubectl get $item_name -n $source_ns &> /dev/null; then
    echo "Syncing ${item_name} from ${source_ns} to ${destination_ns}"
    kubectl get $item_name -n $source_ns -o json | \
      jq 'del(.metadata.namespace)' | \
      jq 'del(.metadata.creationTimestamp)' | \
      jq 'del(.metadata.resourceVersion)' | \
      jq 'del(.metadata.selfLink)' | \
      jq 'del(.metadata.uid)' | \
      kubectl apply -n $destination_ns -f -
  else
    echo "Didn't find $item_name in the $source_ns namespace"
  fi
}

if kubectl get ns services &> /dev/null; then
  for item_name in $(kubectl get configmaps -n default -o name); do
    sync_item "$item_name" "default" "services"
  done
  for item_name in $(kubectl get secret -n default --field-selector="type=Opaque" -o name); do
    if [ "$item_name" != "secret/admin-client-auth" ]; then
      sync_item "$item_name" "default" "services"
    else
      echo "Skipping $item_name"
    fi
  done
else
  echo "Didn't find the services namespace, not trying to sync configmaps and secrets there"
fi
if kubectl get ns user &> /dev/null; then
  sync_item "configmap/cray-configmap-ca-public-key" "default" "user"
  sync_item "secret/admin-client-auth" "default" "user"
else
  echo "Didn't find the user namespace, not attempting to sync there"
fi
if kubectl get ns spire &> /dev/null; then
  sync_item "secret/postgres-backup-s3-credentials" "default" "spire"
else
  echo "Didn't find the spire namespace, not attempting to sync there"
fi
if kubectl get ns argo &> /dev/null; then
  sync_item "secret/postgres-backup-s3-credentials" "default" "argo"
  sync_item "secret/config-data-s3-credentials" "default" "argo"
else
  echo "Didn't find the argo namespace, not attempting to sync there"
fi
if kubectl get ns nexus &> /dev/null; then
  sync_item "configmap/cray-configmap-ca-public-key" "default" "nexus"
else
  echo "Didn't find the nexus namespace, not attempting to sync there"
fi
