# Getting Started

If you're just getting started with a kubernetes homelab cluster, follow the [Installation instructions](installation.md) to get all the requirements set up. This will get you into a position ready to deploy a single node k3s cluster to your local machine.

Once you've got all of the requirements working locally, move on to the [first tutorial](../tutorials/tutorial01.md) to deploy a development K3s instance to your cluster. The tutorials then progressively upgrade the cluster to staging and production environments.

!!! note
    The progressive rollout is important and unavoidable. The initial cluster bootstrap requires the GitOps repo to be available at a location that does not require secrets to access, so we use a local git repo on one of the cluster nodes. Only once we can generate and encrypt secrets (which requires the cluster to be running), can we then migrate to a remotely hosted GitOps repo (eg. on GitHub).
    
    Additionally, the cluster uses Let's Encrypt for SSL certificates and if you deploy directly to this repo's production environment, you will be using the Let's Encrypt production endpoint. If you hit that endpoint too frequently (very likely if you don't know what you're doing), they will rate limit you and you'll have to wait a few days to use their prod endpoint again.

Many of the directories in the repo have their own `README.md` files providing further details on how to interpret and use their contents. 

So - go get started! See the [Installation](installation.md) docs. 