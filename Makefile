.PHONY: help install test-syntax test-connectivity upgrade check-version lint clean

# Variables
PLAYBOOK := ansible/playbooks/upgrade_ios_xe.yml
INVENTORY := ansible/inventory.ini
VAULT_PASS := --ask-vault-pass
LIMIT ?= all

help:
	@echo "Cisco IOS-XE Upgrade Automation - Available Commands:"
	@echo ""
	@echo "  make install           - Install Ansible and required collections"
	@echo "  make test-syntax       - Validate playbook syntax"
	@echo "  make test-connectivity - Test SSH connectivity to switches"
	@echo "  make check-version     - Check current IOS-XE version on all switches"
	@echo "  make upgrade           - Run upgrade playbook (use LIMIT=switch01 for single)"
	@echo "  make lint              - Run ansible-lint on playbook"
	@echo "  make clean             - Clean up Ansible retry files and logs"
	@echo ""
	@echo "Examples:"
	@echo "  make upgrade LIMIT=switch01    # Upgrade single switch"
	@echo "  make upgrade LIMIT=dc1-*       # Upgrade switches matching pattern"
	@echo "  make check-version             # Check all switches"

install:
	@echo "Installing Ansible and collections..."
	pip install ansible ansible-lint yamllint
	ansible-galaxy collection install -r ansible/requirements.yml
	@echo "Installation complete!"

test-syntax:
	@echo "Validating playbook syntax..."
	ansible-playbook $(PLAYBOOK) --syntax-check
	@echo "Syntax check passed!"

test-connectivity:
	@echo "Testing connectivity to switches..."
	ansible switches -i $(INVENTORY) -m ping $(VAULT_PASS)

check-version:
	@echo "Checking current IOS-XE versions..."
	ansible switches -i $(INVENTORY) \
		-m cisco.ios.ios_command \
		-a "commands='show version | include Version'" \
		$(VAULT_PASS)

upgrade:
	@echo "Running IOS-XE upgrade playbook..."
	@echo "Target: $(LIMIT)"
	ansible-playbook $(PLAYBOOK) \
		-i $(INVENTORY) \
		--limit $(LIMIT) \
		$(VAULT_PASS) \
		-vv

upgrade-verbose:
	@echo "Running IOS-XE upgrade playbook (verbose)..."
	ansible-playbook $(PLAYBOOK) \
		-i $(INVENTORY) \
		--limit $(LIMIT) \
		$(VAULT_PASS) \
		-vvv

lint:
	@echo "Running ansible-lint..."
	ansible-lint $(PLAYBOOK)
	@echo "Running yamllint..."
	yamllint ansible/

clean:
	@echo "Cleaning up..."
	find . -name "*.retry" -delete
	find . -name "*.log" -delete
	@echo "Cleanup complete!"

vault-encrypt:
	@echo "Encrypting group_vars/switches.yml..."
	ansible-vault encrypt ansible/group_vars/switches.yml

vault-decrypt:
	@echo "Decrypting group_vars/switches.yml..."
	ansible-vault decrypt ansible/group_vars/switches.yml

vault-edit:
	@echo "Editing encrypted variables..."
	ansible-vault edit ansible/group_vars/switches.yml

vault-view:
	@echo "Viewing encrypted variables..."
	ansible-vault view ansible/group_vars/switches.yml

