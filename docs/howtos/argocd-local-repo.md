# How-To: Notes on using local git repos with ArgoCD

## Dubious authors

Try using a clean clone of a remote repo into the local copy on the host node, instead of pushing to the local copy on the host node.

## `targetRevision`

This probably normally defaults to `HEAD`, but it can also be a branch name (this is undocumented in the argo docs). 