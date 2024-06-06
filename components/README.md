# components

This configures the GitOps controller (Argo CD). Things like RBAC, git repo secrets, config files for ArgoCD *only*, namespace definitions etc belong here.

`ApplicationSets` contains configuration for each ApplicationSet deployed on the cluster.

If an app requires a namespace or other resource, it goes in its app directory in `infrastructure` or `tenants`, not here.
