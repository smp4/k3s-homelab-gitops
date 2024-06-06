# Deploying Helm charts with ArgoCD and Kustomize

**Resources:**

* [kustomize docs](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/helmcharts/=).
* [Redhat article on helm kustomize methods](https://developers.redhat.com/articles/2023/05/25/3-patterns-deploying-helm-charts-argocd).
* [HariSekhon bug installing sealed-secrets with helm](https://github.com/bitnami-labs/sealed-secrets/issues/894).
* [Applying `--enable-helm` flag in ArgoCD config](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/#kustomizing-helm-charts).

Some workloads are deployed from Helm packages. There are multiple ways to do this with ArgoCD. This repo tries to use Kustomize for all deployment configuration management, including managing Helm packages. The workload is configured with the normal base/ overlays Kustomize pattern, with the Helm chart defined in the `base` `kustomization.yaml`. ArgoCD will then look after inflating the chart and patching it when it builds the ArgoCD `application`. 

To do this, ArgoCD must be told to use Helm in its internal Kustomize executable with the `kustomizeBuildOptions: "--enable-helm"` flag. This can be done by patching the `argocd-cm` `ConfigMap`.

A `kustomization.yaml` set up in this method can be built locally to test it works with `kustomize build . --enable-helm`.