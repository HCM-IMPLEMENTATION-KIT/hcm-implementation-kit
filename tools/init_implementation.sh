#!/bin/bash

# Implementation Kit Initialization Script
# This script helps set up new modules in the health campaign field worker app

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"

# Module configuration variables
MODULE_DISPLAY_NAME=""
MODULE_TYPE=""
PACKAGES_TO_ADD=()

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

log_header() {
    echo -e "${CYAN}${BOLD}$1${NC}"
}

# Print welcome banner
print_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}║        ${BOLD}Health Campaign Field Worker App${NC}${CYAN}     ║${NC}"
    echo -e "${CYAN}║              ${BOLD}Implementation Kit Setup${NC}${CYAN}       ║${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Get user input with validation
get_input() {
    local prompt="$1"
    local var_name="$2"
    local required="${3:-true}"
    local default_value="${4:-}"
    
    while true; do
        if [[ -n "$default_value" ]]; then
            echo -ne "${YELLOW}${prompt}${NC} ${PURPLE}[${default_value}]${NC}: "
        else
            echo -ne "${YELLOW}${prompt}${NC}: "
        fi
        
        read -r input
        
        # Use default if input is empty
        if [[ -z "$input" && -n "$default_value" ]]; then
            input="$default_value"
        fi
        
        # Validate required fields
        if [[ "$required" == "true" && -z "$input" ]]; then
            log_error "This field is required. Please provide a value."
            continue
        fi
        
        # Return the input
        eval "$var_name='$input'"
        break
    done
}

# Get yes/no input
get_yes_no() {
    local prompt="$1"
    local var_name="$2"
    local default="${3:-n}"
    
    while true; do
        if [[ "$default" == "y" ]]; then
            echo -ne "${YELLOW}${prompt}${NC} ${PURPLE}[Y/n]${NC}: "
        else
            echo -ne "${YELLOW}${prompt}${NC} ${PURPLE}[y/N]${NC}: "
        fi
        
        read -r -n 1 input
        echo ""
        
        # Use default if empty
        if [[ -z "$input" ]]; then
            input="$default"
        fi
        
        # Normalize input
        input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
        
        if [[ "$input" == "y" || "$input" == "yes" ]]; then
            eval "$var_name='yes'"
            break
        elif [[ "$input" == "n" || "$input" == "no" ]]; then
            eval "$var_name='no'"
            break
        else
            log_error "Please enter 'y' or 'n'"
        fi
    done
}

# Get module selection
get_module_type() {
    log_header "Step 1: Select Module Type"
    echo ""
    echo -e "${CYAN}Available module types:${NC}"
    echo -e "  ${GREEN}1)${NC} Registration Delivery"
    echo -e "  ${GREEN}2)${NC} Inventory"
    echo -e "  ${GREEN}3)${NC} Referral Reconciliation"
    echo -e "  ${GREEN}4)${NC} Attendance"
    echo -e "  ${GREEN}5)${NC} Checklist"
    echo -e "  ${GREEN}6)${NC} Complaints"
    echo -e "  ${GREEN}7)${NC} Digit Data Model"
    echo -e "  ${GREEN}8)${NC} Digit Scanner"
    echo ""
    
    while true; do
        echo -ne "${YELLOW}Select module type (1-8)${NC}: "
        read -r choice
        
        case $choice in
            1)
                MODULE_TYPE="registration_delivery"
                log_info "Selected: Registration Delivery"
                break
                ;;
            2)
                MODULE_TYPE="inventory"
                log_info "Selected: Inventory"
                break
                ;;
            3)
                MODULE_TYPE="referral_reconciliation"
                log_info "Selected: Referral Reconciliation"
                break
                ;;
            4)
                MODULE_TYPE="attendance"
                log_info "Selected: Attendance"
                break
                ;;
            5)
                MODULE_TYPE="checklist"
                log_info "Selected: Checklist"
                break
                ;;
            6)
                MODULE_TYPE="complaints"
                log_info "Selected: Complaints"
                break
                ;;
            7)
                MODULE_TYPE="digit_data_model"
                log_info "Selected: Digit Data Model"
                break
                ;;
            8)
                MODULE_TYPE="digit_scanner"
                log_info "Selected: Digit Scanner"
                break
                ;;
            *)
                log_error "Invalid choice. Please select 1-8."
                ;;
        esac
    done
}

# Collect additional packages
get_additional_packages() {
    log_header "Step 2: Additional Packages"
    echo ""
    
    get_yes_no "Do you want to add additional Flutter packages?" add_packages "n"
    
    if [[ "$add_packages" == "yes" ]]; then
        echo ""
        log_info "Enter package names (one per line, press Enter on empty line to finish):"
        log_info "Packages will be installed immediately after you enter them."
        echo ""
        
        local import_script="$SCRIPT_DIR/import_packages.sh"
        
        if [[ ! -f "$import_script" ]]; then
            log_warning "import_packages.sh script not found: $import_script"
            log_info "Packages cannot be installed automatically"
            return 0
        fi
        
        while true; do
            echo -ne "${PURPLE}Package name${NC}: "
            read -r package
            
            if [[ -z "$package" ]]; then
                break
            fi
            
            # Trim whitespace
            package=$(echo "$package" | xargs)
            
            if [[ -n "$package" ]]; then
                PACKAGES_TO_ADD+=("$package")
                echo ""
                log_info "Installing package: $package"
                echo ""
                
                # Temporarily disable exit on error for package installation
                set +e
                (
                    cd "$WORKSPACE_ROOT/apps/health_campaign_field_worker_app" || exit 1
                    bash "$import_script" "$package"
                )
                local exit_code=$?
                set -e
                
                echo ""
                if [[ $exit_code -eq 0 ]]; then
                    log_success "Successfully installed: $package"
                else
                    log_error "Failed to install: $package (exit code: $exit_code)"
                fi
                echo ""
            fi
        done
        
        if [[ ${#PACKAGES_TO_ADD[@]} -gt 0 ]]; then
            log_info "Total packages installed: ${#PACKAGES_TO_ADD[@]}"
        fi
    fi
}

# Show configuration summary
show_summary() {
    echo ""
    log_header "Configuration Summary"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Module Type:${NC}           $MODULE_TYPE"
    
    if [[ ${#PACKAGES_TO_ADD[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Additional Packages:${NC}"
        for pkg in "${PACKAGES_TO_ADD[@]}"; do
            echo -e "  - $pkg"
        done
    fi
    
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Run module-specific dart script
run_module_script() {
    local module_type="$1"
    local dart_file=""
    
    # Map module type to dart file
    case $module_type in
        registration_delivery)
            dart_file="registration_delivery_imports.dart"
            ;;
        inventory)
            dart_file="inventory_package_imports.dart"
            ;;
        referral_reconciliation)
            dart_file="referral_reconciliation_imports.dart"
            ;;
        attendance)
            dart_file="attendance_package_imports.dart"
            ;;
        checklist)
            dart_file="checklist_package_imports.dart"
            ;;
        complaints)
            dart_file="complaints_package.dart"
            ;;
        digit_data_model)
            dart_file="digit_data_model_imports.dart"
            ;;
        digit_scanner)
            dart_file="digit_scanner_imports.dart"
            ;;
        *)
            log_warning "No dart script found for module type: $module_type"
            return 0
            ;;
    esac
    
    local dart_file_path="$SCRIPT_DIR/$dart_file"
    
    if [[ ! -f "$dart_file_path" ]]; then
        log_warning "Dart file not found: $dart_file_path"
        return 0
    fi
    
    log_info "Running module setup script: $dart_file"
    echo ""
    
    # Check if dart is available
    if ! command -v dart &> /dev/null; then
        log_error "Dart is not installed or not in PATH"
        log_info "Please install Dart or use Flutter SDK which includes Dart"
        return 1
    fi
    
    # Run the dart script from workspace root
    (
        cd "$WORKSPACE_ROOT" || exit 1
        dart "$dart_file_path"
    )
    
    if [[ $? -eq 0 ]]; then
        log_success "Module setup script completed successfully"
    else
        log_error "Module setup script failed"
        return 1
    fi
}

# Main module setup function
setup_module() {
    print_banner
    
    log_header "Welcome to Implementation Kit Setup Wizard"
    echo ""
    log_info "This wizard will help you set up a new module for the Health Campaign Field Worker App"
    echo ""
    
    # Step 1: Module Type
    get_module_type
    echo ""
    
    # Step 2: Additional Packages
    get_additional_packages
    
    # Show summary
    show_summary
    
    # Confirm
    get_yes_no "Do you want to proceed with this configuration?" confirm "y"
    
    if [[ "$confirm" != "yes" ]]; then
        log_warning "Setup cancelled by user"
        exit 0
    fi
    
    echo ""
    log_info "Starting module setup process..."
    echo ""
    
    # Run the module-specific dart script
    run_module_script "$MODULE_TYPE"
    
    # TODO: In the future, this is where we will:
    # - Create module directory structure
    # - Generate boilerplate code
    # - Update routing configuration
    # - Generate models and blocs
    # - Set up localization files
    
    echo ""
    log_success "╔════════════════════════════════════════════════════════════╗"
    log_success "║                                                            ║"
    log_success "║          ✓ Module Setup Completed Successfully!           ║"
    log_success "║                                                            ║"
    log_success "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "Module has been configured successfully!"
    echo ""
    log_info "Next steps (will be automated in future versions):"
    echo -e "  ${CYAN}1.${NC} Review the configuration above"
    echo -e "  ${CYAN}2.${NC} Module structure will be generated automatically"
    echo -e "  ${CYAN}3.${NC} Required packages will be installed"
    echo -e "  ${CYAN}4.${NC} Routing and navigation will be configured"
    echo -e "  ${CYAN}5.${NC} Localization files will be created"
    echo ""
    
    log_info "Module type: $MODULE_TYPE"
    
    if [[ ${#PACKAGES_TO_ADD[@]} -gt 0 ]]; then
        echo ""
        log_info "The following packages were installed:"
        for pkg in "${PACKAGES_TO_ADD[@]}"; do
            echo -e "  ${PURPLE}•${NC} $pkg"
        done
    fi
    
    echo ""
    log_success "Thank you for using the Implementation Kit Setup Wizard!"
    echo ""
}

# Help function
show_help() {
    echo -e "${CYAN}Implementation Kit Setup Script${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -i, --interactive   Run in interactive mode (default)"
    echo ""
    echo "This script helps you set up new modules for the Health Campaign Field Worker App."
    echo "It will guide you through a series of questions to configure your module."
    echo ""
}

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--interactive)
                # Default mode, do nothing
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    parse_arguments "$@"
    setup_module
}

# Run main function
main "$@"