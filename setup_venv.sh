#!/bin/bash
# Setup script for Python virtual environment and Ansible

set -e

echo "==================================="
echo "IOS-XE Upgrade Environment Setup"
echo "==================================="
echo ""

# Find Python 3.10 or newer (required for ansible 9.x+)
PYTHON_CMD=""

# Try to find Python 3.10+ in order of preference
for py_version in python3.13 python3.12 python3.11 python3.10; do
    if command -v $py_version &> /dev/null; then
        PYTHON_CMD=$py_version
        break
    fi
done

# Fallback to python3 and check version
if [ -z "$PYTHON_CMD" ]; then
    if command -v python3 &> /dev/null; then
        PYTHON_CMD=python3
        PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
        PY_MAJOR=$(echo $PY_VERSION | cut -d'.' -f1)
        PY_MINOR=$(echo $PY_VERSION | cut -d'.' -f2)
        
        if [ "$PY_MAJOR" -lt 3 ] || ([ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]); then
            echo "❌ Python 3.10+ required for ansible 9.x (ansible-core 2.16+)"
            echo "   Found: Python $PY_VERSION"
            echo ""
            echo "Please install Python 3.10 or newer:"
            echo "  - macOS: brew install python@3.10"
            echo "  - Ubuntu/Debian: sudo apt install python3.10"
            echo "  - RHEL/CentOS: sudo dnf install python3.10"
            exit 1
        fi
    else
        echo "❌ Python 3 is not installed. Please install Python 3.10 or later."
        exit 1
    fi
fi

PYTHON_VERSION=$($PYTHON_CMD --version | cut -d' ' -f2)
echo "✓ Found Python $PYTHON_VERSION using $PYTHON_CMD"

# Create virtual environment
if [ -d ".venv" ]; then
    echo "⚠️  Virtual environment already exists at .venv"
    read -p "Do you want to recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing existing virtual environment..."
        rm -rf .venv
    else
        echo "Keeping existing virtual environment"
    fi
fi

if [ ! -d ".venv" ]; then
    echo "Creating virtual environment with $PYTHON_CMD..."
    $PYTHON_CMD -m venv .venv
    echo "✓ Virtual environment created"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source .venv/bin/activate

# Install system dependencies for ansible-pylibssh (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    echo "Checking for libssh (optional - for ansible-pylibssh)..."
    if ! brew list libssh &> /dev/null; then
        echo "Installing libssh via Homebrew..."
        brew install libssh
        echo "✓ libssh installed"
    else
        echo "✓ libssh already installed"
    fi
    
    # Set compiler flags for ansible-pylibssh installation
    export LDFLAGS="-L$(brew --prefix libssh)/lib"
    export CFLAGS="-I$(brew --prefix libssh)/include"
    echo "✓ Compiler flags set for libssh"
fi

# Upgrade pip
echo ""
echo "Upgrading pip..."
pip install --upgrade pip setuptools wheel

# Install Python requirements from requirements.txt
echo ""
echo "Installing Python requirements from requirements.txt..."
if [ ! -f "requirements.txt" ]; then
    echo "❌ ERROR: requirements.txt not found!"
    exit 1
fi
pip install -r requirements.txt

# Install Ansible collections
echo ""
echo "Installing Ansible collections..."
if [ -f "ansible/requirements.yml" ]; then
    ansible-galaxy collection install -r ansible/requirements.yml
else
    echo "⚠️  ansible/requirements.yml not found, installing collections manually..."
    ansible-galaxy collection install cisco.ios
    ansible-galaxy collection install ansible.netcommon
fi

echo ""
echo "==================================="
echo "✓ Setup complete!"
echo "==================================="
echo ""
echo "Virtual environment is ready at: .venv"
echo ""
echo "To activate the virtual environment:"
echo "  source .venv/bin/activate"
echo ""
echo "To deactivate:"
echo "  deactivate"
echo ""
echo "Installed tools:"
ansible --version | head -1
echo "ansible-lint: $(ansible-lint --version | head -1)"
echo "yamllint: $(yamllint --version)"
echo ""
echo "Next steps:"
echo "1. Configure ansible/inventory.ini with your switches"
echo "2. Configure ansible/group_vars/switches.yml with credentials"
echo "3. Encrypt sensitive data: ansible-vault encrypt ansible/group_vars/switches.yml"
echo "4. Test connectivity: ansible-playbook ansible/playbooks/test_connectivity.yml -i ansible/inventory.ini --ask-vault-pass"
echo ""

