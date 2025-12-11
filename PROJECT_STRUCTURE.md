# Project Structure

## Directory Layout

```
ios-xe-code-upgrad/
├── ansible/
│   ├── playbooks/
│   │   ├── upgrade_ios_xe.yml           # Main upgrade playbook
│   │   ├── test_connectivity.yml        # Test SSH connectivity
│   │   ├── test_version_check.yml       # Check versions and boot mode
│   │   └── test_flash_space.yml         # Verify flash space
│   ├── group_vars/
│   │   └── switches.yml                 # Variables (ENCRYPT THIS!)
│   ├── inventory.ini                    # Switch inventory
│   ├── requirements.yml                 # Ansible collection requirements
│   └── VAULT_EXAMPLE.md                 # Vault usage guide
├── .gitignore                           # Git ignore patterns
├── .cursorignore                        # Cursor AI ignore patterns
├── CHANGELOG.md                         # Version history
├── Makefile                             # Common commands
├── PROJECT_STRUCTURE.md                 # This file
├── QUICK_REFERENCE.md                   # Quick command reference
├── README.md                            # Main documentation
├── SECURITY.md                          # Security guidelines
└── TESTING.md                           # Testing procedures
```

## File Descriptions

### Main Playbook

**`ansible/playbooks/upgrade_ios_xe.yml`**
- Primary automation playbook for IOS-XE upgrades
- Handles both bundle and install mode switches
- Includes pre-flight checks, image transfer, installation, and verification
- Target version: 17.15.04 (configurable)

### Configuration Files

**`ansible/inventory.ini`**
- Defines target switches
- Group switches under `[switches]` group
- Format: `hostname ansible_host=IP_ADDRESS`

**`ansible/group_vars/switches.yml`**
- Connection settings (ansible_user, ansible_password, etc.)
- FTP server configuration
- Target version and image filename
- **CRITICAL**: Must be encrypted with Ansible Vault in production

**`ansible/requirements.yml`**
- Ansible collection dependencies
- cisco.ios collection (≥5.0.0)
- ansible.netcommon collection (≥5.0.0)

### Test Playbooks

**`ansible/playbooks/test_connectivity.yml`**
- Tests SSH connectivity to switches
- Gathers basic facts (hostname, version, model, serial)
- Use before running upgrade to verify access

**`ansible/playbooks/test_version_check.yml`**
- Checks current IOS-XE version
- Detects boot mode (bundle vs install)
- Displays flash space
- Determines if upgrade is needed

**`ansible/playbooks/test_flash_space.yml`**
- Detailed flash storage analysis
- Lists files on flash
- Calculates space usage and availability
- Provides recommendations

### Documentation

**`README.md`**
- Main project documentation
- Features, prerequisites, configuration
- Usage instructions and troubleshooting
- Comprehensive guide for users

**`SECURITY.md`**
- Enterprise security guidelines
- No hardcoded credentials policy
- Cryptographic standards
- Certificate best practices
- Ansible Vault usage
- Compliance and audit procedures

**`TESTING.md`**
- Complete testing guide
- Pre-deployment testing procedures
- Smoke tests, unit tests, integration tests
- Lab setup instructions
- Test scenarios and expected results

**`VAULT_EXAMPLE.md`**
- Step-by-step Ansible Vault guide
- Encryption methods (file vs variables)
- Password management
- Best practices

**`QUICK_REFERENCE.md`**
- Quick command reference
- One-time setup steps
- Daily operations
- Common issues and solutions
- Cheat sheet for experienced users

**`CHANGELOG.md`**
- Version history
- Release notes
- Breaking changes
- Migration guides

**`PROJECT_STRUCTURE.md`**
- This file
- Directory layout
- File descriptions
- Dependencies

### Build and Operations

**`Makefile`**
- Common operational commands
- `make install` - Install dependencies
- `make test-syntax` - Validate playbook
- `make upgrade` - Run upgrade
- `make check-version` - Check switch versions
- Simplifies daily operations

### Security Files

**`.gitignore`**
- Prevents committing sensitive files
- Blocks password files, vault files, secrets
- Protects against accidental credential leaks

**`.cursorignore`**
- Prevents AI access to sensitive files
- Additional security layer
- Mirrors critical .gitignore entries

## Dependencies

### Python Packages

```bash
# Core
ansible >= 2.16.0

# Optional (for testing/linting)
ansible-lint >= 6.0.0
yamllint >= 1.26.0
```

### Ansible Collections

```bash
# Required
cisco.ios >= 5.0.0
ansible.netcommon >= 5.0.0
```

### System Requirements

- Python 3.8+
- SSH client
- Network connectivity to switches
- FTP server with IOS-XE image

## Usage Workflow

### 1. Initial Setup

```bash
# Install dependencies
make install

# Configure inventory
vim ansible/inventory.ini

# Configure variables
vim ansible/group_vars/switches.yml

# Encrypt sensitive data
ansible-vault encrypt ansible/group_vars/switches.yml
```

### 2. Testing

```bash
# Test connectivity
ansible-playbook ansible/playbooks/test_connectivity.yml -i ansible/inventory.ini --ask-vault-pass

# Check versions
ansible-playbook ansible/playbooks/test_version_check.yml -i ansible/inventory.ini --ask-vault-pass

# Verify flash space
ansible-playbook ansible/playbooks/test_flash_space.yml -i ansible/inventory.ini --ask-vault-pass

# Syntax check
make test-syntax
```

### 3. Upgrade Execution

```bash
# Upgrade single switch (recommended for first run)
make upgrade LIMIT=switch01

# Upgrade all switches
make upgrade

# Upgrade with verbose output
make upgrade-verbose
```

### 4. Post-Upgrade Verification

```bash
# Verify new version
make check-version

# Run connectivity test
ansible-playbook ansible/playbooks/test_connectivity.yml -i ansible/inventory.ini --ask-vault-pass
```

## File Permissions

Recommended file permissions for security:

```bash
chmod 644 ansible/inventory.ini
chmod 600 ansible/group_vars/switches.yml  # Sensitive!
chmod 600 .vault_pass                       # If using password file
chmod 644 ansible/playbooks/*.yml
chmod 644 *.md
chmod 755 Makefile
```

## Customization Points

### Variables to Modify

In `ansible/group_vars/switches.yml`:

```yaml
# Connection credentials
ansible_user: admin                    # Change to your username
ansible_password: <encrypted>          # Encrypt your password
ansible_become_password: <encrypted>   # Encrypt enable password

# FTP Server
ftp_host: 10.10.10.10                 # Your FTP server IP
ftp_username: ftpuser                  # FTP username
ftp_password: <encrypted>              # Encrypt FTP password

# Target Version
target_version: "17.15.04"            # Desired IOS-XE version
image_file: "cat9k_iosxe.17.15.04.SPA.bin"  # Image filename
```

### Playbook Variables to Override

In `ansible/playbooks/upgrade_ios_xe.yml`:

```yaml
required_space_mb: 2048        # Minimum flash space (MB)
install_timeout: 1200          # Install command timeout (seconds)
reboot_wait_timeout: 300       # Wait time after reboot (seconds)
```

## Git Repository Structure

### Version Control

```bash
# Initialize git
git init

# Add files (sensitive files are ignored)
git add .
git commit -m "Initial commit"

# .gitignore automatically excludes:
# - .vault_pass
# - *.log
# - *password*
# - .env files
```

### Branching Strategy

Recommended:
- `main` - Production-ready code
- `develop` - Development branch
- `feature/*` - Feature branches
- `hotfix/*` - Urgent fixes

## Extending the Project

### Adding New Playbooks

```bash
# Create new playbook
vim ansible/playbooks/new_feature.yml

# Test syntax
ansible-playbook ansible/playbooks/new_feature.yml --syntax-check

# Add to Makefile
# Add documentation to README
```

### Supporting Additional Switch Models

```yaml
# Add model-specific variables
# Create model-specific group_vars
# Update playbook conditionals
```

### Integration with External Systems

- Monitoring (Nagios, Zabbix, Prometheus)
- Ticketing (JIRA, ServiceNow)
- Chat notifications (Slack, Teams)
- Backup systems (Git, TFTP)

## Maintenance

### Regular Tasks

1. **Update Ansible Collections**
   ```bash
   ansible-galaxy collection install -r ansible/requirements.yml --upgrade
   ```

2. **Rotate Credentials**
   ```bash
   # Update passwords on switches
   # Re-encrypt variables
   ansible-vault rekey ansible/group_vars/switches.yml
   ```

3. **Review Logs**
   ```bash
   # Check for failed upgrades
   # Review error patterns
   ```

4. **Update Documentation**
   ```bash
   # Update README with new features
   # Update CHANGELOG with versions
   ```

## Troubleshooting File Issues

### File Not Found

```bash
# Verify file exists
ls -la ansible/playbooks/upgrade_ios_xe.yml

# Check working directory
pwd
```

### Permission Denied

```bash
# Fix permissions
chmod 600 ansible/group_vars/switches.yml
```

### Vault Decryption Failed

```bash
# Verify file is encrypted
head -1 ansible/group_vars/switches.yml

# Try with correct password
ansible-vault view ansible/group_vars/switches.yml
```

## Support Files Location

- **Logs**: `*.log` (excluded from git)
- **Retry Files**: `*.retry` (excluded from git)
- **Vault Password**: `.vault_pass` (excluded from git)
- **Temp Files**: `/tmp/ansible-*`

## Backup Strategy

### Important Files to Backup

1. `ansible/inventory.ini` - Switch inventory
2. `ansible/group_vars/switches.yml` - Encrypted variables
3. `.vault_pass` - Vault password (store securely!)
4. Custom playbooks
5. Documentation modifications

### Backup Command

```bash
# Create backup
tar -czf backup_$(date +%Y%m%d).tar.gz \
  ansible/ \
  *.md \
  Makefile \
  .gitignore

# Store securely (off-site)
```

## Getting Help

1. Check [README.md](README.md) for general usage
2. Review [TESTING.md](TESTING.md) for troubleshooting
3. See [SECURITY.md](SECURITY.md) for security concerns
4. Read [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for commands
5. Check [CHANGELOG.md](CHANGELOG.md) for version info

---

**Last Updated**: 2025-12-11

