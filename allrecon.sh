#!/bin/bash
# ALLRECON - Modern Bug Bounty Reconnaissance Framework
# Version: 2.0.0
# Author: Muzakir Lone

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load core libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/parallel.sh"
source "$SCRIPT_DIR/lib/validators.sh"
source "$SCRIPT_DIR/lib/config_parser.sh"

# Load modules
source "$SCRIPT_DIR/modules/subdomain_enum.sh"
source "$SCRIPT_DIR/modules/js_analysis.sh"
source "$SCRIPT_DIR/modules/vuln_scan.sh"
source "$SCRIPT_DIR/modules/url_collection.sh"
source "$SCRIPT_DIR/modules/reporting.sh"

# Global variables
CONFIG_FILE="$SCRIPT_DIR/config/default.yaml"
RESULTS_DIR="$SCRIPT_DIR/results"
PROFILE=""
PARALLEL_MODE=true
LOG_LEVEL_CLI="INFO"

# Signal handler for Ctrl+C (SIGINT)
handle_interrupt() {
    echo -e "\n${RED}[!] Interrupted by user. Exiting...${NC}"
    log_info "Script interrupted by user (Ctrl+C)"
    exit 130
}

# Set up signal trap
trap handle_interrupt SIGINT

# Parse CLI arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL_MODE=true
                shift
                ;;
            --no-parallel)
                PARALLEL_MODE=false
                shift
                ;;
            --log-level)
                LOG_LEVEL_CLI="$2"
                shift 2
                ;;
            --no-color)
                disable_colors
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

# Show help message
show_help() {
    cat << EOF
ALLRECON - Modern Bug Bounty Reconnaissance Framework v2.0.0

Usage: $0 [OPTIONS]

Options:
  --config FILE         Use custom configuration file
  --profile NAME        Use predefined profile (quick, deep)
  --parallel            Enable parallel execution (default)
  --no-parallel         Disable parallel execution
  --log-level LEVEL     Set log level (DEBUG, INFO, WARN, ERROR)
  --no-color            Disable colored output
  --help, -h            Show this help message

Examples:
  $0                                    # Run with default settings
  $0 --profile quick                    # Quick scan profile
  $0 --config custom.yaml               # Custom configuration
  $0 --parallel --log-level DEBUG       # Parallel with debug logging

For more information, see docs/USAGE.md
EOF
}

# Initialize ALLRECON
init_allrecon() {
    # Parse arguments
    parse_arguments "$@"
    
    # Load configuration
    load_config "$CONFIG_FILE"
    
    # Load profile if specified
    if [[ -n "$PROFILE" ]]; then
        load_profile "$PROFILE"
    fi
    
    # Override with CLI settings
    set_config "scan_parallel_enabled" "$PARALLEL_MODE"
    set_config "logging_level" "$LOG_LEVEL_CLI"
    
    # Apply configuration
    apply_config
    
    # Validate configuration
    if ! validate_config; then
        log_error "Configuration validation failed"
        exit 1
    fi
    
    # Create results directory
    mkdir -p "$RESULTS_DIR" 2>/dev/null
    
    log_info "ALLRECON initialized successfully"
    log_info "Results directory: $RESULTS_DIR"
}

# Single domain reconnaissance
single_recon() {
    clear
    show_banner
    
    echo -n -e "${ORANGE}\n[+] Enter Single domain (e.g evil.com) : ${NC}"
    read domain
    
    # Validate domain
    domain=$(validate_domain "$domain")
    if [[ $? -ne 0 ]]; then
        print_error "Invalid domain format"
        return 1
    fi
    
    log_info "Starting single recon for: $domain"
    start_timer
    
    # Setup directories
    setup_domain_directories "$domain" "single"
    
    local d=$(date +"%b-%d-%y %H:%M")
    echo -e "${BLUE}\n[+] Recon Started On $d\n${NC}"
    
    # Check HTTP service
    echo -e "${CP}[+] Checking Services On Target:${NC}"
    echo "$domain" | httpx -threads $(get_config "scan_threads" "30") -o "$domain/httpx.txt"
    
    # Run JS analysis
    run_js_analysis "$domain" "$PARALLEL_MODE"
    
    # Run URL collection
    run_url_collection "$domain" "$domain/httpx.txt"
    
    # Run vulnerability scans
    run_vulnerability_scans "$domain" "$domain/httpx.txt" ""
    
    # Generate report
    local scan_duration=$(stop_timer)
    if [[ "$(get_config 'output_generate_report')" == "true" ]]; then
        generate_text_report "$domain" "$domain/report.txt" "$scan_duration"
    fi
    
    local duration_formatted=$(format_duration $scan_duration)
    print_success "Single recon completed in $duration_formatted"
    log_info "Single recon completed for: $domain"
}

# Massive reconnaissance (with subdomains)
massive_recon() {
    clear
    show_banner
    
    echo -n -e "${BLUE2}\n[+] Full Recon with subdomains (e.g *.example.com): ${NC}"
    read domain
    
    # Validate domain
    domain=$(validate_domain "$domain")
    if [[ $? -ne 0 ]]; then
        print_error "Invalid domain format"
        return 1
    fi
    
    log_info "Starting massive recon for: $domain"
    start_timer
    
    # Setup directories
    setup_domain_directories "$domain" "massive"
    
    local d=$(date +"%b-%d-%y %H:%M")
    echo -e "${RED}\n[+] Massive Recon Started On $d${NC}"
    
    # Run subdomain enumeration
    run_subdomain_enumeration "$domain" "$PARALLEL_MODE"
    
    # Run JS analysis
    run_js_analysis "$domain" "$PARALLEL_MODE"
    
    # Run URL collection
    run_url_collection "$domain" "$domain/final_domains/domains.txt"
    
    # Run vulnerability scans
    run_vulnerability_scans "$domain" "$domain/final_domains/httpx.txt" "http/"
    
    # Generate report
    local scan_duration=$(stop_timer)
    if [[ "$(get_config 'output_generate_report')" == "true" ]]; then
        generate_text_report "$domain" "$domain/report.txt" "$scan_duration"
    fi
    
    local duration_formatted=$(format_duration $scan_duration)
    print_success "Massive recon completed in $duration_formatted"
    log_info "Massive recon completed for: $domain"
}

# Main menu
menu() {
    clear
    show_banner
    
    echo -e -n "${YELLOW}\n[*] Which Type of recon u want to Perform\n ${NC}"
    echo -e "  ${NC}[${CG}1${NC}]${CNC} Single Target Recon"
    echo -e "   ${NC}[${CG}2${NC}]${CNC} Full Target Recon With Subdomains"
    echo -e "   ${NC}[${CG}3${NC}]${CNC} Exit"
    echo -n -e "${RED}\n[+] Select: ${NC}"
    read bounty_play
    
    case "$bounty_play" in
        1)
            single_recon
            ;;
        2)
            massive_recon
            ;;
        3)
            log_info "Exiting ALLRECON"
            exit 0
            ;;
        *)
            print_error "Invalid selection"
            menu
            ;;
    esac
}

# Main execution
main() {
    init_allrecon "$@"
    menu
}

# Run main function
main "$@"
