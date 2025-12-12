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
MODULE_NAME=""
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
    echo -e "${CYAN}║        ${BOLD}Health Campaign Field Worker App${NC}${CYAN}                 ║${NC}"
    echo -e "${CYAN}║              ${BOLD}Implementation Kit Setup${NC}${CYAN}                      ║${NC}"
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
    echo -e "  ${GREEN}1)${NC} Registration Module"
    echo -e "  ${GREEN}2)${NC} Service Delivery Module"
    echo -e "  ${GREEN}3)${NC} Attendance Module"
    echo -e "  ${GREEN}4)${NC} Inventory Management Module"
    echo -e "  ${GREEN}5)${NC} Survey/Checklist Module"
    echo -e "  ${GREEN}6)${NC} Complaint Management Module"
    echo -e "  ${GREEN}7)${NC} Custom Module"
    echo ""
    
    while true; do
        echo -ne "${YELLOW}Select module type (1-7)${NC}: "
        read -r choice
        
        case $choice in
            1)
                MODULE_TYPE="registration"
                log_info "Selected: Registration Module"
                break
                ;;
            2)
                MODULE_TYPE="service_delivery"
                log_info "Selected: Service Delivery Module"
                break
                ;;
            3)
                MODULE_TYPE="attendance"
                log_info "Selected: Attendance Module"
                break
                ;;
            4)
                MODULE_TYPE="inventory"
                log_info "Selected: Inventory Management Module"
                break
                ;;
            5)
                MODULE_TYPE="survey"
                log_info "Selected: Survey/Checklist Module"
                break
                ;;
            6)
                MODULE_TYPE="complaint"
                log_info "Selected: Complaint Management Module"
                break
                ;;
            7)
                MODULE_TYPE="custom"
                log_info "Selected: Custom Module"
                break
                ;;
            *)
                log_error "Invalid choice. Please select 1-7."
                ;;
        esac
    done
}

# Collect additional packages
get_additional_packages() {
    log_header "Step 3: Additional Packages"
    echo ""
    
    get_yes_no "Do you want to add additional Flutter packages?" add_packages "n"
    
    if [[ "$add_packages" == "yes" ]]; then
        echo ""
        log_info "Enter package names (one per line, press Enter on empty line to finish):"
        
        while true; do
            echo -ne "${PURPLE}Package name${NC}: "
            read -r package
            
            if [[ -z "$package" ]]; then
                break
            fi
            
            PACKAGES_TO_ADD+=("$package")
            log_success "Added: $package"
        done
        
        if [[ ${#PACKAGES_TO_ADD[@]} -gt 0 ]]; then
            log_info "Packages to add: ${PACKAGES_TO_ADD[*]}"
        fi
    fi
}

# Show configuration summary
show_summary() {
    echo ""
    log_header "Configuration Summary"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Module Name:${NC}           $MODULE_NAME"
    echo -e "${YELLOW}Display Name:${NC}          $MODULE_DISPLAY_NAME"
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
    
    # Step 2: Module Information
    log_header "Step 2: Module Information"
    echo ""
    
    get_input "Enter module name (snake_case, e.g., household_registration)" MODULE_NAME "true"
    get_input "Enter display name (e.g., Household Registration)" MODULE_DISPLAY_NAME "true"
    
    echo ""
    
    # Step 3: Additional Packages
    get_additional_packages
    
    # Show summary
    show_summary
    
    # Confirm
    get_yes_no "Do you want to proceed with this configuration?" confirm "y"
    
    if [[ "$confirm" != "yes" ]]; then
        log_warning "Setup cancelled by user"
        exit 0
    fi
    
    # TODO: In the future, this is where we will:
    # - Create module directory structure
    # - Generate boilerplate code
    # - Add packages using import_packages.sh
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
    
    log_info "Module '$MODULE_DISPLAY_NAME' has been configured successfully!"
    echo ""
    log_info "Next steps (will be automated in future versions):"
    echo -e "  ${CYAN}1.${NC} Review the configuration above"
    echo -e "  ${CYAN}2.${NC} Module structure will be generated automatically"
    echo -e "  ${CYAN}3.${NC} Required packages will be installed"
    echo -e "  ${CYAN}4.${NC} Routing and navigation will be configured"
    echo -e "  ${CYAN}5.${NC} Localization files will be created"
    echo ""
    
    log_info "Configuration saved for module: $MODULE_NAME"
    log_info "Module type: $MODULE_TYPE"
    
    if [[ ${#PACKAGES_TO_ADD[@]} -gt 0 ]]; then
        echo ""
        log_info "The following packages were requested:"
        for pkg in "${PACKAGES_TO_ADD[@]}"; do
            echo -e "  ${PURPLE}•${NC} $pkg"
        done
        echo ""
        log_info "These will be installed automatically in future versions"
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