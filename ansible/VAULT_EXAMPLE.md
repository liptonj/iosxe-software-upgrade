# Using Ansible Vault to Secure Credentials

## Why Use Ansible Vault?

Ansible Vault encrypts sensitive data like passwords, API keys, and credentials so they can be safely stored in version control.

## Method 1: Encrypt Entire Variables File

### Encrypt the file
```bash
ansible-vault encrypt ansible/group_vars/switches.yml
```

You'll be prompted for a vault password. **Store this password securely!**

### Run playbook with encrypted file
```bash
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini --ask-vault-pass
```

### Edit encrypted file
```bash
ansible-vault edit ansible/group_vars/switches.yml
```

### Decrypt file (if needed)
```bash
ansible-vault decrypt ansible/group_vars/switches.yml
```

## Method 2: Encrypt Individual Variables (Recommended)

This method allows you to keep most of your variables readable while encrypting only sensitive ones.

### Create encrypted variables

```bash
# Encrypt switch password
ansible-vault encrypt_string 'Cisco123' --name 'ansible_password'

# Encrypt enable password
ansible-vault encrypt_string 'Cisco123' --name 'ansible_become_password'

# Encrypt FTP password
ansible-vault encrypt_string 'ftppassword' --name 'ftp_password'
```

### Example output
```yaml
ansible_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          66386439653966636331613532373838396533313333613038363063353064666238653361383166
          6235313934376564653839313633313363646666336662310a376634373063306634636162373532
          ...
```

### Update your switches.yml file

```yaml
---
# Ansible connection settings
ansible_connection: ansible.netcommon.network_cli
ansible_network_os: cisco.ios.ios
ansible_become: true
ansible_become_method: enable

# Switch credentials (encrypted)
ansible_user: admin
ansible_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          66386439653966636331613532373838396533313333613038363063353064666238653361383166
          6235313934376564653839313633313363646666336662310a376634373063306634636162373532
          ...

ansible_become_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          39383931643138326463336631366566353866373432613064303832643065653662313632666336
          3439383538313366356236386235353063666265353861650a383339386566666662363561643336
          ...

# FTP Server Configuration
ftp_host: 10.10.10.10
ftp_username: ftpuser
ftp_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          35343639303766653637643363303931643431366239643233663664633165613731393430633138
          6534636139666164313661383964656165613532316663310a336564653464663337643464373361
          ...

# IOS-XE Upgrade Configuration (not encrypted - not sensitive)
target_version: "17.15.04"
image_file: "cat9k_iosxe.17.15.04.SPA.bin"
```

## Method 3: Use Vault Password File

Store your vault password in a file (never commit this file!):

```bash
# Create password file
echo 'MyVaultPassword123' > .vault_pass

# Secure the file
chmod 600 .vault_pass
```

Add to `.gitignore`:
```
.vault_pass
```

Run playbook without prompting:
```bash
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml -i ansible/inventory.ini --vault-password-file .vault_pass
```

## Best Practices

1. ✅ **Never commit** `.vault_pass` or unencrypted passwords to git
2. ✅ **Use different vault passwords** for dev/staging/prod
3. ✅ **Rotate passwords regularly** and re-encrypt
4. ✅ **Store vault passwords** in a password manager (LastPass, 1Password, etc.)
5. ✅ **Use CI/CD vault secrets** for automation (GitHub Secrets, Jenkins Credentials, etc.)

## Verifying Encryption

Check if a file is encrypted:
```bash
head -1 ansible/group_vars/switches.yml
```

If encrypted, you'll see:
```
$ANSIBLE_VAULT;1.1;AES256
```

## Troubleshooting

### "Vault password incorrect"
- Ensure you're using the correct password
- Check for typos or extra spaces

### "vault ID mismatch"
- Use `--vault-id` flag if using multiple vault passwords
- Example: `ansible-playbook ... --vault-id prod@prompt`

### "Failed to decrypt"
- File may be corrupted
- Restore from backup and re-encrypt

## Security Compliance

According to the workspace rules:
- ❌ **NEVER hardcode credentials** in playbooks or variables
- ✅ **ALWAYS use Ansible Vault** or environment variables for secrets
- ✅ **NEVER commit** `.vault_pass`, `.env`, or plain-text passwords to version control

## Quick Reference

```bash
# Encrypt file
ansible-vault encrypt file.yml

# Decrypt file
ansible-vault decrypt file.yml

# Edit encrypted file
ansible-vault edit file.yml

# View encrypted file
ansible-vault view file.yml

# Change vault password
ansible-vault rekey file.yml

# Encrypt string
ansible-vault encrypt_string 'secret_value' --name 'variable_name'

# Run playbook with vault
ansible-playbook playbook.yml --ask-vault-pass
ansible-playbook playbook.yml --vault-password-file .vault_pass
```

