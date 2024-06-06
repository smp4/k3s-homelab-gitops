# Longhorn readme

Installed on all nodes. Requires that storage be available on all nodes at `/var/lib/longhorn`, the default path for longhorn.

Longhorn distributed storage is intended as the default storage class for this cluster.

Dashboard is available.

## Install

From [github docs](https://github.com/longhorn/longhorn/tree/master/chart):

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
```

Make sure you have set the `longhorn_nfs_backup_target` variable in the Ansible values `all.yml` file. As configured, the backup target must be an NFS file share. If you have no such network backup configured, then delete the daily backup and snapshot jobs from the `infrastructure/longhorn/envs/prod` directory.

## Environments

The `dev` environment has no yaml-configured backups or snapshots. Any backups need to be scheduled manually. The `prod` environment has a daily backup and an hourly snapshot pre-configured. See note above about the backup target.


## Backup target, backups and snapshots

The backup target is set in the `setting-buTarget.yaml` file. It can also be set in the Helm values (and lso possible in the UI).

```yaml
# helm-values.yaml
defaultSettings:   
  backupTarget: "nfs://192.168.0.1:/path/to/nfs/target"  # same as configured in Ansible values all.yml
```

### Create backup and snapshot jobs

Also possible with the UI

To create them with yaml, create the following in `envs/prod` [inspiration](https://github.com/reefland/ansible-k3s-argocd-renovate/blob/3c10b6499d3113d9418a5c4919a1b3d9289ad379/templates/longhorn/workloads/longhorn-config/recurring-job-daily-backup.yaml.j2):

```yaml
# kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base
- recurring-job-daily-backup.yaml
- recurring-job-snapshot.yaml
```

```yaml
# recurring-job-daily-backup
---
apiVersion: longhorn.io/v1beta1
kind: RecurringJob
metadata:
  name: default-group-daily-backup
spec:
  cron: "08 3 * * *"  # Daily at 3:08am
  task: "backup"
  groups:
    - default
  retain: 21  # keep for 21 days
  concurrency: 2  # number of jobs to run concurrently
  labels:
    label/1: default-group-daily-backup
```

```yaml
# recurring-job-snapshot.yaml
---
apiVersion: longhorn.io/v1beta1
kind: RecurringJob
metadata:
  name: default-group-daily-snapshot
spec:
  cron: "03 * * * *"  # Daily at 6:03am
  task: "snapshot"
  groups:
    - default
  retain: 7  # Keep for 7 days
  concurrency: 2  # number of jobs to run concurrently
  labels:
    label/1: default-group-daily-snapshot
```

## PV retain policy

By default, Longhorn will delete the PV when the pod and PVC are deleted. This means that all data is gone when the pod goes down. It is possible to change this behaviour with the `reclaimPolicy` field, setting it to `retain` so that when the pod and PVC are deleted, the PV is retained.

Note that when the pod comes back up, the PV will *not* be automatically reattached to the PVC (this is a security feature). The PV needs to be connected back to the PVC manually by an admin.

This cluster keeps the default `reclaimPolicy` of `delete`, instead opting to use snapshots and backups to manually restore data to a pod in the event of pod deletion.

:warning: Using the ConfigMap method is deprecated. Better to do this in the Helm values file now. :warning:

For more on how to do this, see [GitHub discussion](https://github.com/longhorn/longhorn/pull/1827). An example yaml is below. `reclaimPolicy` is currently set in `values-longhorn.yaml`. It may also be possible to set it by patching the configmap that controls the longhorn storageClass resource (NB: the longhorn devs use the configMap to control the storageClass resource, so editing the storageClass resource itself won't help). Note: untested!

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: longhorn-storageclass
  namespace: longhorn-system
data:
  # default reclaimPolicy is Delete. Retain will keep volumes if workloads with pvc's are deleted, and reattach them when pod is recreated
  storageclass.yaml: |
    kind: StorageClass
    apiVersion: storage.k8s.io/v1
    metadata:
      name: longhorn
      annotations:
        storageclass.kubernetes.io/is-default-class: "true"
    provisioner: driver.longhorn.io
    allowVolumeExpansion: true
    reclaimPolicy: "Retain"
    volumeBindingMode: Immediate
    parameters:
      numberOfReplicas: "3"
      staleReplicaTimeout: "30"
      fromBackup: ""
      fsType: "ext4"
      dataLocality: "disabled"
```

Use the patch to change if the longhorn storage class retains or deletes volumes once their parent workload is removed. Default is Delete. Currently patched to Retain.