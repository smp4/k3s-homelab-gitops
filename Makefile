# lint
lint:
	clear
	yamllint .
	ansible-lint

manifest-templates:
	ansible-playbook -i ./ansible/inventory/localhost.yml --vault-id home@vault_pass ./ansible/playbooks/generate-templates.yml

site-up: site-reset
#	ansible-playbook -i ./ansible/inventory/hosts.yml --vault-id home@prompt ./ansible/playbooks/site.yml
	ansible-playbook -i ./ansible/inventory/hosts.yml --vault-id home@vault_pass ./ansible/playbooks/site.yml

# Records an ansible log in the project root directory
site-up-debug: site-reset
	rm ansible-site.log
	ANSIBLE_ENABLE_TASK_DEBUGGER=True ANSIBLE_LOG_PATH='ansible-site.log' ANSIBLE_DISPLAY_ARGS_TO_STDOUT=True bash -c 'ansible-playbook -vvv -i ./ansible/inventory/hosts.yml --vault-id home@vault_pass ./ansible/playbooks/site.yml'
	
# teardown
site-reset:
	ansible-playbook -i ./ansible/inventory/hosts.yml --vault-id home@vault_pass ./ansible/playbooks/reset.yml

# reboot
site-reboot:
	ansible-playbook -i ./ansible/inventory/hosts.yml --vault-id home@prompt ./ansible/playbooks/reboot.yml

# create argo gitops repo on local filesystem and add it as new remote to current git dir.
local-create-repo:
	mkdir -p /tmp/argo-gitops.git
	cd /tmp/argo-gitops.git && git init --bare
	git remote add local-remote file:///tmp/argo-gitops.git

# Provision a cluster on localhost only, deploying from local gitops repo
# Records an ansible log in the project root directory
local-up:
	rm ansible-local-site.log
	ANSIBLE_ENABLE_TASK_DEBUGGER=True ANSIBLE_LOG_PATH='ansible-local-site.log' ANSIBLE_DISPLAY_ARGS_TO_STDOUT=True bash -c 'ansible-playbook -vvv -i ./ansible/inventory/localhost.yml --vault-id home@vault_pass ./ansible/playbooks/site.yml'

fwd-argocd-server:
	$(info Access ArgoCD UI at https://localhost:8080)
	kubectl port-forward svc/argocd-server -n argocd 8080:443

get-argocd-initpass:
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Provision a cluster on localhost only. No deployments. 
# Records an ansible log in the project root directory
local-up-no-deploy: local-reset
	rm ansible-local-site.log
	ANSIBLE_ENABLE_TASK_DEBUGGER=True ANSIBLE_LOG_PATH='ansible-local-site.log' ANSIBLE_DISPLAY_ARGS_TO_STDOUT=True bash -c 'ansible-playbook -vvv -i ./ansible/inventory/localhost.yml --vault-id home@vault_pass ./ansible/playbooks/site.yml --skip-tags deploy'

# Deploy bootstrapped argocd from gitops repo on local filesystem to existing cluster on localhost.
local-deploy:
	kubectl apply -k /tmp/argo-gitops.git/bootstrap/overlays/default/

# Completely tear down the localhost cluster and local gitops repo.
# Records an ansible log in the project root directory
local-reset:
	rm ansible-local-reset.log
	ANSIBLE_ENABLE_TASK_DEBUGGER=True ANSIBLE_LOG_PATH='ansible-local-reset.log' ANSIBLE_DISPLAY_ARGS_TO_STDOUT=True bash -c 'ansible-playbook -vvv -i ./ansible/inventory/localhost.yml --vault-id home@vault_pass ./ansible/playbooks/reset.yml'
	rm -rfv /tmp/argo-gitops.git

seal-secrets:
	kubeseal --fetch-cert > pub-sealed-secrets.pem
	kubeseal --format=yaml --cert=pub-sealed-secrets.pem --secret-file components/envs/prod/secret-private-gh-credentials.yaml.pass --sealed-secret-file components/envs/prod/secret-private-gh-credentials-sealed.yaml
	kubeseal --format=yaml --cert=pub-sealed-secrets.pem --secret-file components/envs/prod/secret-private-gh-infra-repository.yaml.pass --sealed-secret-file components/envs/prod/secret-private-gh-infra-repository-sealed.yaml
	kubeseal --format=yaml --cert=pub-sealed-secrets.pem --secret-file components/envs/prod/secret-private-gh-infra-repository-pat.yaml.pass --sealed-secret-file components/envs/prod/secret-private-gh-infra-repository-pat-sealed.yaml
	kubeseal --format=yaml --cert=pub-sealed-secrets.pem --secret-file infrastructure/traefik/base/secret-traefik-dashboard.yaml.pass --sealed-secret-file infrastructure/traefik/base/secret-traefik-dashboard-sealed.yaml
	kubeseal --format=yaml --cert=pub-sealed-secrets.pem --secret-file infrastructure/cert-manager/base/secret-cf-token.yaml.pass --sealed-secret-file infrastructure/cert-manager/base/secret-cf-token-sealed.yaml  