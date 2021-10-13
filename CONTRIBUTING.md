See the CASM PET team's [contributing guide](https://connect.us.cray.com/confluence/display/CASMPET/CONTRIBUTING).

## Releasing

If `sonar-jobs-watcher.sh` was changed from the previous release, the
`sonar-jobs-watcher` Pods need to be restarted to pick up the change (they're
not restarted automatically). This is forced by changing the `SCRIPT_VERSION`
environment variable in the DaemonSet.
