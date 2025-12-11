# Configuration Backup and Restore Guide

## Overview

This project includes automated configuration backup functionality to protect against data loss during IOS-XE upgrades. Backups are created automatically before upgrades and can also be run independently.

## Backup Features

✅ **Automatic Backups**: Created before every upgrade  
✅ **Manual Backups**: Run anytime with a single command  
✅ **Multiple Formats**: Running-config, startup-config, and summary files  
✅ **Timestamped Files**: Unique filenames with ISO 8601 timestamps  
✅ **Local Storage**: Saved to Ansible controller  
✅ **Optional FTP**: Can also backup to FTP server  
✅ **Configuration Summary**: Includes version, interfaces, VLANs, routes  

## Quick Start

### Create a Backup

```bash
# Backup all switches
make backup

# Backup specific switch
make backup LIMIT=switch01

# Backup with vault password
ansible-playbook ansible/playbooks/backup_configs.yml \
  -i ansible/inventory.ini \
  --ask-vault-pass
```

### List Backups

```bash
# Show recent backups
make backup-list

# Find specific backup
ls -lh backups/*switch01*
```

### Restore Instructions

```bash
# Display restore guide
make restore-info
```

## Backup Configuration

### Enable/Disable Backups

In `ansible/group_vars/switches.yml`:

```yaml
# Enable automatic backups before upgrades
backup_enabled: true

# Backup directory (relative to playbook location)
backup_dir: "./backups"

# Also backup to FTP server (optional)
backup_to_ftp: false
```

### FTP Backup Configuration

To enable FTP backups, set in `group_vars/switches.yml`:

```yaml
backup_to_ftp: true

# Ensure FTP server details are configured
ftp_host: 10.10.10.10
ftp_username: ftpuser
ftp_password: <encrypted_with_vault>
```

**Note**: FTP server must have a `backups/` directory created.

## Backup File Structure

### Directory Layout

```
backups/
├── switch01_running-config_20251211T143022.cfg
├── switch01_startup-config_20251211T143022.cfg
├── switch01_summary_20251211T143022.txt
├── switch02_running-config_20251211T143022.cfg
├── switch02_startup-config_20251211T143022.cfg
└── switch02_summary_20251211T143022.txt
```

### Filename Format

```
{hostname}_{config_type}_{timestamp}.{extension}
```

- **hostname**: Inventory hostname (e.g., `switch01`)
- **config_type**: `running-config`, `startup-config`, or `summary`
- **timestamp**: ISO 8601 basic format (e.g., `20251211T143022`)
- **extension**: `.cfg` for configs, `.txt` for summaries

### File Contents

#### Running Configuration (`.cfg`)
Complete running configuration from the switch.

#### Startup Configuration (`.cfg`)
Complete startup configuration from NVRAM.

#### Summary File (`.txt`)
Includes:
- Backup date and time
- Switch model and serial number
- IOS-XE version
- Key configuration elements (hostname, interfaces, routes, VLANs, boot)
- Version and uptime information
- Interface summary
- VLAN summary

## Restore Procedures

### Method 1: FTP Restore (Recommended)

**Prerequisites**: Backup file on FTP server

```bash
# On switch console/SSH
switch# copy ftp://user:password@server/backups/switch01_running-config_20251211T143022.cfg running-config
```

**Or use configure replace** (safer, validates first):

```bash
switch# configure replace ftp://user:password@server/backups/switch01_running-config_20251211T143022.cfg
```

### Method 2: TFTP Restore

**Prerequisites**: Backup file on TFTP server

```bash
# On switch
switch# copy tftp://server/switch01_running-config_20251211T143022.cfg running-config
```

### Method 3: Console/SSH Paste

**For smaller configs or emergency recovery**:

1. Open backup `.cfg` file locally
2. Connect to switch via console or SSH
3. Enter configuration mode:
   ```
   switch# configure terminal
   ```
4. Copy and paste configuration commands
5. Exit and save:
   ```
   switch(config)# end
   switch# write memory
   ```

### Method 4: Ansible Restore (Advanced)

Create a custom playbook to push configuration:

```yaml
---
- name: Restore Configuration
  hosts: switch01
  tasks:
    - name: Restore from backup
      cisco.ios.ios_config:
        src: backups/switch01_running-config_20251211T143022.cfg
```

## Backup Best Practices

### Before Upgrades

✅ **Always backup before upgrades** (automatic with this playbook)  
✅ **Verify backup files exist** after creation  
✅ **Test restore procedure** in lab environment  
✅ **Store backups off-controller** for disaster recovery  

### Regular Backups

```bash
# Schedule daily backups (crontab example)
0 2 * * * cd /path/to/project && make backup > /var/log/switch-backup.log 2>&1
```

### Backup Retention

Recommended retention policy:

- **Daily backups**: Keep 7 days
- **Weekly backups**: Keep 4 weeks
- **Monthly backups**: Keep 12 months
- **Pre-upgrade backups**: Keep indefinitely (or 1 year minimum)

### Cleanup Script

```bash
#!/bin/bash
# cleanup_old_backups.sh

BACKUP_DIR="./backups"
DAYS_TO_KEEP=30

# Delete backups older than 30 days
find "$BACKUP_DIR" -name "*.cfg" -mtime +$DAYS_TO_KEEP -delete
find "$BACKUP_DIR" -name "*.txt" -mtime +$DAYS_TO_KEEP -delete

echo "Cleanup complete. Kept backups from last $DAYS_TO_KEEP days."
```

## Security Considerations

### Backup File Security

⚠️ **Configuration files contain sensitive information**:
- Passwords (may be hashed)
- SNMP community strings
- Network topology
- Access control lists
- Management IPs

### Secure Storage

✅ **Encrypt backups at rest**:
```bash
# Encrypt backup files
gpg --encrypt backups/switch01_running-config_20251211T143022.cfg

# Decrypt when needed
gpg --decrypt backups/switch01_running-config_20251211T143022.cfg.gpg > restored.cfg
```

✅ **Restrict permissions**:
```bash
chmod 600 backups/*.cfg
chmod 700 backups/
```

✅ **Store off-site**:
- Copy to secure backup server
- Use encrypted cloud storage
- Store in network management vault

### .gitignore Protection

The `backups/` directory and `*.cfg` files are automatically excluded from git by `.gitignore`:

```
backups/
*.cfg
```

**Never commit configuration files to version control!**

## Troubleshooting

### Backup Fails

**Error**: "Permission denied creating backup directory"

**Solution**:
```bash
mkdir -p backups
chmod 755 backups
```

**Error**: "Failed to backup to FTP"

**Solution**:
- Verify FTP server is accessible
- Check FTP credentials
- Ensure `backups/` directory exists on FTP server
- Set `backup_to_ftp: false` to skip FTP backup

### Restore Fails

**Error**: "Invalid configuration command"

**Solution**:
- Backup may be from different IOS version
- Some commands may not be supported
- Use `configure replace` instead of direct copy
- Review and manually apply configuration

**Error**: "Flash write error"

**Solution**:
- Insufficient flash space
- Run `install remove inactive`
- Delete old files from flash

## Verification After Restore

After restoring a configuration, verify:

```bash
# Check running config was applied
show running-config

# Verify interfaces are up
show ip interface brief

# Check routing
show ip route

# Verify VLANs
show vlan brief

# Check version (should not have changed)
show version

# Save to startup if satisfied
copy running-config startup-config
```

## Manual Backup Commands

### Via CLI (without Ansible)

```bash
# Backup to FTP
copy running-config ftp://user:password@server/backups/switch01-backup.cfg

# Backup to TFTP
copy running-config tftp://server/switch01-backup.cfg

# Backup to USB (if available)
copy running-config usbflash0:switch01-backup.cfg
```

## Integration with Upgrade Process

The upgrade playbook automatically:

1. ✅ Creates timestamp
2. ✅ Creates backup directory
3. ✅ Backs up running-config to local directory
4. ✅ Optionally backs up to FTP server
5. ✅ Creates configuration summary
6. ✅ Displays backup locations
7. ✅ Continues with upgrade only after successful backup

### Disable Backups (Not Recommended)

To disable automatic backups during upgrades:

```yaml
# In group_vars/switches.yml
backup_enabled: false
```

⚠️ **Warning**: Only disable for testing in lab environments!

## Disaster Recovery

### Complete Switch Failure

If a switch fails completely after upgrade:

1. **Replace hardware** (if necessary)
2. **Install base IOS** (any version to get connectivity)
3. **Restore configuration**:
   ```bash
   copy ftp://server/backups/switch01_running-config_TIMESTAMP.cfg running-config
   ```
4. **Verify functionality**
5. **Upgrade to target version** (if needed)

### Rollback After Upgrade

If upgrade causes issues:

1. **Access switch** (console preferred)
2. **Check backup files** exist
3. **Restore previous config**:
   ```bash
   configure replace ftp://server/backups/switch01_running-config_TIMESTAMP.cfg
   ```
4. **Reload** with previous IOS (may require manual intervention)

## Backup Testing

### Test Restore Procedure

1. **Create test backup**:
   ```bash
   make backup LIMIT=lab-switch01
   ```

2. **Make a small change**:
   ```bash
   # On switch
   configure terminal
   interface Loopback99
   ip address 192.0.2.99 255.255.255.255
   end
   ```

3. **Restore from backup**:
   ```bash
   configure replace ftp://server/backups/lab-switch01_running-config_TIMESTAMP.cfg
   ```

4. **Verify**:
   - Loopback99 should be removed
   - Configuration should match backup
   - All interfaces functional

## References

- [Cisco IOS Configuration Replace](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/fundamentals/configuration/15mt/fundamentals-15-mt-book/cf-config-replace.html)
- [Ansible cisco.ios.ios_config Module](https://docs.ansible.com/ansible/latest/collections/cisco/ios/ios_config_module.html)
- Main Project: [README.md](README.md)
- Security Guidelines: [SECURITY.md](SECURITY.md)

---

**Remember**: Backups are your safety net. Test restore procedures before you need them! 💾

