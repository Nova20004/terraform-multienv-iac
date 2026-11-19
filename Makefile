.DEFAULT_GOAL := help
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ENV ?= dev
TF ?= terraform
SUPPORTED_ENVS := dev staging prod

ifeq ($(filter $(ENV),$(SUPPORTED_ENVS)),)
$(error ENV must be dev, staging or prod (got '$(ENV)'))
endif

ENV_DIR := $(ROOT)/environments/$(ENV)
export ANSIBLE_CONFIG := $(ROOT)/ansible/ansible.cfg

ifneq (,$(wildcard $(ROOT)/.env))
include $(ROOT)/.env
export
endif

# One database per environment. .env holds the password and the host pieces.
# The database name is always terraform_state_<env>, so a dev plan and a
# staging plan take advisory locks in different databases.
STATE_DB_USER ?= terraform
STATE_DB_HOST ?= 127.0.0.1
STATE_DB_PORT ?= 55432
STATE_DB_SSLMODE ?= disable
export PG_CONN_STR := postgres://$(STATE_DB_USER):$(TF_VAR_state_db_password)@$(STATE_DB_HOST):$(STATE_DB_PORT)/terraform_state_$(ENV)?sslmode=$(STATE_DB_SSLMODE)

# The Docker provider does not read the CLI context. It defaults to
# unix:///var/run/docker.sock, which Docker Desktop on macOS does not create.
# Follow the active context unless the user already set DOCKER_HOST.
ifeq ($(strip $(DOCKER_HOST)),)
DETECTED_DOCKER_HOST := $(shell docker context inspect --format '{{.Endpoints.docker.Host}}' 2>/dev/null)
ifneq ($(strip $(DETECTED_DOCKER_HOST)),)
export DOCKER_HOST := $(DETECTED_DOCKER_HOST)
endif
endif

.PHONY: help env ssh-key bootstrap init plan apply configure smoke deploy destroy validate locks psql bootstrap-destroy demo

help:
	@printf '%s\n' \
		'Targets (ENV=dev|staging|prod, default dev):' \
		'  make env                 Write .env from .env.example (never overwrites)' \
		'  make ssh-key             Generate .ssh/id_ed25519 if it is missing' \
		'  make bootstrap           Start the local Postgres state database' \
		'  make init ENV=dev        terraform init -backend-config=backend.hcl' \
		'  make plan ENV=dev        terraform plan -out=tfplan' \
		'  make apply ENV=dev       plan, then apply that exact plan' \
		'  make configure ENV=dev   Ansible, without smoke tests' \
		'  make smoke ENV=dev       /health and pg_isready' \
		'  make deploy ENV=dev      apply + configure + smoke' \
		'  make demo                ssh-key + bootstrap + deploy dev' \
		'  make destroy ENV=dev     plan -destroy, then apply that plan' \
		'  make validate            fmt, terraform validate, ansible syntax-check' \
		'  make locks               Show Postgres advisory locks' \
		'  make psql                Open psql in the state database (needs a TTY)' \
		'  make bootstrap-destroy CONFIRM=yes' \
		'                           Delete the state database. Destroys ALL state.'

define REQUIRE_ENV
@test -f "$(ROOT)/.env" || { echo "Run make env (or copy .env.example and set the password)."; exit 1; }
@test -n "$(TF_VAR_state_db_password)" || { echo "TF_VAR_state_db_password is empty."; exit 1; }
@test "$(TF_VAR_state_db_password)" != "change-me-please-16" || { echo "Replace the placeholder password in .env."; exit 1; }
@test -n "$(PG_CONN_STR)" || { echo "PG_CONN_STR is empty."; exit 1; }
@case "$(PG_CONN_STR)" in *"$(TF_VAR_state_db_password)"*) ;; *) echo "PG_CONN_STR must contain TF_VAR_state_db_password."; exit 1 ;; esac
endef

# Expanded inside recipes, after ssh-key has created the file. Not parsed at
# makefile load time, so a fresh clone does not need the key to exist yet.
define WITH_SSH_KEY
TF_VAR_ssh_public_key="$$(tr -d '\n' < "$(ROOT)/.ssh/id_ed25519.pub")"
endef

ssh-key:
	mkdir -p "$(ROOT)/.ssh"
	chmod 700 "$(ROOT)/.ssh"
	@if [ ! -f "$(ROOT)/.ssh/id_ed25519" ]; then \
		ssh-keygen -t ed25519 -f "$(ROOT)/.ssh/id_ed25519" -N "" -C "terraform-multienv-iac"; \
	fi
	chmod 600 "$(ROOT)/.ssh/id_ed25519"
	@test -f "$(ROOT)/.ssh/id_ed25519.pub"
	chmod 644 "$(ROOT)/.ssh/id_ed25519.pub"

env:
	@if [ -f "$(ROOT)/.env" ]; then \
		echo ".env already exists. Leaving it untouched."; \
		exit 0; \
	fi
	@umask 077; \
	pass="$$(openssl rand -hex 24)"; \
	sed -e "s/^TF_VAR_state_db_password=.*/TF_VAR_state_db_password=$${pass}/" \
		-e "s#postgres://terraform:[^@]*@#postgres://terraform:$${pass}@#" \
		"$(ROOT)/.env.example" > "$(ROOT)/.env"
	@chmod 600 "$(ROOT)/.env"
	@echo "Wrote .env. Password set on both lines. Port left at the example value."

bootstrap:
	$(REQUIRE_ENV)
	$(TF) -chdir="$(ROOT)/bootstrap" init -input=false
	$(TF) -chdir="$(ROOT)/bootstrap" plan -input=false -out="$(ROOT)/bootstrap/tfplan"
	$(TF) -chdir="$(ROOT)/bootstrap" apply -input=false "$(ROOT)/bootstrap/tfplan"

init:
	$(REQUIRE_ENV)
	@if [ ! -f "$(ENV_DIR)/backend.hcl" ]; then cp "$(ENV_DIR)/backend.hcl.example" "$(ENV_DIR)/backend.hcl"; fi
	$(TF) -chdir="$(ENV_DIR)" init -input=false -reconfigure -backend-config=backend.hcl

plan: init ssh-key
	$(WITH_SSH_KEY) $(TF) -chdir="$(ENV_DIR)" plan -input=false -out="$(ENV_DIR)/tfplan"

apply: plan
	$(WITH_SSH_KEY) $(TF) -chdir="$(ENV_DIR)" apply -input=false "$(ENV_DIR)/tfplan"

# A recreated container generates a new SSH host key. accept-new refuses a
# changed key, so drop only this inventory's localhost ports from the lab
# known_hosts file before connecting. The personal known_hosts file is not used.
define REFRESH_HOSTKEYS
@if [ -f "$(ROOT)/.ssh/known_hosts" ]; then \
	awk '/ansible_port=/ { \
		host = ""; port = ""; \
		for (i = 1; i <= NF; i++) { \
			if ($$i ~ /^ansible_host=/) host = substr($$i, 14); \
			if ($$i ~ /^ansible_port=/) port = substr($$i, 14); \
		} \
		if (host != "" && port != "") \
			system("ssh-keygen -f \"$(ROOT)/.ssh/known_hosts\" -R \"[" host "]:" port "\" >/dev/null 2>&1 || true"); \
	}' "$(ROOT)/ansible/inventories/$(ENV)/hosts.ini"; \
fi
endef

configure:
	@command -v ansible-playbook >/dev/null || { echo "Install Ansible: python3 -m pip install -r ansible/requirements.txt"; exit 1; }
	@test -f "$(ROOT)/ansible/inventories/$(ENV)/hosts.ini" || { echo "Run make apply ENV=$(ENV) first."; exit 1; }
	$(REFRESH_HOSTKEYS)
	cd "$(ROOT)/ansible" && ansible-playbook -i "inventories/$(ENV)/hosts.ini" site.yml --skip-tags smoke

smoke:
	@command -v ansible-playbook >/dev/null || { echo "Install Ansible: python3 -m pip install -r ansible/requirements.txt"; exit 1; }
	@test -f "$(ROOT)/ansible/inventories/$(ENV)/hosts.ini" || { echo "Run make apply ENV=$(ENV) first."; exit 1; }
	$(REFRESH_HOSTKEYS)
	cd "$(ROOT)/ansible" && ansible-playbook -i "inventories/$(ENV)/hosts.ini" site.yml --tags smoke

deploy: apply configure smoke

destroy: init ssh-key
	$(WITH_SSH_KEY) $(TF) -chdir="$(ENV_DIR)" plan -destroy -input=false -out="$(ENV_DIR)/tfplan"
	$(WITH_SSH_KEY) $(TF) -chdir="$(ENV_DIR)" apply -input=false "$(ENV_DIR)/tfplan"

validate:
	cd "$(ROOT)" && $(TF) fmt -check -recursive
	@set -e; for dir in bootstrap modules/network modules/compute modules/database environments/dev environments/staging environments/prod; do \
		echo "== $$dir =="; \
		$(TF) -chdir="$(ROOT)/$$dir" init -backend=false -input=false; \
		$(TF) -chdir="$(ROOT)/$$dir" validate; \
	done
	cd "$(ROOT)/ansible" && ansible-playbook --syntax-check -i inventories/syntax/hosts.ini site.yml

locks:
	docker exec "$$($(TF) -chdir="$(ROOT)/bootstrap" output -raw container_name)" \
		psql -U "$(STATE_DB_USER)" -d "terraform_state_$(ENV)" \
		-c "SELECT locktype, classid, objid, pid, mode, granted FROM pg_locks WHERE locktype = 'advisory';"

psql:
	docker exec -it "$$($(TF) -chdir="$(ROOT)/bootstrap" output -raw container_name)" \
		psql -U "$(STATE_DB_USER)" -d "terraform_state_$(ENV)"

bootstrap-destroy:
	$(REQUIRE_ENV)
	@echo "This deletes the state Postgres volume. Every environment's Terraform state is destroyed."
	@echo "Destroy dev, staging and prod before doing this."
	@test "$(CONFIRM)" = "yes" || { echo "Refusing. Re-run with CONFIRM=yes"; exit 1; }
	$(TF) -chdir="$(ROOT)/bootstrap" init -input=false
	$(TF) -chdir="$(ROOT)/bootstrap" plan -destroy -input=false -out="$(ROOT)/bootstrap/tfplan"
	$(TF) -chdir="$(ROOT)/bootstrap" apply -input=false "$(ROOT)/bootstrap/tfplan"

demo:
	$(MAKE) ssh-key
	$(MAKE) bootstrap
	$(MAKE) deploy ENV=dev
