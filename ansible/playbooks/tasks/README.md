# Upgrade Task Modules

This directory contains modular task files used by the upgrade playbook. Breaking the large playbook into smaller, focused task files makes it easier to maintain, test, and reuse.

## Task Files

### 01_display_execution_mode.yml

**Purpose**: Display execution mode status (dry-run, serial, parallel)  
**When**: Run once at the beginning  
**Variables used**: `dry_run`, `serial_mode`, `max_fail_pct`, `fail_fast`

### 02_initialize_and_detect_model.yml

**Purpose**: Initialize variables and detect switch model  
**Tasks**:

- Set backup directory
- Gather switch facts
- Detect model family (C9200, C9300, etc.)
- Select target version based on model
- Select image file based on model
- Check if already at target version (skip if yes)

**Variables set**: `model_family`, `selected_target_version`, `selected_image_file`

### 03_backup_configuration.yml

**Purpose**: Backup switch configuration before upgrade  
**Tasks**:

- Create backup timestamp
- Create backup directory
- Backup running-config to Ansible controller
- Optional FTP backup
- Save configuration summary

**Variables set**: `backup_timestamp`  
**Files created**: `{hostname}_running-config_{timestamp}.cfg`, `{hostname}_summary_{timestamp}.txt`

### 04_check_boot_mode.yml

**Purpose**: Check boot mode and prepare for bundle-to-install conversion  
**Tasks**:

- Check if in INSTALL or BUNDLE mode
- If BUNDLE: Clear old boot variables
- Prepare for install mode conversion

**Variables set**: `is_bundle_mode`

### 05_prepare_for_upgrade.yml

**Purpose**: Prepare switch for upgrade  
**Tasks**:

- Save running-config to startup-config
- Remove inactive packages (if install mode)
- Check flash space after cleanup
- Fail if insufficient space

**Variables set**: `flash_free_mb`, `flash_free_bytes`

### 06_transfer_image.yml

**Purpose**: Transfer IOS-XE image via FTP  
**Tasks**:

- Copy image from FTP server to flash
- Display transfer status

**Duration**: ~10-15 minutes

### 07_install_and_reboot.yml

**Purpose**: Install new image and wait for reboot  
**Tasks**:

- Execute install add/activate/commit
- Wait for switch to reload
- Wait for SSH to become available
- Handle reconnection failures

**Variables set**: `reconnect_result`  
**Duration**: ~30-45 minutes

### 08_post_verification.yml

**Purpose**: Verify upgrade success  
**Tasks**:

- Gather facts after upgrade
- Verify new version matches target
- Verify boot mode is INSTALL
- Display success or failure message

**Variables set**: `post_upgrade_facts`

## Usage

### In a Playbook

```yaml
---
- name: My Custom Upgrade Playbook
  hosts: switches
  gather_facts: false

  tasks:
    # Include specific tasks you need
    - include_tasks: tasks/02_initialize_and_detect_model.yml
    - include_tasks: tasks/03_backup_configuration.yml
    - include_tasks: tasks/05_prepare_for_upgrade.yml
```

### Full Upgrade (Modular)

Use the modular playbook:

```bash
ansible-playbook ansible/playbooks/upgrade_ios_xe_modular.yml \
  -i ansible/inventory.ini \
  --ask-vault-pass
```

### Reusing Individual Tasks

```yaml
# Just backup configs using the task
- name: Backup Only
  hosts: switches
  gather_facts: false
  vars:
    backup_enabled: true
    backup_dir_name: "backups"

  tasks:
    - include_tasks: tasks/02_initialize_and_detect_model.yml
    - include_tasks: tasks/03_backup_configuration.yml
```

## Benefits of Modular Approach

### Maintainability

- ✅ Each file is small and focused (<100 lines)
- ✅ Easy to find and fix issues
- ✅ Clear separation of concerns
- ✅ Better code organization

### Testability

- ✅ Test individual task files
- ✅ Easier to debug specific steps
- ✅ Can run tasks in isolation
- ✅ Better error messages with line numbers

### Reusability

- ✅ Use tasks in other playbooks
- ✅ Mix and match tasks as needed
- ✅ Share common tasks across projects
- ✅ Build custom workflows easily

### Readability

- ✅ Main playbook is clean (~80 lines vs 464 lines)
- ✅ Tasks are self-documented by filename
- ✅ Easier for new team members to understand
- ✅ Clear execution flow

## Comparison

### Monolithic (Current)

**File**: `upgrade_ios_xe.yml` (464 lines)

**Pros**:

- Everything in one place
- No need to jump between files

**Cons**:

- Hard to navigate
- Difficult to maintain
- Can't easily reuse sections
- 464 lines is overwhelming

### Modular (New)

**File**: `upgrade_ios_xe_modular.yml` (~80 lines)  
**Task Files**: 8 files (~50-100 lines each)

**Pros**:

- Easy to navigate and maintain
- Can reuse tasks in other playbooks
- Clear structure
- Better for teams
- Easier testing

**Cons**:

- More files to manage
- Need to jump between files to see full logic

## Variable Flow

Variables flow between task files through the playbook context:

```
01_display_execution_mode.yml
  ↓ (no vars set)

02_initialize_and_detect_model.yml
  ↓ Sets: model_family, selected_target_version, selected_image_file, facts_output

03_backup_configuration.yml
  ↓ Uses: facts_output, selected_target_version
  ↓ Sets: backup_timestamp

04_check_boot_mode.yml
  ↓ Sets: is_bundle_mode

05_prepare_for_upgrade.yml
  ↓ Uses: is_bundle_mode
  ↓ Sets: flash_free_mb

06_transfer_image.yml
  ↓ Uses: selected_image_file

07_install_and_reboot.yml
  ↓ Uses: selected_image_file
  ↓ Sets: reconnect_result

08_post_verification.yml
  ↓ Uses: selected_target_version, reconnect_result
  ↓ Sets: post_upgrade_facts
```

## Migration Path

### Option 1: Keep Both (Recommended)

- Keep `upgrade_ios_xe.yml` (monolithic - works today)
- Add `upgrade_ios_xe_modular.yml` (new modular version)
- Test modular version in parallel
- Switch when confident

### Option 2: Replace Completely

- Backup `upgrade_ios_xe.yml` → `upgrade_ios_xe_legacy.yml`
- Replace with modular version
- Update Makefile to point to modular version

### Option 3: Gradual Migration

- Extract one section at a time
- Test after each extraction
- Eventually fully modular

## Testing Modular Tasks

```bash
# Test individual task file
ansible-playbook -i ansible/inventory.ini test_task.yml

# Where test_task.yml is:
---
- hosts: switches
  gather_facts: false
  tasks:
    - include_tasks: tasks/05_prepare_for_upgrade.yml
```

## Best Practices

1. ✅ **One responsibility per task file**
2. ✅ **Clear, descriptive filenames**
3. ✅ **Document variables used/set**
4. ✅ **Keep tasks under 100 lines**
5. ✅ **Use comments to explain complex logic**
6. ✅ **Test task files individually**

---

**Recommendation**: Use `upgrade_ios_xe_modular.yml` for better maintainability! 🎯
