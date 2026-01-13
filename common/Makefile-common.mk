#SHELL := /bin/bash
SHELL := /bin/zsh
# CONTAINER - AVD Universal
# "image" - ghcr.io/aristanetworks/avd/universal:python3.11-avd-v5.0.0"
HOME_DIR = $(shell pwd)
AVD_COLLECTION_VERSION ?= 5.5.1
CVP_COLLECTION_VERSION ?= 3.12.0

ANSIBLE_ARGS ?=

INVENTORY:=inventory.yml
ENV_FILE:=.env

# Calculate the number of elements in SITES
NUM_SITES := $(words $(SITES))

# This is lazy. Evaluated when used.
ARISTA_AVD_DIR=$(shell ansible-galaxy collection list arista.avd --format yaml | head -1 | cut -d: -f1)

help: ## Display help message for all Makefiles
	@grep -h -E '^[0-9a-zA-Z_-]+\.*[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

## Setup LAB Steps ##

.PHONY: clab-containerlab-build-deploy
clab-containerlab-build-deploy: ## CLAB - Build and deploy to containerlab on localhost
	export AUTO_DESTROY="True"; \
    $(MAKE) prod-build; \
	#export MGMT_STATIC_IP_DISABLED="True"; \
	$(MAKE) topgen-default containerlab-deploy clab-create-inventory clab-build; \
	#export MGMT_STATIC_IP_DISABLED=""; \
	$(MAKE) topgen-default ## Builds all the steps for the clab 

.PHONY: act-config-build-deploy-to-act
act-config-build-deploy-to-act: ## ACT - Build and deploy to act - all steps 
	export AUTO_DESTROY="True"; \
    $(MAKE) prod-build; \
	#export MGMT_STATIC_IP_DISABLED="True"; \
	$(MAKE) topgen-default; \
	#export MGMT_STATIC_IP_DISABLED=""; \
	$(MAKE) ce_act_topo_create ce_act_labs_create ## Builds all the steps for the ce act lab 
	@echo "Waiting for 5 seconds for act to create labs..."
	@sleep 5
	$(MAKE) ce_act_labs_deploy ## create labs 
	@echo -e "\n\nWhen it is done wait for the lab to fnish 5-20 minutes depending on the deploy size.";
	@echo -e "Run the inventory and act build:";
	@echo -e "make act-inventory-process act-build\n"
	@echo -e "If you have CVaaS run the register command:"
	@echo -e "make act-register-devices-to-cvaas\n"
	@echo -e "deploy configs to CVaaS:"
	@echo -e "make act-deploy-cvaas\n"
	@echo -e "To run only on one site use the SITES variable:"
	@echo -e "SITES=\"sites/site1\" make act-build\n"
	@echo -e "tools server for use to get to internet from MGMT vrf 192.168.0.6"
## Build ##

.PHONY: prod-build
prod-build: ## PROD - Build configuration. Single site SITES="sites/site1 sites/site2" make build 

	@echo "PROD: Sites - $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			FABRIC=$$(bash $(COMMON_PATH)/name-format.sh $$dir $$FABRIC_NAME_UPPER $$FABRIC_NAME;); \
			ANSIBLE_TARGET_HOSTS="PROD"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			ansible-playbook $(COMMON_PATH)/playbooks/build.yml -i "$$dir/inventory.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "fabric_name=$$FABRIC" \
			$(ANSIBLE_ARGS); \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done


.PHONY: clab-build
clab-build: ## CLAB - Build configuration. Single site or list: SITES="sites/site1 sites/site2" make build 

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			FABRIC=$$(bash $(COMMON_PATH)/name-format.sh $$dir $$FABRIC_NAME_UPPER $$FABRIC_NAME;); \
			ANSIBLE_TARGET_HOSTS="CLAB"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			ansible-playbook $(COMMON_PATH)/playbooks/build.yml -i "$$dir/inventory-containerlab.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "fabric_name=$$FABRIC" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: act-build
act-build: ## ACT - Build configuration. Single site or list: SITES="sites/site1" make build 

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			FABRIC=$$(bash $(COMMON_PATH)/name-format.sh $$dir $$FABRIC_NAME_UPPER $$FABRIC_NAME;); \
			ANSIBLE_TARGET_HOSTS="ACT"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS Hmm $$GLOBAL_VARS_FILE"; \
			ansible-playbook $(COMMON_PATH)/playbooks/build.yml -i "$$dir/inventory-act.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "fabric_name=$$FABRIC" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

## Deploy CVaaS ##

.PHONY: prod-deploy-cvaas
prod-deploy-cvaas: ## PROD - Deploy Prod AVD configs to CVaaS 
	

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="PROD"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_PROD"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_PROD"; \
			ansible-playbook $(COMMON_PATH)/playbooks/deploy-cvaas.yml -i "$$dir/inventory.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: pre-prod-deploy-cvaas
pre-prod-deploy-cvaas: ## PROD - Deploy Prod AVD configs to CVaaS 
	

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="PROD"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_LAB"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/deploy-cvaas.yml -i "$$dir/inventory.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: clab-deploy-cvaas
clab-deploy-cvaas: ## CLAB - Deploy containerlab AVD config to CVaaS

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="CLAB"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_LAB"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/deploy-cvaas.yml -i "$$dir/inventory-containerlab.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/clab" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: act-deploy-cvaas
act-deploy-cvaas: ## ACT - Deploy act AVD config to CVaaS

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="ACT"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_LAB"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/deploy-cvaas.yml -i "$$dir/inventory-act.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/act" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done


## Deploy CVaaS ##

.PHONY: prod-deploy-cvp
prod-deploy-cvp: ## PROD - Deploy Prod AVD configs to CVP
	

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="PROD"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_PROD"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_PROD"; \
			ansible-playbook $(COMMON_PATH)/playbooks/deploy-cvp.yml -i "$$dir/inventory.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done


.PHONY: clab-deploy-cvp
clab-deploy-cvp: ## CLAB - Deploy containerlab AVD config to CVP
	

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="CLAB"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_LAB"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/deploy-cvp.yml -i "$$dir/inventory-containerlab.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/clab" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: act-deploy-cvp
act-deploy-cvp: ## ACT - Deploy containerlab AVD config to CVP
	

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="ACT"; \
			export CVAAS_SERVER="$$CVP_SERVER"; \
			export CVAAS_TOKEN="$$CVP_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/deploy-cvp.yml -i "$$dir/inventory-act.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/act" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done


## Deploy eAPI ##

.PHONY: prod-deploy-eapi
prod-deploy-eapi: ## PROD - Deploy Prod AVD configs via eAPI
	

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="PROD"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_PROD"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_PROD"; \
			ansible-playbook $(COMMON_PATH)/playbooks/deploy-eapi.yml -i "$$dir/inventory.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done


.PHONY: clab-deploy-eapi
clab-deploy-eapi: ## CLAB - Deploy containerlab AVD config via eAPI
	

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="CLAB"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_LAB"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/deploy-eapi.yml -i "$$dir/inventory-containerlab.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/clab" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: act-deploy-eapi
act-deploy-eapi: ## ACT - Deploy Lab AVD config via eAPI
	

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="ACT"; \
			# export CVAAS_SERVER="$$CVAAS_SERVER_LAB"; \
			# export CVAAS_TOKEN="$$CVAAS_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/deploy-eapi.yml \
			-i "$$dir/inventory-act.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/act" \
			-vvv \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

## Register Devices to CVaaS Terminattr##

.PHONY: prod-register-devices-to-cvaas
prod-register-devices-to-cvaas: ## PROD - Register PROD device to CVaaS.
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="PROD"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_PROD"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_PROD"; \
			ansible-playbook $(COMMON_PATH)/playbooks/register-to-cv-tenant.yml -i "$$dir/inventory.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: clab-register-devices-to-cvaas
clab-register-devices-to-cvaas: ## CLAB - Register containerlab devices to cvaas.


	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="CLAB"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_LAB"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/register-to-cv-tenant.yml -i "$$dir/inventory-containerlab.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/clab" \
			-e "terminattr_interface=Management0" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: clab-register-devices-to-cvaas-vrf-mgmt
clab-register-devices-to-cvaas-vrf-mgmt: ## CLAB - Register containerlab devices to cvaas with MGMT vrf.


	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="CLAB"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_LAB"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/register-to-cv-tenant.yml -i "$$dir/inventory-containerlab.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/clab" \
			-e "terminattr_vrf=MGMT" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done


.PHONY: act-register-devices-to-cvaas
act-register-devices-to-cvaas: ## ACT - Register devices to cvaas.


	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="ACT"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_LAB"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/register-to-cv-tenant.yml -i "$$dir/inventory-act.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/act" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: act-register-devices-to-cvaas-mgmt
act-register-devices-to-cvaas-mgmt: ## ACT - Register devices to CVaaS vrf MGMT and interface101.


	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="ACT"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_LAB"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/register-to-cv-tenant.yml -i "$$dir/inventory-act.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/act" \
			-e "terminattr_vrf=$$EOS_MGMT_VRF" \
			-e "terminattr_interface=$$EOS_MGMT_VLAN" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: act-register-devices-to-cvp
act-register-devices-to-cvp: ## ACT - Register devices to cvp vm.


	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="ACT"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			ansible-playbook $(COMMON_PATH)/playbooks/register-to-cvp-tenant.yml -i "$$dir/inventory-act.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/act" \
			-e "cvp_url=$$CVP_SERVER" \
			-e "cvp_service_token=$$CVP_TOKEN_LAB" \
			-e "terminator_server=$$CVP_SERVER_LOCAL" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done


.PHONY: act-tools-server-setup
act-tools-server-setup: ## ACT - Setup tools server with needed apps.
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ansible-playbook $(COMMON_PATH)/playbooks/tools-server.yml -i "$$dir/inventory-act.yml" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: act-internet-server-setup
act-internet-server-setup: ## ACT - Run setup for internet servers
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ansible-playbook $(COMMON_PATH)/playbooks/internet-server.yml -i "$$dir/inventory-act.yml" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: act-connections
act-connections: ## ACT - Build config for ACT custom connections.
	@echo "This Makefile's command: $(SITES)"
	@set -a; \
	source $(ENV_FILE); \
	ANSIBLE_TARGET_HOSTS="ACT_CUSTOM_CONNECTIONS"; \
	ansible-playbook $(COMMON_PATH)/playbooks/act-connections.yml -i "wan/merged_inventory.yml" \
	-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
	-e "act_build=true" \
	--diff \
	$(ANSIBLE_ARGS) ;

.PHONY: act-connections-ping
act-connections-ping: ## ACT - Ping act devices.
	@echo "This Makefile's command: $(SITES)"
	@set -a; \
	source $(ENV_FILE); \
	ANSIBLE_TARGET_HOSTS="ACT_CUSTOM_CONNECTIONS"; \
	ansible-playbook $(COMMON_PATH)/playbooks/act-connections.yml -i "wan/merged_inventory.yml" \
	-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
	-e "act_deploy=true" \
	--tags ping \
	-vvv \
	--diff \
	$(ANSIBLE_ARGS) ;

.PHONY: act-connections-deploy
act-connections-deploy: ## ACT - Deploy ACT custom connections on running devices.
	@echo "This Makefile's command: $(SITES)"
	@set -a; \
	source $(ENV_FILE); \
	ANSIBLE_TARGET_HOSTS="ACT_CUSTOM_CONNECTIONS"; \
	ansible-playbook $(COMMON_PATH)/playbooks/act-connections.yml -i "wan/merged_inventory.yml" \
	-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
	-e "act_deploy=true" \
	--diff \
	$(ANSIBLE_ARGS) ;

# .PHONY: test-site1-act-connections
# test-site1-act-connections: ## Run ansible playbook to connect act devices.
# 	@echo "This Makefile's command: $(SITES)"
# 	@set -a; \
# 	source $(ENV_FILE); \
# 	ANSIBLE_TARGET_HOSTS="ACT_CONNECTIONS_SITE1"; \
# 	ansible-playbook $(COMMON_PATH)/playbooks/act-connections.yml -i "sites/site1/inventory-act.yml" \
# 	-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
# 	-e "act_build=true" \
# 	-e "act_gre_start_key=\"70000\"" \
# 	--diff \
# 	-vvv \
# 	$(ANSIBLE_ARGS) ;

# .PHONY: test-site1-act-connections-run
# test-site1-act-connections-run: ## Run ansible playbook to connect act devices.
# 	@echo "This Makefile's command: $(SITES)"
# 	@set -a; \
# 	source $(ENV_FILE); \
# 	ANSIBLE_TARGET_HOSTS="ACT_CONNECTIONS_SITE1"; \
# 	ansible-playbook $(COMMON_PATH)/playbooks/act-connections.yml -i "sites/site1/inventory-act.yml" \
# 	-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
# 	-e "act_deploy=true" \
# 	--diff \
# 	$(ANSIBLE_ARGS) ;
# ## Validate device states ##

.PHONY: prod-validate
prod-validate: ## PROD - Validate network state
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="PROD"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			ansible-playbook $(COMMON_PATH)/playbooks/validate.yml -i "$$dir/inventory.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: clab-validate
clab-validate: ## CLAB - Validate containerlab network state
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			ANSIBLE_TARGET_HOSTS="CLAB"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			ansible-playbook $(COMMON_PATH)/playbooks/validate.yml -i "$$dir/inventory-containerlab.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/clab" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

## Ping Devices ##

.PHONY: prod-ping
prod-ping: ## PROD - Ping network devices
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="PROD"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			ansible-playbook $(COMMON_PATH)/playbooks/ping.yml -i "$$dir/inventory.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: clab-ping
clab-ping: ## CLAB - Ping containerlab network state
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			ANSIBLE_TARGET_HOSTS="CLAB"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			ansible-playbook $(COMMON_PATH)/playbooks/ping.yml -i "$$dir/inventory-containerlab.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/clab" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

## Topology generations for act and clab  ##

.PHONY: topgen-default
topgen-default: ## TOPGEN - act_topgen build topology for containerlab and CE ACT

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="PROD"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			if [ -n "$$MGMT_STATIC_IP_DISABLED" ]; then \
				echo "MGMT_STATIC_IP_DISABLED True!"; \
				ansible-playbook $(COMMON_PATH)/playbooks/act_topgen.yml -i "$$dir/inventory.yml" \
				-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
				-e "clab_device_default=true" \
				-e "basename_act=$$PROJECT_NAME-$$TARGET_SITE_RAW" \
				-e "clab_name=$$PROJECT_NAME-$$TARGET_SITE_RAW" \
				-e "clab_static_mgmt_ip=''" \
				$(ANSIBLE_ARGS) ; \
			else \
				echo "MGMT_STATIC_IP_DISABLED False!"; \
				ansible-playbook $(COMMON_PATH)/playbooks/act_topgen.yml -i "$$dir/inventory.yml" \
				-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
				-e "clab_device_default=true" \
				-e "basename_act=$$PROJECT_NAME-$$TARGET_SITE_RAW" \
				-e "clab_name=$$PROJECT_NAME-$$TARGET_SITE_RAW" \
				$(ANSIBLE_ARGS) ; \
			fi; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done


.PHONY: topgen-avd
topgen-avd: ## TOPGEN - act_topgen build topology for containerlab and CE ACT attaching avd config to startup.

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS=$$(bash $(COMMON_PATH)/name-format.sh $$dir $$FABRIC_NAME_UPPER $$FABRIC_NAME;); \
			# ANSIBLE_TARGET_HOSTS="PROD"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			\
			ansible-playbook $(COMMON_PATH)/playbooks/act_topgen.yml -i "$$dir/inventory.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "basename_act=$$PROJECT_NAME-$$TARGET_SITE_RAW" \
			-e "clab_name=$$PROJECT_NAME-$$TARGET_SITE_RAW" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

# ContianerLab #######################
.PHONY: setup-bridge
setup-bridge: ## CONTAINERLAB - Setup Dummy bridge
	@if ! ip link show br-dummy > /dev/null 2>&1; then \
		echo "Creating bridge br-dummy..."; \
		sudo ip link add br-dummy type bridge; \
		sudo ip link set br-dummy up; \
	fi

.PHONY: containerlab-deploy
containerlab-deploy: ## CONTAINERLAB - Deploy containerlab ceos locally
	$(MAKE) setup-bridge
	@echo "This Makefile's command: $(SITES)"
	-@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			cd "$(HOME_DIR)/$$dir/clab"; \
			clab deploy $(ANSIBLE_ARGS); \
			if [ -n "$$AUTO_DESTROY" ]; then \
				echo "AUTO_DESTROY True!"; \
				clab destroy $(ANSIBLE_ARGS); \
			else \
				echo "AUTO_DESTROY False!"; \
			fi; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done
	$(MAKE) clab-fqdn-add-host-file

.PHONY: containerlab-destroy
containerlab-destroy: ## CONTAINERLAB - Destroy containerlab ceos locally

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			cd "$(HOME_DIR)/$$dir/clab"; \
			clab destroy $(ANSIBLE_ARGS); \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: containerlab-get-image
containerlab-get-image: ## CONTAINERLAB - Download and install cEOSarm image to docker(needs arista.com profile key)
	@set -a; \
	source $(ENV_FILE); \
	IMAGE_REPO="arista/ceos"; \
	IMAGE_NAME="$${IMAGE_REPO}:$${CEOS_ARM_IMAGE}"; \
	if docker image inspect "$$IMAGE_NAME" >/dev/null 2>&1; then \
		# If the command succeeds (exit code 0), the image exists; \
		echo "Image $${IMAGE_NAME} already exists."; \
		echo "Skipping download."; \
	else \
		echo "Downloading Image $${IMAGE_NAME}." \
		mkdir ceos_images; \
		cd ceos_images; \
		ardl get eos --format cEOSarm --version $$CEOS_ARM_IMAGE --import-docker; \
		cd ..; \
		rm -fr ceos_images; \
	fi
################################################################################
# AVD Commands
################################################################################


# ACT_CLI commands
.PHONY: ce_act_topo_create
ce_act_topo_create: ## CE_ACT - Create Act Toploogy

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- CURRENT Dir $(HOME_DIR) ---"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ce_act topology create -n "$${PROJECT_NAME}-$${TARGET_SITE_RAW}" \
			-t "$(HOME_DIR)/$$dir/act/$$PROJECT_NAME-$$TARGET_SITE_RAW.yml" \
			--topo_description "$${PROJECT_DESCIPTION}"; \
			if [ $(NUM_SITES) -gt 1 ]; then \
				echo "Multiple sites detected ($(NUM_SITES)). Pausing for 10 seconds..."; \
				sleep 10; \
			fi; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: ce_act_topo_update
ce_act_topo_update: ## CE_ACT - Update Act Toploogy
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ce_act topology update -n "$${PROJECT_NAME}-$${TARGET_SITE_RAW}" \
			-t "$(HOME_DIR)/$$dir/act/$$PROJECT_NAME-$$TARGET_SITE_RAW.yml"; \
			if [ $(NUM_SITES) -gt 1 ]; then \
				echo "Multiple sites detected ($(NUM_SITES)). Pausing for 10 seconds..."; \
				sleep 10; \
			fi; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: ce_act_labs_create
ce_act_labs_create: ## CE_ACT - Create ACT Lab
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ce_act labs create -n "$${PROJECT_NAME}-$${TARGET_SITE_RAW}" \
			-t "$$PROJECT_NAME-$$TARGET_SITE_RAW.yml" \
			-d "$${PROJECT_DESCIPTION}"; \
			if [ $(NUM_SITES) -gt 1 ]; then \
				echo "Multiple sites detected ($(NUM_SITES)). Pausing for 10 seconds..."; \
				sleep 10; \
			fi; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: ce_act_labs_deploy
ce_act_labs_deploy: ## CE_ACT - Deploy ACT Lab 
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ce_act labs action deploy -n "$${PROJECT_NAME}-$${TARGET_SITE_RAW}"; \
			if [ $(NUM_SITES) -gt 1 ]; then \
				echo "Multiple sites detected ($(NUM_SITES)). Pausing for 10 seconds..."; \
				sleep 10; \
			fi; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: ce_act_labs_start
ce_act_labs_start: ## CE_ACT - Start ACT Toploogy
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ce_act labs action start -n "$${PROJECT_NAME}-$${TARGET_SITE_RAW}"; \
			if [ $(NUM_SITES) -gt 1 ]; then \
				echo "Multiple sites detected ($(NUM_SITES)). Pausing for 10 seconds..."; \
				sleep 10; \
			fi; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: ce_act_labs_stop
ce_act_labs_stop: ## CE_ACT - Stop ACT Toploogy
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ce_act labs action stop -n "$${PROJECT_NAME}-$${TARGET_SITE_RAW}" -o yaml; \
			if [ $(NUM_SITES) -gt 1 ]; then \
				echo "Multiple sites detected ($(NUM_SITES)). Pausing for 10 seconds..."; \
				sleep 10; \
			fi; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: ce_act_topo_read
ce_act_topo_read: ## CE_ACT - Read ACT Toploogy
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ce_act topology read -n "$${PROJECT_NAME}-$${TARGET_SITE_RAW}"; \
			if [ $(NUM_SITES) -gt 1 ]; then \
				echo "Multiple sites detected ($(NUM_SITES)). Pausing for 10 seconds..."; \
				sleep 10; \
			fi; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: ce_act_labs_read
ce_act_labs_read: ## CE_ACT - Read ACT Lab
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ce_act labs read -n "$${PROJECT_NAME}-$${TARGET_SITE_RAW}"; \
			if [ $(NUM_SITES) -gt 1 ]; then \
				echo "Multiple sites detected ($(NUM_SITES)). Pausing for 10 seconds..."; \
				sleep 10; \
			fi; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done


.PHONY: act-inventory-process
act-inventory-process: ## ACT - Get inventory file from CE ACT API and make the custom inventory file
	@echo "This Makefile's command: $(SITES)"
	$(MAKE) ce_act_tools_get_yaml act-create-inventory

.PHONY: ce_act_tools_get_yaml
ce_act_tools_get_yaml: ## CE_ACT - Download ACT Inventory from CE ACT API
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p temp/; \
			ce_act labs read -n "$${PROJECT_NAME}-$${TARGET_SITE_RAW}" -o yaml > "temp/$${PROJECT_NAME}-$${TARGET_SITE_RAW}-inventory.yml"; \
			if [ $(NUM_SITES) -gt 1 ]; then \
				echo "Multiple sites detected ($(NUM_SITES)). Pausing for 10 seconds..."; \
				sleep 10; \
			fi; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: act-create-inventory
act-create-inventory: ## ACT - Create ACT inventory based on PROD inventory

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
# 			TARGET_SITE=$$(echo "$$TARGET_SITE_RAW" | tr '[:lower:]' '[:upper:]'); \
# 			FABRIC_BASENAME="_FABRIC"; \
# 			ANSIBLE_TARGET_HOSTS="$$TARGET_SITE$$FABRIC_BASENAME"; \
			ANSIBLE_TARGET_HOSTS=$$(bash $(COMMON_PATH)/name-format.sh $$dir $$FABRIC_NAME_UPPER $$FABRIC_NAME;); \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			python3 $(COMMON_PATH)/scripts/update_clab_act_inventory --inv_file "$$dir/inventory.yml" \
			--fabric_name "$$ANSIBLE_TARGET_HOSTS" \
			--site "$$TARGET_SITE_RAW" \
			--env_name "PROD" \
			--act "temp/$${PROJECT_NAME}-$${TARGET_SITE_RAW}-inventory.yml" \
			$(ANSIBLE_ARGS) ; \
			echo "python3 $(COMMON_PATH)/scripts/update_clab_act_inventory --inv_file \"$$dir/inventory.yml\" --fabric_name \"$$ANSIBLE_TARGET_HOSTS\" --site \"$$TARGET_SITE_RAW\" --env_name \"PROD\" --act \"temp/$${PROJECT_NAME}-$${TARGET_SITE_RAW}-inventory.yml\""; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: act-create-inventory2
act-create-inventory2: ## ACT - Create ACT inventory based on PROD inventory

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
# 			TARGET_SITE=$$(echo "$$TARGET_SITE_RAW" | tr '[:lower:]' '[:upper:]'); \
# 			FABRIC_BASENAME="_FABRIC"; \
# 			ANSIBLE_TARGET_HOSTS="$$TARGET_SITE$$FABRIC_BASENAME"; \
			ANSIBLE_TARGET_HOSTS=$$(bash $(COMMON_PATH)/name-format.sh $$dir $$FABRIC_NAME_UPPER $$FABRIC_NAME;); \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			python3 $(COMMON_PATH)/scripts/update_clab_act_inventory2 --inv_file "$$dir/inventory.yml" \
			--fabric_name "$$ANSIBLE_TARGET_HOSTS" \
			--site "$$TARGET_SITE_RAW" \
			--env_name "PROD" \
			--act "temp/$${PROJECT_NAME}-$${TARGET_SITE_RAW}-inventory.yml" \
			$(ANSIBLE_ARGS) ; \
			echo "python3 $(COMMON_PATH)/scripts/update_clab_act_inventory2 --inv_file \"$$dir/inventory.yml\" --fabric_name \"$$ANSIBLE_TARGET_HOSTS\" --site \"$$TARGET_SITE_RAW\" --env_name \"PROD\" --act \"temp/$${PROJECT_NAME}-$${TARGET_SITE_RAW}-inventory.yml\""; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done


.PHONY: clab-create-inventory
clab-create-inventory: ## CLAB - Create containerlab inventory based on PROD inventory

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			TARGET_SITE=$$(echo "$$TARGET_SITE_RAW" | tr '[:lower:]' '[:upper:]'); \
			FABRIC_BASENAME="_FABRIC"; \
			ANSIBLE_TARGET_HOSTS="$$TARGET_SITE$$FABRIC_BASENAME"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			python3 $(COMMON_PATH)/scripts/update_clab_act_inventory --inv_file "$$dir/inventory.yml" \
			--fabric_name "$$ANSIBLE_TARGET_HOSTS" \
			--site "$$TARGET_SITE_RAW" \
			--clab "$$dir/clab/clab-$${PROJECT_NAME}-$${TARGET_SITE_RAW}/ansible-inventory.yml" \
			--env_name "PROD" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

# yq '.all.children.SERVERS | select(.hostname == "cvp") | .internal_ip' /workspace/temp/inventory-ce_act.yaml


.PHONY: ce_act_devices_running
ce_act_devices_running: ## CE_ACT - Count the number of ACT devices running
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- CURRENT Dir $(HOME_DIR) ---"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p temp/; \
			ce_act labs read -n "$${PROJECT_NAME}-$${TARGET_SITE_RAW}" -o yaml > "temp/$${PROJECT_NAME}-$${TARGET_SITE_RAW}-inventory.yml"; \
			yq '[.[].devices.veos[]| select(.state == "Running")] | length' "temp/$${PROJECT_NAME}-$${TARGET_SITE_RAW}-inventory.yml"; \
			if [ $(NUM_SITES) -gt 1 ]; then \
				echo "Multiple sites detected ($(NUM_SITES)). Pausing for 10 seconds..."; \
				sleep 10; \
			fi; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

## Mermaid ##

.PHONY: mermaid-cli-install
mermaid-cli-install: ## MERMAID - Install docker Mermaid CLI
	@if docker image inspect minlag/mermaid-cli:latest > /dev/null 2>&1; then \
		echo "Image minlag/mermaid-cli is installed."; \
	else \
		echo -e "Image minlag/mermaid-cli is NOT installed.\nInstalling..."; \
		docker pull minlag/mermaid-cli:latest; \
	fi

.PHONY: mermaid-generate-diagram
mermaid-generate-diagram: ## MERMAID - Generate Mermaid diagram

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			TARGET_SITE=$$(echo "$$TARGET_SITE_RAW" | tr '[:lower:]' '[:upper:]'); \
			FABRIC_BASENAME="_FABRIC"; \
			ANSIBLE_TARGET_HOSTS="$$TARGET_SITE$$FABRIC_BASENAME"; \
			echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
			python3 $(COMMON_PATH)/scripts/generate_mermaid_diagram --topology_file "$$dir/act/$$PROJECT_NAME-$$TARGET_SITE_RAW.yml" \
			--diagram_name "site_diagram" \
			--avd_documentation_name \
			"$${ANSIBLE_TARGET_HOSTS}-documentation.md" \
			--topology_grouping "$$DIAGRAM_SITES" \
			--verbose ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: mermaid-docker-clean
mermaid-docker-clean: ## MERMAID - Clean all docker mermaid cli containers
	@CONTAINERS=$$(docker ps -a --filter "ancestor=minlag/mermaid-cli" --format "{{.ID}}"); \
	if [ -n "$$CONTAINERS" ]; then \
		echo "Stopping containers: $$CONTAINERS"; \
		docker stop $$CONTAINERS; \
		echo "Removing containers: $$CONTAINERS"; \
		docker rm $$CONTAINERS; \
	else \
		echo "No containers found for image minlag/mermaid-cli."; \
	fi


.PHONY: util-purge-site-configs
util-purge-site-configs: ## UTILS - Remove all the sites configs except inventory.yml and group_vars and custom connections
	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$(HOME_DIR)/$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			echo "Removing Configs"; \
			cd "$(HOME_DIR)/$$dir/"; \
			ls -1 | grep -v -e inventory.yml -e group_vars -e act | xargs rm -rf; \
			cd "$(HOME_DIR)/$$dir/act"; \
			pwd; \
			ls -1 | grep -v -e custom-connections | xargs rm -rf; \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$(HOME_DIR)/$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: act-wan-inventory-merge
act-wan-inventory-merge: ## ACT - Merge all ACT inventory sites connecitons files into wan folder

	@echo "This Makefile's command: $(SITES)"
	@python3 $(COMMON_PATH)/scripts/inventory_merge

.PHONY: act-wan-build-merge
act-wan-build-merge: ## ACT - Connecitons build and merge files

	@echo "This Makefile's command: $(SITES)"
	@python3 $(COMMON_PATH)/scripts/act_build_merge

### Studios


.PHONY: lab-studios-interface-input-get
lab-studios-interface-input-get: ## STUDIOS - Get Studios input (export) in for Campus fabric in YAML file

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p "$$dir/studios/lab"; \
			echo "$$CVAAS_SERVER_LAB"; \
			python $(COMMON_PATH)/scripts/studios_scripts/studio_update.py \
			--server "$$CVAAS_SERVER_LAB" \
			--token "$$CVAAS_TOKEN_LAB" \
			--operation get \
			--studio-id studio-campus-access-interfaces \
			--output-folder "$$dir/studios/lab" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: lab-studios-build-quick-actions
lab-studios-build-quick-actions: ## STUDIOS - Build quick actions to lab using tsv

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p "$$dir/studios/lab"; \
			echo "$$CVAAS_SERVER_LAB"; \
			python $(COMMON_PATH)/scripts/studios_scripts/studio_build_ports_for_quick_actions.py \
			--server "$$CVAAS_SERVER_LAB" \
			--token "$$CVAAS_TOKEN_LAB" \
			--file-interface-tsv "$$dir/studios/studio-campus-ports.tsv" \
			--file-interface-studio-inputs "$$dir/studios/lab/studio-campus-access-interfaces-inputs.yaml" \
			--file-interface-studio-output "$$dir/studios/lab/studio-campus-access-interfaces-inputs-new.yaml" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: lab2-studios-build-quick-actions
lab2-studios-build-quick-actions: ## STUDIOS - BETA Build quick actions to lab using tsv

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p "$$dir/studios/lab"; \
			echo "$$CVAAS_SERVER_LAB"; \
			python $(COMMON_PATH)/scripts/studios_scripts/studio_build_ports_for_quick_actions2.py \
			--server "$$CVAAS_SERVER_LAB" \
			--token "$$CVAAS_TOKEN_LAB" \
			--file-interface-tsv "$$dir/studios/studio-campus-ports.tsv" \
			--file-interface-studio-inputs "$$dir/studios/lab/studio-campus-access-interfaces-inputs.yaml" \
			--file-interface-studio-output "$$dir/studios/lab/studio-campus-access-interfaces-inputs-new.yaml" \
			--avd-intended-directory "$$dir/intended/structured_configs" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: lab-studios-interface-input-set
lab-studios-interface-input-set: ## STUDIOS - Set Studios inputs (import) for Campus fabric based on YAML file

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p "$$dir/studios/lab"; \
			echo "$$CVAAS_SERVER_LAB"; \
			python $(COMMON_PATH)/scripts/studios_scripts/studio_update.py \
			--server "$$CVAAS_SERVER_LAB" \
			--token "$$CVAAS_TOKEN_LAB" \
			--operation set \
			--studio-id studio-campus-access-interfaces \
			--yaml-file "$$dir/studios/lab/studio-campus-access-interfaces-inputs-new.yaml" \
			--build-only=True \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: lab-studios-interfaces-tsv-update
lab-studios-interfaces-tsv-update: ## STUDIOS - Build and update using tsv and make workspace.
	$(MAKE) lab-studios-interface-input-get lab-studios-build-quick-actions lab-studios-interface-input-set

# Studios lab cvp:
.PHONY: lab-studios-interface-input-get-cvp
lab-studios-interface-input-get-cvp: ## STUDIOS - Get Studios input (export) in for Campus fabric in YAML file CVP

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p "$$dir/studios/lab"; \
			echo "$$CVP_SERVER"; \
			python $(COMMON_PATH)/scripts/studios_scripts/studio_update.py \
			--server "$$CVP_SERVER:443" \
			--token "$$CVP_TOKEN_LAB" \
			--operation get \
			--studio-id studio-campus-access-interfaces \
			--output-folder "$$dir/studios/lab" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: lab2-studios-build-quick-actions-cvp
lab2-studios-build-quick-actions-cvp: ## STUDIOS - BETA Build quick actions to lab using tsv CVP

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p "$$dir/studios/lab"; \
			echo "$$CVP_SERVER"; \
			python $(COMMON_PATH)/scripts/studios_scripts/studio_build_ports_for_quick_actions2.py \
			--server "$$CVP_SERVER:443" \
			--token "$$CVP_TOKEN_LAB" \
			--file-interface-tsv "$$dir/studios/studio-campus-ports.tsv" \
			--file-interface-studio-inputs "$$dir/studios/lab/studio-campus-access-interfaces-inputs.yaml" \
			--file-interface-studio-output "$$dir/studios/lab/studio-campus-access-interfaces-inputs-new.yaml" \
			--avd-intended-directory "$$dir/intended/structured_configs" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: lab-studios-interface-input-set-cvp
lab-studios-interface-input-set-cvp: ## STUDIOS - Set Studios inputs (import) for Campus fabric based on YAML file CVP

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p "$$dir/studios/lab"; \
			echo "$$CVP_SERVER"; \
			python $(COMMON_PATH)/scripts/studios_scripts/studio_update.py \
			--server "$$CVP_SERVER:443" \
			--token "$$CVP_TOKEN_LAB" \
			--operation set \
			--studio-id studio-campus-access-interfaces \
			--yaml-file "$$dir/studios/lab/studio-campus-access-interfaces-inputs-new.yaml" \
			--build-only=True \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: lab-studios-interfaces-tsv-update-cvp
lab-studios-interfaces-tsv-update-cvp: ## STUDIOS - Build and update using tsv and make workspace.
	$(MAKE) lab-studios-interface-input-get-cvp lab2-studios-build-quick-actions-cvp lab-studios-interface-input-set-cvp


# Studios add all:
.PHONY: lab-studios-add-all-inventory-updates-cvp
lab-studios-add-all-inventory-updates-cvp: ## STUDIOS - Set Studios inventory update all

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p "$$dir/studios/lab"; \
			echo "$$CVP_SERVER"; \
			python $(COMMON_PATH)/scripts/studios_scripts/studio_onboarding2.py \
			--server "$$CVP_SERVER" \
			--token "$$CVP_TOKEN_LAB" \
			--operation set-all \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

# Studios add all:
.PHONY: lab-studios-add-all-inventory-updates-cvaas
lab-studios-add-all-inventory-updates-cvass: ## STUDIOS - Set Studios inventory update all

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p "$$dir/studios/lab"; \
			echo "$$CVAAS_SERVER_LAB"; \
			python $(COMMON_PATH)/scripts/studios_scripts/studio_onboarding2.py \
			--server "$$CVAAS_SERVER_LAB" \
			--token "$$CVAAS_TOKEN_LAB" \
			--operation set-all \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done


# Studios PROD
.PHONY: prod-studios-interface-input-get
prod-studios-interface-input-get: ## STUDIOS - Get Studios input (export) in for Campus fabric in YAML file

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p "$$dir/studios/prod"; \
			echo "$$CVAAS_SERVER_PROD"; \
			python $(COMMON_PATH)/scripts/studios_scripts/studio_update.py \
			--server "$$CVAAS_SERVER_PROD" \
			--token "$$CVAAS_TOKEN_PROD" \
			--operation get \
			--studio-id studio-campus-access-interfaces \
			--output-folder "$$dir/studios/prod" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: prod-studios-build-quick-actions
prod-studios-build-quick-actions: ## STUDIOS - Build quick actions to lab using tsv

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p "$$dir/studios/prod"; \
			echo "$$CVAAS_SERVER_PROD"; \
			python $(COMMON_PATH)/scripts/studios_scripts/studio_build_ports_for_quick_actions2.py \
			--server "$$CVAAS_SERVER_PROD" \
			--token "$$CVAAS_TOKEN_PROD" \
			--file-interface-tsv "$$dir/studios/studio-campus-ports.tsv" \
			--file-interface-studio-inputs "$$dir/studios/prod/studio-campus-access-interfaces-inputs.yaml" \
			--file-interface-studio-output "$$dir/studios/prod/studio-campus-access-interfaces-inputs-new.yaml" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done


.PHONY: prod-studios-interface-input-set
prod-studios-interface-input-set: ## STUDIOS - Set Studios inputs (import) for Campus fabric based on YAML file

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			mkdir -p "$$dir/studios/prod"; \
			echo "$$CVAAS_SERVER_LAB"; \
			python $(COMMON_PATH)/scripts/studios_scripts/studio_update.py \
			--server "$$CVAAS_SERVER_PROD" \
			--token "$$CVAAS_TOKEN_PROD" \
			--operation set \
			--studio-id studio-campus-access-interfaces \
			--yaml-file "$$dir/studios/prod/studio-campus-access-interfaces-inputs-new.yaml" \
			--build-only=True \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: prod-studios-interfaces-tsv-update
prod-studios-interfaces-tsv-update: ## STUDIOS - Build and update using tsv and make workspace.
	$(MAKE) studios-interface-input-get-prod studios-build-quick-actions-prod studios-interface-input-set-prod


# WAN Stitching

.PHONY: act-build-wan
act-build-wan: ## ACT - BETA Build WAN configuration. Single site or list: SITES="sites/site1" make build 

	@echo "This Makefile's command: $(SITES)"
	TARGET_SITE_RAW=$$(basename "wan"); \
	dir="wan"; \
	FABRIC="ACT_CUSTOM_CONNECTIONS"; \
	ANSIBLE_TARGET_HOSTS="ACT_CUSTOM_CONNECTIONS"; \
	echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
	ansible-playbook $(COMMON_PATH)/playbooks/build.yml -i "$$dir/merged_inventory.yml" \
	-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
	-e "fabric_name=$$FABRIC" \
	-e "global_vars_on=False" \
	-vvv \
	$(ANSIBLE_ARGS) ; \
	

##### AGNI

# .PHONY: agni-get-ca
# agni-get-ca: ## AGNI - get Root CA

# 	@echo "This Makefile's command: $(SITES)"
# 	@set -a; \
# 	source "$(HOME_DIR)/$(ENV_FILE)"; \
# 	TARGET_SITE_RAW=$$(basename "$$dir"); \
# 	TARGET_SITE_lower=$$(echo "$$TARGET_SITE_RAW" | tr '[:lower:]' '[:upper:]'); \
# 	ANSIBLE_TARGET_HOSTS=$$(bash $(COMMON_PATH)/name-format.sh $$dir $$FABRIC_NAME_UPPER $$FABRIC_NAME;); \
# 	ANSIBLE_TARGET_HOSTS="ACT_CUSTOM_CONNECTIONS"; \
# 	echo "FABRIC NAME: $$ANSIBLE_TARGET_HOSTS"; \
# 	python3 $(COMMON_PATH)/scripts/agni/agni-switch.py \
# 	echo "python3 $(COMMON_PATH)/scripts/agni/agni-switch.py --inv_file \"$$dir/inventory.yml\" --fabric_name \"$$ANSIBLE_TARGET_HOSTS\" --site \"$$TARGET_SITE_RAW\" --env_name \"PROD\" --act \"temp/$${PROJECT_NAME}-$${TARGET_SITE_RAW}-inventory.yml\""; \


.PHONY: agni-csr-get
agni-csr-get: ## CLAB - AGNI CSR Get certificate

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="AGNI_CERTIFICATES"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_LAB"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/agni-certificates.yml -i "$$dir/inventory-containerlab.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/clab" \
			-vvv \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: clab-tls-certificates
clab-tls-certificates: ## CLAB - TLS CSR Get certificate

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		if [ -d "$$dir" ]; then \
			echo "--- Entering $$dir ---"; \
			set -a; \
			source $(ENV_FILE); \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			ANSIBLE_TARGET_HOSTS="TLS_CERTIFICATES"; \
			export CVAAS_SERVER="$$CVAAS_SERVER_LAB"; \
			export CVAAS_TOKEN="$$CVAAS_TOKEN_LAB"; \
			ansible-playbook $(COMMON_PATH)/playbooks/tls-certificates.yml -i "$$dir/inventory-containerlab.yml" \
			-e "target_hosts=$$ANSIBLE_TARGET_HOSTS" \
			-e "root_dir={{ inventory_dir }}/clab" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done

.PHONY: clab-fqdn-add-host-file
clab-fqdn-add-host-file: ## CLAB - Add fqdn to local hostfile names

	@echo "This Makefile's command: $(SITES)"
	@for dir in $(SITES); do \
		echo "###############################"; \
		if [ -d "$$dir" ]; then \
			set -a; \
			source "$(HOME_DIR)/$(ENV_FILE)"; \
			echo "--- Entering $$dir ---"; \
			TARGET_SITE_RAW=$$(basename "$$dir"); \
			LAB_NAME="$$PROJECT_NAME-$$TARGET_SITE_RAW"; \
			echo $$LAB_NAME; \
			sudo python $(COMMON_PATH)/scripts/clab_add_host_fqdn.py \
			--domain "$$TLS_DOMAIN_NAME" \
			--lab "$$LAB_NAME" \
			$(ANSIBLE_ARGS) ; \
		else \
			echo "Warning: Directory '$$dir' not found. Skipping."; \
		fi; \
	done
