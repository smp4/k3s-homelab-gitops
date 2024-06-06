# Tutorial part 1: Localhost with `dev` infrastructure

This tutorial sets up a cluster for local testing so that you can get used to the deployment pattern and get the kubernetes config (yaml) working correctly, before having to worry about networking.

For local testing, we will create a single-node K3s cluster on your local machine and deploy the `dev` environment. This option can be used to trial the repo before moving to a hosted GitOps repo, deploying to remote nodes, and/ or bringing in more than one node.

First, make sure that you have completed the [Installation](../getting-started/installation.md). You may also benefit from reading about the [Repo Contents](../getting-started/repo-contents.md) before moving on, if you haven't already.

!!! info
    The `K3s/first_server_argocd` role is skipped in the `site` playbook when deploying to a `localhost` cluster, provisioning just an empty cluster. The user is then responsible for deploying any workloads to that cluster manually, or with the provided `make local-bootstrap-argocd` command.


## Create local Git repo

To get started, create the local Git repository in your `/tmp` directory and add it as a new Git remote to your current Git working directory. Using the provided `make` convenience routine:

```bash
make local-create-repo
```

!!! tip
    Before running any `make` commands, you can make sure you're happy with them by opening up the `Makefile` in the project root and checking them first.

The command assumes this directory is already configured as a Git repo (which will be the case if you cloned this from GitHub). This command creates a [bare](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols) Git remote repository at `/tmp/argo-gitops.git` and adds it to the list of Git remotes under the short name `local-remote` in your current Git working directory (wherever you are running the `make` command from). 

You can add a remote repository manually if desired:

```bash
git remote add local-remote file:///tmp/argo-gitops.git
```

The `make local-create-repo` command **does not** push any files to the new remote. You still need to do this manually.

You can now treat `/tmp/argo-gitops.git` like any other remote repository, allowing you to test how ArgoCD reconciles cluster state with GitOps repo state, including tracking different branches or commits, without having to upload anything to someone elses server.

Note that by default, the ArgoCD ApplicationSets in `appset-infrastructure.yaml` and `appset-tenants.yaml` track the `main` branch, so you need to merge any changes into `main` in your working repository before pushing to the local remote *or* change which branch is tracked in those config files.

!!! danger
    Note that the `reset` playbook and `make local-reset` both delete the `/tmp/argo-gitops.git` directory and all of its contents as part of cluster teardown. This local GitOps repo is for local testing only. The `/tmp` directory on a UNIX-like system is **volatile**, which means it is emptied whenever you reboot your machine. Do not rely on it for production!

Verify the local remote has been created and added to your GitOps working repo:

```bash
ls /tmp/argo-gitops.git
git remote  # list remotes
git remote show local-remote # give details
```

Should see `local-remote` listed.

To push from your working repo to the local remote:

```bash
git push local-remote main
```

## Set the deployment environment

The cluster will by default deploy to a `dev` state. We will learn more about why in [Part 2](tutorial02.md). For now, we just need to make sure all the infrastructure workloads are configured to deploy into environments compatible with `dev`. Make sure only the following ArgoCD generator marker files have the extension `*.json`. All other `config.json` files must be renamed to `config.json.ignore`. 

- `infrastructure/argocd/envs/dev/config.json`
- `infrastructure/longhorn/envs/prd/config.json`
- `infrastructure/traefik/envs/dev/config.json`

The other infrastructure workloads are always deployed into their `prod` environments.

Note that the `cert-manager` authority that gets used to sign SSL certificates is dictated by `traefik`, which is why `cert-manager` can always be deployed to `prod`.


## Provision the cluster

Now provision the cluster to your local machine and deploy ArgoCD:

```bash
make local-up
```

This will execute the `site` playbook and:

- Execute the playbook against the `localhost.yaml` inventory file, which you should make sure lists connection details for the local machine in the `servers` group only, and no machines in the `agent` group.
- Provision a `localhost`-only cluster running K3s.
- Apply the bootstrap configuration files, which will deploy ArgoCD.
- Deploy the ApplicationSets, which will track the Git repo at `/tmp/argo-gitops.git` on your local machine.

Now, each time you push updates on the `main` branch to that repo, ArgoCD will reconcile any differences between the configuration state in the repo and the live state in the cluster. This is the core of GitOps! Congratulations!

The deployment may take 5 - 10 minutes worst case if it takes a while to download and deploy the containers.


## Verification

Check all pods are ready:

```bash
kubectl get pods -A
```

If you get errors from `kubectl` suggesting it cannot find a `kubeconfig` file or similar, see [Accessing the `kubeconfig` file](../howtos/kubectl.md).

Now get the initial ArgoCD admin secret and forward the port for the web UI access to the argocd API:

```bash
make get-argocd-initpass
```

In your browser go to [https://localhost:8080](https://localhost:8080), login with user `admin`, and the password from above.

Done! Note that you may need to give ArgoCD 2-5 minutes to reconcile and deploy the ApplicationSet (or force it yourself in the UI or CLI).

## Generate secrets

We need to generate sealed secrets for: 

- Cert Manager DNS service access token. See [Cert Manager workload readme.md](https://github.com/smp4/k3s-homelab-gitops/tree/main/infrastructure/cert-manager/README.md).
- Traefik UI. See [Traefik workload readme](https://github.com/smp4/k3s-homelab-gitops/tree/main/infrastructure/traefik/README.md).


## Other useful `make` commands

Some other `make` commands to ease local development:

If you want to tear down the whole cluster:

```bash
make local-reset
```

Provision an empty K3s cluster to your local machine. That is, without also deploying the bootstrap deployment workloads:

```bash
make local-up-no-deploy
```

Deploy the bootstrap deployments to an existing local cluster from the local Git remote (ie. you must run `make local-create-repo` first and push something to it):

```bash
make local-deploy
```

Forward the port to the ArgoCD user interface. Useful if networking isn't working and you want to use the UI to debug Argo. This will make the ArgoCD login available at [https://localhost:8080](https://localhost:8080).

```bash
make fwd-argocd-server
```


## Cleanup

Finally, tear down the local cluster ready for the next tutorial.

```bash
make local-reset
```

You can also use this command at any time if something went wrong and you want to start again. It triggers the `reset.yml` Ansible playbook which will stop the K3s executable, remove all installed files and directories from your machine, and undo any network configuration.