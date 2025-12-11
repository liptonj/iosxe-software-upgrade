# Multi-Model Environment Example

This guide shows how to manage upgrades across different Catalyst switch models in the same environment.

## Scenario

You have a mixed environment:

- 5x Catalyst 9300 switches (data center)
- 3x Catalyst 9400 switches (core)
- 2x Catalyst 9200CX switches (branch offices)
- 1x Catalyst 9350 switch (distribution)
- 1x Catalyst 3850 switch (legacy - different image)

All need to be upgraded, but the 3850 uses a different image file.

## Directory Structure

```
iosxe-software-upgrade/
├── ansible/
│   ├── inventory.ini
│   ├── group_vars/
│   │   ├── switches.yml                 # Global defaults
│   │   ├── switches.yml.template
│   │   └── legacy_switches.yml          # For 3850
│   └── host_vars/
│       └── special-switch-01.yml        # Unique overrides
```

## Step 1: Inventory Setup

**File:** `ansible/inventory.ini`

```ini
# Modern Cat9k Switches
[cat9k_switches]
dc-9300-01 ansible_host=10.1.1.10
dc-9300-02 ansible_host=10.1.1.11
dc-9300-03 ansible_host=10.1.1.12
dc-9300-04 ansible_host=10.1.1.13
dc-9300-05 ansible_host=10.1.1.14

core-9400-01 ansible_host=10.1.2.10
core-9400-02 ansible_host=10.1.2.11
core-9400-03 ansible_host=10.1.2.12

branch-9200-01 ansible_host=10.2.1.10
branch-9200-02 ansible_host=10.2.2.10

# Legacy Switches (different image)
[legacy_switches]
legacy-3850-01 ansible_host=10.3.1.10

# All switches group
[switches:children]
cat9k_switches
legacy_switches
```

## Step 2: Global Variables

**File:** `ansible/group_vars/switches.yml` (encrypted)

```yaml
---
# Global settings for all switches
ansible_connection: ansible.netcommon.network_cli
ansible_network_os: cisco.ios.ios
ansible_become: true
ansible_become_method: enable

# Credentials (encrypt with vault!)
ansible_user: admin
ansible_password: <encrypted>
ansible_become_password: <encrypted>

# FTP Server
ftp_host: 10.10.10.10
ftp_username: ftpuser
ftp_password: <encrypted>

# Default target for Cat9k switches
target_version: "17.15.04"
image_file: "cat9k_iosxe.17.15.04.SPA.bin"

# Model-specific version mapping (auto-detected)
target_versions_by_model:
  C9200: "17.15.04"
  C9200CX: "17.15.04"
  C9200L: "17.15.04"
  C9300: "17.15.04"
  C9300X: "17.15.04"
  C9350: "17.15.04"
  C9400: "17.15.04"
  C9500: "17.15.04"
  C9500X: "17.15.04"

# Model-specific image mapping (auto-detected)
image_files_by_model:
  C9200: "cat9k_iosxe.17.15.04.SPA.bin"
  C9200CX: "cat9k_iosxe.17.15.04.SPA.bin"
  C9200L: "cat9k_iosxe.17.15.04.SPA.bin"
  C9300: "cat9k_iosxe.17.15.04.SPA.bin"
  C9300X: "cat9k_iosxe.17.15.04.SPA.bin"
  C9350: "cat9k_iosxe.17.15.04.SPA.bin"
  C9400: "cat9k_iosxe.17.15.04.SPA.bin"
  C9500: "cat9k_iosxe.17.15.04.SPA.bin"
  C9500X: "cat9k_iosxe.17.15.04.SPA.bin"

# Backup settings
backup_enabled: true
backup_dir_name: "backups"
backup_to_ftp: false
```

## Step 3: Legacy Switch Group Variables

**File:** `ansible/group_vars/legacy_switches.yml`

```yaml
---
# Override for 3850 legacy switches
target_version: "16.12.10"
image_file: "cat3k_caa-universalk9.16.12.10.SPA.bin"
required_space_mb: 1024 # 3850 has less flash
install_timeout: 1800 # May take longer

# 3850 doesn't use install mode the same way
# Add specific notes or custom handling if needed
```

## Alternative: Single Global Config with Model Mapping

Instead of separate group_vars files, use model detection in main config:

**File:** `ansible/group_vars/switches.yml`

```yaml
---
# This config handles ALL models with auto-detection

# Defaults
target_version: "17.15.04"
image_file: "cat9k_iosxe.17.15.04.SPA.bin"

# Different versions for different models
target_versions_by_model:
  C9200: "17.15.04"
  C9300: "17.15.04"
  C9400: "17.12.01" # Core switches on stable release
  C9500: "17.12.01" # High-end switches on stable release
  C3850: "16.12.10" # Legacy model, different major version

# Corresponding images
image_files_by_model:
  C9200: "cat9k_iosxe.17.15.04.SPA.bin"
  C9300: "cat9k_iosxe.17.15.04.SPA.bin"
  C9400: "cat9k_iosxe.17.12.01.SPA.bin"
  C9500: "cat9k_iosxe.17.12.01.SPA.bin"
  C3850: "cat3k_caa-universalk9.16.12.10.SPA.bin"
```

**Result when running dry-run:**

```
C9300-48P  → Would upgrade to 17.15.04 using cat9k_iosxe.17.15.04.SPA.bin
C9400-LC   → Would upgrade to 17.12.01 using cat9k_iosxe.17.12.01.SPA.bin
WS-C3850   → Would upgrade to 16.12.10 using cat3k_caa-universalk9.16.12.10.SPA.bin
```

## Step 4: Per-Host Override (if needed)

If one switch needs special handling:

**File:** `ansible/host_vars/special-switch-01.yml`

```yaml
---
# This switch stays on older version
target_version: "17.09.04"
image_file: "cat9k_iosxe.17.09.04.SPA.bin"
```

## Usage Examples

### Test All Switches (Dry-Run)

```bash
# Test upgrade on ALL switches (no changes)
make upgrade-dry-run

# Output shows:
# - dc-9300-01: Would upgrade to 17.15.04 using cat9k_iosxe.17.15.04.SPA.bin
# - core-9400-01: Would upgrade to 17.15.04 using cat9k_iosxe.17.15.04.SPA.bin
# - legacy-3850-01: Would upgrade to 16.12.10 using cat3k_caa-universalk9.16.12.10.SPA.bin
```

### Upgrade by Group

```bash
# Upgrade only Cat9k switches
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  --limit cat9k_switches \
  --ask-vault-pass

# Upgrade only core switches
make upgrade LIMIT="core-9400-*"

# Upgrade only legacy switches
make upgrade LIMIT=legacy_switches
```

### Upgrade Individual Switch

```bash
# Dry-run first
make upgrade-dry-run LIMIT=dc-9300-01

# Then upgrade
make upgrade LIMIT=dc-9300-01
```

### Rolling Upgrade Strategy

```bash
# Upgrade one at a time with verification
for switch in dc-9300-01 dc-9300-02 dc-9300-03; do
  echo "Upgrading $switch..."
  make upgrade LIMIT=$switch
  sleep 300  # Wait 5 minutes between switches
done
```

## Model Detection in Action

The playbook uses regex pattern `C9(200|300|350|400|500)[A-Z]*` to detect:

| Full Model       | Detected Family | Image Selected               |
| ---------------- | --------------- | ---------------------------- |
| C9200-24P        | C9200           | cat9k_iosxe.17.15.04.SPA.bin |
| C9200CX-12P-2X2G | C9200CX         | cat9k_iosxe.17.15.04.SPA.bin |
| C9200L-48P-4G    | C9200L          | cat9k_iosxe.17.15.04.SPA.bin |
| C9300-48P        | C9300           | cat9k_iosxe.17.15.04.SPA.bin |
| C9300X-24HX      | C9300X          | cat9k_iosxe.17.15.04.SPA.bin |
| C9350-24P        | C9350           | cat9k_iosxe.17.15.04.SPA.bin |
| C9400-LC-48P     | C9400           | cat9k_iosxe.17.15.04.SPA.bin |
| C9500-16X        | C9500           | cat9k_iosxe.17.15.04.SPA.bin |
| C9500X-28C8D     | C9500X          | cat9k_iosxe.17.15.04.SPA.bin |
| WS-C3850-48P     | Unknown         | cat3k... (uses default)      |

When you run dry-run, you'll see:

```
TASK [Display switch information]
ok: [dc-9300-01] => {
    "msg": "Switch Model: C9300-48P\nModel Family: C9300\nCurrent Version: 17.06.05\nTarget Version: 17.15.04\nImage File: cat9k_iosxe.17.15.04.SPA.bin\n"
}

TASK [Display switch information]
ok: [branch-9200cx-01] => {
    "msg": "Switch Model: C9200CX-12P-2X2G\nModel Family: C9200CX\nCurrent Version: 17.18.01\nTarget Version: 17.15.04\nImage File: cat9k_iosxe.17.15.04.SPA.bin\n"
}

TASK [Display switch information]
ok: [legacy-3850-01] => {
    "msg": "Switch Model: WS-C3850-48P\nModel Family: Unknown\nCurrent Version: 16.09.08\nTarget Version: 16.12.10\nImage File: cat3k_caa-universalk9.16.12.10.SPA.bin\n"
}
```

## Variable Precedence

When multiple variable files define the same variable:

1. **host_vars/switch.yml** (highest priority)
2. **group_vars/specific_group.yml** (e.g., legacy_switches.yml)
3. **group_vars/switches.yml** (lowest priority)

## FTP Server Organization

Organize images on your FTP server:

```
ftp_server/
├── cat9k/
│   ├── cat9k_iosxe.17.15.04.SPA.bin
│   ├── cat9k_iosxe.17.09.04.SPA.bin
│   └── cat9k_iosxe.17.18.01.SPA.bin
├── cat3k/
│   ├── cat3k_caa-universalk9.16.12.10.SPA.bin
│   └── cat3k_caa-universalk9.16.09.08.SPA.bin
└── backups/
    └── (switch backups if using FTP backup)
```

Update paths in variables:

```yaml
# For Cat9k
image_file: "cat9k/cat9k_iosxe.17.15.04.SPA.bin"

# For Cat3k
image_file: "cat3k/cat3k_caa-universalk9.16.12.10.SPA.bin"
```

## Best Practices for Mixed Environments

### 1. Test by Model Type

```bash
# Test legacy switches first (lower risk)
make upgrade-dry-run LIMIT=legacy_switches

# Then test one Cat9k
make upgrade-dry-run LIMIT=dc-9300-01

# Finally test all
make upgrade-dry-run
```

### 2. Upgrade in Stages

**Week 1:** Legacy switches

```bash
make backup LIMIT=legacy_switches
make upgrade LIMIT=legacy_switches
```

**Week 2:** Branch switches

```bash
make backup LIMIT="branch-*"
make upgrade LIMIT="branch-*"
```

**Week 3:** Data center (one at a time)

```bash
for i in {01..05}; do
  make upgrade LIMIT=dc-9300-$i
  sleep 600
done
```

**Week 4:** Core switches (after hours, one at a time)

```bash
make upgrade LIMIT=core-9400-01
# Verify, then:
make upgrade LIMIT=core-9400-02
# etc.
```

### 3. Separate Maintenance Windows

```yaml
# ansible/group_vars/legacy_switches.yml
# Schedule: Saturday 2am-6am

# ansible/group_vars/cat9k_switches.yml
# Schedule: Sunday 2am-6am
```

### 4. Document Model-Specific Issues

Create notes for each model:

```yaml
# ansible/group_vars/legacy_switches.yml
---
# NOTES:
# - 3850 upgrades take ~45 minutes (vs 30 for Cat9k)
# - Must use cat3k images, not cat9k
# - Flash is limited to ~1GB free space
# - No automatic install mode conversion

target_version: "16.12.10"
image_file: "cat3k_caa-universalk9.16.12.10.SPA.bin"
required_space_mb: 900
install_timeout: 2700 # 45 minutes
```

## Verification

### Verify Variables Per Switch

```bash
# Check what image file will be used for each switch
ansible switches -i ansible/inventory.ini \
  -m debug \
  -a "msg='Host: {{ inventory_hostname }}, Image: {{ image_file }}'" \
  --ask-vault-pass

# See all variables for a specific switch
ansible -i ansible/inventory.ini \
  -m debug \
  -a "var=hostvars[inventory_hostname]" \
  dc-9300-01 \
  --ask-vault-pass
```

### Test Model Detection

```bash
# Run dry-run to see model detection
make upgrade-dry-run LIMIT=dc-9300-01

# Look for this output:
# Model Family: C9300
# Image File: cat9k_iosxe.17.15.04.SPA.bin
```

## Troubleshooting

### Model Not Detected

If model family shows "Unknown":

```yaml
# Add manual override in host_vars
# File: ansible/host_vars/unrecognized-switch.yml
image_file: "cat9k_iosxe.17.15.04.SPA.bin"
```

### Wrong Image Selected

Check the model detection regex:

- Model: `C9300-48P` → Extracts: `C9300` ✅
- Model: `WS-C3850-48P` → Extracts: `None` (not C9xxx) ✅

If needed, update the regex in the playbook for other patterns.

### Different Images for Same Model

Use host_vars for exceptions:

```bash
# One 9300 stays on older version
# File: ansible/host_vars/dc-9300-special.yml
target_version: "17.09.04"
image_file: "cat9k_iosxe.17.09.04.SPA.bin"
```

## Migration Example

Upgrading from 16.x to 17.x across mixed environment:

```bash
# 1. Backup everything
make backup

# 2. Test on one switch per model
make upgrade-dry-run LIMIT=dc-9300-01
make upgrade-dry-run LIMIT=core-9400-01
make upgrade-dry-run LIMIT=branch-9200-01
make upgrade-dry-run LIMIT=legacy-3850-01

# 3. Upgrade lab/test switches
make upgrade LIMIT=lab-switches

# 4. Rolling production upgrade
# See "Upgrade in Stages" above
```

## Advanced: Dynamic Image Selection

For even more control, override in inventory:

```ini
[switches]
sw-01 ansible_host=10.1.1.10 image_file=cat9k_iosxe.17.15.04.SPA.bin
sw-02 ansible_host=10.1.1.11 image_file=cat9k_iosxe.17.09.04.SPA.bin
```

Or use command line:

```bash
# Override image for single run
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  --limit switch01 \
  -e "image_file=cat9k_iosxe.17.15.04.SPA.bin" \
  -e "target_version=17.15.04" \
  --ask-vault-pass
```

---

**Remember**: Always test with dry-run first, especially in mixed environments! 🎯
