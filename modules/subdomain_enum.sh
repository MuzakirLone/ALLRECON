#!/bin/bash
# ALLRECON - Subdomain Enumeration Module
# Comprehensive subdomain discovery and resolution

# Source dependencies
MODULE_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$MODULE_ROOT_DIR/lib/colors.sh"
source "$MODULE_ROOT_DIR/lib/logger.sh"
source "$MODULE_ROOT_DIR/lib/utils.sh"
source "$MODULE_ROOT_DIR/lib/parallel.sh"
source "$MODULE_ROOT_DIR/lib/validators.sh"

tool_enabled_or_default() {
    local tool="$1"
    if declare -F is_tool_enabled >/dev/null 2>&1; then
        is_tool_enabled "$tool"
        return $?
    fi
    return 0
}

module_skipped_or_default() {
    local module="$1"
    if declare -F should_skip_module >/dev/null 2>&1; then
        should_skip_module "$module"
        return $?
    fi
    return 1
}

# Subdomain enumeration with crt.sh
enum_crt_sh() {
    local domain="$1"
    local output_file="$2"
    
    log_info "Running crt.sh enumeration for: $domain"
    echo -e "${CPO}\n[+] Crt.sh Enumeration Started:${NC}"
    
    run_interruptible \
        "curl -s 'https://crt.sh/?q=%25.$domain&output=json' | jq -r '.[].name_value' | sed 's/\\*\\.//g' | sort -u | tee '$output_file'" \
        "crt.sh enumeration"
    
    if validate_output_file "$output_file" "crt.sh"; then
        local count=$(count_lines "$output_file")
        print_success "crt.sh found $count subdomains"
    fi
}

# Subdomain enumeration with subfinder
enum_subfinder() {
    local domain="$1"
    local output_file="$2"
    
    if ! tool_enabled_or_default "subfinder"; then
        log_info "Skipping subfinder because it is disabled by the active profile"
        : > "$output_file"
        return 0
    fi
    
    log_info "Running subfinder enumeration for: $domain"
    echo -e "${CP}\n[+] subfinder Enumeration Started:${NC}"
    
    run_interruptible \
        "subfinder -d '$domain' -o '$output_file'" \
        "subfinder enumeration"
    
    if validate_output_file "$output_file" "subfinder"; then
        local count=$(count_lines "$output_file")
        print_success "subfinder found $count subdomains"
    fi
}

# Subdomain enumeration with assetfinder
enum_assetfinder() {
    local domain="$1"
    local output_file="$2"
    
    if ! tool_enabled_or_default "assetfinder"; then
        log_info "Skipping assetfinder because it is disabled by the active profile"
        : > "$output_file"
        return 0
    fi
    
    log_info "Running assetfinder enumeration for: $domain"
    echo -e "${PINK}\n[+] Assetfinder Enumeration Started:${NC}"
    
    run_interruptible \
        "assetfinder -subs-only '$domain' | tee '$output_file'" \
        "assetfinder enumeration"
    
    if validate_output_file "$output_file" "assetfinder"; then
        local count=$(count_lines "$output_file")
        print_success "assetfinder found $count subdomains"
    fi
}

# Subdomain bruteforce with dnsx
enum_dnsx_bruteforce() {
    local domain="$1"
    local output_file="$2"
    local wordlist="${3:-/usr/share/seclists/Discovery/DNS/deepmagic.com-prefixes-top50000.txt}"
    local resolvers="${4:-~/tools/resolvers/resolver.txt}"
    
    log_info "Running dnsx bruteforce for: $domain"
    echo -e "${CN}\n[+] dnsx Bruteforce Started:${NC}"
    
    # Expand tilde in paths
    wordlist="${wordlist/#\~/$HOME}"
    resolvers="${resolvers/#\~/$HOME}"
    : > "$output_file"
    
    if module_skipped_or_default "bruteforce" || ! tool_enabled_or_default "dnsx"; then
        log_info "Skipping dnsx bruteforce due to active profile"
        return 0
    fi
    
    if ! command -v dnsx >/dev/null 2>&1; then
        log_warn "dnsx not found, skipping dnsx bruteforce"
        return 1
    fi
    
    if [[ ! -f "$wordlist" ]]; then
        log_warn "Wordlist not found: $wordlist, skipping dnsx bruteforce"
        return 1
    fi
    
    if [[ ! -f "$resolvers" ]]; then
        log_warn "Resolvers file not found: $resolvers, skipping dnsx bruteforce"
        return 1
    fi
    
    run_interruptible \
        "dnsx -silent -d '$domain' -w '$wordlist' -r '$resolvers' -o '$output_file'" \
        "dnsx bruteforce"
    
    if validate_output_file "$output_file" "dnsx"; then
        local count=$(count_lines "$output_file")
        print_success "dnsx found $count subdomains"
    fi
}

# Resolve all subdomains
resolve_subdomains() {
    local domain="$1"
    local input_file="$2"
    local output_file="$3"
    local resolvers="${4:-~/tools/resolvers/resolver.txt}"
    
    log_info "Resolving all subdomains for: $domain"
    echo -e "${BLUE}\n[+] Resolving All Subdomains:${NC}"
    
    # Expand tilde in paths
    resolvers="${resolvers/#\~/$HOME}"
    
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    : > "$output_file"
    
    if [[ ! -f "$resolvers" ]] || ! command -v dnsx >/dev/null 2>&1; then
        if [[ ! -f "$resolvers" ]]; then
            log_warn "Resolvers file not found: $resolvers, using default resolution"
        else
            log_warn "dnsx not found, using default resolution"
        fi
        # Use basic resolution
        while IFS= read -r subdomain; do
            if domain_resolves "$subdomain"; then
                echo "$subdomain" >> "$output_file"
            fi
        done < "$input_file"
    else
        run_interruptible \
            "dnsx -silent -l '$input_file' -r '$resolvers' -wd '$domain' -o '$output_file'" \
            "dnsx subdomain resolution"
    fi
    
    if validate_output_file "$output_file" "resolver"; then
        local count=$(count_lines "$output_file")
        print_success "Resolved $count live subdomains"
    fi
}

# Check HTTP/HTTPS services
check_http_services() {
    local input_file="$1"
    local output_file="$2"
    local threads="${3:-30}"
    
    log_info "Checking HTTP/HTTPS services"
    echo -e "${PINK}\n[+] Checking Services On Subdomains:${NC}"
    
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    : > "$output_file"
    
    if ! tool_enabled_or_default "httpx"; then
        log_info "Skipping httpx because it is disabled by the active profile"
        return 0
    fi
    
    run_interruptible \
        "cat '$input_file' | httpx -threads $threads -o '$output_file'" \
        "HTTP service detection"
    
    if validate_output_file "$output_file" "httpx"; then
        local count=$(count_lines "$output_file")
        print_success "Found $count live HTTP/HTTPS services"
    fi
}

# Subdomain takeover detection with subzy
check_takeover_subzy() {
    local input_file="$1"
    local output_file="$2"
    
    if ! tool_enabled_or_default "subzy"; then
        log_info "Skipping subzy because it is disabled by the active profile"
        : > "$output_file"
        return 0
    fi
    
    log_info "Checking for subdomain takeovers with subzy"
    echo -e "${CP}\n[+] Searching For Subdomain TakeOver (subzy):${NC}"
    
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    run_interruptible \
        "subzy run --hide_fails --targets '$input_file' | tee '$output_file'" \
        "subzy takeover detection"
    
    if validate_output_file "$output_file" "subzy"; then
        local count=$(grep -c "VULNERABLE" "$output_file" 2>/dev/null || echo "0")
        if [[ $count -gt 0 ]]; then
            print_warning "Found $count potential subdomain takeovers!"
        else
            print_success "No subdomain takeovers detected"
        fi
    fi
}

# Subdomain takeover detection with subjack
check_takeover_subjack() {
    local input_file="$1"
    local output_file="$2"
    
    if ! tool_enabled_or_default "subjack"; then
        log_info "Skipping subjack because it is disabled by the active profile"
        : > "$output_file"
        return 0
    fi
    
    log_info "Checking for subdomain takeovers with subjack"
    echo -e "${CP}\n[+] Searching For Subdomain TakeOver (subjack):${NC}"
    
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    run_interruptible \
        "subjack -w '$input_file' -t 100 -timeout 30 -o '$output_file' -ssl" \
        "subjack takeover detection"
    
    if validate_output_file "$output_file" "subjack"; then
        local count=$(count_lines "$output_file")
        if [[ $count -gt 0 ]]; then
            print_warning "Found $count potential subdomain takeovers!"
        else
            print_success "No subdomain takeovers detected"
        fi
    fi
}

# Complete subdomain enumeration workflow
run_subdomain_enumeration() {
    local domain="$1"
    local parallel_mode="${2:-true}"
    local output_root="${3:-$domain}"
    local base_dir="$output_root/domain_enum"
    local wordlist
    local resolvers
    
    if declare -F get_config >/dev/null 2>&1; then
        wordlist="$(get_config 'wordlist_subdomain_bruteforce' '/usr/share/seclists/Discovery/DNS/deepmagic.com-prefixes-top50000.txt')"
        resolvers="$(get_config 'wordlist_resolvers' '~/tools/resolvers/resolver.txt')"
    else
        wordlist="/usr/share/seclists/Discovery/DNS/deepmagic.com-prefixes-top50000.txt"
        resolvers="~/tools/resolvers/resolver.txt"
    fi
    
    log_info "Starting complete subdomain enumeration for: $domain"
    
    # Create directory
    create_directory "$base_dir"
    
    if [[ "$parallel_mode" == "true" ]] && [[ "$PARALLEL_ENABLED" == "true" ]]; then
        echo -e "${GREEN}[i] Running subdomain enumeration in parallel mode${NC}"
        
        # Run all enumeration tools in parallel
        if tool_enabled_or_default "crtsh" || tool_enabled_or_default "crt.sh"; then
            run_parallel_job "enum_crt_sh '$domain' '$base_dir/crt.txt'" "crt.sh enumeration"
        else
            : > "$base_dir/crt.txt"
            log_info "Skipping crt.sh because it is disabled by the active profile"
        fi
        run_parallel_job "enum_subfinder '$domain' '$base_dir/subfinder.txt'" "subfinder enumeration"
        run_parallel_job "enum_assetfinder '$domain' '$base_dir/assetfinder.txt'" "assetfinder enumeration"
        run_parallel_job "enum_dnsx_bruteforce '$domain' '$base_dir/dnsx.txt' '$wordlist' '$resolvers'" "dnsx enumeration"
        
        # Wait for all enumeration jobs to complete
        wait_for_all_jobs
    else
        echo -e "${YELLOW}[i] Running subdomain enumeration in sequential mode${NC}"
        
        # Run sequentially
        if tool_enabled_or_default "crtsh" || tool_enabled_or_default "crt.sh"; then
            enum_crt_sh "$domain" "$base_dir/crt.txt"
        else
            : > "$base_dir/crt.txt"
            log_info "Skipping crt.sh because it is disabled by the active profile"
        fi
        enum_subfinder "$domain" "$base_dir/subfinder.txt"
        enum_assetfinder "$domain" "$base_dir/assetfinder.txt"
        enum_dnsx_bruteforce "$domain" "$base_dir/dnsx.txt" "$wordlist" "$resolvers"
    fi
    
    # Combine and deduplicate results
    echo -e "${CP}\n[+] Collecting All Subdomains Into Single File:${NC}"
    {
        for result_file in "$base_dir/crt.txt" "$base_dir/subfinder.txt" "$base_dir/assetfinder.txt" "$base_dir/dnsx.txt"; do
            [[ -f "$result_file" ]] && cat "$result_file"
        done
    } | sed '/^[[:space:]]*$/d' | sort -u > "$base_dir/all.txt"
    
    local total_found=$(count_lines "$base_dir/all.txt")
    print_success "Total unique subdomains found: $total_found"
    
    # Resolve subdomains
    local final_dir="$output_root/final_domains"
    create_directory "$final_dir"
    
    resolve_subdomains "$domain" "$base_dir/all.txt" "$final_dir/domains.txt" "$resolvers"
    
    # Check HTTP services
    check_http_services "$final_dir/domains.txt" "$final_dir/httpx.txt"
    
    # Check for takeovers
    local takeover_dir="$output_root/takeovers"
    create_directory "$takeover_dir"
    
    if [[ "$parallel_mode" == "true" ]] && [[ "$PARALLEL_ENABLED" == "true" ]]; then
        run_parallel_job "check_takeover_subzy '$base_dir/all.txt' '$takeover_dir/subzy.txt'" "subzy takeover check"
        run_parallel_job "check_takeover_subjack '$base_dir/all.txt' '$takeover_dir/take.txt'" "subjack takeover check"
        wait_for_all_jobs
    else
        check_takeover_subzy "$base_dir/all.txt" "$takeover_dir/subzy.txt"
        check_takeover_subjack "$base_dir/all.txt" "$takeover_dir/take.txt"
    fi
    
    log_info "Subdomain enumeration completed for: $domain"
    echo -e "${GREEN}\n[✓] Subdomain Enumeration Completed${NC}\n"
}

# Export functions
export -f enum_crt_sh
export -f enum_subfinder
export -f enum_assetfinder
export -f enum_dnsx_bruteforce
export -f resolve_subdomains
export -f check_http_services
export -f check_takeover_subzy
export -f check_takeover_subjack
export -f run_subdomain_enumeration
