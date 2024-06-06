# Adding new nodes to the cluster

Do this manually or tear down and re-provision the cluster with an updated inventory file. The Ansible playbooks are not designed to add new nodes to an existing cluster.

!!! warning
        All nodes need to be running the same version of k3s. So, if using the k3s installation script to set up a new node, watch out that it will install the latest stable k3s version, which may be more current than the versions currently running in the cluster. Upgrade the cluster, or install an older k3s version on the new node.