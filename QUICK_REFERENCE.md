# Quick Reference Card - IOS-XE Upgrade

📘 **Windows users**: Replace `make` with `.\run.ps1` and see [WINDOWS.md](WINDOWS.md)

## One-Time Setup

**Linux/macOS:**

```bash
# 1. Install Ansible
pip install ansible

# 2. Install Cisco IOS collection
ansible-galaxy collection install -r ansible/requirements.yml

# 3. Configure inventory
vim ansible/inventory.ini
# Add: switch01 ansible_host=10.1.1.10

# 4. Configure variables
vim ansible/group_vars/switches.yml
# Update: credentials, FTP server, target version

# 5. Encrypt credentials
ansible-vault encrypt ansible/group_vars/switches.yml
```

**Windows (PowerShell):**

```powershell
# 1. Run setup
.\setup_venv.bat

# 2. Activate environment
.\.venv\Scripts\Activate.ps1

# 3. Configure inventory
notepad ansible\inventory.ini

# 4. Configure variables
notepad ansible\group_vars\switches.yml

# 5. Encrypt credentials
ansible-vault encrypt ansible\group_vars\switches.yml
```

## Daily Operations

**Linux/macOS:**

### Backup Configurations

```bash
# Backup all switches
make backup

# Backup single switch
make backup LIMIT=switch01

# List backups
make backup-list

# Show restore instructions
make restore-info
```

### Test Upgrade (Dry-Run) 🔍

```bash
# Test upgrade workflow WITHOUT making changes
make upgrade-dry-run

# Test specific switch
make upgrade-dry-run LIMIT=switch01
```

### Run Upgrade (Live) ⚡

```bash
# Standard execution (includes automatic backup)
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  --ask-vault-pass

# Using Makefile
make upgrade LIMIT=switch01

# Single switch
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  --limit switch01 \
  --ask-vault-pass

# Verbose output
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  --ask-vault-pass \
  -vvv
```

**Windows (PowerShell):**

```powershell
# Backup configs
.\run.ps1 backup
.\run.ps1 backup switch01

# Check versions
.\run.ps1 check-version

# Test upgrade (dry-run)
.\run.ps1 upgrade-dry-run switch01

# Run upgrade (live)
.\run.ps1 upgrade switch01

# List backups
.\run.ps1 backup-list
```

### Pre-Flight Checks

**Linux/macOS:**

```bash
# Syntax check
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml --syntax-check

# Test connectivity
ansible switches -i ansible/inventory.ini -m ping

# Check current version
ansible switches -i ansible/inventory.ini \
  -m cisco.ios.ios_facts \
  -a "gather_subset=hardware"
```

### Vault Operations

```bash
# Encrypt file
ansible-vault encrypt ansible/group_vars/switches.yml

# Edit encrypted file
ansible-vault edit ansible/group_vars/switches.yml

# View encrypted file
ansible-vault view ansible/group_vars/switches.yml

# Decrypt file
ansible-vault decrypt ansible/group_vars/switches.yml

# Encrypt string
ansible-vault encrypt_string 'password123' --name 'ansible_password'
```

## Variables Reference

### Required Variables (group_vars/switches.yml)

```yaml
# Connection
ansible_user: admin
ansible_password: <encrypted>
ansible_become_password: <encrypted>

# FTP Server
ftp_host: 10.10.10.10
ftp_username: ftpuser
ftp_password: <encrypted>

# Target Version
target_version: "17.15.04"
image_file: "cat9k_iosxe.17.15.04.SPA.bin"

# Backup Configuration
backup_enabled: true
backup_dir: "./backups"
backup_to_ftp: false
```

### Optional Variables (Override in playbook)

```yaml
required_space_mb: 2048 # Min flash space required
install_timeout: 1200 # Install command timeout (seconds)
reboot_wait_timeout: 300 # Wait time after reboot (seconds)
```

## Common Issues & Solutions

| Issue                      | Solution                                           |
| -------------------------- | -------------------------------------------------- |
| "Insufficient flash space" | Free up space or reduce required_space_mb          |
| "Connection timeout"       | Check SSH, firewall, credentials                   |
| "FTP transfer failed"      | Verify FTP server, network, VRF                    |
| "Module not found"         | Run: `ansible-galaxy collection install cisco.ios` |
| "Vault password incorrect" | Check password, verify file is encrypted           |

## Playbook Workflow

```
1. Gather version       → Skip if already at target
2. BACKUP CONFIG        → Save to ./backups with timestamp ✨
3. Check boot mode      → Clear boot vars if bundle mode
4. Save to startup      → Backup running-config to NVRAM
5. CLEAN OLD PACKAGES   → Remove inactive (frees space) ✨ FIRST
6. VERIFY FLASH SPACE   → Check AFTER cleanup (~2GB required) ✨
7. Transfer image       → FTP transfer (~10-15 min)
8. Install & activate   → Switch reboots (~15-20 min)
9. Wait & reconnect     → Wait for boot (~5-10 min)
10. Verify version      → Confirm success
```

## Safety Checklist

Before running upgrade:

- [ ] Tested in lab environment
- [ ] Maintenance window scheduled
- [ ] Configuration backed up
- [ ] Console/OOB access available
- [ ] Rollback plan documented
- [ ] Network redundancy verified
- [ ] FTP server accessible from switches
- [ ] Credentials encrypted with Vault

## Expected Timing

- **FTP Transfer**: 10-15 minutes (1GB file)
- **Install Process**: 15-20 minutes
- **Reboot**: 5-10 minutes
- **Total**: ~30-45 minutes per switch

## Emergency Rollback

If upgrade fails:

```bash
# 1. Console access to switch
# 2. Check boot flash
dir flash:

# 3. Set boot to previous version
conf t
boot system flash:packages.conf
end
wr mem
reload

# 4. Or use install rollback (if available)
install rollback
```

## Support & Documentation

- **Main README**: [README.md](README.md)
- **Vault Guide**: [ansible/VAULT_EXAMPLE.md](ansible/VAULT_EXAMPLE.md)
- **Testing Guide**: [TESTING.md](TESTING.md)
- **Cisco IOS Collection**: https://docs.ansible.com/projects/ansible/latest/collections/cisco/ios/
- **Reference Blog**: https://www.packetswitch.co.uk/cisco-ios-xe-catalyst-9000-switches-upgrade-using-ansible/

## File Structure

```
ios-xe-code-upgrad/
├── ansible/
│   ├── playbooks/
│   │   └── upgrade_ios_xe.yml        # Main playbook
│   ├── group_vars/
│   │   └── switches.yml              # Variables (encrypt this!)
│   ├── inventory.ini                 # Switch inventory
│   ├── requirements.yml              # Ansible collections
│   └── VAULT_EXAMPLE.md              # Vault usage guide
├── README.md                         # Full documentation
├── TESTING.md                        # Testing guide
├── QUICK_REFERENCE.md                # This file
└── .gitignore                        # Git ignore patterns
```

## Quick Commands

```bash
# Test syntax
make test-syntax  # or
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml --syntax-check

# Upgrade single switch
make upgrade LIMIT=switch01  # or
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini --limit switch01 --ask-vault-pass

# Check versions
make check-version  # or
ansible switches -i ansible/inventory.ini -m cisco.ios.ios_command -a "commands='show version'"
```

---

**Remember**: Always test in lab first! 🧪
