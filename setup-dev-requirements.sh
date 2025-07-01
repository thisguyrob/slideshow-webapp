#!/bin/bash
# ------------------------------------------------------------
# setup-dev-requirements.sh - Development Environment Setup
# ------------------------------------------------------------
# This script installs Docker and downloads dependencies for
# offline development of the slideshow web app
# ------------------------------------------------------------

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OFFLINE_DIR="$(pwd)/dev-dependencies"
NODE_VERSION="18.19.0"
PYTHON_VERSION="3.9"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "x64" ;;
        arm64|aarch64) echo "arm64" ;;
        armv7l) echo "arm" ;;
        *) echo "unknown" ;;
    esac
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

create_offline_dir() {
    log_info "Creating offline dependencies directory..."
    mkdir -p "$OFFLINE_DIR"/{docker,node,python,tools}
    log_success "Created $OFFLINE_DIR"
}

# Docker Installation Functions
install_docker_macos() {
    log_info "Installing Docker Desktop for macOS..."
    
    if check_command docker; then
        log_warning "Docker already installed"
        return 0
    fi
    
    local arch=$(detect_arch)
    local docker_dmg=""
    
    if [[ "$arch" == "arm64" ]]; then
        docker_dmg="Docker-arm64.dmg"
        log_info "Downloading Docker Desktop for Apple Silicon..."
        curl -L "https://desktop.docker.com/mac/main/arm64/Docker.dmg" -o "$OFFLINE_DIR/docker/$docker_dmg"
    else
        docker_dmg="Docker-x64.dmg"
        log_info "Downloading Docker Desktop for Intel Mac..."
        curl -L "https://desktop.docker.com/mac/main/amd64/Docker.dmg" -o "$OFFLINE_DIR/docker/$docker_dmg"
    fi
    
    log_info "Installing Docker Desktop..."
    hdiutil attach "$OFFLINE_DIR/docker/$docker_dmg"
    cp -R /Volumes/Docker/Docker.app /Applications/
    hdiutil detach /Volumes/Docker
    
    log_success "Docker Desktop installed. Please start it manually from Applications."
    log_warning "You may need to restart your terminal and run 'docker --version' to verify."
}

install_docker_linux() {
    log_info "Installing Docker for Linux..."
    
    if check_command docker; then
        log_warning "Docker already installed"
        return 0
    fi
    
    # Detect Linux distribution
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
    else
        log_error "Cannot detect Linux distribution"
        return 1
    fi
    
    case $DISTRO in
        ubuntu|debian)
            log_info "Installing Docker on Ubuntu/Debian..."
            
            # Download Docker installation script
            curl -fsSL https://get.docker.com -o "$OFFLINE_DIR/docker/get-docker.sh"
            chmod +x "$OFFLINE_DIR/docker/get-docker.sh"
            
            # Install Docker
            sudo "$OFFLINE_DIR/docker/get-docker.sh"
            
            # Add user to docker group
            if [[ -n "${USER:-}" ]]; then
                sudo usermod -aG docker "$USER"
            else
                # In containers, USER might not be set, use whoami as fallback
                sudo usermod -aG docker "$(whoami)"
            fi
            
            log_success "Docker installed. Please log out and back in for group changes to take effect."
            ;;
        centos|rhel|fedora)
            log_info "Installing Docker on CentOS/RHEL/Fedora..."
            
            # Download and install Docker
            curl -fsSL https://get.docker.com -o "$OFFLINE_DIR/docker/get-docker.sh"
            chmod +x "$OFFLINE_DIR/docker/get-docker.sh"
            sudo "$OFFLINE_DIR/docker/get-docker.sh"
            
            # Start and enable Docker
            sudo systemctl start docker
            sudo systemctl enable docker
            if [[ -n "${USER:-}" ]]; then
                sudo usermod -aG docker "$USER"
            else
                # In containers, USER might not be set, use whoami as fallback
                sudo usermod -aG docker "$(whoami)"
            fi
            
            log_success "Docker installed and started."
            ;;
        *)
            log_warning "Unsupported Linux distribution: $DISTRO"
            log_info "Please install Docker manually from https://docs.docker.com/engine/install/"
            ;;
    esac
}

install_docker_windows() {
    log_info "Setting up Docker for Windows..."
    
    if check_command docker; then
        log_warning "Docker already installed"
        return 0
    fi
    
    local docker_installer="Docker Desktop Installer.exe"
    
    log_info "Downloading Docker Desktop for Windows..."
    curl -L "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" -o "$OFFLINE_DIR/docker/$docker_installer"
    
    log_info "Docker Desktop installer downloaded to: $OFFLINE_DIR/docker/$docker_installer"
    log_warning "Please run the installer manually as administrator."
    log_warning "You may need to enable WSL 2 and Hyper-V features."
}

# Node.js Installation Functions
install_node() {
    local os=$(detect_os)
    local arch=$(detect_arch)
    
    log_info "Setting up Node.js $NODE_VERSION..."
    
    if check_command node; then
        local current_version=$(node --version | sed 's/v//')
        if [[ "$current_version" == "$NODE_VERSION"* ]]; then
            log_warning "Node.js $NODE_VERSION already installed"
            return 0
        fi
    fi
    
    case $os in
        macos)
            local node_pkg="node-v$NODE_VERSION-darwin-$arch.tar.gz"
            log_info "Downloading Node.js for macOS..."
            curl -L "https://nodejs.org/dist/v$NODE_VERSION/$node_pkg" -o "$OFFLINE_DIR/node/$node_pkg"
            
            # Extract and install
            cd "$OFFLINE_DIR/node"
            tar -xzf "$node_pkg"
            sudo cp -R "node-v$NODE_VERSION-darwin-$arch"/* /usr/local/
            ;;
        linux)
            local node_pkg="node-v$NODE_VERSION-linux-$arch.tar.xz"
            log_info "Downloading Node.js for Linux..."
            curl -L "https://nodejs.org/dist/v$NODE_VERSION/$node_pkg" -o "$OFFLINE_DIR/node/$node_pkg"
            
            # Extract and install
            cd "$OFFLINE_DIR/node"
            tar -xJf "$node_pkg"
            sudo cp -R "node-v$NODE_VERSION-linux-$arch"/* /usr/local/
            ;;
        windows)
            local node_msi="node-v$NODE_VERSION-x64.msi"
            log_info "Downloading Node.js for Windows..."
            curl -L "https://nodejs.org/dist/v$NODE_VERSION/$node_msi" -o "$OFFLINE_DIR/node/$node_msi"
            
            log_info "Node.js installer downloaded to: $OFFLINE_DIR/node/$node_msi"
            log_warning "Please run the MSI installer manually."
            return 0
            ;;
    esac
    
    log_success "Node.js $NODE_VERSION installed"
}

# Python Installation Functions
install_python() {
    local os=$(detect_os)
    
    log_info "Setting up Python $PYTHON_VERSION..."
    
    if check_command python$PYTHON_VERSION; then
        local current_version=$(python$PYTHON_VERSION --version | sed 's/Python //' | cut -d. -f1,2)
        if [[ "$current_version" == "$PYTHON_VERSION" ]]; then
            log_warning "Python $PYTHON_VERSION already installed"
            return 0
        fi
    fi
    
    case $os in
        macos)
            if check_command brew; then
                log_info "Installing Python via Homebrew..."
                brew install python@$PYTHON_VERSION
            else
                log_warning "Homebrew not found. Please install Python manually from python.org"
                local python_pkg="python-$PYTHON_VERSION-macos11.pkg"
                curl -L "https://www.python.org/ftp/python/${PYTHON_VERSION}.0/$python_pkg" -o "$OFFLINE_DIR/python/$python_pkg"
                log_info "Python installer downloaded to: $OFFLINE_DIR/python/$python_pkg"
            fi
            ;;
        linux)
            if [[ -f /etc/os-release ]]; then
                . /etc/os-release
                case $ID in
                    ubuntu|debian)
                        # Add deadsnakes PPA for older Python versions
                        sudo apt-get update
                        sudo apt-get install -y software-properties-common
                        sudo add-apt-repository -y ppa:deadsnakes/ppa
                        sudo apt-get update
                        sudo apt-get install -y python$PYTHON_VERSION python$PYTHON_VERSION-dev python$PYTHON_VERSION-venv python$PYTHON_VERSION-distutils
                        # Install pip for the specific Python version
                        curl -sS https://bootstrap.pypa.io/get-pip.py | python$PYTHON_VERSION - --ignore-installed --break-system-packages
                        ;;
                    centos|rhel|fedora)
                        sudo dnf install -y python$PYTHON_VERSION python$PYTHON_VERSION-pip python$PYTHON_VERSION-devel
                        ;;
                esac
            fi
            ;;
        windows)
            local python_exe="python-${PYTHON_VERSION}.0-amd64.exe"
            log_info "Downloading Python for Windows..."
            curl -L "https://www.python.org/ftp/python/${PYTHON_VERSION}.0/$python_exe" -o "$OFFLINE_DIR/python/$python_exe"
            log_info "Python installer downloaded to: $OFFLINE_DIR/python/$python_exe"
            log_warning "Please run the installer manually."
            ;;
    esac
}

# Download Development Dependencies
download_npm_dependencies() {
    log_info "Downloading npm dependencies for offline use..."
    
    if [[ ! -f package.json ]]; then
        log_warning "No package.json found. Creating minimal one for development..."
        cat > package.json << EOF
{
  "name": "slideshow-dev",
  "version": "1.0.0",
  "devDependencies": {
    "npm-pack-all": "^1.12.5"
  }
}
EOF
    fi
    
    # Create npm cache directory
    mkdir -p "$OFFLINE_DIR/node/npm-cache"
    
    # Download backend dependencies
    if [[ -d backend ]]; then
        log_info "Caching backend dependencies..."
        cd backend
        npm install --cache "$OFFLINE_DIR/node/npm-cache"
        npm pack
        mv *.tgz "$OFFLINE_DIR/node/"
        cd ..
    fi
    
    # Download frontend dependencies
    if [[ -d frontend/my-app ]]; then
        log_info "Caching frontend dependencies..."
        cd frontend/my-app
        npm install --cache "$OFFLINE_DIR/node/npm-cache"
        npm pack
        mv *.tgz "$OFFLINE_DIR/node/"
        cd ../..
    fi
}

download_python_dependencies() {
    log_info "Downloading Python dependencies for offline use..."

    mkdir -p "$OFFLINE_DIR/python/wheels"

    # Download madmom and its dependencies
    local pip_cmd="python$PYTHON_VERSION -m pip"
    if check_command python$PYTHON_VERSION; then
        # madmom's setup.py requires Cython and numpy for metadata generation
        if ! $pip_cmd show Cython >/dev/null 2>&1; then
            log_info "Installing build dependency Cython..."
            $pip_cmd install --quiet Cython
        fi

        if ! $pip_cmd show numpy >/dev/null 2>&1; then
            log_info "Installing build dependency numpy..."
            $pip_cmd install --quiet numpy
        fi

        $pip_cmd download --dest "$OFFLINE_DIR/python/wheels" madmom numpy scipy Cython
        log_success "Python dependencies downloaded"
    else
        log_warning "Python $PYTHON_VERSION not available. Skipping Python dependency download."
    fi
}

download_docker_images() {
    log_info "Pre-downloading Docker base images..."
    
    if check_command docker && docker info >/dev/null 2>&1; then
        local images=("node:18-bookworm" "node:18-bookworm-slim" "python:3.9-slim")
        
        for image in "${images[@]}"; do
            log_info "Pulling $image..."
            docker pull "$image"
            
            # Save image for offline use
            local filename=$(echo "$image" | tr ':/' '-').tar
            docker save "$image" -o "$OFFLINE_DIR/docker/$filename"
            log_success "Saved $image to $filename"
        done
    else
        log_warning "Docker not available. Skipping image download."
    fi
}

download_tools() {
    log_info "Downloading additional development tools..."
    
    local os=$(detect_os)
    local arch=$(detect_arch)
    
    # Download yt-dlp
    case $os in
        macos|linux)
            curl -L "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" -o "$OFFLINE_DIR/tools/yt-dlp"
            chmod +x "$OFFLINE_DIR/tools/yt-dlp"
            ;;
        windows)
            curl -L "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -o "$OFFLINE_DIR/tools/yt-dlp.exe"
            ;;
    esac
    
    log_success "Development tools downloaded"
}

create_install_script() {
    log_info "Creating offline installation script..."
    
    cat > "$OFFLINE_DIR/install-offline.sh" << 'EOF'
#!/bin/bash
# Offline installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing from offline dependencies in $SCRIPT_DIR"

# Load Docker images
if command -v docker >/dev/null 2>&1; then
    for image_file in "$SCRIPT_DIR/docker"/*.tar; do
        if [[ -f "$image_file" ]]; then
            echo "Loading Docker image: $(basename "$image_file")"
            docker load -i "$image_file"
        fi
    done
fi

# Install Python packages
if command -v python3.9 >/dev/null 2>&1; then
    echo "Installing Python packages from wheels..."
    python3.9 -m pip install --find-links "$SCRIPT_DIR/python/wheels" --no-index madmom
fi

# Install npm packages from cache
if command -v npm >/dev/null 2>&1; then
    echo "Using npm cache..."
    npm config set cache "$SCRIPT_DIR/node/npm-cache"
fi

echo "Offline installation complete!"
EOF
    
    chmod +x "$OFFLINE_DIR/install-offline.sh"
    log_success "Created offline installation script"
}

create_readme() {
    log_info "Creating development setup README..."
    
    cat > "$OFFLINE_DIR/README.md" << EOF
# Development Dependencies

This directory contains all dependencies needed for offline development of the slideshow web app.

## Contents

- \`docker/\` - Docker Desktop installers and pre-built images
- \`node/\` - Node.js installers and npm package cache
- \`python/\` - Python installers and wheel packages
- \`tools/\` - Additional development tools (yt-dlp, etc.)

## Offline Installation

Run the installation script:
\`\`\`bash
./install-offline.sh
\`\`\`

## Manual Installation

### Docker
- **macOS**: Run \`docker/Docker-*.dmg\`
- **Windows**: Run \`docker/Docker Desktop Installer.exe\` as administrator
- **Linux**: Run \`docker/get-docker.sh\`

### Node.js
- **macOS/Linux**: Extract and copy to \`/usr/local/\`
- **Windows**: Run \`node/node-*.msi\`

### Python
- **macOS**: Run \`python/python-*.pkg\`
- **Windows**: Run \`python/python-*.exe\`
- **Linux**: Packages already installed via package manager

## Verification

After installation, verify with:
\`\`\`bash
docker --version
node --version
python3.9 --version
python3.9 -m pip list | grep madmom
\`\`\`

## Development Workflow

1. Start Docker Desktop (if on macOS/Windows)
2. Build the project: \`./docker-test-runner.sh\`
3. Or run manually: \`docker build -t slideshow . && docker run -p 3000:3000 slideshow\`

Generated on: $(date)
Platform: $(uname -s) $(uname -m)
EOF
    
    log_success "Created development README"
}

# Main execution
main() {
    local os=$(detect_os)
    local arch=$(detect_arch)
    
    echo "========================================="
    echo "   Slideshow Web App - Dev Setup"
    echo "========================================="
    echo "Platform: $os ($arch)"
    echo "Offline dir: $OFFLINE_DIR"
    echo ""
    
    # Create directory structure
    create_offline_dir
    
    # Install core dependencies
    case $os in
        macos)
            install_docker_macos
            ;;
        linux)
            install_docker_linux
            ;;
        windows)
            install_docker_windows
            ;;
        *)
            log_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
    
    install_node
    install_python
    
    # Download offline dependencies
    download_npm_dependencies
    download_python_dependencies
    download_docker_images
    download_tools
    
    # Create offline installation tools
    create_install_script
    create_readme
    
    echo ""
    echo "========================================="
    echo "           Setup Complete!"
    echo "========================================="
    log_success "Development environment ready"
    log_info "Offline dependencies saved to: $OFFLINE_DIR"
    log_info "Total size: $(du -sh "$OFFLINE_DIR" | cut -f1)"
    
    if [[ "$os" == "linux" ]] && groups | grep -q docker; then
        log_warning "Please log out and back in for Docker group membership to take effect"
    fi
    
    echo ""
    echo "Next steps:"
    echo "1. Restart your terminal"
    echo "2. Run: docker --version && node --version && python3.9 --version"
    echo "3. Test the app: ./docker-test-runner.sh"
    echo ""
    echo "For offline installation on other machines:"
    echo "- Copy the '$OFFLINE_DIR' directory"
    echo "- Run: $OFFLINE_DIR/install-offline.sh"
}

# Run main function
main "$@"