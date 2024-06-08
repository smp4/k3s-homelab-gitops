# Installation

This page describes how to set up and install this Git repo on your local machine including getting the repo, installing Ansible, generating secrets and configuring the Ansible inventory and variables.

## Requirements

- At least one machine to act as a server node.
- Operating on a UNIX/ Linux operating system.
- Minimum 1, ideally 3, machines or VM's to host the cluster nodes. 
- You must have `git` installed on at least your local workstation and the master server node.
- You have set up SSH access to all cluster nodes, ideally password-less.
- All cluster machines must have the relevant ports open on their firewalls. See below.

Preferably:

- A domain name to use for the cluster, with DNS and Let's Encrypt set up to issue certificates. See [Techno Tim](https://technotim.live/posts/kube-traefik-cert-manager-le/) for a guide.
 
!!! info
    HA ArgoCD is installed by default, which requires at least three nodes. If your cluster has less than three nodes, the HA installation will still work, however you will have several ArgoCD pods stuck in the `Pending` state. This won't affect Argo but will chew up node resources. If using less than three nodes, change the ArgoCD `install.yaml` location specification in `bootstrap/base/kustomization.yaml`.

 See [k3s requirements docs](https://docs.k3s.io/installation/requirements). When installing with multiple server nodes, the Ansible scripts will install K3S with the `--cluster-init` flag, which will set up an embedded `etcd` datastore. This requires further ports to be opened on the servers. Again, see the K3S docs.

Note, the following installation instructions will overwrite existing K3s installations on the hosts, and will overwrite the `.kube` directory on the hosts, if it exists.

### Ports and firewall rules

For this cluster to work, make sure the following ports are open. For more information, see [K3s docs](https://docs.k3s.io/installation/requirements#networking).

| Protocol | Port | Source | Destination | Description |
| - | - | - | - | - |
| TCP | 2379 - 2380 | Servers | Servers | HA K3s with embedded etcd |
| TCP | 6443 | Agents and workstation | Servers | K3s supervisor and Kubernetes API Server |
| UDP | 8472 | All nodes | All nodes | Flannel VXLAN |
| TCP | 10250 | All nodes | All nodes | Kubelet metrics |
| TCP & UDP | 7946 | All nodes and clients | Servers | MetalLB L2 mode traffic |
| TCP | 7472 | All nodes | All nodes | MetalLB metrics between nodes |
|  |  | 10.42.0.0/16 | any | K3s pods |
|  |  | 10.43.0.0/16 | any | K3s services |

Note also that if you are using an NFS network store as backup target, all nodes will need to have access to that target, as will the K3s pods (`10.42.0.0/16`).

Example NFS setup:

| Protocol | Port | Source | Destination | Description |
| - | - | - | - | - |
|  | 2049 | 10.42.0.0/16 | NFS target host | K3s pods to NFS |
|  | 111 | 10.43.0.0/16 | NFS target host | K3s pods to NFS |
|  | 2049 | Servers | NFS target host | K3s server nodes running Longhorn to NFS |


## Definitions

Before going further, some definitions are necessary.

* **Site**: Refers to your infrastructure - the totality of the local (and possibly remote) machines and connecting network that will constitute your cluster and client machines connecting to your cluster. This term is relevant only within the scope of this repo.
* **Local machine**: Your local machine can take on any of the above roles. In fact, with K3s, it *can* simultaneously take all three if you wish. Also called your local host.
* **Ansible controller workstation**: The machine from which you will be executing any Ansible playbooks or Makefile commands from this repo. It's most likely your local machine and probably not a cluster node. It is not necessary that it isn't a cluster node, but you might find interesting (read: painful) edge cases if your local machine is also a cluster node.
* **K3s/ Kubernetes server nodes**: One or more machines running K3s as server nodes. The server nodes run together to form the cluster **control plane**. Given how voting amongst server nodes works, it makes sense for the control plane to consist of an odd number of server nodes only. A minimum of one server node is necessary to have a K3s cluster, in which case that node will operate as the server as well as execute workloads. A **Highly Available (HA)** control plane will exist only once there are three or more (5, 7, ...) server nodes.
* **Master server node**: The first machine in the `server` list of the Ansible inventory. This term is relevant only within the scope of this repo. While all K3s server nodes are created equal, the Ansible playbooks in this repo will provision and bootstrap the cluster infrastructure workload to the master server node first, before adding other server or agent nodes to the cluster. This is because the virtual IP provided by KubeVIP needs to be available before any other nodes can be added, and this will only happen once KubeVIP is deployed to the cluster.
* **K3s agent nodes**: One or more machines running K3s as an agent. These are worker nodes that execute workloads. A server node can also be a worker node. Any number of agent nodes can be added to the cluster, to increase the available resources and redundancy.

All machines are assumed to be on the same private network.

## Install kubectl, ArgoCD CLI and Helm

!!! warning 
    You must use a kubectl version that is within one minor version difference of your cluster. For example, a v1.29 client can communicate with v1.28, v1.29, and v1.30 control planes. Using the latest compatible version of kubectl helps avoid unforeseen issues.

Install `kubectl` following the [docs](https://kubernetes.io/docs/tasks/tools/). `kustomize` [comes as part of](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_kustomize/) `kubectl`, albeit an earlier version sometimes. 

Install `helm` following the [docs](https://helm.sh/docs/intro/install/).

Install ArgoCD CLI following the [docs](https://argo-cd.readthedocs.io/en/stable/cli_installation/).

## Initialise GitOps repo

This is a public repo. Ultimately, you will want to be using this as a private repo, but perhaps you will want to keep it connected to this public instance to be able to pull upstream changes. To achieve this, mirror this public repo into your own private repo.  

First, create your own private repo somewhere (eg. GitHub), eg `k3s-homelab-gitops-private`. The following commands assume you have an ssh connection to GitHub.

```bash
git clone --bare git@github.com:smp4/k3s-homelab-gitops.git
cd k3s-homelab-gitops
git push --mirror git@github.com:smp4/k3s-homelab-gitops-private.git 
cd ..
rm -rf k3s-homelab-gitops
```

Clone the private repo to the local file system on the Ansible controller workstation.

```bash
git clone git@github.com:smp4/k3s-homelab-gitops-private.git
# do work, add, commit
git push origin main
```

Now you can work on the repo privately.

To pull upstream changes from this public repo:

```bash
git remote add public-repo git@github.com:smp4/k3s-homelab-gitops.git
git pull public-repo main
git push origin main
```

This will create a remote server listing for the public repo in your git settings called `public-repo`. The `pull` command will create a merge commit. 

## Install Ansible

Ansible is used for setup operations on the cluster node machines - OS level tasks.

For the most part, the repo does not use Ansible to do any templating of the Kubernetes resource yaml files. The idea is that Ansible is used only at bootstrap and then forgotten. An exception is some of the cluster infrastructure resources that are applied at bootstrap, including Kube VIP, where things like `apiserver_endpoint` are templated into the Kube VIP manifest.

Install Ansible in a Python virtual environment on the Ansible controller workstation (Ansible is a Python application).

Optionally use `direnv` to automatically load environment variables and activate the Python virtual environment whenever you `cd` into the repo directory.

[Install `direnv`](https://github.com/direnv/direnv/blob/master/docs/installation.md):

```bash
curl -sfL https://direnv.net/install.sh | bash
```

Add the following line to `~/.zshrc` (see the `direnv` docs for other shells):

```bash
eval "$(direnv hook zsh)"
```

Create `.envrc` file in the root directory of this repo and set up Python virtual environment, specifying `.venv` as the directory to store the virtual environment (so that it is easily recognised by IDE's), and explicitly selecting a Python version:

```bash
echo "export VIRTUAL_ENV=.venv" >> .envrc
echo "layout python /usr/local/bin/python3.11" >> .envrc
direnv allow
which python3
which pip
pip install --upgrade pip
```

Otherwise, create the virtual environment using your preferred method.

With the virtual environment created, install requirements:

```bash
pip install -r requirements.txt
```

If needed in development, use a `.env` file to define environment variables within the repo.

Install the required Ansible collections:

```bash
ansible-galaxy install -r ./ansible/collections/requirements.yml
```

## Create Ansible inventory and values files

Next, configure your cluster site. If you are going to follow the tutorials and first deploy to your local host, you will need to populate the `ansible/inventory/localhost.yml` file. If you are only following the other tutorials, or deploying directly to a cluster of nodes, then you can ignore this file. All users will eventually need to populate the `ansible/inventory/hosts.yml` file.

Start with the defaults in the `samples/` directory:

```bash
cp ./samples/localhost-sample.yml ./ansible/inventory/localhost.yml
cp ./samples/hosts-sample.yml ./ansible/inventory/hosts.yml
cp ./samples/all-sample.yml ./ansible/inventory/group_vars/all.yml
```

Edit `localhost.yml` and `all.yml` with the relevant values for your local machine. Descriptions for each variable are given in the sample files. The `localhost.yml`, make sure you list connection details for the local machine in the `servers` group only, and no machines in the `agent` group.

Update the host connection details in `hosts.yml` and cluster configuration variables in `all.yml` to suit your needs. You may need to modify the `all.yml` file when progressing to cluster deployment. 

At this point, it might be useful to understand what each of the directories in the [repo contents](../getting-started/repo-contents.md) are doing. 


## Generate templated manifests

Ansible is mostly used for bootstrapping the cluster nodes, however in a small number of cases it is mandatory to generate some kubernetes manifest (yaml) files from templates. This is just a hack to use Ansible to template and generate the KubeVIP and MetalLB manifests into the working directory of the GitOps repo on your local machine and only needs to be performed once prior to the first cluster deployment. 

!!! warning
    The following steps generating the KubeVIP templates and committing them to the repo **must** be completed before any deployments are made to the cluster, as KubeVIP creates the API endpoint IP address which both your local machine and all cluster nodes require to connect to and join the cluster.

Create the KubeVIP and MetalLB manifests from the Ansible templates with the Ansible playbook `generate-templates`. From the repo root directory:

```bash
make manifest-templates
```

It does not matter which Ansible inventory file is used to execute the `generate-templates` play, as it will execute it on the local machine (the Ansible Controller) only, and once only. The contents of the values file `all.yml` are the main input. 

!!! warning
    The `make manifest-templates` command must be run from the root directory of this repo (the directory in which you found the `README.md` that you're currently reading). This directory is used to template and copy the kubeVIP manifests into the respective infrastructure workload directories in `./infrastructure`.

Commit the new files and push to the repository so that ArgoCD can reconcile them into the cluster later.

```bash
git status
git add .
git commit -m "Add KubeVIP manifests."
git push  # Assuming the repo is already set up to push to remote origin.
```


## Create local bootstrap secrets

These secrets are used by Ansible to bootstrap the node machines. Encrypted secrets are implemented as variables (rather than files).

Bootstrap secrets (host `ansible_become_pass`, `k3s_token` ) are stored in Ansible Vault. Ansible Vault comes as part of the Ansible installation. The user must create these secrets locally, and store them locally. They are never used again once the cluster is initialised. The encrypted secrets are provided to Ansible via `ansible/inventory/group_vars/all.yml` and `ansible/inventory/hosts.yml` (or `localhost.yml`). These files, with their secrets, are listed in `.gitignore`, so are never committed to version control. 

Production-time secrets will be separately encrypted and stored using Sealed Secrets.

The user must create the bootstrap encrypted secrets first, before running any Ansible playbooks. The scripts are currently configured assuming all secrets belong to a `vault-id` called `home`, encrypted with a single password.

Create the secrets at the prompts triggered by each of the following commands. **Don't** hit `enter` after entering the password: use `ctrl-d` per the instructions that Ansible will print to screen. Use the same vault password for each command (you can use different passwords if you want, but then the `make` commands in future steps won't work out of hte box).

To encrypt a password to elevate `ansible_user` privileges on a host, run and paste the output of the following for the respective host in `hosts.yml`:

```bash
ansible-vault encrypt_string --vault-id home@prompt --stdin-name "ansible_become_pass"
```

To encrypt the `vault_k3s_token` variable in `all.yml`:

```bash
ansible-vault encrypt_string --vault-id home@prompt --stdin-name "k3s_token"
```

The above secrets need to be generated for each node.

For convenience, save your vault password in plain text in a file called `vault_pass` in the root directory of this repo. Make sure this filename is in your `.gitignore` so that it doesn't get tracked by Git. 

```bash
# example vault_pass file
your-password-here-in-plain-text
```

Some of the Ansible-related `make` commands used throughout the tutorials will call this password automatically to decrypt your secrets. If you don't want to store your password like this, you will need to manually edit the `Makefile` yourself. Other commands will prompt the user for the password of the `home` vault. Use these as an example for your changes.

Now `kubectl` can be used without having to use `sudo` or manually specify the cluster config location.

From here, if you know what you are doing you can provision and deploy the cluster directly to production. To take an incremental approach, checking that everything works at each step, deploy in stages following the [Tutorials](../tutorials/index.md).

## Customise the cluster configuration

Manually edit the following `*.yaml` files to suit your preferences.

| File | Key | Value | Comment |
| - | - | - | - |
| `components/base/ingress-argo.yaml` | `spec.routes.match:` | `Host('argocd.your.domain.com')` | URL for ArgoCD UI |
| `components/envs/prod/patch-appproj-dev1-sourceRepos.yaml` | `spec.sourceRepos:` | Private Gitops Repo URL (ssh) | 
| `components/envs/prod/patch-appset-infrastructure-generators.yaml` | `spec.generators.git.repoURL:`| Private Gitops Repo URL (ssh) |
| `components/envs/prod/patch-appset-infrastructure-source.yaml` | `spec.template.spec.source.repoURL:`| Private Gitops Repo URL (ssh) |
| `components/envs/prod/patch-appset-tenants-generators.yaml` | `spec.generators.git.repoURL:`| Private Gitops Repo URL (ssh) |
| `components/envs/prod/patch-appset-tenants-source.yaml` | `spec.template.spec.source.repoURL`| Private Gitops Repo URL (ssh) |
| `infrastructure/cert-manager/base/issuer-letsencrypt-prod.yaml` | `spec.acme.email`, `spec.acme.solvers.dns01.cloudflare.email` | Your DNS service email address (eg Cloudflare) | |
| `infrastructure/cert-manager/base/issuer-letsencrypt-prod.yaml` | `spec.solvers.selector.dnsZones` | Your DNS zone URL | |
| `infrastructure/cert-manager/base/issuer-letsencrypt-stage.yaml` | per prod | per prod | |
| `infrastructure/longhorn/base/ingressRoute-dashboard.yaml` | `spec.routes.match:` | `Host('longhorn.your.domain.com')` | URL for longhorn UI | 
| `infrastructure/longhorn/base/setting-buTarget.yaml` | `value:` | `nfs://192.168.0.1:/path/to/your/nfs/backup/target` | Same directory as set in Ansible `all.yml` values file for `longhorn_nfs_backup_target` | 
| `infrastructure/traefik/base/ingress-dashboard.yaml` | `spec.routes.match:` | Host('traefik.your.domain.com')` | URL for Traefik UI |
| `infrastructure/traefik/base/values-traefik.yaml` | `loadBalncerIP:` | Any IP in the MetalLB range | |
| `infrastructure/traefik/envs/dev/cert-selfsigned.yaml` | `spec.commonName:`, `spec.dnsNames:` | `traefik.your.domain.com`| URL for Traefik UI | 
| `infrastructure/traefik/envs/prod/cert-wildcard-prod.yaml` | `spec.dnsNames:`, `spec.commonName` | `your.domain.come` | Your root domain URL | 
| `infrastructure/traefik/envs/stage/cert-wildcard-prod.yaml` | `spec.dnsNames:`, `spec.commonName` | `your.domain.come` | Your root domain URL | 
| `tenants/test-ingress/base/whoami.yaml` | In IngressRoute `spec.routes.match:` | `Host('test.your.domain.com)` | URL for ingress test tenant workload | 
| `tenants/test-lb/base/service.yaml` | `metadata.annotations.metallb.universe.tf/loadBalancerIPs:` | IP address | IP Address from your MetalLB pool |


For instructions on which values to use, see the `README.md` files in each of the workload directories.

## Helm Charts

Several of the infrastructure workloads are installed from Helm Charts. Go through each of the infrastructure workload directories, read their `README.md` files and follow their installation instructions.