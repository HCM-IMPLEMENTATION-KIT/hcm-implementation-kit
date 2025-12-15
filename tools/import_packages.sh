#!/bin/bash

# Flutter Package Import Script
# Usage: ./import_packages.sh [options] package1 package2 package3...
# Options:
#   -d, --dev          Add packages as dev dependencies
#   -p, --path PATH    Specify custom pubspec.yaml path (default: current directory)
#   -v, --version VER  Specify package version (applies to all packages)
#   -g, --git URL      Add package from git repository
#   -r, --ref REF      Git reference (branch/tag/commit) for git packages
#   -h, --help         Show this help message
#   --workspace        Install in all workspace packages (melos workspace)
#   --main-app         Install in main app only (apps/health_campaign_field_worker_app)
#   --dry-run          Show what would be installed without actually doing it
#   --force-override   Force add to pubspec_override.yaml instead of regular pubspec.yaml
#   --list-packages    List packages from a text file (one package per line)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Default values
DEV_DEPENDENCY=false
PUBSPEC_PATH=""
PACKAGE_VERSION=""
GIT_URL=""
GIT_REF=""
WORKSPACE_MODE=false
MAIN_APP_MODE=false
DRY_RUN=false
FORCE_OVERRIDE=false
PACKAGE_LIST_FILE=""
PACKAGES=()

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"

# Help function
show_help() {
    echo -e "${CYAN}Flutter Package Import Script${NC}"
    echo ""
    echo "Usage: $0 [options] package1 package2 package3..."
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  -d, --dev              Add packages as dev dependencies"
    echo "  -p, --path PATH        Specify custom pubspec.yaml path"
    echo "  -v, --version VER      Specify package version (applies to all packages)"
    echo "  -g, --git URL          Add package from git repository"
    echo "  -r, --ref REF          Git reference (branch/tag/commit) for git packages"
    echo "  --workspace            Install in all workspace packages (melos workspace)"
    echo "  --main-app             Install in main app only (apps/health_campaign_field_worker_app)"
    echo "  --dry-run              Show what would be installed without actually doing it"
    echo "  --force-override       Force add to pubspec_override.yaml"
    echo "  --list-packages FILE   Read packages from file (one per line)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo "  $0 http dio                              # Add http and dio packages"
    echo "  $0 -d build_runner json_annotation      # Add as dev dependencies"
    echo "  $0 -v '^1.0.0' shared_preferences       # Add with specific version"
    echo "  $0 -g https://github.com/user/repo.git  # Add from git"
    echo "  $0 --workspace provider                  # Add to all workspace packages"
    echo "  $0 --main-app flutter_bloc               # Add to main app only"
    echo "  $0 --dry-run http dio                    # Preview what would be installed"
    echo "  $0 --force-override dio                  # Force add to pubspec_override.yaml"
    echo "  $0 --list-packages packages.txt         # Read packages from file"
}

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

log_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1"
}

# Check if Flutter is installed
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    # Check Flutter version
    local flutter_version
    flutter_version=$(flutter --version | head -n 1 | cut -d' ' -f2)
    log_info "Using Flutter version: $flutter_version"
}

# Check if melos is available for workspace operations
check_melos() {
    if ! command -v melos &> /dev/null; then
        log_warning "Melos is not installed. Workspace operations may not work."
        return 1
    fi
    return 0
}

# Get latest package version from pub.dev
get_latest_package_version() {
    local package_name="$1"
    
    if command -v curl &> /dev/null; then
        local version
        version=$(curl -s "https://pub.dev/api/packages/$package_name" 2>/dev/null | \
                 grep -o '"latest":{"version":"[^"]*"' | \
                 cut -d'"' -f6)
        echo "$version"
    else
        echo ""
    fi
}

# Check if flutter pub add failed due to version conflict
check_version_conflict() {
    local output="$1"
    
    if echo "$output" | grep -q -E "(version solving failed|dependency conflict|incompatible version|version conflict|Could not find a solution)"; then
        return 0
    fi
    
    return 1
}

# Add package to pubspec_override.yaml
add_package_to_override() {
    local package_name="$1"
    local package_version="$2"
    local pubspec_dir="$3"
    local override_file="$pubspec_dir/pubspec_override.yaml"
    
    log_info "Adding $package_name to pubspec_override.yaml"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would add $package_name:$package_version to $override_file"
        return 0
    fi
    
    # Create pubspec_override.yaml if it doesn't exist
    if [[ ! -f "$override_file" ]]; then
        cat > "$override_file" << EOF
# This file contains dependency overrides to resolve version conflicts
# Generated by import_packages.sh on $(date)
name: override_dependencies

dependency_overrides:
EOF
        log_info "Created new pubspec_override.yaml"
    fi
    
    # Check if the package already exists in override file
    if grep -q "^  $package_name:" "$override_file"; then
        log_warning "$package_name already exists in pubspec_override.yaml"
        # Update existing entry
        if [[ -n "$package_version" ]]; then
            sed -i.bak "s/^  $package_name:.*$/  $package_name: $package_version/" "$override_file"
            log_info "Updated $package_name version in pubspec_override.yaml"
        fi
        return 0
    fi
    
    # Add the package to dependency_overrides section
    if [[ -n "$package_version" ]]; then
        echo "  $package_name: $package_version" >> "$override_file"
    else
        local latest_version
        latest_version=$(get_latest_package_version "$package_name")
        if [[ -n "$latest_version" ]]; then
            echo "  $package_name: ^$latest_version" >> "$override_file"
            log_info "Using latest version: ^$latest_version"
        else
            echo "  $package_name: any" >> "$override_file"
            log_warning "Could not determine version, using 'any'"
        fi
    fi
    
    log_success "Added $package_name to pubspec_override.yaml"
}

# Validate package name
validate_package_name() {
    local package_name="$1"
    
    # Check if package name is valid (contains only lowercase letters, numbers, and underscores)
    if [[ ! "$package_name" =~ ^[a-z0-9_]+$ ]]; then
        log_warning "Package name '$package_name' may not be valid (should only contain lowercase letters, numbers, and underscores)"
        return 1
    fi
    
    return 0
}

# Check if package exists on pub.dev
check_package_exists() {
    local package_name="$1"
    
    if command -v curl &> /dev/null; then
        local status_code
        status_code=$(curl -s -o /dev/null -w "%{http_code}" "https://pub.dev/packages/$package_name")
        
        if [[ "$status_code" == "200" ]]; then
            return 0
        else
            log_warning "Package '$package_name' not found on pub.dev (HTTP $status_code)"
            return 1
        fi
    else
        log_warning "curl not available, skipping package existence check"
        return 0
    fi
}

# Add package to pubspec.yaml using flutter pub add
add_package_flutter() {
    local package_name="$1"
    local pubspec_dir="$2"
    local package_spec="$package_name"
    local specified_version=""
    
    # Validate package name
    if ! validate_package_name "$package_name"; then
        log_error "Invalid package name: $package_name"
        return 1
    fi
    
    # Check if package exists (unless it's a git package)
    if [[ -z "$GIT_URL" ]] && ! check_package_exists "$package_name"; then
        read -p "Package '$package_name' not found on pub.dev. Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping $package_name"
            return 0
        fi
    fi
    
    # Build package specification
    if [[ -n "$PACKAGE_VERSION" ]]; then
        package_spec="$package_name:$PACKAGE_VERSION"
        specified_version="$PACKAGE_VERSION"
    elif [[ -n "$GIT_URL" ]]; then
        package_spec="$package_name --git-url=$GIT_URL"
        if [[ -n "$GIT_REF" ]]; then
            package_spec="$package_spec --git-ref=$GIT_REF"
        fi
    fi
    
    # Check if we should force add to override
    if [[ "$FORCE_OVERRIDE" == true ]]; then
        log_info "Force adding $package_name to pubspec_override.yaml"
        add_package_to_override "$package_name" "$specified_version" "$pubspec_dir"
        return 0
    fi
    
    # Build flutter pub add command
    # Check if .fvm folder exists to determine whether to use fvm or flutter directly
    local flutter_cmd="flutter"
    if [[ -d "$pubspec_dir/.fvm" ]] || [[ -d "$WORKSPACE_ROOT/.fvm" ]]; then
        if command -v fvm &> /dev/null; then
            flutter_cmd="fvm flutter"
            log_info "Using FVM (Flutter Version Management)"
        else
            log_warning ".fvm folder found but fvm command not available, using regular flutter"
        fi
    fi
    
    local cmd="$flutter_cmd pub add"
    if [[ "$DEV_DEPENDENCY" == true ]]; then
        cmd="$cmd --dev"
    fi
    cmd="$cmd $package_spec"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would execute in $pubspec_dir: $cmd"
        return 0
    fi
    
    log_info "Adding $package_name to $pubspec_dir"
    
    # Change to pubspec directory and run command
    local output
    local exit_code
    output=$(
        cd "$pubspec_dir" || exit 1
        eval "$cmd" 2>&1
    )
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Successfully added $package_name"
    else
        # Check if the failure was due to a version conflict
        if check_version_conflict "$output"; then
            log_warning "Version conflict detected for $package_name"
            log_info "Output: $output"
            log_info "Attempting to add to pubspec_override.yaml instead"
            
            # Add to pubspec_override.yaml
            add_package_to_override "$package_name" "$specified_version" "$pubspec_dir"
            
            # Try running flutter pub get to see if override resolves the conflict
            log_info "Running flutter pub get to apply override..."
            local get_output
            get_output=$(
                cd "$pubspec_dir" || exit 1
                flutter pub get 2>&1
            )
            
            if [[ $? -eq 0 ]]; then
                log_success "Successfully resolved version conflict using pubspec_override.yaml"
            else
                log_error "Failed to resolve version conflict even with override"
                log_debug "Flutter pub get output: $get_output"
                return 1
            fi
        else
            log_error "Failed to add $package_name: $output"
            return 1
        fi
    fi
}

# Add packages to workspace using melos
add_packages_workspace() {
    local packages=("$@")
    
    if ! check_melos; then
        log_error "Melos is required for workspace operations"
        exit 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would add packages to workspace: ${packages[*]}"
        return 0
    fi
    
    log_info "Adding packages to workspace using melos"
    
    for package in "${packages[@]}"; do
        local cmd="melos add $package"
        if [[ "$DEV_DEPENDENCY" == true ]]; then
            cmd="$cmd --dev"
        fi
        
        log_info "Executing: $cmd"
        (cd "$WORKSPACE_ROOT" && eval "$cmd")
        
        if [[ $? -eq 0 ]]; then
            log_success "Successfully added $package to workspace"
        else
            log_error "Failed to add $package to workspace"
        fi
    done
}

# Read packages from file
read_packages_from_file() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        log_error "Package list file not found: $file_path"
        exit 1
    fi
    
    log_info "Reading packages from file: $file_path"
    
    local packages=()
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            # Trim whitespace
            line=$(echo "$line" | xargs)
            packages+=("$line")
        fi
    done < "$file_path"
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages found in file: $file_path"
        exit 1
    fi
    
    log_info "Found ${#packages[@]} packages in file"
    printf '%s\n' "${packages[@]}"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dev)
                DEV_DEPENDENCY=true
                shift
                ;;
            -p|--path)
                PUBSPEC_PATH="$2"
                shift 2
                ;;
            -v|--version)
                PACKAGE_VERSION="$2"
                shift 2
                ;;
            -g|--git)
                GIT_URL="$2"
                shift 2
                ;;
            -r|--ref)
                GIT_REF="$2"
                shift 2
                ;;
            --workspace)
                WORKSPACE_MODE=true
                shift
                ;;
            --main-app)
                MAIN_APP_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force-override)
                FORCE_OVERRIDE=true
                shift
                ;;
            --list-packages)
                PACKAGE_LIST_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                PACKAGES+=("$1")
                shift
                ;;
        esac
    done
}

# Get pubspec.yaml path
get_pubspec_path() {
    if [[ -n "$PUBSPEC_PATH" ]]; then
        echo "$PUBSPEC_PATH"
    elif [[ "$MAIN_APP_MODE" == true ]]; then
        echo "$WORKSPACE_ROOT/apps/health_campaign_field_worker_app/pubspec.yaml"
    elif [[ -f "pubspec.yaml" ]]; then
        echo "$(pwd)/pubspec.yaml"
    elif [[ -f "$WORKSPACE_ROOT/pubspec.yaml" ]]; then
        echo "$WORKSPACE_ROOT/pubspec.yaml"
    else
        log_error "Could not find pubspec.yaml. Please specify path with -p option."
        exit 1
    fi
}

# Get all Flutter project directories in workspace
get_flutter_projects() {
    local projects=()
    
    # Add main app
    if [[ -f "$WORKSPACE_ROOT/apps/health_campaign_field_worker_app/pubspec.yaml" ]]; then
        projects+=("$WORKSPACE_ROOT/apps/health_campaign_field_worker_app")
    fi
    
    # Add packages
    if [[ -d "$WORKSPACE_ROOT/packages" ]]; then
        while IFS= read -r -d '' pubspec; do
            projects+=("$(dirname "$pubspec")")
        done < <(find "$WORKSPACE_ROOT/packages" -name "pubspec.yaml" -print0)
    fi
    
    # Add root if it has pubspec.yaml
    if [[ -f "$WORKSPACE_ROOT/pubspec.yaml" ]]; then
        projects+=("$WORKSPACE_ROOT")
    fi
    
    printf '%s\n' "${projects[@]}"
}

# Show summary of what will be done
show_summary() {
    echo -e "${CYAN}===============================================${NC}"
    echo -e "${CYAN}           FLUTTER PACKAGE IMPORT${NC}"
    echo -e "${CYAN}===============================================${NC}"
    
    if [[ "$WORKSPACE_MODE" == true ]]; then
        echo -e "${YELLOW}Mode:${NC} Workspace (all packages)"
    else
        local pubspec_path
        pubspec_path=$(get_pubspec_path)
        echo -e "${YELLOW}Mode:${NC} Single project"
        echo -e "${YELLOW}Target:${NC} $pubspec_path"
    fi
    
    echo -e "${YELLOW}Packages:${NC} ${PACKAGES[*]}"
    
    if [[ "$DEV_DEPENDENCY" == true ]]; then
        echo -e "${YELLOW}Type:${NC} Development dependencies"
    else
        echo -e "${YELLOW}Type:${NC} Regular dependencies"
    fi
    
    if [[ -n "$PACKAGE_VERSION" ]]; then
        echo -e "${YELLOW}Version:${NC} $PACKAGE_VERSION"
    fi
    
    if [[ -n "$GIT_URL" ]]; then
        echo -e "${YELLOW}Git URL:${NC} $GIT_URL"
        if [[ -n "$GIT_REF" ]]; then
            echo -e "${YELLOW}Git Ref:${NC} $GIT_REF"
        fi
    fi
    
    if [[ "$FORCE_OVERRIDE" == true ]]; then
        echo -e "${YELLOW}Override:${NC} Forced to pubspec_override.yaml"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}Mode:${NC} DRY RUN (no changes will be made)"
    fi
    
    echo -e "${CYAN}===============================================${NC}"
}

# Main execution function
main() {
    parse_arguments "$@"
    
    # Read packages from file if specified
    if [[ -n "$PACKAGE_LIST_FILE" ]]; then
        mapfile -t file_packages < <(read_packages_from_file "$PACKAGE_LIST_FILE")
        PACKAGES+=("${file_packages[@]}")
    fi
    
    # Validate inputs
    if [[ ${#PACKAGES[@]} -eq 0 && -z "$GIT_URL" ]]; then
        log_error "No packages specified"
        show_help
        exit 1
    fi
    
    # If git URL is provided but no package name, extract from URL
    if [[ -n "$GIT_URL" && ${#PACKAGES[@]} -eq 0 ]]; then
        local repo_name
        repo_name=$(basename "$GIT_URL" .git)
        PACKAGES=("$repo_name")
    fi
    
    check_flutter
    
    show_summary
    
    if [[ "$WORKSPACE_MODE" == true ]]; then
        add_packages_workspace "${PACKAGES[@]}"
    else
        local pubspec_path
        pubspec_path=$(get_pubspec_path)
        local pubspec_dir
        pubspec_dir=$(dirname "$pubspec_path")
        
        # Add each package
        local failed_packages=()
        for package in "${PACKAGES[@]}"; do
            if ! add_package_flutter "$package" "$pubspec_dir"; then
                failed_packages+=("$package")
            fi
        done
        
        # Report results
        if [[ ${#failed_packages[@]} -gt 0 ]]; then
            log_error "Failed to add packages: ${failed_packages[*]}"
            exit 1
        fi
    fi
    
    if [[ "$DRY_RUN" == false ]]; then
        log_success "Package import completed successfully!"
        log_info "You may want to run 'flutter pub get' or 'melos bootstrap' to update dependencies."
        
        # Show any override files created
        local pubspec_dir
        if [[ "$WORKSPACE_MODE" == false ]]; then
            pubspec_path=$(get_pubspec_path)
            pubspec_dir=$(dirname "$pubspec_path")
            if [[ -f "$pubspec_dir/pubspec_override.yaml" ]]; then
                log_info "Created/updated pubspec_override.yaml for version conflict resolution"
            fi
        fi
    else
        log_info "Dry run completed. No actual changes were made."
    fi
}

# Run main function with all arguments
main "$@"