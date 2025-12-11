# Security Guidelines

## Overview

This playbook follows strict security best practices to protect sensitive network infrastructure. All code adheres to enterprise security standards for credential management, cryptographic operations, and secure communications.

## Security Rules Applied

### 1. No Hardcoded Credentials (CRITICAL)

**Rule**: NEVER store secrets, passwords, API keys, tokens, or any other credentials directly in source code.

**Implementation in this project**:

✅ **Compliant Approach**:
- All credentials stored as variables in `ansible/group_vars/switches.yml`
- Variables designed to be encrypted with Ansible Vault
- Placeholder values in documentation
- `.gitignore` prevents committing sensitive files
- `.cursorignore` prevents AI access to sensitive files

❌ **Forbidden Patterns** (Not used in this project):
```yaml
# NEVER do this:
ansible_password: "Cisco123"              # Plain-text password
ftp_password: "mySecret123"               # Hardcoded secret
api_key: "AKIA1234567890ABCDEF"          # AWS key in code
connection_string: "mongodb://user:pass@host"  # Credentials in string
```

### 2. Ansible Vault Encryption (REQUIRED)

**All sensitive data MUST be encrypted using Ansible Vault.**

#### Encrypt Entire File
```bash
ansible-vault encrypt ansible/group_vars/switches.yml
```

#### Encrypt Individual Variables (Recommended)
```bash
ansible-vault encrypt_string 'Cisco123' --name 'ansible_password'
ansible-vault encrypt_string 'ftppassword' --name 'ftp_password'
```

#### Encrypted Variable Example
```yaml
ansible_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          66386439653966636331613532373838396533313333613038363063353064666238653361383166
          6235313934376564653839313633313363646666336662310a376634373063306634636162373532
          ...
```

### 3. Cryptographic Security Guidelines

This project follows enterprise cryptographic standards:

#### Approved Algorithms

✅ **Secure Hash Functions**:
- SHA-256, SHA-384, SHA-512

✅ **Secure Symmetric Encryption**:
- AES-128-GCM, AES-256-GCM
- ChaCha20-Poly1305

✅ **Secure Key Exchange**:
- ECDHE (Elliptic Curve Diffie-Hellman Ephemeral)
- DHE with strong primes

#### Forbidden Algorithms (Never Used)

❌ **Banned Hash Algorithms**:
- MD2, MD4, MD5, SHA-0, SHA-1
- Reason: Cryptographically broken, vulnerable to collision attacks

❌ **Banned Symmetric Ciphers**:
- RC2, RC4, Blowfish, DES, 3DES
- Reason: Weak key sizes, known vulnerabilities

❌ **Banned Key Exchange**:
- Static RSA key exchange
- Anonymous Diffie-Hellman
- Reason: No forward secrecy, vulnerable to MITM attacks

#### SSH Configuration

Ansible uses SSH for switch connections. Ensure secure SSH configuration:

```yaml
# Secure SSH settings (add to group_vars if needed)
ansible_ssh_common_args: '-o StrictHostKeyChecking=yes -o UserKnownHostsFile=~/.ssh/known_hosts'
```

### 4. Certificate Best Practices

If using certificates for authentication (not required for basic setup):

**Certificate Validation Checks**:
- ✅ Expiration status (must be valid)
- ✅ Public key strength (RSA ≥ 2048 bits, ECDSA ≥ 256 bits)
- ✅ Signature algorithm (SHA-2 family only, no MD5/SHA-1)
- ✅ Proper certificate chain validation

**Self-signed certificates** should only be used for:
- Development/testing environments
- Internal lab infrastructure
- Never for production networks

### 5. Network Security

#### FTP vs SCP vs SFTP

**Current Implementation**: FTP (for performance)
- FTP transfers complete faster (~10 min vs ~30+ min for SCP)
- FTP traffic should be isolated to management VRF
- Consider using SFTP in high-security environments

**Security Recommendations**:
```yaml
# For higher security, use SCP (slower but encrypted):
- name: Transfer via SCP
  cisco.ios.ios_command:
    commands:
      - command: "copy scp://{{ ftp_username }}@{{ ftp_host }}/{{ image_file }} flash:{{ image_file }}"
```

#### Management VRF

If using management VRF (recommended for production):

```yaml
# In group_vars/switches.yml add:
management_vrf: "Mgmt-vrf"

# Update playbook FTP command:
copy ftp://...  vrf {{ management_vrf }}
```

### 6. Access Control

#### Privilege Escalation

```yaml
# Secure enable password handling
ansible_become: true
ansible_become_method: enable
ansible_become_password: !vault |  # Always encrypted
```

#### Least Privilege

- Use dedicated automation user accounts
- Grant only required privileges
- Avoid using shared accounts
- Rotate credentials regularly

### 7. Secrets Management Best Practices

#### Vault Password Storage

**Option 1**: Prompt for password (most secure)
```bash
ansible-playbook playbook.yml --ask-vault-pass
```

**Option 2**: Password file (secure permissions required)
```bash
# Create password file
echo 'VaultPassword123' > .vault_pass
chmod 600 .vault_pass

# Use in playbook
ansible-playbook playbook.yml --vault-password-file .vault_pass
```

**Option 3**: Environment variable
```bash
export ANSIBLE_VAULT_PASSWORD_FILE=.vault_pass
ansible-playbook playbook.yml
```

**NEVER**:
- Commit `.vault_pass` to git
- Store vault password in plain text
- Share vault password via email/chat
- Use weak vault passwords

#### Password Rotation

Regularly rotate all credentials:

```bash
# 1. Update credentials on switches
# 2. Re-encrypt with new vault password
ansible-vault rekey ansible/group_vars/switches.yml
```

### 8. File Protection

#### .gitignore
```
# Prevent committing sensitive files
.vault_pass
.vault_password
*.key
*.pem
*password*
*secret*
.env
```

#### .cursorignore
```
# Prevent AI access to sensitive files
.vault_pass
*password*
*secret*
.env
```

#### File Permissions
```bash
# Secure sensitive files
chmod 600 ansible/group_vars/switches.yml
chmod 600 .vault_pass
```

### 9. Logging Security

**Safe Logging**:
```yaml
- name: Task with password
  cisco.ios.ios_command:
    commands:
      - "copy ftp://{{ ftp_username }}:{{ ftp_password }}@..."
  no_log: true  # Prevents password in logs
```

**Current Implementation**:
- Debug output does NOT display plain-text passwords
- Ansible automatically masks passwords in verbose output
- FTP passwords in URLs are handled securely

### 10. Audit and Compliance

#### Security Checklist

Before deploying to production:

- [ ] All credentials encrypted with Ansible Vault
- [ ] No plain-text passwords in any files
- [ ] `.gitignore` properly configured
- [ ] Vault password stored securely (password manager)
- [ ] SSH keys used where possible
- [ ] Management VRF configured (if applicable)
- [ ] File permissions set correctly (600 for sensitive files)
- [ ] Audit logs enabled on switches
- [ ] Regular credential rotation scheduled
- [ ] Security scanning completed

#### Regular Security Audits

```bash
# Check for hardcoded secrets
grep -r "password\|secret\|key" ansible/ --exclude-dir=.git

# Verify Vault encryption
head -1 ansible/group_vars/switches.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256

# Check file permissions
ls -la ansible/group_vars/
ls -la .vault_pass
```

## Incident Response

### If Credentials Are Compromised

1. **Immediate Actions**:
   - Change all compromised passwords on switches
   - Rotate vault password
   - Re-encrypt all sensitive variables
   - Review access logs on switches

2. **Investigation**:
   - Identify how credentials were exposed
   - Check git history for leaked secrets
   - Review who had access to vault password

3. **Remediation**:
   - Update all credentials
   - Re-encrypt with new vault password
   - Update documentation
   - Notify security team

### Git Secret Scanning

If secrets were committed to git:

```bash
# Remove from git history (dangerous - backup first!)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch ansible/group_vars/switches.yml" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (coordinate with team!)
git push origin --force --all
```

**Better approach**: Use tools like `git-secrets` or `trufflehog` to prevent commits with secrets.

## Compliance Standards

This project is designed to comply with:

- ✅ **NIST SP 800-53**: Security and Privacy Controls
- ✅ **CIS Benchmarks**: Cisco IOS Security
- ✅ **PCI DSS**: Payment Card Industry Data Security Standard
- ✅ **SOC 2**: Security, Availability, and Confidentiality

## Security Training Resources

- [Ansible Security Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html#security)
- [NIST Cryptographic Standards](https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines)
- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

## Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** create a public GitHub issue
2. Contact the security team directly
3. Provide detailed information about the vulnerability
4. Allow time for patch development before disclosure

## Security Contact

For security concerns: [Your Security Team Email]

---

**Remember**: Security is everyone's responsibility. When in doubt, ask! 🔒

