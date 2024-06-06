# Sealed Secrets

## Installation

**`kubeseal`**

```bash
brew install kubeseal
```

**Kustomized Helm**

A Kustomization of the Sealed Secrets repo must be done using the Kustomize `HelmCharts` object. Pre-inflating the Helm chart locally, then patching it with Kustomize will not work - the CRDs won't be installed (even if Helm is told to do so). See [sealed-secrets bug](https://github.com/bitnami-labs/sealed-secrets/issues/894).

In order to build the kustomization locally to check that your config works, install the Helm repo:

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update sealed-secrets
```

Note on the `sealed-secrets-controller` name and workload `namespace` (see sealed-secrets readme):

> You can set fullnameOverride when installing the chart to override the name. Note also that `kubeseal` assumes that the controller is installed within the `kube-system` namespace by default. So if you want to use the `kubeseal` CLI without having to pass the expected controller name and namespace you should install the Helm Chart like this:
>
> `helm install sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller sealed-secrets/sealed-secrets`

In this repo, Sealed Secrets is installed in the `kube-system` namespace and with the name `sealed-secrets-controller` so that extra arguments are not required for `kubeseal`.


## Sealing a secret

Prerequisite: `Sealed-Secrets` is deployed and running in your cluster (ie. cluster has to be up first).

Get the public key from the Sealed Secrets Controller (only need it once per cluster on your local machine):

```bash
kubeseal --fetch-cert > pub-sealed-secrets.pem
```

This can be safely checked into source control. It is not a security compromise (it's only the public key).

For the rest, check the `README.md` file in the `infrastructure/traefik` directory, which steps through creating a sealed secret for the Traefik dashboard.


# Troubleshooting

See [issue 894](https://github.com/bitnami-labs/sealed-secrets/issues/894). Helm chart inflation with kustomization does not install CRDs, must do it using the `helmCharts` object or with `Helm`.