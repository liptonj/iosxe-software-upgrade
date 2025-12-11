# PowerShell script for Windows environment setup
# IOS-XE Software Upgrade - Windows Setup

Write-Host "===================================" -ForegroundColor Cyan
Write-Host "IOS-XE Upgrade Environment Setup" -ForegroundColor Cyan
Write-Host "Windows Edition" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Function to test if running as Administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check for Python 3.10+
$pythonFound = $false
$pythonCmd = ""

# Try to find Python 3.10+ in order of preference
$pythonVersions = @("python3.13", "python3.12", "python3.11", "python3.10", "python3", "python")

foreach ($pyVersion in $pythonVersions) {
    if (Get-Command $pyVersion -ErrorAction SilentlyContinue) {
        $versionOutput = & $pyVersion --version 2>&1
        if ($versionOutput -match "Python (\d+)\.(\d+)") {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            
            if ($major -eq 3 -and $minor -ge 10) {
                $pythonCmd = $pyVersion
                $pythonFound = $true
                Write-Host "✓ Found Python $($matches[0]) using $pyVersion" -ForegroundColor Green
                break
            }
        }
    }
}

if (-not $pythonFound) {
    Write-Host "❌ Python 3.10+ is required for ansible 9.x (ansible-core 2.16+)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Python 3.10 or newer:" -ForegroundColor Yellow
    Write-Host "  1. Download from: https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "  2. Or use winget: winget install Python.Python.3.12" -ForegroundColor Yellow
    Write-Host "  3. Or use Chocolatey: choco install python" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Make sure to check 'Add Python to PATH' during installation!" -ForegroundColor Yellow
    exit 1
}

# Check if virtual environment exists
if (Test-Path ".venv") {
    Write-Host "⚠️  Virtual environment already exists at .venv" -ForegroundColor Yellow
    $response = Read-Host "Do you want to recreate it? (y/N)"
    if ($response -match "^[Yy]") {
        Write-Host "Removing existing virtual environment..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force .venv
    } else {
        Write-Host "Keeping existing virtual environment" -ForegroundColor Cyan
    }
}

# Create virtual environment
if (-not (Test-Path ".venv")) {
    Write-Host ""
    Write-Host "Creating virtual environment with $pythonCmd..." -ForegroundColor Cyan
    & $pythonCmd -m venv .venv
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create virtual environment" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Virtual environment created" -ForegroundColor Green
}

# Activate virtual environment
Write-Host ""
Write-Host "Activating virtual environment..." -ForegroundColor Cyan
& .\.venv\Scripts\Activate.ps1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to activate virtual environment" -ForegroundColor Red
    Write-Host ""
    Write-Host "If you see an execution policy error, run:" -ForegroundColor Yellow
    Write-Host "  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

# Upgrade pip
Write-Host ""
Write-Host "Upgrading pip..." -ForegroundColor Cyan
python -m pip install --upgrade pip setuptools wheel

# Check if requirements.txt exists
if (-not (Test-Path "requirements.txt")) {
    Write-Host "❌ ERROR: requirements.txt not found!" -ForegroundColor Red
    exit 1
}

# Install Python requirements
Write-Host ""
Write-Host "Installing Python requirements from requirements.txt..." -ForegroundColor Cyan
pip install -r requirements.txt

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install Python requirements" -ForegroundColor Red
    exit 1
}

# Install Ansible collections
Write-Host ""
Write-Host "Installing Ansible collections..." -ForegroundColor Cyan
if (Test-Path "ansible\requirements.yml") {
    ansible-galaxy collection install -r ansible\requirements.yml
} else {
    Write-Host "⚠️  ansible\requirements.yml not found, installing collections manually..." -ForegroundColor Yellow
    ansible-galaxy collection install cisco.ios
    ansible-galaxy collection install ansible.netcommon
}

Write-Host ""
Write-Host "===================================" -ForegroundColor Green
Write-Host "✓ Setup complete!" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host ""
Write-Host "Virtual environment is ready at: .venv" -ForegroundColor Cyan
Write-Host ""
Write-Host "To activate the virtual environment:" -ForegroundColor Cyan
Write-Host "  .\.venv\Scripts\Activate.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "Or on Command Prompt:" -ForegroundColor Cyan
Write-Host "  .venv\Scripts\activate.bat" -ForegroundColor Yellow
Write-Host ""
Write-Host "To deactivate:" -ForegroundColor Cyan
Write-Host "  deactivate" -ForegroundColor Yellow
Write-Host ""
Write-Host "Installed tools:" -ForegroundColor Cyan
ansible --version | Select-Object -First 1
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Configure ansible\inventory.ini with your switches" -ForegroundColor White
Write-Host "2. Configure ansible\group_vars\switches.yml with credentials" -ForegroundColor White
Write-Host "3. Encrypt sensitive data: ansible-vault encrypt ansible\group_vars\switches.yml" -ForegroundColor White
Write-Host "4. Test connectivity: .\run.ps1 test-connectivity" -ForegroundColor White
Write-Host ""

