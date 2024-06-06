# Repository Contents

The repo contains:

* `ansible/` and `ansible.cfg`, Ansible playbooks and configuration used for provisioning a fresh cluster and triggering bootstrap deployment of the cluster workloads, and cluster teardown.
* `assets/`, containing images used in the documentation.
* `changelog.d/` directory, containing changelog fragments and settings files for `scriv`, the changelog management tool for this repo.
* A `docs/` directory, containing the raw markdown files for the project documentation.
* `bootstrap/`, `components/`, `infrastructure/` the GitOps directories for cluster bootstrap and ongoing management of the cluster configuration.
* A `tenants/` directory, which contains sample tenant applications to test your cluster is working.
* A `samples/` directory, to be used with Ansible to set up the inventory and values files. 
* A `Makefile`, providing simple access to core commands necessary to provision, deploy and tear down the cluster.
* A `requirements.txt` Python requirements file listing requirements for development of this repo.
* A `mkdocs.yml` file, configuring Material for Mkdocs, the document generation tool for this repo. 
* `README.md`, the readme.

And other various tool specific configuration files (google them).

