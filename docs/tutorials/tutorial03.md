# Tutorial part 3: Cluster with remote GitOps repo and `stage` infrastructure

This third part of the tutorial continues from the end of [Part 2](tutorial02.md). If not done already, follow the [Installation](../getting-started/installation.md) instructions, make sure you have [cleaned up any deployments you made in Part 1](tutorial01.md#cleanup), and set up the cluster as described in Part 2.


## Deploy the cluster

If you just finished Part 2, then you should have the local Git repo on the master server node. To verify, get the ArgoCD password and log in to the UI as in the last tutorials to verify that everything is deployed correctly.


## Configure ArgoCD to pull from the remote GitOps repo

If you followed the installation instructions, you [will have forked the public instance](../getting-started/installation.md#initialise-gitops-repo) of this GitOps repo into your own private GitOps repo. If you haven't already, push all of your local commits from Parts 1 and 2 of this tutorial to your remote repo:

```bash
git push origin main
``` 

We will now configure ArgoCD to use the remote repo as the source of truth for the cluster config. 

Find the `repoURL: git@github.com:USERNAME/YOUR-PRIVATE-FORK-OF-THIS-REPO.git` line in the following files and replace it with the URL to your private repo. You can get this URL by clicking on the "Code" button on the top right of the repo page on GitHub.

- `components/envs/prod/patch-appset-infrastructure-generators.yaml`
- `components/envs/prod/patch-appset-infrastructure-source.yaml`
- `components/envs/prod/patch-appset-tenants-generators.yaml`
- `components/envs/prod/patch-appset-tenants-source.yaml`

Also set the private repo URL in the `sourceRepos:` field in `components/envs/prod/patch-appproj-dev1-sourceRepos.yaml`.

These files configure where the cluster infrastructure and tenant workloads can be pulled from. At the moment, we are assuming that tenant workload configurations will be stored in the same repo as the infrastructure configurations. You can change this if you want in the `patch-appproj-dev1*` patch file and `patch-appset-tenants*.yaml` files listed above. These three files must have the same repo URL.

## Create remote GitOps repo secrets

Repository details to be used with ArgoCD are stored in secrets. We will create a credential template so that the repository credentials can be re-used for any repo stored under your user profile on the remote host (eg. GitHub). The following assumes that you are using GitHub with an SSH connection. See [ArgoCD docs on repositories](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#repositories) for further information on other methods.

### Create GitHub private key

See the [GitHub Docs](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/about-ssh).

!!! note
    ArgoCD does not support SSH private keys protected with a passphrase. See [issue#1894](https://github.com/argoproj/argo-cd/issues/1894).

In your local repo:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"  # your github account email

# Save to a file "argocd-to-gh"
# Leave the passphrase empty
```

We won't be using this private key on a local machine and it isn't protected with a passphrase, so we do not need to add it to any key chain or `ssh-agent`.

Copy the public key to your GitHub account.

### Create local plain text secrets

Sealed Secrets works by taking a Kubernetes secret object and encrypting it with a public key provided by the Sealed Secrets application (which is why the cluster must be deployed first, so the Sealed Secrets is available to perform this operation). 

We next create a `yaml` file to describe the secret object, with the secret stored in plain text *on our local file system only*. We will then encrypt it using Sealed Secrets and output it to an encrypted `yaml` file. This encrypted file can safely be uploaded to a Git repository. The only entity that can now unencrypt the secret is the Sealed Secrets instance running inside your cluster. Not even the author of the secret can unencrypt it. 

!!! tip
    As a matter of convention, you can name your plaintext secret files with the extension `*.pass`, then add `*.pass` as an entry to your `.gitignore` file to make sure plaintext files do not get uploaded to remote repositories. 

First, create the plain text credential template secret object:

```yaml
# components/envs/prod/secret-private-gh-credentials.yaml.pass
apiVersion: v1
kind: Secret
metadata:
  name: private-gh-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: https://github.com:USERNAME
  sshPrivatekey: |
    -----BEGIN OPENSSH PRIVATE KEY-----  #gitleaks:allow
    ...
    -----END OPENSSH PRIVATE KEY-----  #gitleaks:allow
```

(Ignore the gitleaks tags - these are to prevent false positives when running gitleaks on the repo).

Open the private key file `id_ed25519-argocd` and copy the private key contents into the appropriate section in the above credentials secret.

Now create the plain text repository secret object:

```yaml
# components/envs/prod/secret-private-gh-infra-repository.yaml.pass
apiVersion: v1
kind: Secret
metadata:
  name: private-infra-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: git@github.com:USERNAME/YOUR-PRIVATE-FORK-OF-THIS-REPO.git
```

Replace the URLs with your correct username and repo address. 

### Encrypt secrets

Fetch the public key from Sealed secrets. In the root directory of your GitOps repo:

```bash
kubeseal --fetch-cert > pub-sealed-secrets.pem
```

!!! tip
    This public key can be shared in your GitOps repo with no risk to security. However, if you don't want to share it, and `*.pem` to your `.gitignore` file.

We can now use the public key to encrypt our secrets. From the project root directory:

```bash
kubeseal --format=yaml \
  --cert=pub-sealed-secrets.pem \
  --secret-file components/envs/prod/secret-private-gh-credentials.yaml.pass \
  --sealed-secret-file components/envs/prod/secret-private-gh-credentials-sealed.yaml

kubeseal --format=yaml \
  --cert=pub-sealed-secrets.pem \
  --secret-file components/envs/prod/secret-private-gh-infra-repository.yaml.pass \
  --sealed-secret-file components/envs/prod/secret-private-gh-infra-repository-sealed.yaml
```

As the ArgoCD docs [note](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#repositories), Sealed Secrets will remove the labels from the secret object we defined in the plain text file. We need to readd them manually. Add the following to the sealed yaml files:

```yaml
# secret-private-gh-credentials-sealed.yaml
...
kind: SealedSecret
...
spec:
  template:
    metadata:
      labels: 
        "argocd.argoproj.io/secret-type": repo-creds
...
```

```yaml
# secret-private-gh-infra-repository-sealed.yaml
...
kind: SealedSecret
...
spec:
  template:
    metadata:
      labels: 
        "argocd.argoproj.io/secret-type": repository
...
```

Add the secret files to `kustomization.yaml`:

```yaml
# components/envs/prod/kustomization.yaml
...
resources:
  - secret-private-gh-infra-repository-sealed.yaml
  - secret-private-gh-credentials-sealed.yaml
  - ...
```

You can delete the `*.pass` files now if you wish, but you will need to recreate them to re-encrypt the secrets if you want to update them later.

!!! warning
    If using SSH and a custom Git repository, you will also need to add SSH known host public keys to ArgoCD. Argo already has the GitHub (and some others) known host keys built in, so in this case you don't need to do anything extra. See [the docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#ssh-known-host-public-keys).

This should be all the configuration changes we need.

You can now delete the public and private keys - they aren't needed anymore (the private key is stored in your cluster in a SealedSecret, and the public key is copied to GitHub).

### Push the new config to the cluster

```bash
# commit the new secrets to the gitops repo
git push server-remote main
```

Refresh the argo app in the UI. You wont see the new secrets in the cluster yet because we are still running ArgoCD in its `dev` environment. 

### Change ArgoCD applictionSet files to remote repo

Switch to the remote repo patch files in `components/envs/prod/kustomization.yaml`:

```yaml
patches:
# use these for remote gitops repo
  - path: patch-appproj-dev1-sourceRepos.yaml
  - path: patch-appset-infrastructure-generators.yaml
  - path: patch-appset-infrastructure-source.yaml
  - path: patch-appset-tenants-generators.yaml
  - path: patch-appset-tenants-source.yaml
```


## Migrate to remote GitOps repo

Commit the above changes and push them to the remote repo. Then push the changes to the local repo on the master node.

```bash
git push origin main
git push server-remote main
```

ArgoCD polls the repo every three minutes. If you can't wait that long, click `Sync` on the ArgoCD app in the UI. Ideally, nothing should visibly change. Check which repo is being polled in Settings>Repositories. Congratulations!

You now no longer need to push any code to the local repo on the master server node. Everything is on the remote repo and you can benefit from all the reliability that comes from the GitHub servers. 


## Migrate to Let's Encrypt staging API

Finally, we can migrate the SSL certificates from self-signed to the Let's Encrypt staging API. This will let us test the SSL configuration without using the Let's Encrypt production API, which is rate limited.

Rename the ArgoCD marker files to:

- `infrastructure/traefik/envs/dev/config.json.ignore`
- `infrastructure/traefik/envs/stage/config.json`

After letting ArgoCD sync the changes (or syncing manually via the UI), you should see Traefik move to the new environment. You may have to wait 5 - 10 minutes for the staging certificate to be registered and received from Let's Encrypt. Once it has loaded, you can visit the websites of your workloads with `https://` and inspect the certificates. 

Note that the staging certificates will still give an error in your browser as they are *not* signed. But we can open the certificates up from the browser and check that they are being issued from the Let's Encrypt staging endpoint, which tells us we can safely move on to the Let's Encrypt production API.

!!! warning
    If you haven't done it already, you will need to generate a secret for the Let's Encrypt DNS service access token. See [generate the required secrets](tutorial01.md#generate-secrets) in Part 1 of this tutorial.

## Moving On

In the next part of the tutorial, we will migrate the cluster to a fully `prod` environment. Get started on [Part 4](tutorial04.md).