# Cisco IOS-XE Catalyst 9300 Upgrade Automation

Automated upgrade playbook for Cisco Catalyst 9300 switches running IOS-XE using Ansible.

## Features

- ✅ **Automatic configuration backup** before upgrades
- ✅ Automated version checking and upgrade
- ✅ Bundle to Install mode conversion
- ✅ Flash space verification
- ✅ Old boot variable cleanup
- ✅ FTP-based image transfer
- ✅ Post-upgrade verification
- ✅ Standalone backup playbook for anytime backups
- ✅ Uses only native `cisco.ios` collection modules

## Prerequisites

### 1. Ansible Installation

```bash
# Install Ansible
pip install ansible

# Install Cisco IOS collection
ansible-galaxy collection install cisco.ios
```

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

### 2. Variables Configuration

Edit `ansible/group_vars/switches.yml`:

```yaml
# Switch credentials
ansible_user: admin
ansible_password: your_password
ansible_become_password: your_enable_password

# FTP Server Configuration
ftp_host: 10.10.10.10
ftp_username: ftpuser
ftp_password: ftppassword

# Target version
target_version: "17.15.04"
image_file: "cat9k_iosxe.17.15.04.SPA.bin"
```

### 3. Secure Credentials with Ansible Vault (Recommended)

**IMPORTANT**: Never store plain-text passwords in production!

```bash
# Encrypt the entire variables file
ansible-vault encrypt ansible/group_vars/switches.yml

# Or encrypt individual strings
ansible-vault encrypt_string 'your_password' --name 'ansible_password'
ansible-vault encrypt_string 'ftp_password' --name 'ftp_password'
```

## Usage

### Pre-Flight Check (Syntax Validation)

```bash
# Validate playbook syntax
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini --syntax-check

# Dry-run check (connects but makes no changes)
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini --check
```

### Execute Upgrade

```bash
# Run the upgrade playbook
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini

# With vault-encrypted variables
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini --ask-vault-pass

# Limit to specific switches
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini --limit switch01

# Verbose output for troubleshooting
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini -vvv
```

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
