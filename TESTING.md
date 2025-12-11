# Testing Guide for IOS-XE Upgrade Playbook

## Pre-Deployment Testing

### 1. Syntax Validation

Validate YAML syntax and playbook structure:

```bash
# Check playbook syntax
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml --syntax-check

# Expected output:
# playbook: ansible/playbooks/upgrade_ios_xe.yml
```

### 2. YAML Linting

Use yamllint for additional validation:

```bash
# Install yamllint
pip install yamllint

# Lint all YAML files
yamllint ansible/

# Or lint specific files
yamllint ansible/playbooks/upgrade_ios_xe.yml
yamllint ansible/group_vars/switches.yml
```

### 3. Ansible-Lint

Run ansible-lint for best practices:

```bash
# Install ansible-lint
pip install ansible-lint

# Run linting
ansible-lint ansible/playbooks/upgrade_ios_xe.yml
```

## Dry-Run Testing

### Check Mode (No Changes)

Run in check mode to see what would happen without making changes:

```bash
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  --check
```

**Note**: Check mode has limitations with network devices and may fail at certain tasks that require actual execution.

### Diff Mode

Show differences that would be made:

```bash
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  --check --diff
```

## Lab Environment Testing

### Recommended Lab Setup

1. **Isolated Network**: Test on isolated switches (not production)
2. **Console Access**: Have console/OOB access available
3. **Backup Configuration**: Save full configs before testing
4. **Rollback Plan**: Document rollback procedure

### Test Scenarios

#### Scenario 1: Already at Target Version

```bash
# Should skip upgrade and complete successfully
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  --limit switch_already_upgraded \
  -vvv
```

**Expected**: Playbook detects version match and skips upgrade.

#### Scenario 2: Bundle Mode Conversion

```bash
# Test bundle-to-install conversion
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  --limit switch_in_bundle_mode \
  -vvv
```

**Expected**: 
- Boot variables cleared
- Install mode conversion successful
- Version upgraded

#### Scenario 3: Install Mode Upgrade

```bash
# Test normal upgrade in install mode
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  --limit switch_in_install_mode \
  -vvv
```

**Expected**:
- Old packages removed
- New version installed
- Verification successful

#### Scenario 4: Insufficient Flash Space

Pre-test setup:
```bash
# Manually fill flash to test failure handling
# ssh to switch and create large files
```

**Expected**: Playbook fails with clear error message about insufficient space.

## Smoke Testing

### Basic Connectivity Test

```yaml
# Create test_connectivity.yml
---
- name: Test Switch Connectivity
  hosts: switches
  gather_facts: false
  
  tasks:
    - name: Test SSH connection
      cisco.ios.ios_facts:
        gather_subset: min
      
    - name: Display hostname
      ansible.builtin.debug:
        msg: "Connected to {{ ansible_net_hostname }}"
```

Run test:
```bash
ansible-playbook test_connectivity.yml -i ansible/inventory.ini
```

### Version Check Test

```yaml
# Create test_version_check.yml
---
- name: Test Version Detection
  hosts: switches
  gather_facts: false
  
  tasks:
    - name: Gather version
      cisco.ios.ios_facts:
        gather_subset: hardware
      
    - name: Display version
      ansible.builtin.debug:
        msg: "Current version: {{ ansible_facts.ansible_net_version }}"
    
    - name: Check boot mode
      cisco.ios.ios_command:
        commands:
          - show version | include INSTALL|BUNDLE
      register: boot_mode
    
    - name: Display boot mode
      ansible.builtin.debug:
        msg: "{{ boot_mode.stdout[0] }}"
```

Run test:
```bash
ansible-playbook test_version_check.yml -i ansible/inventory.ini
```

## Unit Testing

### Test Individual Tasks

Create task-specific test playbooks:

```yaml
# test_flash_space.yml
---
- name: Test Flash Space Check
  hosts: switches
  gather_facts: false
  
  tasks:
    - name: Check flash space
      cisco.ios.ios_command:
        commands:
          - dir flash: | include bytes free
      register: flash_output
    
    - name: Parse flash space
      ansible.builtin.set_fact:
        flash_free_bytes: "{{ flash_output.stdout[0] | regex_search('(\\d+) bytes free', '\\1') | first }}"
    
    - name: Display
      ansible.builtin.debug:
        msg: "Free: {{ (flash_free_bytes | int / 1024 / 1024) | int }} MB"
```

## Integration Testing

### End-to-End Test Plan

1. **Pre-Test Verification**
   ```bash
   # Document current state
   ansible-playbook test_version_check.yml -i ansible/inventory.ini > pre_test_state.txt
   ```

2. **Execute Upgrade**
   ```bash
   # Run with maximum verbosity
   ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
     -i ansible/inventory.ini \
     --limit test_switch01 \
     -vvv | tee upgrade_log.txt
   ```

3. **Post-Test Verification**
   ```bash
   # Verify new state
   ansible-playbook test_version_check.yml -i ansible/inventory.ini > post_test_state.txt
   
   # Compare states
   diff pre_test_state.txt post_test_state.txt
   ```

4. **Functional Testing**
   - Test switch basic functionality
   - Verify routing protocols
   - Check interface status
   - Validate VLANs and trunks
   - Test management access

## Performance Testing

### Timing Tests

Add timing to playbook tasks:

```bash
# Run with profile tasks callback
ANSIBLE_CALLBACK_WHITELIST=profile_tasks \
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini
```

### Expected Timings

| Task | Expected Duration |
|------|------------------|
| FTP Transfer (1GB) | 10-15 minutes |
| Install Process | 15-20 minutes |
| Reboot & Reconnect | 5-10 minutes |
| **Total** | **30-45 minutes** |

## Regression Testing

### Test After Code Changes

```bash
# Run full test suite
./run_tests.sh

# Test specific scenarios
ansible-playbook test_bundle_mode.yml -i ansible/inventory.ini
ansible-playbook test_install_mode.yml -i ansible/inventory.ini
ansible-playbook test_version_match.yml -i ansible/inventory.ini
```

## Security Testing

### Credential Handling Test

```bash
# Verify no plain-text passwords in output
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  -vvv 2>&1 | grep -i "password\|secret"

# Should see masked output like: ********
```

### Vault Encryption Test

```bash
# Verify vault files are encrypted
head -1 ansible/group_vars/switches.yml

# Should see: $ANSIBLE_VAULT;1.1;AES256
```

## Failure Testing

### Simulate Failures

1. **Network Interruption**
   - Disconnect network mid-upgrade
   - Expected: Playbook timeout and failure

2. **Wrong Credentials**
   - Use incorrect passwords
   - Expected: Authentication failure

3. **FTP Server Down**
   - Stop FTP server
   - Expected: Transfer failure with clear error

4. **Insufficient Permissions**
   - Use non-privileged user
   - Expected: Enable password failure

## Acceptance Testing Checklist

Before production deployment:

- [ ] Syntax check passes
- [ ] Ansible-lint passes
- [ ] Test connectivity successful
- [ ] Version detection accurate
- [ ] Bundle mode conversion works
- [ ] Install mode upgrade works
- [ ] Flash space check works
- [ ] Insufficient space fails gracefully
- [ ] Version verification accurate
- [ ] Boot mode verification accurate
- [ ] Credentials properly encrypted
- [ ] No sensitive data in logs
- [ ] Timing within expected ranges
- [ ] Rollback procedure documented
- [ ] Lab testing completed
- [ ] Documentation reviewed

## Test Environment Setup

### Minimal Lab Setup

```ini
# lab_inventory.ini
[switches]
lab-switch-01 ansible_host=192.168.1.10
lab-switch-02 ansible_host=192.168.1.11
```

### Test FTP Server

```bash
# Quick FTP server for testing (vsftpd example)
sudo apt install vsftpd
sudo systemctl start vsftpd

# Or use Python for testing
python3 -m pyftpdlib -p 21 -w
```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/test.yml
name: Ansible Playbook Tests

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Ansible
        run: pip install ansible ansible-lint
      - name: Syntax check
        run: ansible-playbook ansible/playbooks/upgrade_ios_xe.yml --syntax-check
      - name: Ansible lint
        run: ansible-lint ansible/playbooks/upgrade_ios_xe.yml
```

## Reporting

### Generate Test Report

```bash
# Capture full output
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  -vvv > test_report_$(date +%Y%m%d_%H%M%S).log 2>&1
```

### Test Results Format

Document results:
- Test date/time
- Ansible version
- Switch model and current version
- Test scenario
- Result (Pass/Fail)
- Duration
- Issues encountered
- Recommendations

## Troubleshooting Test Failures

### Common Test Issues

1. **Module Not Found**
   ```bash
   # Install required collections
   ansible-galaxy collection install -r ansible/requirements.yml
   ```

2. **Connection Timeout**
   - Check network connectivity
   - Verify SSH is enabled
   - Check firewall rules

3. **Authentication Failure**
   - Verify credentials in group_vars
   - Check enable password
   - Test manual SSH connection

## Next Steps

After successful testing:
1. Document test results
2. Update any playbook issues found
3. Schedule production maintenance window
4. Prepare rollback plan
5. Execute production upgrade

