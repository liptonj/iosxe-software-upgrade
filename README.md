# Cisco IOS-XE Catalyst 9300 Upgrade Automation

Automated upgrade playbook for Cisco Catalyst 9300 switches running IOS-XE using Ansible.

**Platforms**: Linux, macOS, and Windows | **📘 Windows users**: See [WINDOWS.md](WINDOWS.md) for Windows-specific setup

## Features

- ✅ **Automatic configuration backup** before upgrades
- ✅ **Automatic model detection** and image file selection
- ✅ **Per-model version mapping** (different versions for different models)
- ✅ **Dry-run mode** to test workflow without changes
- ✅ **Multiple execution modes** (serial, batched, parallel)
- ✅ **Modular task structure** for easy maintenance (NEW ⭐)
- ✅ Automated version checking and upgrade
- ✅ Bundle to Install mode conversion
- ✅ Flash space verification
- ✅ Old boot variable cleanup
- ✅ FTP-based image transfer
- ✅ Post-upgrade verification
- ✅ Standalone backup playbook for anytime backups
- ✅ Support for multiple switch models (9200, 9300, 9400, 9500)
- ✅ Uses only native `cisco.ios` collection modules

## Playbook Architecture

**Fully Modular & Atomic Design** for maximum maintainability and reusability:

- **Main playbook** (`upgrade_ios_xe.yml`) - Clean orchestrator (~100 lines)
- **23 atomic tasks** - Organized by function (common, backup, boot, flash, install, test, verify)
- **10 aggregators** - Group related atomic tasks
- **All playbooks** - Use the same atomic tasks (no duplication)

Each atomic task handles ONE responsibility and can be reused in any playbook.

📖 **See [ARCHITECTURE.md](ARCHITECTURE.md) for complete architecture overview**  
📖 **See [REFACTORING.md](REFACTORING.md) for details on task structure**  
📖 **See [tasks/STRUCTURE.md](ansible/playbooks/tasks/STRUCTURE.md) for atomic task organization**

## Prerequisites

### 1. Ansible Installation

**Linux/macOS:**

```bash
# Run automated setup
./setup_venv.sh

# Or manually:
pip install ansible
ansible-galaxy collection install cisco.ios
```

**Windows:**

```powershell
# Run automated setup
.\setup_venv.bat

# Or manually:
pip install ansible
ansible-galaxy collection install cisco.ios
```

📘 **Windows users**: See [WINDOWS.md](WINDOWS.md) for complete setup guide

### 2. Network Requirements

- SSH access to all target switches
- FTP server with IOS-XE image file accessible from switches
- Management network connectivity

### 3. Switch Requirements

- Cisco Catalyst 9300 series switches
- IOS-XE 16.x or 17.x
- Sufficient flash space (~2GB free recommended)
- Switch in either Bundle or Install mode (playbook handles both)

## Configuration

### 1. Inventory Setup

Edit `ansible/inventory.ini` and add your switches:

```ini
[switches]
switch01 ansible_host=10.1.1.10
switch02 ansible_host=10.1.1.11
switch03 ansible_host=10.1.1.12
```

### 2. Variables Configuration (IMPORTANT!)

**Step 1**: Create your variables file from the template:

```bash
# Copy the template
cp ansible/group_vars/switches.yml.template ansible/group_vars/switches.yml

# Edit with your actual credentials
vim ansible/group_vars/switches.yml
```

**Step 2**: Update these values in `switches.yml`:

```yaml
# Switch credentials
ansible_user: admin
ansible_password: YOUR_SWITCH_PASSWORD_HERE
ansible_become_password: YOUR_ENABLE_PASSWORD_HERE

# FTP Server Configuration
ftp_host: 10.10.10.10
ftp_username: ftpuser
ftp_password: YOUR_FTP_PASSWORD_HERE

# Target version
target_version: "17.15.04"
image_file: "cat9k_iosxe.17.15.04.SPA.bin"
```

### 3. Encrypt Credentials (REQUIRED!)

**⚠️ CRITICAL**: Never commit unencrypted credentials to git!

```bash
# Encrypt the variables file
ansible-vault encrypt ansible/group_vars/switches.yml

# Enter a strong vault password when prompted
# SAVE THIS PASSWORD SECURELY (password manager, team vault, etc.)
```

**The `switches.yml` file is in `.gitignore`** - it won't be committed to git.  
**The `switches.yml.template` is committed** - safe to share with team.

📖 **For detailed setup instructions**, see [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md)

## Usage

### Pre-Flight Check (Syntax Validation)

```bash
# Validate playbook syntax
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini --syntax-check

# Dry-run check (connects but makes no changes)
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini --check
```

### Test Upgrade Workflow (Dry-Run) 🔍

**IMPORTANT**: Always test with dry-run first!

```bash
# Dry-run - Test WITHOUT making changes
make upgrade-dry-run

# Dry-run on specific switch
make upgrade-dry-run LIMIT=switch01

# Or use ansible-playbook directly
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  -e "dry_run=true" \
  --ask-vault-pass
```

**Dry-run shows what WOULD happen:**

- ✅ Checks version and boot mode
- ✅ Verifies flash space
- ✅ Shows what would be backed up
- ✅ Shows what would be cleaned
- ✅ Shows what would be transferred
- ✅ Shows estimated downtime
- ❌ Does NOT make any changes
- ❌ Does NOT transfer files
- ❌ Does NOT upgrade switches

### Execute Upgrade (Live Mode) ⚡

**After testing with dry-run, choose an execution mode:**

#### Serial Mode (RECOMMENDED for Production) 🛡️

```bash
# Upgrade ONE switch at a time (safest)
make upgrade-serial

# Stops immediately if any switch fails
# Expected duration: N switches × 40 minutes
```

#### Batched Mode (2 at a time)

```bash
# Upgrade 2 switches at a time
make upgrade-batch

# Waits for both before starting next batch
# Aborts if >25% fail
```

#### Parallel Mode (Fastest, Higher Risk)

```bash
# Upgrade up to 5 switches simultaneously
make upgrade

# ⚠️ WARNING: Multiple switches down at once
# Use only in lab/test environments
```

#### Single Switch

```bash
# Upgrade one specific switch
make upgrade LIMIT=switch01

# Or use ansible-playbook directly
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  --limit switch01 \
  --ask-vault-pass
```

📖 **For detailed execution strategies and failure handling**, see [EXECUTION_MODES.md](EXECUTION_MODES.md)

## Configuration Backup

### Automatic Backups

**Backups are automatically created before every upgrade!** Configuration files are saved to the `./backups` directory with timestamps.

**Backup files created**:

- `{hostname}_running-config_{timestamp}.cfg` - Running configuration
- `{hostname}_startup-config_{timestamp}.cfg` - Startup configuration
- `{hostname}_summary_{timestamp}.txt` - Configuration summary

### Manual Backup Anytime

```bash
# Backup all switches
make backup

# Backup specific switch
make backup LIMIT=switch01

# Or use the playbook directly
ansible-playbook ansible/playbooks/backup_configs.yml \
  -i ansible/inventory.ini \
  --ask-vault-pass
```

### List and Manage Backups

```bash
# List recent backups
make backup-list

# Show restore instructions
make restore-info

# Find specific backup
ls -lh backups/*switch01*
```

### Configuration Options

In `ansible/group_vars/switches.yml`:

```yaml
# Enable/disable automatic backups (default: true)
backup_enabled: true

# Backup directory location
backup_dir: "./backups"

# Also backup to FTP server (optional)
backup_to_ftp: false
```

**📖 For complete backup and restore procedures**, see [BACKUP_RESTORE.md](BACKUP_RESTORE.md)

## Multi-Model Support

### Automatic Model Detection

The playbook **automatically detects** your switch model and selects the appropriate image file!

**Supported Models:**

- Catalyst 9200 Series: C9200, C9200CX, C9200L
- Catalyst 9300 Series: C9300, C9300X
- Catalyst 9350 Series: C9350
- Catalyst 9400 Series: C9400
- Catalyst 9500 Series: C9500, C9500X

### How It Works

1. Playbook gathers facts from switch
2. Detects model family (C9200, C9300, etc.)
3. Looks up image file in `image_files_by_model` dictionary
4. Falls back to default `image_file` if model not mapped

### Configure Model-Specific Versions and Images

In `ansible/group_vars/switches.yml`:

```yaml
# Defaults
target_version: "17.15.04"
image_file: "cat9k_iosxe.17.15.04.SPA.bin"

# Model-specific version mapping (optional)
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
  # C3850: "16.12.10"  # Older models may require different version

# Model-specific image mapping (optional)
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
  # C3850: "cat3k_caa-universalk9.16.12.10.SPA.bin"
```

**Example: Mixed versions for different models**

```yaml
target_versions_by_model:
  C9300: "17.15.04" # Latest for 9300
  C9400: "17.12.01" # Core switches stay on stable release
  C3850: "16.12.10" # Older model, different version entirely

image_files_by_model:
  C9300: "cat9k_iosxe.17.15.04.SPA.bin"
  C9400: "cat9k_iosxe.17.12.01.SPA.bin"
  C3850: "cat3k_caa-universalk9.16.12.10.SPA.bin"
```

### Per-Switch Overrides

For individual switches with unique requirements, create host_vars:

**File:** `ansible/host_vars/special-switch.yml`

```yaml
---
image_file: "cat9k_iosxe.17.09.04.SPA.bin"
target_version: "17.09.04"
```

📖 **See [ansible/host_vars/README.md](ansible/host_vars/README.md) for more examples**

## Playbook Workflow

The playbook performs the following steps:

1. **Pre-Flight Checks**

   - Gathers current IOS-XE version
   - Skips upgrade if already at target version

2. **Configuration Backup** ✨

   - Creates timestamped backup files
   - Saves running-config to Ansible controller
   - Saves startup-config
   - Creates configuration summary
   - Optional FTP backup

3. **Boot Mode Check**

   - Checks boot mode (Bundle vs Install)
   - If Bundle mode: Clears all old boot variables

4. **Pre-Installation Preparation** ✨ IMPROVED

   - Saves running-config to startup-config
   - **Removes inactive packages FIRST** (if install mode) - frees up space
   - **Verifies flash space AFTER cleanup** (~2GB required)
   - Fails if insufficient space

5. **Image Transfer**

   - Transfers new image via FTP
   - Configurable timeout (default 900s)
   - Only starts after confirming sufficient space

6. **Installation and Upgrade**

   - Runs `install add file activate commit`
   - Handles prompts automatically
   - Converts bundle to install mode automatically
   - Switch reboots automatically

7. **Post-Upgrade Verification**

   - Waits for switch to reload and reconnect
   - Verifies new version matches target
   - Confirms install mode is active
   - Reports success/failure

## Troubleshooting

### Common Issues

**1. Insufficient Flash Space**

```
Error: Insufficient flash space. Available: 1500 MB, Required: 2048 MB
```

**Solution**: Free up space manually or reduce `required_space_mb` variable.

**2. FTP Transfer Timeout**

```
Error: Connection timeout during FTP transfer
```

**Solution**: Increase `ansible_command_timeout` or check FTP server connectivity.

**3. SSH Connection Issues**

```
Error: Failed to connect to the host via ssh
```

**Solution**: Verify SSH is enabled on switch and credentials are correct.

### Enable Debug Output

```bash
# Maximum verbosity
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini -vvvv
```

## Safety Features

- ✅ Version verification before upgrade
- ✅ Flash space validation
- ✅ Configuration backup before changes
- ✅ Post-upgrade version verification
- ✅ Automatic failure on version mismatch
- ✅ Idempotent (safe to run multiple times)

## Security Best Practices

1. **Never commit plain-text credentials** to version control
2. **Use Ansible Vault** for all sensitive data
3. **Restrict FTP access** to management network only
4. **Use SSH keys** instead of passwords where possible
5. **Test in lab environment** before production deployment

## Testing

### Pre-Production Testing

1. **Test in Lab**

   - Always test on non-production switches first
   - Verify compatibility with your specific hardware/software combination

2. **Syntax Check**

   ```bash
   ansible-playbook ansible/playbooks/upgrade_ios_xe.yml --syntax-check
   ```

3. **Dry Run**
   ```bash
   ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini --check
   ```

## Requirements File

Create `requirements.yml` for collection dependencies:

```yaml
---
collections:
  - name: cisco.ios
    version: ">=5.0.0"
  - name: ansible.netcommon
    version: ">=5.0.0"
```

Install collections:

```bash
ansible-galaxy collection install -r requirements.yml
```

## References

- [Cisco IOS Collection Documentation](https://docs.ansible.com/projects/ansible/latest/collections/cisco/ios/index.html)
- [Manual Upgrade Process](https://www.packetswitch.co.uk/cisco-ios-xe-catalyst-9000-switches-upgrade-using-ansible/)
- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)

## License

This project is provided as-is for network automation purposes.

## Disclaimer

**IMPORTANT**: This playbook will reboot your switches during the upgrade process. Always:

- Test in a non-production environment first
- Schedule maintenance windows
- Have console/OOB access available
- Backup configurations before running
- Verify network redundancy is in place
