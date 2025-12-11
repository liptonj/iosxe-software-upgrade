# Windows Setup Guide

Complete guide for setting up and using the IOS-XE upgrade automation on Windows.

## Quick Start

### 1. Install Python 3.10+

**Option A: Official Python Installer** (Recommended)

1. Download from https://www.python.org/downloads/
2. Run installer
3. ✅ **IMPORTANT**: Check "Add Python to PATH"
4. Click "Install Now"

**Option B: Windows Package Manager (winget)**

```powershell
winget install Python.Python.3.12
```

**Option C: Chocolatey**

```powershell
choco install python
```

### 2. Run Setup Script

**Double-click** `setup_venv.bat` **OR** run in PowerShell:

```powershell
# Navigate to project directory
cd C:\path\to\iosxe-software-upgrade

# Run setup (automatically uses PowerShell)
.\setup_venv.bat

# Or run PowerShell directly
.\setup_venv.ps1
```

**If you see an execution policy error:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 3. Activate Virtual Environment

**PowerShell:**

```powershell
.\.venv\Scripts\Activate.ps1
```

**Command Prompt (cmd.exe):**

```cmd
.venv\Scripts\activate.bat
```

### 4. Configure Your Switches

**Create variables file from template:**

```powershell
# Copy the template
copy ansible\group_vars\switches.yml.template ansible\group_vars\switches.yml

# Edit with your credentials
notepad ansible\group_vars\switches.yml
```

**Edit inventory:**

```powershell
notepad ansible\inventory.ini
```

### 5. Encrypt Credentials (REQUIRED!)

**⚠️ CRITICAL**: Never commit unencrypted credentials!

```powershell
ansible-vault encrypt ansible\group_vars\switches.yml
```

**Note**: The `switches.yml` file is in `.gitignore` and won't be committed.  
Use `switches.yml.template` for reference.

### 6. Test Connectivity

```powershell
.\run.ps1 test-connectivity
```

## Daily Operations (Windows)

### Using run.ps1 (Recommended)

The `run.ps1` script provides all the same commands as the Linux/Mac `Makefile`:

```powershell
# Make sure virtual environment is activated first!
.\.venv\Scripts\Activate.ps1

# Show all available commands
.\run.ps1 help

# Backup configurations
.\run.ps1 backup
.\run.ps1 backup switch01

# Check versions
.\run.ps1 check-version

# Run upgrade
.\run.ps1 upgrade switch01

# List backups
.\run.ps1 backup-list

# View encrypted variables
.\run.ps1 vault-view
```

### Using Ansible Directly

```powershell
# Backup switches
ansible-playbook ansible\playbooks\backup_configs.yml `
  -i ansible\inventory.ini `
  --ask-vault-pass

# Upgrade single switch
ansible-playbook ansible\playbooks\upgrade_ios_xe.yml `
  -i ansible\inventory.ini `
  --limit switch01 `
  --ask-vault-pass

# Check connectivity
ansible switches -i ansible\inventory.ini -m ping --ask-vault-pass
```

## File Paths (Windows vs Linux/Mac)

| Linux/Mac            | Windows                                  | Description     |
| -------------------- | ---------------------------------------- | --------------- |
| `./setup_venv.sh`    | `.\setup_venv.ps1` or `.\setup_venv.bat` | Setup script    |
| `make backup`        | `.\run.ps1 backup`                       | Backup configs  |
| `make upgrade`       | `.\run.ps1 upgrade`                      | Run upgrade     |
| `ansible/`           | `ansible\`                               | Use backslashes |
| `.venv/bin/activate` | `.venv\Scripts\Activate.ps1`             | Activate venv   |

## Windows-Specific Notes

### PowerShell Execution Policy

If scripts won't run, you may need to adjust the execution policy:

```powershell
# Check current policy
Get-ExecutionPolicy

# Allow running scripts (recommended for current user only)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or bypass temporarily for one command
powershell -ExecutionPolicy Bypass -File .\setup_venv.ps1
```

### Long Path Support

Windows has a 260-character path limit by default. If you encounter path-too-long errors:

1. Press `Win + R`
2. Type `gpedit.msc`
3. Navigate to: Computer Configuration → Administrative Templates → System → Filesystem
4. Enable "Enable Win32 long paths"

**Or** via Registry:

```powershell
# Run as Administrator
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
  -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

### SSH Issues

**Problem**: "paramiko not installed" or SSH connection fails

**Solution**:

```powershell
pip install paramiko
```

**For better performance** (optional):

```powershell
# Install via Chocolatey or vcpkg (requires build tools)
# Then:
pip install ansible-pylibssh
```

### Firewall Issues

If connections to switches fail:

1. Check Windows Firewall
2. Allow Python through firewall:
   - Windows Security → Firewall & network protection
   - Allow an app through firewall
   - Add Python

## IDE Setup (Windows)

### VS Code (Recommended)

1. Install VS Code: https://code.visualstudio.com/
2. Install extensions:
   - Python (Microsoft)
   - Ansible (Red Hat)
   - YAML (Red Hat)
3. Open project folder
4. Select Python interpreter:
   - Press `Ctrl+Shift+P`
   - Type "Python: Select Interpreter"
   - Choose `.venv\Scripts\python.exe`

### PyCharm

1. Open project
2. File → Settings → Project → Python Interpreter
3. Click gear icon → Add
4. Choose "Existing environment"
5. Select `.venv\Scripts\python.exe`

## Troubleshooting

### "python is not recognized"

Python is not in PATH. Reinstall Python and check "Add Python to PATH" or add manually:

```powershell
# Add to PATH temporarily
$env:Path += ";C:\Users\YourName\AppData\Local\Programs\Python\Python312"

# Or add permanently via System Properties → Environment Variables
```

### "ansible-playbook is not recognized"

Virtual environment is not activated. Run:

```powershell
.\.venv\Scripts\Activate.ps1
```

You should see `(.venv)` at the beginning of your prompt.

### "permission denied" errors

Run PowerShell as Administrator:

1. Right-click PowerShell icon
2. Choose "Run as Administrator"

### Virtual environment won't activate

Try Command Prompt instead of PowerShell:

```cmd
.venv\Scripts\activate.bat
```

### Backup files not saving

Check folder permissions. Run as Administrator or change backup directory:

```yaml
# In ansible\group_vars\switches.yml
backup_dir: "C:\\Users\\YourName\\Documents\\switch-backups"
```

## Command Reference

### Setup Commands

```powershell
# Initial setup
.\setup_venv.bat                    # Run setup

# Activate environment
.\.venv\Scripts\Activate.ps1        # PowerShell
.venv\Scripts\activate.bat          # Command Prompt

# Deactivate
deactivate
```

### Upgrade Commands

```powershell
# Backup first
.\run.ps1 backup

# Upgrade all switches
.\run.ps1 upgrade

# Upgrade specific switch
.\run.ps1 upgrade switch01

# Verbose output
ansible-playbook ansible\playbooks\upgrade_ios_xe.yml `
  -i ansible\inventory.ini `
  -vvv
```

### Vault Commands

```powershell
# Encrypt credentials
.\run.ps1 vault-encrypt

# Edit encrypted file
.\run.ps1 vault-edit

# View encrypted file
.\run.ps1 vault-view

# Decrypt (not recommended)
.\run.ps1 vault-decrypt
```

## Performance Tips

1. **Use SSD**: Store project on SSD for faster Python package installation
2. **Disable antivirus scanning** for `.venv` folder (speeds up script execution)
3. **Use Windows Terminal**: Better than default Command Prompt
4. **Enable Developer Mode**: Settings → Update & Security → For developers

## Differences from Linux/Mac

| Feature                | Linux/Mac                   | Windows                        |
| ---------------------- | --------------------------- | ------------------------------ |
| Setup script           | `setup_venv.sh`             | `setup_venv.ps1` or `.bat`     |
| Command runner         | `Makefile` (make)           | `run.ps1`                      |
| Path separator         | `/`                         | `\`                            |
| Virtual env activation | `source .venv/bin/activate` | `.\.venv\Scripts\Activate.ps1` |
| Package manager        | brew/apt                    | winget/choco                   |
| SSH library            | Usually libssh              | paramiko (easier)              |

## Getting Help

```powershell
# Show all commands
.\run.ps1 help

# Ansible help
ansible-playbook --help
ansible-vault --help

# Python version
python --version

# Installed packages
pip list
```

## Next Steps

After setup:

1. ✅ Read main [README.md](README.md) for complete documentation
2. ✅ Review [SECURITY.md](SECURITY.md) for best practices
3. ✅ Check [BACKUP_RESTORE.md](BACKUP_RESTORE.md) for backup procedures
4. ✅ Test in lab environment first!

---

**Need more help?** Check the main README.md for detailed documentation.
