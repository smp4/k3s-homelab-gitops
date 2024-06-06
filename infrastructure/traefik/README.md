# Traefik

Installed using kustomization `helmCharts` object.

## Environments

The `dev` environment uses a self-signed certificate from `cert-manager` and a user/ password for auth on the traefik dashboard that is stored in base64.

The `stage` environment uses SSL/ TLS certificates from LetsEncrypt staging via `cert-manager`, and requires you (the admin) to create a sealed secret for the Traefik dashboard auth login.

The `prod` environment is the same as `stage` except it uses the LetsEncrypt production endpoint. Uses the same sealed secret for Traefik dashboard auth login. Only use this once everything is working in staging so that you don't get rate limited by LetsEncrypt.

## Usage

### Creating sealed secrets for Traefik dashboard in `stage` and `prod`

Prerequisite:

* `Sealed-Secrets` is deployed and running in your cluster (ie. cluster has to be up first).
* `kubeseal` is installed locally.
* The controller public key is available locally. See `README.md` in `infrastructure/sealed-secrets`.

Run all of the following in `infrastructure/traefik/base`.

```bash
kubeseal --fetch-cert > ../../../pub-sealed-secrets.pem
```

To avoid putting the password into shell history, put it in plain text in a text file, pipe it into  `apache2-utils` to create the auth data and encode it in base64 for kubernetes. Then delete the text file.

```bash
touch plainpass
```

In the file:

```bash
# plainpass
your-password-here-in-plain-text
```

Create the auth object and encode it, then delete the password file. This creates an auth object for username `user`.

```bash
cat ../../../plainpass | htpasswd -ni user | openssl base64
rm plainpass
```

Then paste it into the `data` section of a secret:

```yaml
# infrastructure/traefik/base/secret-dashboard.yaml.pass
...
data:
    users: <base64 encoded here>
```

Note that the `*.pass` file extension is used by the repo's `.gitignore` to prevent from plaintext secret files being committed to source control.

Create a sealed secret file from the plain text secret, then delete the plain text secret:

```bash
kubeseal --format=yaml \
  --cert=../../../pub-sealed-secrets.pem \
  --secret-file secret-dashboard.yaml.pass \
  --sealed-secret-file secret-dashboard-sealed.yaml

rm -f secret-dashboard.yaml.pass
```

Make sure the sealed secret config is included in `kustomization.yaml`:

```yaml
# traefik/base/kustomization.yaml
...
resources:
    - secret-dashboard-sealed.yaml
```

The secret then just gets referenced by its name wherever it is needed in other kubernetes resource configurations.

## (Not Implemented) Install with pre-inflation of Helm chart with kustomize

These notes are retained for posterity. This method is not used in the current cluster config.

Uses best practice, inflating a fork of the remote configuration (the helm chart). Rebase/ reinflate the fork periodically to capture upstream changes. See [kustomize example](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/chart.md).

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
```

**Install CRDs**

Note that the `helm template` method advocated for below with `make inflate-chart` **does not** install any CRDs to the cluster (where Helm may normally have done so using `helm install`). Need to do this manually via `base/kustomization.yaml`

!!! warning
    The URLs to the Traefik v2 CRDs changed in April 2024 when Traefik v3 was released with the Helm chart v28.0.0-rc1. 

!!! warning
    The CRDs are versioned, as is (of course) the Helm chart. The user (you) must manually make sure that the correct CRD version pulled in via `kustomization.yaml` aligns with the Helm chart version used in the `make inflate-chart` command.

```yaml
# kustomization.yaml
...
resources:
- https://raw.githubusercontent.com/traefik/traefik/v2.11/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
- https://raw.githubusercontent.com/traefik/traefik/v2.11/docs/content/reference/dynamic-configuration/kubernetes-crd-rbac.yml
```

**Creating the helm kustomization**

See [kustomize docs](https://kubectl.docs.kubernetes.io/references/kustomize/builtins/#_helmchartinflationgenerator_).

**Updating the yaml**

To update the yaml based on a new version of the Helm chart, update values in `values.yaml` and environment kustomization in `envs`, then fully inflate the chart and write it out to the `base` directory with `make inflate-chart`. Set the name of the chart to reflect the version of the chart. This yaml then gets referenced in `base/kustomization.yaml` as a normal kustomize resource.

## Acknowledgements

Dashboard, middleware and helm values from [Techno Tim](https://technotim.live/posts/kube-traefik-cert-manager-le/).
