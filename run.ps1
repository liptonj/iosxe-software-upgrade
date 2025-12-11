# PowerShell script for running Ansible tasks (Windows alternative to Makefile)
# IOS-XE Software Upgrade - Command Runner

param(
  [Parameter(Position = 0)]
  [string]$Command = "help",
    
  [Parameter(Position = 1)]
  [string]$Limit = "all"
)

# Variables
$PLAYBOOK = "ansible\playbooks\upgrade_ios_xe.yml"
$INVENTORY = "ansible\inventory.ini"
$VAULT_PASS = "--ask-vault-pass"

# Colors
function Write-Header {
  param([string]$Message)
  Write-Host $Message -ForegroundColor Cyan
}

function Write-Success {
  param([string]$Message)
  Write-Host $Message -ForegroundColor Green
}

function Write-Error {
  param([string]$Message)
  Write-Host $Message -ForegroundColor Red
}

# Suppress Ansible warnings
$env:ANSIBLE_DEPRECATION_WARNINGS = "False"
$env:ANSIBLE_COMMAND_WARNINGS = "False"
$env:ANSIBLE_ACTION_WARNINGS = "False"
$env:ANSIBLE_SYSTEM_WARNINGS = "False"
$env:ANSIBLE_LOCALHOST_WARNING = "False"

# Check if virtual environment is activated
if (-not $env:VIRTUAL_ENV) {
  Write-Error "Virtual environment is not activated!"
  Write-Host ""
  Write-Host "Please activate the virtual environment first:" -ForegroundColor Yellow
  Write-Host "  .\.venv\Scripts\Activate.ps1" -ForegroundColor White
  Write-Host ""
  Write-Host "Or on Command Prompt:" -ForegroundColor Yellow
  Write-Host "  .venv\Scripts\activate.bat" -ForegroundColor White
  exit 1
}

# Command implementations
switch ($Command.ToLower()) {
  "help" {
    Write-Header "Cisco IOS-XE Upgrade Automation - Available Commands:"
    Write-Host ""
    Write-Host "Setup & Testing:" -ForegroundColor Yellow
    Write-Host "  .\run.ps1 install           - Install Ansible and required collections"
    Write-Host "  .\run.ps1 test-syntax       - Validate playbook syntax"
    Write-Host "  .\run.ps1 test-connectivity - Test SSH connectivity to switches"
    Write-Host "  .\run.ps1 check-version     - Check current IOS-XE version on all switches"
    Write-Host ""
    Write-Host "Backup & Restore:" -ForegroundColor Yellow
    Write-Host "  .\run.ps1 backup            - Backup all switch configurations"
    Write-Host "  .\run.ps1 backup-list       - List all backup files"
    Write-Host "  .\run.ps1 restore-info      - Display restore instructions"
    Write-Host ""
    Write-Host "Upgrade Operations:" -ForegroundColor Yellow
    Write-Host "  .\run.ps1 upgrade           - Run upgrade playbook"
    Write-Host "  .\run.ps1 upgrade-dry-run   - Test upgrade workflow WITHOUT making changes"
    Write-Host ""
    Write-Host "Maintenance:" -ForegroundColor Yellow
    Write-Host "  .\run.ps1 lint              - Run ansible-lint on playbook"
    Write-Host "  .\run.ps1 clean             - Clean up Ansible retry files and logs"
    Write-Host ""
    Write-Host "Vault Operations:" -ForegroundColor Yellow
    Write-Host "  .\run.ps1 vault-encrypt     - Encrypt variables file"
    Write-Host "  .\run.ps1 vault-decrypt     - Decrypt variables file"
    Write-Host "  .\run.ps1 vault-edit        - Edit encrypted variables"
    Write-Host "  .\run.ps1 vault-view        - View encrypted variables"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\run.ps1 backup switch01           # Backup single switch"
    Write-Host "  .\run.ps1 upgrade switch01          # Upgrade single switch"
    Write-Host "  .\run.ps1 check-version             # Check all switches"
    Write-Host ""
  }
    
  "install" {
    Write-Header "Installing Ansible and collections..."
    pip install -r requirements.txt
    ansible-galaxy collection install -r ansible\requirements.yml
    Write-Success "Installation complete!"
  }
    
  "test-syntax" {
    Write-Header "Validating playbook syntax..."
    ansible-playbook $PLAYBOOK --syntax-check
    if ($LASTEXITCODE -eq 0) {
      Write-Success "Syntax check passed!"
    }
  }
    
  "test-connectivity" {
    Write-Header "Testing connectivity to switches..."
    ansible switches -i $INVENTORY -m ping $VAULT_PASS
  }
    
  "check-version" {
    Write-Header "Checking current IOS-XE versions..."
    ansible switches -i $INVENTORY `
      -m cisco.ios.ios_command `
      -a "commands='show version | include Version'" `
      $VAULT_PASS
  }
    
  "backup" {
    Write-Header "Backing up switch configurations..."
    if (-not (Test-Path "backups")) {
      New-Item -ItemType Directory -Path "backups" | Out-Null
    }
    $limitArg = if ($Limit -ne "all") { "--limit $Limit" } else { "" }
    ansible-playbook ansible\playbooks\backup_configs.yml `
      -i $INVENTORY `
      $limitArg `
      $VAULT_PASS
  }
    
  "backup-list" {
    Write-Header "Available configuration backups:"
    Write-Host "==================================" -ForegroundColor Cyan
    if (Test-Path "backups") {
      Get-ChildItem -Path "backups" -File | 
      Sort-Object LastWriteTime -Descending | 
      Select-Object -First 20 |
      Format-Table Name, Length, LastWriteTime -AutoSize
    }
    else {
      Write-Host "No backups directory found. Run '.\run.ps1 backup' first."
    }
  }
    
  "restore-info" {
    Write-Header "============================================"
    Write-Header "Configuration Restore Instructions"
    Write-Header "============================================"
    Write-Host ""
    Write-Host "To restore a configuration:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Option 1: Via FTP (if FTP server accessible)" -ForegroundColor Yellow
    Write-Host "  1. Copy backup to FTP server"
    Write-Host "  2. On switch: copy ftp://user@host/backup.cfg running-config"
    Write-Host ""
    Write-Host "Option 2: Via console/SSH" -ForegroundColor Yellow
    Write-Host "  1. Open backup file locally"
    Write-Host "  2. Copy/paste commands to switch console"
    Write-Host ""
    Write-Host "Recent backups:" -ForegroundColor Cyan
    if (Test-Path "backups") {
      Get-ChildItem -Path "backups\*.cfg" -File -ErrorAction SilentlyContinue | 
      Sort-Object LastWriteTime -Descending | 
      Select-Object -First 5 |
      ForEach-Object { Write-Host "  $_" }
    }
    else {
      Write-Host "  No backups directory found"
    }
    Write-Header "============================================"
  }
    
  "upgrade" {
    Write-Header "Running IOS-XE upgrade playbook..."
    Write-Host "Target: $Limit" -ForegroundColor Cyan
    $limitArg = if ($Limit -ne "all") { "--limit $Limit" } else { "" }
    ansible-playbook $PLAYBOOK `
      -i $INVENTORY `
      $limitArg `
      $VAULT_PASS `
      -vv
  }
    
  "upgrade-dry-run" {
    Write-Header "Running IOS-XE upgrade playbook in DRY-RUN mode..."
    Write-Host "Target: $Limit" -ForegroundColor Cyan
    Write-Host "🔍 DRY-RUN: No changes will be made to switches" -ForegroundColor Yellow
    $limitArg = if ($Limit -ne "all") { "--limit $Limit" } else { "" }
    ansible-playbook $PLAYBOOK `
      -i $INVENTORY `
      $limitArg `
      -e "dry_run=true" `
      $VAULT_PASS `
      -vv
  }
    
  "lint" {
    Write-Header "Running ansible-lint..."
    ansible-lint $PLAYBOOK
    Write-Header "Running yamllint..."
    yamllint ansible\
  }
    
  "clean" {
    Write-Header "Cleaning up..."
    Get-ChildItem -Path . -Filter "*.retry" -Recurse | Remove-Item -Force
    Get-ChildItem -Path . -Filter "*.log" -Recurse | Remove-Item -Force
    Write-Success "Cleanup complete!"
  }
    
  "vault-encrypt" {
    Write-Header "Encrypting group_vars\switches.yml..."
    ansible-vault encrypt ansible\group_vars\switches.yml
  }
    
  "vault-decrypt" {
    Write-Header "Decrypting group_vars\switches.yml..."
    ansible-vault decrypt ansible\group_vars\switches.yml
  }
    
  "vault-edit" {
    Write-Header "Editing encrypted variables..."
    ansible-vault edit ansible\group_vars\switches.yml
  }
    
  "vault-view" {
    Write-Header "Viewing encrypted variables..."
    ansible-vault view ansible\group_vars\switches.yml
  }
    
  default {
    Write-Error "Unknown command: $Command"
    Write-Host ""
    Write-Host "Run '.\run.ps1 help' to see available commands" -ForegroundColor Yellow
    exit 1
  }
}

