# Setup Instructions

## First-Time Setup

### Step 1: Create Your Variables File

The project uses a template for variables. Create your own encrypted copy:

```bash
# Copy the template to create your vars file
cp ansible/group_vars/switches.yml.template ansible/group_vars/switches.yml

# Edit with your actual credentials
vim ansible/group_vars/switches.yml
# or
nano ansible/group_vars/switches.yml
```

**Update these values:**

- `ansible_user`: Your switch username
- `ansible_password`: Your switch password
- `ansible_become_password`: Your enable password
- `ftp_host`: Your FTP server IP
- `ftp_username`: Your FTP username
- `ftp_password`: Your FTP password
- `target_version`: Target IOS-XE version (e.g., "17.15.04")
- `image_file`: Image filename (e.g., "cat9k_iosxe.17.15.04.SPA.bin")

### Step 2: Encrypt the Variables File

**CRITICAL**: Never commit unencrypted credentials!

```bash
# Encrypt your switches.yml file
ansible-vault encrypt ansible/group_vars/switches.yml

# You'll be prompted for a vault password
# SAVE THIS PASSWORD SECURELY!
```

### Step 3: Configure Inventory

```bash
# Edit the inventory file
vim ansible/inventory.ini
```

Add your switches:

```ini
[switches]
switch01 ansible_host=10.1.1.10
switch02 ansible_host=10.1.1.11
switch03 ansible_host=10.1.1.12
```

### Step 4: Test Connectivity

```bash
# Test SSH connectivity
make test-connectivity

# You'll be prompted for the vault password
```

## File Security

### What's Committed to Git

✅ **Committed** (safe to share):

- `switches.yml.template` - Template with placeholders
- All playbooks
- Documentation
- Makefile, setup scripts

❌ **NOT Committed** (in .gitignore):

- `switches.yml` - Your actual encrypted variables
- `.vault_pass` - Vault password file
- `backups/` - Configuration backups
- Any files with passwords/secrets

### Verification

```bash
# Check what will be committed
git status

# switches.yml should NOT appear in the list
# If it does, check your .gitignore
```

## Updating Variables

### Edit Encrypted File

```bash
# Edit without decrypting
ansible-vault edit ansible/group_vars/switches.yml

# Or decrypt, edit, re-encrypt (not recommended)
ansible-vault decrypt ansible/group_vars/switches.yml
vim ansible/group_vars/switches.yml
ansible-vault encrypt ansible/group_vars/switches.yml
```

### Change Vault Password

```bash
# Change the vault password
ansible-vault rekey ansible/group_vars/switches.yml
```

## Team Collaboration

### For New Team Members

**Give them:**

1. ✅ Access to this git repository
2. ✅ The vault password (via secure channel - NOT git!)
3. ✅ FTP server details (if not in template)

**They run:**

```bash
# 1. Clone repo
git clone <repository-url>
cd iosxe-software-upgrade

# 2. Setup environment
./setup_venv.sh

# 3. Create vars from template
cp ansible/group_vars/switches.yml.template ansible/group_vars/switches.yml

# 4. Edit with actual credentials
vim ansible/group_vars/switches.yml

# 5. Encrypt
ansible-vault encrypt ansible/group_vars/switches.yml
```

### Sharing the Encrypted File

**Option 1**: Share the pre-encrypted file

```bash
# Copy the encrypted file to new team member
# They use the same vault password
scp ansible/group_vars/switches.yml teammate@host:~/project/ansible/group_vars/
```

**Option 2**: Use different vault passwords per environment

```bash
# Dev environment
ansible-vault encrypt ansible/group_vars/switches.yml --vault-id dev@prompt

# Prod environment
ansible-vault encrypt ansible/group_vars/switches.yml --vault-id prod@prompt
```

## Best Practices

### 1. Never Commit Unencrypted Credentials

❌ **DON'T**:

```bash
git add ansible/group_vars/switches.yml  # If unencrypted!
git commit -m "Added credentials"  # DANGER!
```

✅ **DO**:

```bash
# Always verify file is encrypted first
head -1 ansible/group_vars/switches.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256

git add ansible/group_vars/switches.yml  # OK if encrypted
```

### 2. Separate Vault Passwords

Different passwords for different environments:

- Dev: `dev-vault-password`
- Staging: `staging-vault-password`
- Production: `production-vault-password`

### 3. Store Vault Password Securely

**Good options:**

- Password manager (1Password, LastPass, etc.)
- CI/CD secrets (GitHub Secrets, Jenkins Credentials)
- HashiCorp Vault
- Team password vault

**Bad options:**

- ❌ Slack/Teams messages
- ❌ Email
- ❌ Sticky notes
- ❌ In the git repository

### 4. Rotate Credentials Regularly

```bash
# 1. Change passwords on switches
# 2. Update switches.yml
ansible-vault edit ansible/group_vars/switches.yml

# 3. Test
make test-connectivity

# 4. Change vault password
ansible-vault rekey ansible/group_vars/switches.yml
```

## Troubleshooting Setup

### "switches.yml not found"

You need to create it from the template:

```bash
cp ansible/group_vars/switches.yml.template ansible/group_vars/switches.yml
vim ansible/group_vars/switches.yml
ansible-vault encrypt ansible/group_vars/switches.yml
```

### "Vault password incorrect"

- Check for typos
- Verify you're using the correct password
- Ask team member who created the vault file

### "File is not encrypted"

```bash
# Check if file is encrypted
head -1 ansible/group_vars/switches.yml

# If not encrypted, encrypt it NOW:
ansible-vault encrypt ansible/group_vars/switches.yml
```

### Git Wants to Commit switches.yml

If switches.yml appears in `git status` and it's NOT encrypted:

```bash
# 1. STOP! Do not commit
# 2. Remove from staging
git reset ansible/group_vars/switches.yml

# 3. Encrypt it
ansible-vault encrypt ansible/group_vars/switches.yml

# 4. Verify .gitignore is working
git status  # switches.yml should NOT appear
```

## Quick Setup Checklist

- [ ] Clone repository
- [ ] Run `./setup_venv.sh` (or `.\setup_venv.bat` on Windows)
- [ ] Copy `switches.yml.template` to `switches.yml`
- [ ] Edit `switches.yml` with your credentials
- [ ] Encrypt `switches.yml` with Ansible Vault
- [ ] Update `inventory.ini` with your switches
- [ ] Test connectivity: `make test-connectivity`
- [ ] Verify `.gitignore` excludes `switches.yml`
- [ ] Store vault password securely

---

**Remember**: The template is for reference only. Always use the encrypted `switches.yml` file! 🔐
