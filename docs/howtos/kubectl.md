## Accessing the `kubeconfig` file

`kubectl` is used to access the kubernetes API server on your cluster from the command line. Unless you previously installed `kubectl`, then after provisioning the K3s cluster, the `kubectl` command probably references the `kubectl` provided by K3s. Check this with `which kubectl`.

By default, the K3s-provided `kubectl` references the cluster configuration provided at `/etc/rancher/K3s/K3s.yaml` which requires `sudo` privileges to run. This is deliberate, as it makes sure only users with superuser access privileges can manipulate the cluster. However, entering a sudo password quickly becomes annoying (convenience is the enemy of security).

Instead, the `site` playbook drops the cluster config file into the default `kubectl` configuration directory at `~/.kube/config` (this is a file, not a directory). To get the K3s `kubectl` to reference this config file, either use the `--kubeconfig` flag or set the `KUBECONFIG` environment variable for your current shell.

If you followed along in the [Installation](../getting-started/installation.md) section, then you probably have `direnv` set up, which can be used to load the `KUBECONFIG` env variable automatically when you `cd` into your local copy of the GitOps directory:

```bash
echo "export KUBECONFIG=$HOME/.kube/local-config" > .envrc
direnv allow
```