.PHONY: help install test-syntax test-connectivity upgrade check-version lint clean backup backup-list restore-info

# Variables
PLAYBOOK := ansible/playbooks/upgrade_ios_xe.yml
INVENTORY := ansible/inventory.ini
VAULT_PASS := --ask-vault-pass
LIMIT ?= all

help:
	@echo "Cisco IOS-XE Upgrade Automation - Available Commands:"
	@echo ""
	@echo "Setup & Testing:"
	@echo "  make install           - Install Ansible and required collections"
	@echo "  make test-syntax       - Validate playbook syntax"
	@echo "  make test-connectivity - Test SSH connectivity to switches"
	@echo "  make check-version     - Check current IOS-XE version on all switches"
	@echo ""
	@echo "Backup & Restore:"
	@echo "  make backup            - Backup all switch configurations"
	@echo "  make backup-list       - List all backup files"
	@echo "  make restore-info      - Display restore instructions"
	@echo ""
	@echo "Upgrade Operations:"
	@echo "  make upgrade           - Run upgrade playbook (use LIMIT=switch01 for single)"
	@echo ""
	@echo "Maintenance:"
	@echo "  make lint              - Run ansible-lint on playbook"
	@echo "  make clean             - Clean up Ansible retry files and logs"
	@echo ""
	@echo "Examples:"
	@echo "  make backup                    # Backup all switch configs"
	@echo "  make backup LIMIT=switch01     # Backup single switch"
	@echo "  make upgrade LIMIT=switch01    # Upgrade single switch"
	@echo "  make upgrade LIMIT=dc1-*       # Upgrade switches matching pattern"

install:
	@echo "Installing Ansible and collections..."
	pip install -r requirements.txt
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

backup:
	@echo "Backing up switch configurations..."
	@mkdir -p backups
	ansible-playbook ansible/playbooks/backup_configs.yml \
		-i $(INVENTORY) \
		--limit $(LIMIT) \
		$(VAULT_PASS)

backup-list:
	@echo "Available configuration backups:"
	@echo "=================================="
	@if [ -d "backups" ]; then \
		ls -lht backups/ | head -20; \
	else \
		echo "No backups directory found. Run 'make backup' first."; \
	fi

restore-info:
	@echo "============================================"
	@echo "Configuration Restore Instructions"
	@echo "============================================"
	@echo ""
	@echo "To restore a configuration:"
	@echo ""
	@echo "Option 1: Via FTP (if FTP server accessible)"
	@echo "  1. Copy backup to FTP server"
	@echo "  2. On switch: copy ftp://user@host/backup.cfg running-config"
	@echo "  3. Or: configure replace ftp://user@host/backup.cfg"
	@echo ""
	@echo "Option 2: Via console/SSH"
	@echo "  1. Open backup file locally"
	@echo "  2. Copy/paste commands to switch console"
	@echo "  3. Or use: configure terminal"
	@echo ""
	@echo "Option 3: Via TFTP"
	@echo "  1. Copy backup to TFTP server"
	@echo "  2. On switch: copy tftp://host/backup.cfg running-config"
	@echo ""
	@echo "Recent backups:"
	@if [ -d "backups" ]; then \
		ls -lt backups/*.cfg 2>/dev/null | head -5 || echo "No backup files found"; \
	else \
		echo "No backups directory found"; \
	fi
	@echo "============================================"

