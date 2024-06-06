# cert-manager installation

## Kustomized Helm installation

Default `values.yaml` is taken from the cert-manager [best practice documentation](https://cert-manager.io/docs/installation/best-practice/#best-practice-helm-chart-values).

!!! info
    Certificates must be in the namespace of the ingress using it.

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update
```

## Creating sealed secrets for DNS provider token

Prerequisite:

* `Sealed-Secrets` is deployed and running in your cluster (ie. cluster has to be up first).
* `kubeseal` is installed locally.
* The controller public key is available locally. See `README.md` in `infrastructure/sealed-secrets`.

Run all of the following in `infrastructure/cert-manager/base`.

```bash
kubeseal --fetch-cert > ../../../pub-sealed-secrets.pem
```

Create a `Secret` config file with the token provided in plain text:

```yaml
# infrastructure/cert-manager/base/secret-cf-token.yaml.pass
---
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  cloudflare-token: token-goes-here
```

The `*.pass` file extension is used by the repo's `gitignore` to prevent from plaintext secret files being committed to source control.

Create a sealed secret file from the plain text secret, then delete the plain text secret:

```bash
kubeseal --format=yaml \
  --cert=../../../pub-sealed-secrets.pem \
  --secret-file secret-cf-token.yaml.pass \
  --sealed-secret-file secret-cf-token-sealed.yaml

rm -f secret-cf-token.yaml.pass
```

Make sure the sealed secret config is included in `kustomization.yaml`:

```yaml
# cert-manager/base/kustomization.yaml
...
resources:
    - secret-cf-token-sealed.yaml
```

The secret then just gets referenced by its name wherever it is needed in other kubernetes resource configurations.
