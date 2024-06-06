# Tutorial part 4: Cluster with remote GitOps repo and `prod` infrastructure

This fourth part of the tutorial continues from the end of [Part 3](tutorial03.md). If not done already, follow the [Installation](../getting-started/installation.md) instructions, make sure you have [cleaned up any deployments you made in Part 1](tutorial01.md#cleanup), and set up the cluster as described in Parts 2 and 3.

You should have a cluster deployed to your node machines with ArgoCD monitoring your private external repo for changes to configuration, and SSl certificates being served by the Let's Encrypt staging endpoint.

If not done already, follow the [Installation](../getting-started/installation.md) instructions.

## Checks prior to launching `prod`

- Remove the default ArgoCD admin password and set your own. This is possible through the ArgoCD UI.
- Ensure the Traefik dashboard has a password.
- Optional: Set up backups and snapshots in Longhorn. See the [Longhorn docs](https://longhorn.io/docs/1.6.2/snapshots-and-backups/).


## Change all environments to `prod`

Ensure the following ArgoCD marker files are renamed, and any sibling environment marker files are renamed to `config.json.ignore`:

- `infrastructure/argocd/envs/prod/config.json`
- `infrastructure/cert-manager/prod/config.json`
- `infrastructure/kubevip/envs/prod/config.json`
- `infrastructure/longhorn/envs/prod/config.json`
- `infrastructure/metallb/envs/prod/config.json`
- `infrastructure/sealed-secrets/envs/prod/config.json`
- `infrastructure/traefik/envs/stage/config.json`

As well as the test tenant applications:

- `tenants/test-ingress/envs/prod/config.json`
- `tenants/test-lb/envs/prod/config.json`

Commit and push the changes to the private GitOps repo.

It should migrate within 3 minutes, or manually sync the applications in the ArgoCD UI. You should no longer see certificate errors when visiting `https://` page hosted by the cluster.

## Congratulations!

You've deployed the cluster to production. Now you can [deploy your own tenant workloads](tutorial05.md) to the cluster.