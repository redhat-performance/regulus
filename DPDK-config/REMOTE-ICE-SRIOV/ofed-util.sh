#!/bin/bash

# Mellanox OFED Installation Script
# This script checks if OFED is installed and installs it if needed

set -e  # Exit on any error

# Configuration
OFED_VERSION="5.8-1.0.1.1"
OS_VERSION="rhel8.6"
ARCH="x86_64"
OFED_PACKAGE="MLNX_OFED_LINUX-${OFED_VERSION}-${OS_VERSION}-${ARCH}"
OFED_URL="https://content.mellanox.com/ofed/MLNX_OFED-${OFED_VERSION}/${OFED_PACKAGE}.tgz"
OFED_TARBALL="${OFED_PACKAGE}.tgz"


DEBUG=true
DPRINT() {
    if $DEBUG; then
        printf "($1): $2\n"
    fi
    #Example: DPRINT $LINENO "g_sut_name: $g_sut_name"
}

# Logging functions
log_info() {
    DPRINT $1 "[INFO] $2"
}

log_warn() {
    echo -e "[WARN] $1"
}

log_error() {
    echo -e "[ERROR] $1"
}

DRY=true  # set to true to print debug
RUN_CMD() {
    local cmd="$*"

    if $DRY; then
        echo "[DRY] Command: $cmd"
        #eval "$cmd"
    else
        echo "CMD: $cmd"
        eval "$cmd"
    fi
}

# Function to check if OFED is already installed and working
check_ofed_status() {
    local ofed_installed=false
    
    log_info $LINENO "Checking OFED installation status..."
    
    # Method 1: Check for OFED packages
    if rpm -qa | grep -q "mlnx-ofed" 2>/dev/null; then
        log_info $LINEO "Found OFED packages installed"
        ofed_installed=true
    fi
    
    # Method 2: Check for working mlx5 Verbs devices
    if command -v ibv_devinfo >/dev/null 2>&1; then
        if ibv_devinfo 2>/dev/null | grep -q "hca_id.*mlx5_"; then
            log_info $LINENO "Found working mlx5 Verbs devices"
            ofed_installed=true
        fi
    fi
    
    # Method 3: Check for OFED configuration
    if [ -d /etc/infiniband ] && [ -f /etc/infiniband/openib.conf ]; then
        log_info $LINENO "Found OFED configuration"
        ofed_installed=true
    fi
    
    # Method 4: Check for mlx5 kernel modules
    if lsmod | grep -q mlx5_core 2>/dev/null; then
        log_info $LINENO "Found mlx5_core kernel module loaded"
        ofed_installed=true
    fi
    
    if [ "$ofed_installed" = "true" ]; then
        log_info $LINENO "OFED appears to be installed and working"
        return 0
    else
        log_warn "OFED not detected or not working properly"
        return 1
    fi
}

# Function to download OFED
download_ofed() {
    log_info $LINENO "Downloading OFED package: $OFED_TARBALL"
    
    if [ -f "$OFED_TARBALL" ]; then
        log_info $LINENO "OFED tarball already exists, skipping download"
        return 0
    fi
    
    if ! command -v wget >/dev/null 2>&1; then
        log_error "wget is not installed. Please install wget first."
        return 1
    fi
    
    if ! wget "$OFED_URL"; then
        log_error "Failed to download OFED package"
        return 1
    fi
    
    log_info $LINENO "Download completed successfully"
}

# Function to extract OFED
extract_ofed() {
    log_info $LINENO "Extracting OFED package: $OFED_TARBALL"
    
    if [ -d "$OFED_PACKAGE" ]; then
        log_info $LINENO "OFED directory already exists, skipping extraction"
        return 0
    fi
    
    if ! tar -xzf "$OFED_TARBALL"; then
        log_error "Failed to extract OFED package"
        return 1
    fi
    
    log_info $LINENO "Extraction completed successfully"
}

# Function to install OFED
install_ofed() {
    log_info $LINENO "Installing OFED..."
    
    if [ ! -d "$OFED_PACKAGE" ]; then
        log_error "OFED directory $OFED_PACKAGE not found"
        return 1
    fi
    
    cd "$OFED_PACKAGE" || {
        log_error "Failed to change to OFED directory"
        return 1
    }
    
    if [ ! -f "./mlnxofedinstall" ]; then
        log_error "mlnxofedinstall script not found"
        return 1
    fi

    log_info $LINENO "Running mlnxofedinstall --force..."
    if ! ./mlnxofedinstall --force; then
        log_error "OFED installation failed"
        return 1
    fi
    
    cd .. || true
    log_info $LINENO "OFED installation completed successfully"
}

# Function to verify installation
verify_installation() {
    log_info $LINENO "Verifying OFED installation..."
    
    # Check if mlx5 modules are loaded
    if ! lsmod | grep -q mlx5_core; then
        log_warn "mlx5_core module not loaded, trying to load it..."
        modprobe mlx5_core || log_warn "Failed to load mlx5_core module"
    fi
    
    # Check for Verbs devices
    if command -v ibv_devinfo >/dev/null 2>&1; then
        local mlx_devices=$(ibv_devinfo 2>/dev/null | grep -c "hca_id.*mlx5_" || echo "0")
        if [ "$mlx_devices" -gt 0 ]; then
            log_info $LINENO "Found $mlx_devices mlx5 Verbs device(s)"
            log_info $LINENO "OFED installation verified successfully"
            return 0
        else
            log_warn "No mlx5 Verbs devices found"
        fi
    else
        log_warn "ibv_devinfo command not available"
    fi
    
    # Check for OFED packages
    local ofed_packages=$(rpm -qa | grep -c "mlnx-ofed" || echo "0")
    if [ "$ofed_packages" -gt 0 ]; then
        log_info $LINENO "Found $ofed_packages OFED packages installed"
        return 0
    fi
    
    log_warn "OFED installation verification inconclusive"
    return 1
}

# Function to cleanup downloaded files
cleanup() {
    if [ "$1" = "--keep-files" ]; then
        log_info $LINENO "Keeping downloaded files as requested"
        return 0
    fi
    
    log_info $LINENO "Cleaning up downloaded files..."
    rm -f "$OFED_TARBALL"
    rm -rf "$OFED_PACKAGE"
    log_info $LINENO "Cleanup completed"
}

# Main function
main() {
    log_info $LINENO "Starting Mellanox OFED installation process"
    log_info $LINENO "OFED Version: $OFED_VERSION"
    log_info $LINENO "Target OS: $OS_VERSION"
    log_info $LINENO "Architecture: $ARCH"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Check if OFED is already installed
    if check_ofed_status; then
        log_info $LINENO "OFED is already installed and working. Skipping installation."
        exit 0
    fi
    
    # Create temporary directory and work from there
    local temp_dir="/tmp/ofed_install_$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir" || {
        log_error "Failed to create/access temporary directory"
        exit 1
    }
    
    # Install OFED
    if download_ofed && extract_ofed && install_ofed; then
        log_info $LINENO "OFED installation process completed"
        
        # Verify installation
        if verify_installation; then
            log_info $LINENO "OFED installation successful!"
        else
            log_warn "OFED installation completed but verification failed"
        fi
        
        # Cleanup (comment out if you want to keep files)
        #cleanup
        
        # Create marker file for future checks
        echo "OFED installed on $(date) - Version: $OFED_VERSION" > /tmp/ofed_installed_marker
        
    else
        log_error "OFED installation failed"
        cleanup --keep-files
        exit 1
    fi
    
    # Clean up temp directory
    cd /
    rm -rf "$temp_dir"
    
    log_info $LINENO "Installation process completed. You may need to reboot or restart services."
}

# Parse command line arguments
case "${1:-}" in
    --check-only)
        check_ofed_status
        exit $?
        ;;
    --help|-h)
        echo "Usage: $0 [--check-only] [--help]"
        echo "  --check-only  Only check if OFED is installed, don't install"
        echo "  --help        Show this help message"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac

