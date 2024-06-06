# Home Kubernetes Cluster GitOps Repository

<p align="left">
  <p align="left">
	  <a href="https://github.com/gitleaks/gitleaks/">
        	<img alt="gitleaks badge" src="https://img.shields.io/badge/protected%20by-gitleaks-blue">
    	 </a>
  </p>
</p>

> A basic, unavoidably opinionated, non-professional template for bootstrapping a K3S cluster at home. 

This is the public version of the GitOps infrastructure repository for my home cluster. It is intended to be used as a template for a new cluster, and then to be forked and modified to suit your needs. 

:warning: **Use at your own risk! I am not a Kubernetes professional. This template (sometimes) attempts, and does not guarantee, to follow configuration and security best practices. I am not responsible for any damages or data loss.** :warning:

In particular, this template uses [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to store secrets in Git. It is useful, but not recommended for production. Anything that encrypts secrets in a hosted repository makes it difficult to adequately respond to a compromised key. This is because even if you re-encrypt everything with a new key, the compromised key can still be used to decrypt historical data in git history. 

Tested on server nodes running Ubuntu 22.04 LTS.

## Features

- **K3s** light weight Kubernetes cluster.
- **ArgoCD** for GitOps declarative deployment management.
- **kubevip** providing a virtual IP for the kubernetes API server to provide high availability to the control plane. If one control node goes down, then the API server remains available at the same IP address on another control node.
- **MetalLB** load balancer service on bare metal.
- **Traefik** ingress, defaulting to providing access to deployments and providing SSL termination.
- **cert-manager** to automate TLS certificate retrieval and update from **Let's Encrypt** for SSL connections.
- **Bitnami Sealed Secrets** to store encrypted secrets securely in Git repositories.
- **Longhorn** distributed storage for cluster persistence.
- Automated node provisioning and bootstrapping with **Ansible**.
- Tutorials to get you started and learn how to move between local and cluster nodes and local and remote GitOps repos


## Who is this repo for

This repo does not add anything particularly new to the Kubernetes ecosystem, but creating a homelab cluster is full of many tiny paper cuts that aren't obvious until you roll your sleeves up and try to get the thing to work. Kubernetes, and even some elements of K3S, just weren't built for small home clusters. 

This repo provides a solution for the interested single developer trying to get a homelab cluster up and running on spare hardware, that they can use to learn, and to host their own workloads. ArgoCD is not set up here with comprehensive RBAC, projects and permission management to support multiple teams deploying to the cluster (although you could of course change this yourself - let me know if you do!).


## Who is this repo not for

Professionals. This repo is not production ready, and all though Highly Available (HA) K3S can be installed, the remainder of the infrastructure workloads are not necessarily configured for HA needs. 

This repo is also not necessarily following security best practices. That's a full time job, and I already have another job.


## Getting Started

The [Installation](docs/howtos/installation.md) docs describe how to set up and install this Git repo on your local machine including getting the repo, installing Ansible, generating secrets and configuring the Ansible inventory and variables.

For more detailed docs, see the [docs](https://smp4.github.io/k3s-homelab-gitops/).

## Support

Use the GitHub Discussions for support. Please look first to see if your topic has already been addressed in an existing thread. I cannot guarantee a timely reply - life is busy - but I will try.

If you find a bug, please file an issue. 


## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## Roadmap

This is more of a wishlist than a roadmap.

- Tutorial part 5: Deploying a tenant workload.
- Implement [graceful node shutdown](https://github.com/k3s-io/k3s/discussions/4319).
- ArgoCD slack notifications.
- Renovate update PRs ([inspiration](https://github.com/reefland/ansible-k3s-argocd-renovate)).
- Define tenant application versions in a `version.yml` file with a container tag per environment in `tenants/#/envs/`.
- Sealed Secrets [best practices](https://kubernetes.io/docs/concepts/configuration/secret/) (encryption at rest, RBAC).
- Basic auth on longhorn dashboard

## Acknowledgements and Inspiration

- [Techno Tim](https://github.com/techno-tim/k3s-ansible/tree/master).
- [Hari Sekohn Kubernetes-configs](https://github.com/HariSekhon/Kubernetes-configs/tree/master).
- [Ric Sanfre Pi Kubernetes Cluster Project](https://picluster.ricsanfre.com/).
- [k3s-ansible](https://github.com/k3s-io/k3s-ansible/).
- [k3s-ansible Jon Stumpf](https://github.com/jon-stumpf/k3s-ansible).
- [Christianh814](https://github.com/christianh814/example-kubernetes-go-repo)

There are several other sources. Where possible, I have referenced them directly in the code where I used their solutions or patterns.

## License

[MIT](https://choosealicense.com/licenses/mit/)

If you use this repo, I'd love to know about it. Send me a message.
