# bootstrap

The minimum configuration needed to get the cluster started. This is typically just deploying ArgoCD as the GitOps controller.

The `bootstrap` directory contains only the ArgoCD installation yaml (and patches thereof) for ArgoCD itself. It should not need to be modified during cluster runtime. 

See the `components` directory for config of ArgoCD `ApplicationSets`,  `AppProjects` and other components. 


## Environments

There are two pre-configured ArgoCD deployment environments:

* `dev` uses a local Git repository for cluster infrastructure config.
* `prod` uses a remote Git repository for cluster infrastructure config.

To deploy for example the `dev` environment, make sure the ArgoCD generator marker files are named appropriately to deploy the `dev` environment and ignore the `prod` environment:

- `infrastructure/argocd/envs/dev/config.json`
- `infrastructure/argocd/envs/prod/config.json.ignore`

And vice versa to deploy `prod`.

## :warning: Using ArgoCD to bootstrap itself and the cluster

The cluster must be bootstrapped into the `dev` environment using a Git repository on the local filesystem, as this does NOT require a kubernetes secret to be decrypted (which, since Sealed Secrets is used for secrets, requires the cluster to first be bootstrapped). 

The Ansible process triggered by `make site-up` will bootstrap to `dev` by default.

Once the cluster is bootstrapped into `dev`, create and encrypt the `prod` repo URL and credential secrets, then change ArgoCD to `prod`.

See the Tutorials for guidance.


## Acknowledgements

* [Christianh814](https://github.com/christianh814/example-kubernetes-go-repo)