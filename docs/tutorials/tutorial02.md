# Tutorial part 2: Cluster with `dev` infrastructure

If not done already, follow the [Installation](../getting-started/installation.md) instructions and make sure you have [cleaned up any deployments you made in the first part of the tutorial](tutorial01.md#cleanup).

For all deployments to the cluster machines, we need to bootstrap the cluster first into the ArgoCD `dev` environment to get all of the infrastructure up and running. This is because we are using sealed-secrets to encrypt secrets, which needs to be first deployed and running on the cluster to create secrets to encrypt our remote Git (eg. GitHub) repo credentials. 

This means we need to create a local Git repo on the master server node that ArgoCD can pull config from, before we deploy the cluster. In this second tutorial, we will only create the GitOps repo on the master node and stop there. In [Tutorial 3](tutorial03.md), we will update the cluster config, create the remote repo credential secrets and migrate to the remotely hosted repo as the source of truth for our cluster config.

## GitOps repo on master server node local filesystem

Set up the Git remote repo on the local file system of the [master server node](../getting-started/installation.md#definitions). We will do this manually.

!!! tip
    If you're doing your own thing and executing this tutorial on your local machine only, then you can use `make local-create-repo` for the next step, just as we did in [Part 1](tutorial01.md).

SSH into the master server node, then:

```bash
user@masterservernode:$ mkdir -p /tmp/argo-gitops.git
user@masterservernode:$ cd /tmp/argo-gitops.git 
user@masterservernode:$ git init --bare
```

On your local workstation:

```bash
git remote add server-remote ssh://user@masterservernode/tmp/argo-gitops.git
```

Where `user@masterservernode` are the user and server address used to SSH into the master server node.

!!! tip
    This assumes the ssh connection details for `user@masterservernode` are already available in `~/.ssh/config` on your local workstation, which allows specifying a non-standard port and an identity file. To go one step further and customise the ssh command itself, see [Stackoverflow](https://stackoverflow.com/questions/41219524/tell-git-which-ssh-config-file-to-use). 
    
    For old (<2.10) versions of Git, the `GIT_SSH_COMMAND` environment variable may also be useful. Git uses its own SSH client, sometimes it may be better to use the OpenSSH client instead, which can be done with this env variable.

Push the `main` branch on your local workstation to the `server-remote` repo:

```bash
git push server-remote main
```

The GitOps repo is now ready to be used by the cluster.

## Set the deployment environment

Follow the same instructions as in [Part 01](tutorial01.md#set-the-deployment-environment). If you already followed the first tutorial, you shouldn't need to change any of the `config.json` files.


## Deploy the cluster

We will now be deploying to the cluster nodes. Make sure `ansible/inventory/hosts.yml` is correctly populated. We will no longer be using `localhosts.yml` for the remainder of the tutorial.

Get the site up:

```bash
make site-up
```

Once the playbook has finished, and if not done already, see [Accessing the `kubeconfig` file](../howtos/kubectl.md).

## Verification

Check that all pods are ready:

```bash
kubectl get pods -A
```

Get the initial ArgoCD admin secret:

```bash
make get-argocd-initpass
```

In your browser go to [https://localhost:8080](https://localhost:8080), login with user `admin`, and password from above.

If you cannot access this URL, you may need to forward the port first:

```bash
make fwd-argocd-server
```

Congratulations, you're done! You can now test on your cluster using a locally hosted (to the cluster) repo.

## Generate secrets

If you want to test SSL certificate generation or access the Traefik UI, [generate the required secrets](tutorial01.md#generate-secrets).

## Moving on

In [Part 3](tutorial03.md), we will repeat the above steps, but this time we will migrate the GitOps repo from the local Git repo to the remote repo. We will continue in Part 3 with the cluster in its current state. There is no need to tear it down.


## Cleanup

If you need to tear the cluster down at any time you can reset everything with:

```bash
make site-reset
```

Note that this will delete the remote repo at `/tmp/argo-gitops.git` on the master server node too. You will have to create it again if you reboot the master server node, or run `make site-reset` before you can deploy the cluster. 
