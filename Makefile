ENV ?= dev

.PHONY: test fmt validate plan apply destroy local k8s-render

test:            ## run API tests
	cd app/api && pytest -q

fmt:             ## format terraform
	terraform -chdir=infra fmt -recursive

validate:        ## offline terraform validation
	terraform -chdir=infra init -backend=false -input=false && terraform -chdir=infra validate

plan:            ## plan an environment: make plan ENV=prod
	terraform -chdir=infra init -reconfigure -backend-config=envs/$(ENV).backend.hcl
	terraform -chdir=infra plan -var-file=envs/$(ENV).tfvars -out=tfplan

apply:
	terraform -chdir=infra apply tfplan

destroy:         ## tear down dev to save credits
	terraform -chdir=infra destroy -var-file=envs/$(ENV).tfvars

local:           ## run all three tiers with docker compose
	docker compose up --build

k8s-render:
	kubectl kustomize k8s/overlays/$(ENV)
