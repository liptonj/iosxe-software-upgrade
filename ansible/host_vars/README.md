# Host-Specific Variables

This directory allows you to override variables for individual switches.

## Usage

Create a file named after your switch (from inventory) with specific overrides:

### Example: Override Image File for Specific Switch

If you have a switch that needs a different image file:

**File:** `ansible/host_vars/switch01.yml`

```yaml
---
# Override for switch01
image_file: "cat9k_iosxe.17.09.04.SPA.bin" # Different version
target_version: "17.09.04"
```

### Example: Different Model Requiring Different Image

**File:** `ansible/host_vars/old-switch-01.yml`

```yaml
---
# Older 3850 model needs different image
image_file: "cat3k_caa-universalk9.16.12.10.SPA.bin"
target_version: "16.12.10"
required_space_mb: 1024 # Smaller flash on 3850
```

### Example: Override FTP Server

**File:** `ansible/host_vars/remote-site-switch.yml`

```yaml
---
# Remote site uses different FTP server
ftp_host: 192.168.100.10
ftp_username: remote_ftp_user
ftp_password: different_password # Encrypt with vault!
```

### Example: Disable Backup for Specific Switch

**File:** `ansible/host_vars/lab-switch-01.yml`

```yaml
---
# Lab switch - skip backups
backup_enabled: false
```

## Variable Precedence

Ansible variable precedence (highest to lowest):

1. **Command line** (`-e "image_file=..."`)
2. **host_vars** (this directory)
3. **group_vars/switches.yml**
4. **Playbook vars**
5. **Playbook defaults**

## Security

**Encrypt host_vars files** that contain credentials:

```bash
# Encrypt a host_vars file
ansible-vault encrypt ansible/host_vars/switch01.yml

# Edit encrypted host_vars
ansible-vault edit ansible/host_vars/switch01.yml
```

## Mixed Environment Example

### Inventory

```ini
[switches:children]
cat9300_switches
cat9400_switches
old_3850_switches

[cat9300_switches]
sw-9300-01 ansible_host=10.1.1.10
sw-9300-02 ansible_host=10.1.1.11

[cat9400_switches]
sw-9400-01 ansible_host=10.1.2.10

[old_3850_switches]
sw-3850-01 ansible_host=10.1.3.10
```

### Group Variables

**File:** `ansible/group_vars/old_3850_switches.yml`

```yaml
---
# Older 3850 switches use different image
image_file: "cat3k_caa-universalk9.16.12.10.SPA.bin"
target_version: "16.12.10"
required_space_mb: 1024
```

**File:** `ansible/group_vars/cat9300_switches.yml`

```yaml
---
# Cat9300 specific settings
image_file: "cat9k_iosxe.17.15.04.SPA.bin"
target_version: "17.15.04"
```

## Best Practices

1. ✅ Use **group_vars** for groups of similar switches
2. ✅ Use **host_vars** for unique per-switch configuration
3. ✅ Keep sensitive data encrypted
4. ✅ Document why overrides exist (comments)
5. ✅ Test with dry-run first: `make upgrade-dry-run LIMIT=switch01`

## Testing Host Variables

```bash
# Test what variables a specific host will use
ansible -i ansible/inventory.ini -m debug -a "var=hostvars[inventory_hostname]" switch01

# Check which image file will be used
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  --limit switch01 \
  -e "dry_run=true" \
  --ask-vault-pass
```

---

**Remember**: The playbook automatically detects switch models and selects the appropriate image! 🎯
