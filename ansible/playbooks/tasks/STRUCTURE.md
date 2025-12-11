# Task Structure - Atomic and Reusable

## Directory Organization

```
ansible/playbooks/tasks/
├── common/                          # Shared utility tasks
│   ├── gather_switch_facts.yml      # Gather facts from switch
│   ├── detect_model.yml             # Detect model family
│   ├── select_version_and_image.yml # Select version/image by model
│   └── check_version_skip.yml       # Skip if already upgraded
├── backup/                          # Backup operations
│   ├── create_backup_timestamp.yml  # Generate timestamp
│   └── backup_running_config.yml    # Backup to controller
├── boot/                            # Boot mode operations
│   ├── check_boot_mode.yml          # Detect INSTALL/BUNDLE mode
│   └── clear_boot_variables.yml     # Clear boot vars for conversion
├── flash/                           # Flash space operations
│   └── check_flash_space.yml        # Verify sufficient space
├── install/                         # Installation operations
│   ├── save_running_to_startup.yml  # Save config
│   └── remove_inactive_packages.yml # Clean old packages
├── 01_display_execution_mode.yml    # Aggregator: Show execution mode
├── 02_initialize_and_detect_model.yml # Aggregator: Init + model detect
├── 03_backup_configuration.yml      # Aggregator: Backup operations
├── 04_check_boot_mode.yml           # Aggregator: Boot mode tasks
├── 05_prepare_for_upgrade.yml       # Aggregator: Preparation tasks
├── 06_transfer_image.yml            # Transfer image (atomic)
├── 07_install_and_reboot.yml        # Install and reboot (atomic)
├── 08_post_verification.yml         # Verify upgrade (atomic)
├── test_connectivity.yml            # Test task: SSH connectivity
├── check_flash_space_detailed.yml   # Test task: Detailed flash analysis
├── README.md                        # Task documentation
└── STRUCTURE.md                     # This file
```

## Task Hierarchy

### Level 1: Main Playbook
```
upgrade_ios_xe.yml (~100 lines)
  └── Calls numbered aggregator tasks (01-08)
```

### Level 2: Aggregator Tasks
```
02_initialize_and_detect_model.yml
  ├── common/gather_switch_facts.yml
  ├── common/detect_model.yml
  ├── common/select_version_and_image.yml
  └── common/check_version_skip.yml

03_backup_configuration.yml
  ├── backup/create_backup_timestamp.yml
  └── backup/backup_running_config.yml

04_check_boot_mode.yml
  ├── boot/check_boot_mode.yml
  └── boot/clear_boot_variables.yml

05_prepare_for_upgrade.yml
  ├── install/save_running_to_startup.yml
  ├── install/remove_inactive_packages.yml
  └── flash/check_flash_space.yml
```

### Level 3: Atomic Tasks
```
common/gather_switch_facts.yml       (~10 lines)
common/detect_model.yml              (~10 lines)
common/select_version_and_image.yml  (~30 lines)
boot/check_boot_mode.yml             (~20 lines)
boot/clear_boot_variables.yml        (~30 lines)
flash/check_flash_space.yml          (~25 lines)
install/save_running_to_startup.yml  (~20 lines)
install/remove_inactive_packages.yml (~30 lines)
... and more
```

## Benefits of Atomic Tasks

### 1. Maximum Reusability

**Example: Just check boot mode in custom playbook**
```yaml
---
- name: Check All Switch Boot Modes
  hosts: switches
  tasks:
    - include_tasks: tasks/common/gather_switch_facts.yml
    - include_tasks: tasks/boot/check_boot_mode.yml
```

**Example: Just backup without upgrade**
```yaml
---
- name: Backup Only
  hosts: switches
  tasks:
    - include_tasks: tasks/common/gather_switch_facts.yml
    - include_tasks: tasks/backup/create_backup_timestamp.yml
    - include_tasks: tasks/backup/backup_running_config.yml
```

### 2. Mix and Match

Build custom workflows easily:

```yaml
---
- name: Custom Pre-Flight Check
  hosts: switches
  tasks:
    - include_tasks: tasks/common/gather_switch_facts.yml
    - include_tasks: tasks/common/detect_model.yml
    - include_tasks: tasks/boot/check_boot_mode.yml
    - include_tasks: tasks/flash/check_flash_space.yml
    # Stop here - no upgrade
```

### 3. Easy Testing

Test individual atomic tasks:

```bash
# Test just model detection
ansible-playbook test_model_detect.yml

# Where test_model_detect.yml is:
---
- hosts: switches[0]
  tasks:
    - include_tasks: tasks/common/gather_switch_facts.yml
    - include_tasks: tasks/common/detect_model.yml
```

### 4. Clear Dependencies

Each atomic task has minimal dependencies:

| Task | Requires | Sets |
|------|----------|------|
| `gather_switch_facts.yml` | Nothing | `facts_output` |
| `detect_model.yml` | `facts_output` | `model_family` |
| `select_version_and_image.yml` | `model_family` | `selected_target_version`, `selected_image_file` |
| `check_boot_mode.yml` | Nothing | `is_bundle_mode`, `is_install_mode` |
| `clear_boot_variables.yml` | Nothing | None |
| `check_flash_space.yml` | Nothing | `flash_free_mb` |
| `save_running_to_startup.yml` | Nothing | None |
| `remove_inactive_packages.yml` | `is_bundle_mode` | None |

## Usage Examples

### Example 1: Verify All Switches Without Upgrading

```yaml
---
- name: Verification Only
  hosts: switches
  gather_facts: false
  tasks:
    - include_tasks: tasks/common/gather_switch_facts.yml
    - include_tasks: tasks/common/detect_model.yml
    - include_tasks: tasks/common/select_version_and_image.yml
    - include_tasks: tasks/boot/check_boot_mode.yml
    - include_tasks: tasks/flash/check_flash_space.yml
    
    - name: Report status
      ansible.builtin.debug:
        msg: |
          {{ inventory_hostname }}:
          - Model: {{ model_family }}
          - Version: {{ facts_output.ansible_facts.ansible_net_version }}
          - Target: {{ selected_target_version }}
          - Boot Mode: {{ 'Install' if is_install_mode else 'Bundle' }}
          - Flash Free: {{ flash_free_mb }} MB
          - Ready: {{ 'Yes' if flash_free_mb | int > 2048 else 'No' }}
```

### Example 2: Just Clean Old Packages

```yaml
---
- name: Clean Old Packages
  hosts: switches
  gather_facts: false
  vars:
    dry_run: false
  tasks:
    - include_tasks: tasks/boot/check_boot_mode.yml
    - include_tasks: tasks/install/remove_inactive_packages.yml
```

### Example 3: Mass Backup

```yaml
---
- name: Backup All Switches
  hosts: switches
  gather_facts: false
  vars:
    backup_enabled: true
    backup_dir_name: "backups"
  tasks:
    - include_tasks: tasks/common/gather_switch_facts.yml
    - include_tasks: tasks/backup/create_backup_timestamp.yml
    - include_tasks: tasks/backup/backup_running_config.yml
```

### Example 4: Health Check Report

```yaml
---
- name: Generate Health Report
  hosts: switches
  gather_facts: false
  tasks:
    - include_tasks: tasks/common/gather_switch_facts.yml
    - include_tasks: tasks/common/detect_model.yml
    - include_tasks: tasks/boot/check_boot_mode.yml
    - include_tasks: tasks/flash/check_flash_space.yml
    
    - name: Save health report
      ansible.builtin.copy:
        content: |
          Switch: {{ inventory_hostname }}
          Model: {{ facts_output.ansible_facts.ansible_net_model }}
          Version: {{ facts_output.ansible_facts.ansible_net_version }}
          Boot Mode: {{ 'Install' if is_install_mode else 'Bundle' }}
          Flash Free: {{ flash_free_mb }} MB
        dest: "./reports/{{ inventory_hostname }}_health.txt"
      delegate_to: localhost
```

## Atomic Task Design Principles

### 1. Single Responsibility
✅ Each task does ONE thing well  
❌ Don't combine unrelated operations

### 2. Minimal Dependencies
✅ Only depend on variables that must exist  
❌ Don't assume too much context

### 3. Clear Naming
✅ Verb + noun: `gather_switch_facts`, `check_boot_mode`  
❌ Vague names: `init`, `setup`, `run`

### 4. Self-Contained
✅ Can run independently (if dependencies met)  
❌ Don't require specific task order (unless documented)

### 5. Small Size
✅ Under 50 lines ideally  
❌ Avoid 100+ line "atomic" tasks

## Directory Naming Conventions

| Directory | Purpose | Example Tasks |
|-----------|---------|---------------|
| `common/` | Shared utilities used everywhere | gather_facts, detect_model |
| `backup/` | Backup-related operations | create_timestamp, backup_config |
| `boot/` | Boot mode operations | check_mode, clear_variables |
| `flash/` | Flash storage operations | check_space, list_files |
| `install/` | Install/upgrade operations | save_config, remove_packages |
| `verify/` | Verification operations | check_version, verify_boot_mode |
| `transfer/` | File transfer operations | ftp_transfer, scp_transfer |

## Extending with New Atomic Tasks

### Adding a New Atomic Task

**Step 1**: Create the atomic task file

```bash
vim ansible/playbooks/tasks/verify/check_routing.yml
```

```yaml
---
# Verify routing is working post-upgrade
- name: Check routing table
  cisco.ios.ios_command:
    commands:
      - show ip route summary
  register: route_check

- name: Display route count
  ansible.builtin.debug:
    msg: "Routes: {{ route_check.stdout[0] }}"
```

**Step 2**: Include in aggregator or main playbook

```yaml
# In 08_post_verification.yml, add:
- name: Check routing
  ansible.builtin.include_tasks: verify/check_routing.yml
```

## Best Practices

### ✅ DO

- Keep atomic tasks under 50 lines
- Use clear, descriptive filenames
- Document dependencies at top of file
- Use consistent variable naming
- Make tasks idempotent
- Handle dry-run mode where applicable

### ❌ DON'T

- Mix multiple responsibilities in one atomic task
- Create deep nesting (max 3 levels: main → aggregator → atomic)
- Hardcode values - use variables
- Forget error handling
- Skip documentation

## Testing Atomic Tasks

```bash
# Create simple test wrapper
cat > test_atomic.yml <<EOF
---
- hosts: switches[0]
  gather_facts: false
  vars:
    required_space_mb: 2048
  tasks:
    - include_tasks: tasks/flash/check_flash_space.yml
EOF

# Run it
ansible-playbook test_atomic.yml -i ansible/inventory.ini
```

---

**Atomic tasks = maximum flexibility and reusability!** 🎯

