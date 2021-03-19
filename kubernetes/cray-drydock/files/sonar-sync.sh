#!/bin/sh
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
