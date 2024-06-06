# Naming conventions

This repo uses the following file, directory and kubernetes object naming conventions:-

- **Directory names** are normally one word generically describing the kubernetes objects, or environment, or type of configuration they contain.
- YAML **configuration filenames** are of the form `<k8s_object_type_abbreviation>-<description>.yaml`. The description should be terse and without hyphens. Use underscores in the description if needed for readability, but the preference is to do without any delimiters in the description.
  - `pv-<description>.yaml`
  - `pvc-<description>.yaml`
  - `appproj-<description>.yaml`
  - `appset-<description>.yaml`
  - ...
- Kubernetes **object names** (stated within the configuration files) should be of the form `<description>-<k8s_object_type_abbreviation>`. Hyphens are allowed for readability. For example, `argo-gitops-pv`.
  - `<description>-pv`
  - `<description>-pvc`
  - `<description>-appproj`
  - `<description>-appset`
  - ...