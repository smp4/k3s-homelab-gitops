# Example patch for `argocd-cm`

```yaml
# patch-customdiff.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm

data:
  resource.customizations: |
      admissionregistration.k8s.io/ValidatingWebhookConfiguration:
        ignoreDifferences: |
          jsonPointers:
            - /webhooks/0/clientConfig/caBundle  
```

