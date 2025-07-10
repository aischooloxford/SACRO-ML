#!/bin/bash

# Vulnerability Scanner Script for SACRO-ML
# Resolves Grype warnings and provides comprehensive vulnerability scanning

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/bin"
SBOM_FILE="${SCRIPT_DIR}/sacroml-sbom.spdx.json"
RESULTS_DIR="${SCRIPT_DIR}/scan-results"
PROJECT_NAME="sacroml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get OS distribution
get_distro() {
    if command_exists lsb_release; then
        echo "$(lsb_release -si | tr '[:upper:]' '[:lower:]'):$(lsb_release -sr)"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${ID}:${VERSION_ID}"
    else
        echo "ubuntu:22.04"  # Default fallback
    fi
}

# Install tools if needed
install_tools() {
    log_info "Checking for required tools..."
    
    mkdir -p "${BIN_DIR}"
    mkdir -p "${RESULTS_DIR}"
    
    # Install Grype
    if [ ! -f "${BIN_DIR}/grype" ]; then
        log_info "Installing Grype..."
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b "${BIN_DIR}"
        log_success "Grype installed"
    else
        log_info "Grype already installed"
    fi
    
    # Install Syft
    if [ ! -f "${BIN_DIR}/syft" ]; then
        log_info "Installing Syft..."
        curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b "${BIN_DIR}"
        log_success "Syft installed"
    else
        log_info "Syft already installed"
    fi
}

# Get project version
get_project_version() {
    if [ -f "sacroml/version.py" ]; then
        python -c "exec(open('sacroml/version.py').read()); print(__version__)" 2>/dev/null || echo "unknown"
    elif [ -f "pyproject.toml" ] && command_exists python; then
        python -c "
import tomllib
with open('pyproject.toml', 'rb') as f:
    data = tomllib.load(f)
    print(data.get('project', {}).get('version', 'unknown'))
" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Generate SBOM
generate_sbom() {
    local target_path="${1:-dir:.}"
    local output_file="${2:-$SBOM_FILE}"
    
    log_info "Generating SBOM for ${target_path}..."
    
    # Remove existing SBOM
    [ -f "$output_file" ] && rm -f "$output_file"
    
    # Generate SBOM
    "${BIN_DIR}/syft" scan "$target_path" -o spdx-json="$output_file"
    
    if [ -f "$output_file" ]; then
        log_success "SBOM generated: $output_file"
        return 0
    else
        log_error "Failed to generate SBOM"
        return 1
    fi
}

# Scan with Grype
scan_vulnerabilities() {
    local target="$1"
    local output_format="${2:-table}"
    local output_file="$3"
    local distro="${4:-$(get_distro)}"
    
    log_info "Scanning $target for vulnerabilities..."
    log_info "Using distribution: $distro"
    
    local cmd=("${BIN_DIR}/grype" "$target" "--distro" "$distro" "--output" "$output_format")
    
    if [ -n "$output_file" ]; then
        "${cmd[@]}" > "$output_file"
        log_success "Scan completed. Results saved to: $output_file"
    else
        "${cmd[@]}"
        log_success "Scan completed"
    fi
}

# Scan directory directly (with warnings resolution)
scan_directory() {
    local target_dir="${1:-dir:.}"
    local distro="${2:-$(get_distro)}"
    
    log_info "Scanning directory directly: $target_dir"
    scan_vulnerabilities "$target_dir" "table" "" "$distro"
}

# Scan virtual environment
scan_venv() {
    local venv_path="${1:-.venv}"
    local distro="${2:-$(get_distro)}"
    
    if [ -d "$venv_path" ]; then
        log_info "Scanning virtual environment: $venv_path"
        scan_vulnerabilities "dir:$venv_path" "table" "" "$distro"
    else
        log_warning "Virtual environment not found: $venv_path"
        return 1
    fi
}

# Comprehensive scan (recommended approach)
comprehensive_scan() {
    local distro="$(get_distro)"
    local timestamp="$(date +%Y%m%d_%H%M%S)"
    
    log_info "Starting comprehensive vulnerability scan..."
    log_info "Project: $PROJECT_NAME"
    log_info "Distribution: $distro"
    
    # Generate SBOM
    if generate_sbom "dir:."; then
        # Scan SBOM with different output formats
        log_info "Scanning SBOM (table format)..."
        scan_vulnerabilities "sbom:$SBOM_FILE" "table" "" "$distro"
        
        log_info "Generating JSON report..."
        scan_vulnerabilities "sbom:$SBOM_FILE" "json" "${RESULTS_DIR}/vulnerability-report-${timestamp}.json" "$distro"
        
        log_info "Generating SARIF report..."
        scan_vulnerabilities "sbom:$SBOM_FILE" "sarif" "${RESULTS_DIR}/vulnerability-report-${timestamp}.sarif" "$distro"
        
        log_success "Comprehensive scan completed. Reports saved in: $RESULTS_DIR"
    else
        log_error "Failed to generate SBOM. Cannot proceed with comprehensive scan."
        return 1
    fi
}

# Compare scans (directory vs SBOM)
compare_scans() {
    local distro="$(get_distro)"
    local timestamp="$(date +%Y%m%d_%H%M%S)"
    
    log_info "Running comparison scan (directory vs SBOM)..."
    
    # Scan directory
    log_info "1. Scanning directory directly..."
    scan_vulnerabilities "dir:." "json" "${RESULTS_DIR}/dir-scan-${timestamp}.json" "$distro"
    
    # Generate and scan SBOM
    if generate_sbom "dir:."; then
        log_info "2. Scanning SBOM..."
        scan_vulnerabilities "sbom:$SBOM_FILE" "json" "${RESULTS_DIR}/sbom-scan-${timestamp}.json" "$distro"
        
        log_success "Comparison scans completed. Check ${RESULTS_DIR} for results."
    fi
}

# Clean up temporary files
cleanup() {
    log_info "Cleaning up temporary files..."
    [ -f "$SBOM_FILE" ] && rm -f "$SBOM_FILE"
    log_success "Cleanup completed"
}

# Show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  install         Install Grype and Syft tools"
    echo "  sbom [PATH]     Generate SBOM for specified path (default: current directory)"
    echo "  scan [TARGET]   Scan target with Grype (directory, SBOM, etc.)"
    echo "  dir [PATH]      Scan directory directly with warnings resolved"
    echo "  venv [PATH]     Scan virtual environment (default: .venv)"
    echo "  comprehensive   Full scan with SBOM generation and multiple output formats"
    echo "  compare         Compare directory scan vs SBOM scan"
    echo "  cleanup         Remove temporary files"
    echo ""
    echo "Examples:"
    echo "  $0 install                    # Install tools"
    echo "  $0 comprehensive              # Recommended full scan"
    echo "  $0 dir                        # Scan current directory"
    echo "  $0 venv .venv                 # Scan virtual environment"
    echo "  $0 sbom dir:.                 # Generate SBOM"
    echo "  $0 scan sbom:my-sbom.json     # Scan existing SBOM"
    echo "  $0 compare                    # Compare scan methods"
    echo ""
    echo "Environment Variables:"
    echo "  GRYPE_DISTRO    Override OS distribution detection"
    echo "  GRYPE_OUTPUT    Default output format (table, json, sarif)"
}

# Main script logic
main() {
    local command="${1:-comprehensive}"
    
    case "$command" in
        "install")
            install_tools
            ;;
        "sbom")
            install_tools
            generate_sbom "${2:-dir:.}"
            ;;
        "scan")
            if [ -z "$2" ]; then
                log_error "Target required for scan command"
                show_usage
                exit 1
            fi
            install_tools
            scan_vulnerabilities "$2" "${GRYPE_OUTPUT:-table}"
            ;;
        "dir")
            install_tools
            scan_directory "${2:-dir:.}" "${GRYPE_DISTRO:-$(get_distro)}"
            ;;
        "venv")
            install_tools
            scan_venv "${2:-.venv}" "${GRYPE_DISTRO:-$(get_distro)}"
            ;;
        "comprehensive")
            install_tools
            comprehensive_scan
            ;;
        "compare")
            install_tools
            compare_scans
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Trap to cleanup on exit
trap cleanup EXIT

# Run main function with all arguments
main "$@"