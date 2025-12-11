#!/bin/bash
# Setup script for Python virtual environment and Ansible

set -e

echo "==================================="
echo "IOS-XE Upgrade Environment Setup"
echo "==================================="
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8 or later."
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo "✓ Found Python $PYTHON_VERSION"

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
    echo "Creating virtual environment..."
    python3 -m venv .venv
    echo "✓ Virtual environment created"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source .venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip setuptools wheel

# Install Ansible and dependencies
echo ""
echo "Installing Ansible and dependencies..."
pip install ansible>=2.16.0
pip install ansible-lint yamllint

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

# Create requirements.txt if it doesn't exist
if [ ! -f "requirements.txt" ]; then
    echo "Creating requirements.txt..."
    cat > requirements.txt << 'EOF'
# Core Dependencies
ansible>=2.16.0

# Linting and Testing
ansible-lint>=6.0.0
yamllint>=1.26.0
pylint>=2.15.0

# Testing (optional)
pytest>=7.0.0
pytest-cov>=4.0.0

# Formatting (optional)
black>=22.0.0
EOF
    echo "✓ requirements.txt created"
fi

# Install Python requirements
echo ""
echo "Installing Python requirements..."
pip install -r requirements.txt

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

