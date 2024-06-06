# Tutorial

In its initial state, this template deploys to a `dev` environment. The tutorials follow an incremental approach to eventually deploy to production:

- Start with a `dev` state for testing on your localhost with no *Let's Encrypt* interaction, then
- Deploys the `dev` configuration to all nodes in the cluster, then
- Deploys to a `stage` configuration to all nodes in the cluster to test syncing from a remote repo (GitHub) and certificate issuance from the *Let's Encrypt* staging API, then finally
- Deploys to a `prod` state on the whole cluster, which just changes to the production API on *Let's Encrypt*. 

*Let's Encrypt* has rate limiting on their production API, so it's good to make sure everything is working on staging first. The cluster can be torn down at any time if you wish to restart from a clean state.

In summary:

| Step                     | State   | Nodes            | GitOps repo location                            | `cert-manager` authority       |
| ------------------------ | ------- | ---------------- | ----------------------------------------------- | ------------------------------ |
| [Part 01](tutorial01.md) | `dev`   | `localhost` only | Local filesystem on `localhost` with `hostPath` | self-signed                    |
| [Part 02](tutorial02.md) | `dev`   | All nodes        | Local filesystem on master node with `hostPath` | self-signed                    |
| [Part 03](tutorial03.md) | `stage` | All nodes        | Remotely hosted repo                            | *Let's Encrypt* staging API    |
| [Part 04](tutorial04.md) | `prod`  | All nodes        | Remotely hosted repo                            | *Let's Encrypt* production API |

[Part 05](tutorial05.md) deploys a new app to the production cluster.

## Activating environments

The presence of a `config.json` file in an environment directory of a workload is a marker to, and provides configuration for, ArgoCD, our GitOps deployment manager. This file tells Argo to deploy the kubernetes configuration present in that directory. Unused environments will have their `config.json` files renamed to `config.json.ignore`. 

The cluster configuration assumes that only one deployment environment is active for any one infrastructure workload at a time. If this rule is violated, you will probably experience networking conflicts.

That's enough - go get started with [Part 01](tutorial01.md).