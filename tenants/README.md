# Tenants

This directory is owned by developers. Developers should only have to commit a directory with basic app config YAML, and the `/components/applicationsets/tenants-appset.yaml` ApplicationSet looks after creating the workload.

Allowable namespaces and clusters are set by operations via the `appproj-dev1` ArgoCD Application Project.

The `kustomization.yaml` file in the the root directory of each app can refer to another Git repository, or be a Git submodule.
