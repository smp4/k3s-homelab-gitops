# Tutorial part 5: Deploy new app to cluster with `prod` infrastructure

TODO

App version shall be defined in a yaml, with no other config in that yaml. This allows it to be easily bumped and diffed, and copied over.

Note that a namespace with the pattern `<appname>-<environment>`, using the exact same wording as used in the directory structure under `tenants/` must be set up by the cluster admin in `components/namespaces`before you can deploy the app.