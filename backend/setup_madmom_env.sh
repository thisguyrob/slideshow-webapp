#!/bin/bash
# Setup dedicated Python 3.9 environment for madmom

set -e

echo "Setting up madmom Python 3.9 environment..."

# Create a dedicated directory for madmom
MADMOM_DIR="/opt/madmom-env"

# Install pyenv if not available
if ! command -v pyenv &> /dev/null; then
    echo "Installing pyenv..."
    curl https://pyenv.run | bash
    export PATH="$HOME/.pyenv/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi

# Install Python 3.9 via pyenv
echo "Installing Python 3.9.18..."
pyenv install 3.9.18 || echo "Python 3.9.18 already installed"

# Create virtual environment
echo "Creating madmom virtual environment..."
pyenv virtualenv 3.9.18 madmom-env || echo "Virtual environment already exists"

# Activate environment and install dependencies
echo "Installing madmom and dependencies..."
pyenv activate madmom-env
pip install --upgrade pip
pip install numpy==1.21.6 scipy==1.7.3 cython==0.29.32
pip install madmom

echo "Madmom environment setup complete!"
echo "Virtual environment created at: ~/.pyenv/versions/madmom-env"