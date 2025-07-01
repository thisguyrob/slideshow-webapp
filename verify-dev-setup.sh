#!/bin/bash
# ------------------------------------------------------------
# verify-dev-setup.sh - Verify Development Environment
# ------------------------------------------------------------
# This script checks if all required dependencies are properly
# installed for slideshow web app development
# ------------------------------------------------------------

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Helper functions
log_check() {
    echo -e "\n${BLUE}Checking: $1${NC}"
}

log_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((CHECKS_PASSED++))
}

log_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((CHECKS_FAILED++))
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((CHECKS_WARNING++))
}

check_command() {
    local cmd=$1
    local name=${2:-$cmd}
    
    if command -v "$cmd" >/dev/null 2>&1; then
        local version=""
        case $cmd in
            docker)
                if docker info >/dev/null 2>&1; then
                    version=$(docker --version | cut -d' ' -f3 | tr -d ',')
                    log_pass "$name installed and running (v$version)"
                else
                    log_warn "$name installed but not running"
                fi
                ;;
            node)
                version=$(node --version)
                log_pass "$name installed ($version)"
                ;;
            npm)
                version=$(npm --version)
                log_pass "$name installed (v$version)"
                ;;
            python3)
                version=$(python3 --version | cut -d' ' -f2)
                log_pass "$name installed (v$version)"
                ;;
            pip3)
                version=$(pip3 --version | cut -d' ' -f2)
                log_pass "$name installed (v$version)"
                ;;
            ffmpeg)
                version=$(ffmpeg -version 2>/dev/null | head -n1 | cut -d' ' -f3)
                log_pass "$name installed ($version)"
                ;;
            yt-dlp)
                version=$(yt-dlp --version 2>/dev/null || echo "unknown")
                log_pass "$name installed ($version)"
                ;;
            *)
                log_pass "$name installed"
                ;;
        esac
    else
        log_fail "$name not found"
    fi
}

check_python_package() {
    local package=$1
    
    if python3 -c "import $package" 2>/dev/null; then
        local version=$(python3 -c "import $package; print(getattr($package, '__version__', 'unknown'))" 2>/dev/null || echo "unknown")
        log_pass "Python package '$package' installed ($version)"
    else
        log_fail "Python package '$package' not found"
    fi
}

check_docker_image() {
    local image=$1
    
    if docker image inspect "$image" >/dev/null 2>&1; then
        log_pass "Docker image '$image' available"
    else
        log_warn "Docker image '$image' not found (will be downloaded when needed)"
    fi
}

check_project_structure() {
    local required_files=(
        "backend/package.json"
        "backend/index.js"
        "backend/api/projects.js"
        "backend/api/uploads.js"
        "backend/api/process.js"
        "backend/api/analyze.js"
        "frontend/my-app/package.json"
        "Dockerfile"
        "docker-compose.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_pass "Project file '$file' exists"
        else
            log_fail "Project file '$file' missing"
        fi
    done
}

check_network_connectivity() {
    if curl -s --max-time 5 https://github.com >/dev/null; then
        log_pass "Network connectivity available"
    else
        log_warn "Network connectivity limited (offline mode only)"
    fi
}

# Main verification
echo "========================================="
echo "   Development Environment Verification"
echo "========================================="

# Core system tools
log_check "Core Development Tools"
check_command "docker" "Docker"
check_command "node" "Node.js"
check_command "npm" "npm"
check_command "python3" "Python 3"
check_command "pip3" "pip3"

# Media processing tools
log_check "Media Processing Tools"
check_command "ffmpeg" "FFmpeg"
check_command "yt-dlp" "yt-dlp"

# Optional tools
log_check "Optional Tools"
check_command "git" "Git"
check_command "curl" "curl"
check_command "brew" "Homebrew (macOS)" || true

# Python packages
log_check "Python Packages"
check_python_package "numpy"
check_python_package "scipy"
check_python_package "madmom"

# Docker images
log_check "Docker Images"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    check_docker_image "node:18-bookworm-slim"
    check_docker_image "python:3.11-slim"
else
    log_warn "Docker not running - cannot check images"
fi

# Project structure
log_check "Project Structure"
check_project_structure

# Network
log_check "Network Connectivity"
check_network_connectivity

# Port availability
log_check "Port Availability"
if lsof -i :3000 >/dev/null 2>&1; then
    log_warn "Port 3000 is in use (may need to stop existing service)"
else
    log_pass "Port 3000 available"
fi

# Permissions
log_check "Permissions"
if [[ -w "$(pwd)" ]]; then
    log_pass "Write permissions in current directory"
else
    log_fail "No write permissions in current directory"
fi

# Platform-specific checks
case "$(uname -s)" in
    Darwin*)
        log_check "macOS Specific"
        if command -v sips >/dev/null 2>&1; then
            log_pass "sips (image conversion) available"
        else
            log_warn "sips not found (HEIC conversion may not work)"
        fi
        ;;
    Linux*)
        log_check "Linux Specific"
        if command -v heif-convert >/dev/null 2>&1; then
            log_pass "heif-convert available"
        else
            log_warn "heif-convert not found (install libheif-examples for HEIC support)"
        fi
        ;;
    CYGWIN*|MINGW*|MSYS*)
        log_check "Windows Specific"
        if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
            log_pass "Running in WSL environment"
        else
            log_warn "Not in WSL - Docker may require WSL 2"
        fi
        ;;
esac

# Summary
echo ""
echo "========================================="
echo "           Verification Summary"
echo "========================================="
echo -e "${GREEN}Passed: $CHECKS_PASSED${NC}"
echo -e "${YELLOW}Warnings: $CHECKS_WARNING${NC}"
echo -e "${RED}Failed: $CHECKS_FAILED${NC}"

if [[ $CHECKS_FAILED -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}🎉 Your development environment is ready!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run: ./docker-test-runner.sh"
    echo "2. Or manually: docker build -t slideshow . && docker run -p 3000:3000 slideshow"
    echo "3. Open: http://localhost:3000"
    
    if [[ $CHECKS_WARNING -gt 0 ]]; then
        echo ""
        echo "Note: Warnings above are non-critical but may affect some features."
    fi
    
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some dependencies are missing!${NC}"
    echo ""
    echo "To fix issues:"
    echo "1. Run: ./setup-dev-requirements.sh"
    echo "2. Or install missing dependencies manually"
    echo "3. Run this verification script again"
    
    exit 1
fi