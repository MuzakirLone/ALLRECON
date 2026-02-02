#!/bin/bash
# ALLRECON - Utility Functions
# Core helper functions for file operations, URL handling, and common tasks

# Source dependencies (use relative paths since we're in lib/)
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/logger.sh"

# Global variables
ALLRECON_VERSION="2.0.0"
ALLRECON_START_TIME=""

# Function to handle user interrupt (from original script)
function handle_interrupt() {
    read -t 0.1 -n 10000 discard # Clear input buffer
    read -t 1 -n 1 -p "Type 'exit' to skip to next command or press Enter to continue: " input
    if [[ "$input" == "e" ]]; then
        read -t 2 -n 3 rest_input
        if [[ "$input$rest_input" == "exit" ]]; then
            echo -e "\n${ORANGE}[!] Skipping current command...${NC}"
            return 1
        fi
    fi
    return 0
}

# Function to run a command with interrupt capability (from original script)
function run_interruptible() {
    local cmd="$1"
    local description="$2"

    # Set up trap to catch user input
    trap "handle_interrupt" SIGINT

    log_info "Running: $description"
    echo -e "${ORANGE}[+] Running: $description${NC}"
    echo -e "${ORANGE}[+] Press Ctrl+C during execution to get option to exit current command${NC}"

    # Run the command with interrupt handling
    { eval "$cmd"; } || true

    # Reset trap
    trap - SIGINT
}

# Directory Operations
create_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            log_debug "Created directory: $dir"
            return 0
        else
            log_error "Failed to create directory: $dir"
            return 1
        fi
    fi
    return 0
}

check_directory() {
    local dir="$1"
    [[ -d "$dir" ]]
}

# File Operations
check_file_exists() {
    local file="$1"
    [[ -f "$file" ]]
}

check_file_not_empty() {
    local file="$1"
    [[ -s "$file" ]]
}

safe_delete_file() {
    local file="$1"
    if check_file_exists "$file"; then
        rm "$file" 2>/dev/null
        log_debug "Deleted file: $file"
    fi
}

count_lines() {
    local file="$1"
    if check_file_exists "$file"; then
        wc -l < "$file" | tr -d ' '
    else
        echo "0"
    fi
}

# URL Operations
extract_domain_from_url() {
    local url="$1"
    echo "$url" | awk -F[/:] '{print $4}'
}

is_valid_url() {
    local url="$1"
    [[ "$url" =~ ^https?:// ]]
}

# String Operations
trim_whitespace() {
    local var="$1"
    echo "$var" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

to_lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

to_uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Progress Indicators
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

show_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%${remaining}s" | tr ' ' '-'
    printf "] %d%%" $percentage
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Timing Functions
start_timer() {
    ALLRECON_START_TIME=$(date +%s)
}

stop_timer() {
    local end_time=$(date +%s)
    local duration=$((end_time - ALLRECON_START_TIME))
    echo "$duration"
}

format_duration() {
    local duration=$1
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" $hours $minutes $seconds
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" $minutes $seconds
    else
        printf "%ds" $seconds
    fi
}

# Banner Display (from original script)
show_banner() {
    local width=80
    local title="ALLRECON - Bug Bounty Reconnaissance Framework"
    local version="Version: $ALLRECON_VERSION"
    local author="By Muzakir Lone"
    
    echo -e ${RED}"$(printf '%*s' $width | tr ' ' '#')"
    printf "${CP}%*s\n" $(((${#title} + width)/2)) "$title"
    printf "${CP}%*s\n" $(((${#version} + width)/2)) "$version"
    printf "${CP}%*s\n" $(((${#author} + width)/2)) "$author"
    echo -e ${RED}"$(printf '%*s' $width | tr ' ' '#')\n${NC}"
}

# Array Operations
array_contains() {
    local element="$1"
    shift
    local array=("$@")
    for item in "${array[@]}"; do
        [[ "$item" == "$element" ]] && return 0
    done
    return 1
}

array_unique() {
    local -a arr=("$@")
    printf '%s\n' "${arr[@]}" | sort -u
}

# Tool Checking
check_tool_installed() {
    local tool="$1"
    command -v "$tool" &> /dev/null
}

check_tool_version() {
    local tool="$1"
    local version_flag="${2:---version}"
    
    if check_tool_installed "$tool"; then
        $tool $version_flag 2>&1 | head -n 1
    else
        echo "Not installed"
    fi
}

# Wait for jobs
wait_for_jobs() {
    local max_wait=${1:-300}  # Default 5 minutes
    local start_time=$(date +%s)
    
    while [[ $(jobs -r | wc -l) -gt 0 ]]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $max_wait ]]; then
            log_warn "Timeout waiting for background jobs"
            return 1
        fi
        
        sleep 1
    done
    
    return 0
}

# Setup directory structure for domain
setup_domain_directories() {
    local domain="$1"
    local scan_type="${2:-massive}"  # single or massive
    local results_base="${3:-results}"  # Base results directory
    
    # Redirect log output to stderr to avoid interfering with return value
    log_info "Setting up directory structure for: $domain" >&2
    
    # Base directory under results
    local base_path="$results_base/$domain"
    create_directory "$base_path" >&2
    
    # Common directories
    local dirs=(
        "$base_path/vulnerabilities"
        "$base_path/vulnerabilities/cors"
        "$base_path/vulnerabilities/xss_scan"
        "$base_path/vulnerabilities/sqli"
        "$base_path/vulnerabilities/LFI"
        "$base_path/vulnerabilities/openredirect"
        "$base_path/waybackurls"
        "$base_path/target_wordlist"
        "$base_path/gf"
        "$base_path/nuclei_scan"
        "$base_path/js"
    )
    
    # Additional directories for massive recon
    if [[ "$scan_type" == "massive" ]]; then
        dirs+=(
            "$base_path/domain_enum"
            "$base_path/final_domains"
            "$base_path/takeovers"
        )
    fi
    
    for dir in "${dirs[@]}"; do
        create_directory "$dir" >&2
    done
    
    log_info "Directory structure created successfully at: $base_path" >&2
    echo "$base_path"  # Return the full path to stdout
}

# Deduplicate and merge files
deduplicate_files() {
    local output_file="$1"
    shift
    local input_files=("$@")
    
    log_debug "Deduplicating files into: $output_file"
    
    # Create temp file
    local temp_file=$(mktemp)
    
    # Combine all files
    for file in "${input_files[@]}"; do
        if check_file_exists "$file"; then
            cat "$file" >> "$temp_file"
        fi
    done
    
    # Sort and deduplicate
    sort -u "$temp_file" > "$output_file"
    
    # Cleanup
    rm "$temp_file"
    
    local count=$(count_lines "$output_file")
    log_info "Deduplicated $(count_lines "$temp_file") lines to $count unique entries"
}

# Export functions
export -f handle_interrupt
export -f run_interruptible
export -f create_directory
export -f check_directory
export -f check_file_exists
export -f check_file_not_empty
export -f safe_delete_file
export -f count_lines
export -f extract_domain_from_url
export -f is_valid_url
export -f trim_whitespace
export -f to_lowercase
export -f to_uppercase
export -f show_spinner
export -f show_progress_bar
export -f start_timer
export -f stop_timer
export -f format_duration
export -f show_banner
export -f array_contains
export -f array_unique
export -f check_tool_installed
export -f check_tool_version
export -f wait_for_jobs
export -f setup_domain_directories
export -f deduplicate_files
