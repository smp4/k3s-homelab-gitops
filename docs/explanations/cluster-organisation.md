# Cluster organisation and GitOps approach

## Cluster

The GitOps approach assumes a single cluster and that ArgoCD and all managed applications are installed inside the same cluster. It will be one large shared cluster acting like a [general purpose infrastructure platform](https://learnk8s.io/how-many-clusters) for homelab workloads.

On the plus side, this means only one copy of the cluster infrastructure (load balancer, ingress, monitoring etc) is needed and can be shared by all workloads. It is also easier to administrate than having multiple clusters for each app.

Downsides of this architecture include the risk that non-prod instances can starve prod instances of resources, poorer security, risk of non-prod config errors impacting prod....etc. See [learning k8s](https://learnk8s.io/how-many-clusters).

## Environments

Kustomize is used to create `base` workload configurations with environment-specific modifications stored in individual overlay directories per environment. The repo *does not* use branching for different environments. 

To activate an environment for a workload (which will be deployed as an ArgoCD Application), simply include a `config.json` file in the desired environment directory.

## ArgoCD Projects

With the exception of the `kube-system` namespace, cluster workloads are entirely managed by ArgoCD. ArgoCD organises namespaces into projects. From the [ArgoCD docs](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/):

> Projects provide the following features:
>
> * restrict what may be deployed (trusted Git source repositories)
> * restrict where apps may be deployed to (destination clusters and namespaces)
> * restrict what kinds of objects may or may not be deployed (e.g. RBAC, CRDs, DaemonSets, NetworkPolicy etc...)
> * defining project roles to provide application RBAC (bound to OIDC groups and/or JWT tokens)
>
> Additional projects can be created to give separate teams different levels of access to namespaces.
>
> If unspecified, an application belongs to the default project, which is created automatically and by default, permits deployments from any source repo, to any cluster, and all resource Kinds. The default project can be modified, but not deleted.

[Note](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/):

> Projects with access to the namespace in which Argo CD is installed effectively have admin-level privileges.


## ArgoCD Applications

An application may consistent of multiple components (ie. separate containers for frontend, backend, database), managed as (possibly) an App of Apps pattern via ArgoCD, and deployments of that application into each of its required environments constitute discrete, separate *instances* of that application. That is, the number of application instances is the number of apps multiplied by the number of (activated) environments within which those apps are to be deployed.


## Separating teams with Kubernetes objects

For a single user, most of the below is unnecessary, but it has been implemented for practice.

- ArgoCD AppProjects delineate which users can deploy what, where (even if in this homelab case, there is only one user). The Ops team uses the default ArgoCD project, `default`, which permits all source repos, namespaces and destinations. The assumption here is that the Ops team are admins and they know what they're doing. Cluster infrastructure is deployed within this project.
- Developers receive their own ArgoCD AppProject(s). The cluster is bootstrapped with a single AppProject, `dev1`. This restricts the source repo to the `tenants` directory of the GitOps repo and deployments to the local cluster only. Additionally, `kube-system` and `argocd` namespaces are denied. This should support "dev team self service". See the [ArgoCD example](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Use-Cases/#use-case-self-service-of-argo-cd-applications-on-multitenant-clusters).
- Environments are created per app instance and each instance has its own namespace, for example `myapp-stage`, to provide logical separation within the cluster.
- Operations teams to easily deploy cluster infrastructure add-ons using the `infrastructure` ApplicationSet. 


## Notes on security

Note that using namespaces for each app instance provides logical separation only, **namespaces do not provide isolation and security between Kubernetes resources**. [Unless you take active steps against it, all communication inside a Kubernetes cluster is allowed by default. And contrary to popular belief a pod from one namespace can freely communicate with a pod on another namespace.](https://codefresh.io/blog/kubernetes-antipatterns-2/). Kubernetes namespaces are not a security measure.

Furthermore, ensure that ***only* admins have the right to write/ merge into the cluster GitOps repo**, to avoid accidental or malicious deployments. See [ArgoCD docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Security/) for more. For further access controls use dev self-service with ApplicationSets, see [Appset in any namespace](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Appset-Any-Namespace/).

For homelab use, I am the only person with admin access to the nodes, cluster control plane APIs and GitOps repo, so the `dev1` project is set up simply to make sure tenant workloads are not inadvertently deployed to the wrong cluster or admin-level namespaces.

## GitOps repo directory structure

The repo structure attempts to merge guidance from [Codefresh](https://codefresh.io/blog/how-to-model-your-gitops-environments-and-promote-releases-between-them/) on modelling environments and [Red](https://developers.redhat.com/articles/2022/09/07/how-set-your-gitops-directory-structure) [Hat](https://github.com/christianh814/example-kubernetes-go-repo) on directory structure best practice. It should reflect a monorepo approach where Ops and Dev both work together in the same GitOps repository.

- Ops deployments (cluster infrastructure) reside in `infrastructure`, developer deployments (apps) reside in `tenants`.
- `components` are cluster resources defined and owned by Ops. These are **Kubernetes specific settings** for infrastructure and applications, such as namespaces, replicas, resource limits, health checks, persistent volumes, affinity rules etc.
- Each application contains a `base` directory containing configuration common to all instances of that workload across all of its environments. It should not change often. This is where environment configuration is **mostly static business settings**. These are settings that having nothing to do with Kubernetes, they never get promoted between environment types (ie. never from stage to prod), and are applicable to all environments of a given type on this cluster (ie. applicable to every staging environment used by an app). Things like the URLs that a production environment should use. Some or all of the structure of this directory may be replicated with an environment directory to apply environment configuration specific to that workload. 
- The `bootstrap` directory contains everything needed (and no more) to initialise the cluster. Ansible provisions the bare cluster and bootstraps the GitOps controller (ArgoCD) from the resources in this directory. 

Extensions (not implemented):

- Use a `variants` directory to define settings common to a certain type of environment (eg. all `stage` environments) or other aspect common between multiple environments. An example might be authentication values for a validation database to be used in non-production environments. When the application instance is deployed, it will inherit both cluster-wide and app-specific configuration for its environment instance from these directories.

### Infrastructure applications

The level 1 directory `infrastructure` (the repository root directory is level 0) contains infrastructure applications that will be shared by all applications deployed to the cluster. The `infrastructure-appset` automatically deploys each app with a level 2 directory inside `infrastructure`.

Only one instance of an infrastructure application should ever be deployed, no matter whether that instance is in a qa, dev, stage or prod environment. Therefore level 4 environment directories (for example `infrastructure/my-infra-app/envs/level-4-env-dir`) are *not* used.

There is only ever one namespace per infrastructure app, named after the application name, eg. `my-infra-app`.


### Tenant applications

Tenant applications reside in the `tenants` level 1 directory. By default, the `tenants-appset` automatically deploys each app with a level 2 directory inside `tenants`. Other ApplicationSet objects may be created in the future by ops if needed, to deploy app with different configuration.

In contrast to infrastructure application behaviour, tenant applications can have any number of environments defined and deployed simultaneously. Each app-environment instance will have its own namespace `<myapp>-<env>`. 

In theory, namespaces should only be defined by ops in `components`, which means the required namespaces must be defined by ops before dev sets up the app deployment configuration in `dev`. The template does *not* currently implement this.

Two example tenant applications are provided by default, to verify the ingress and the load balancer.

## Templating vs patching

As [summarised](https://developers.redhat.com/articles/2022/09/07/how-set-your-gitops-directory-structure#structuring_your_git_repositories) by Red Hat, a key objective of setting up the GitOps repo is to keep it DRY (Don't Repeat Yourself), aka have a single source of truth. This means using Kustomize and/ or Helm for building up the YAML configuration files.

Kustomize uses a patching method which is best when the operator already knows the configurations and deltas beforehand. When you don't know the values beforehand, Helm works much better. Helm uses a templating method that makes it easier to change a variable in many places at once you know what it should be.

Both methods are useful and the repo should probably use both tools as needed (which it does). There is no rule that says only one tool should be used.

An alternative for bootstrapping can be to use Ansible to generate the initial Kustomize YAML from Ansible templates. The readability of the resulting repo is pretty poor, requiring the operator to either do a dummy run of the Ansible playbook to generate the Kustomize yaml to see what it would look like, or try to infer it from the Ansible templates. Not to mention that there are now two tools working together, where perhaps one might have been better (Helm). Examples are [here](https://github.com/reefland/ansible-k3s-argocd-renovate/tree/master) and [here](https://github.com/ricsanfre/pi-cluster).

The ArgoCD ApplicationSet object also allows a form of templating.

For general ease of use, it is common to use Helm for third party workloads that others have pre-packaged, and Kustomize for your own custom workloads.

For several of the infrastructure workloads, Helm and Kustomize are used together. The Helm Chart for the workload is "hydrated" by Kustomize, allowing the easy modification of the generic Chart via the available Helm values, and then overlaid with further environment specific modifications as necessary with Kustomize. See the Traefik workload, for example.