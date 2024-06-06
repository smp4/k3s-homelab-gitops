# infrastructure

Configuration for the in-cluster tooling that will be shared across all applications. The applications in this directory get deployed as an infrastructure ApplicationSet.

There is a directory in here for the GitOps controller (ArgoCD) that references the existing configuration in the `/bootstrap/` directory (remember, DRY).
