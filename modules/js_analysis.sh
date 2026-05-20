#!/bin/bash
# ALLRECON - JavaScript Analysis Module
# JavaScript file discovery and security analysis

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

# Find JS files using gau
find_js_gau() {
    local targets_file="$1"
    local output_file="$2"
    
    if ! tool_enabled_or_default "gau"; then
        log_info "Skipping gau JS discovery because it is disabled by the active profile"
        : > "$output_file"
        return 0
    fi
    
    log_info "Finding JS files with gau"
    echo -e "${BLUE}[+] Finding JS files using gau...${NC}"
    
    run_interruptible \
        "cat '$targets_file' | gau | grep -Ei '\\.js([?#]|$)' | tee '$output_file'" \
        "gau JS search"
    
    if validate_output_file "$output_file" "gau"; then
        local count=$(count_lines "$output_file")
        print_success "gau found $count JS files"
    fi
}

# Find JS files using waybackurls
find_js_waybackurls() {
    local targets_file="$1"
    local output_file="$2"
    
    if ! tool_enabled_or_default "waybackurls"; then
        log_info "Skipping waybackurls JS discovery because it is disabled by the active profile"
        : > "$output_file"
        return 0
    fi
    
    log_info "Finding JS files with waybackurls"
    echo -e "${BLUE}[+] Finding JS files using waybackurls...${NC}"
    
    run_interruptible \
        "cat '$targets_file' | waybackurls | grep -Ei '\\.js([?#]|$)' | tee '$output_file'" \
        "waybackurls JS search"
    
    if validate_output_file "$output_file" "waybackurls"; then
        local count=$(count_lines "$output_file")
        print_success "waybackurls found $count JS files"
    fi
}

# Find JS files using katana
find_js_katana() {
    local live_urls_file="$1"
    local output_file="$2"
    
    if ! tool_enabled_or_default "katana"; then
        log_info "Skipping katana JS discovery because it is disabled by the active profile"
        : > "$output_file"
        return 0
    fi
    
    log_info "Finding JS files with katana"
    echo -e "${BLUE}[+] Finding JS files using katana...${NC}"
    
    run_interruptible \
        "cat '$live_urls_file' | xargs -r -I{} katana -u '{}' -jc -silent | grep -Ei '\\.js([?#]|$)' | tee '$output_file'" \
        "katana JS search"
    
    if validate_output_file "$output_file" "katana"; then
        local count=$(count_lines "$output_file")
        print_success "katana found $count JS files"
    fi
}

# Extract JS from robots.txt
find_js_robots() {
    local targets_file="$1"
    local output_file="$2"
    
    if ! tool_enabled_or_default "curl"; then
        log_info "Skipping robots.txt JS discovery because curl is disabled by the active profile"
        : > "$output_file"
        return 0
    fi
    
    log_info "Extracting JS from robots.txt"
    echo -e "${BLUE}[+] Extracting JS from robots.txt...${NC}"
    
    run_interruptible \
        "while IFS= read -r target; do curl -s \"https://\$target/robots.txt\" | awk -v host=\"https://\$target\" '/\\.js([?#]|$)/ { if (\$NF ~ /^https?:\\/\\//) print \$NF; else print host \"/\" \$NF }'; done < '$targets_file' | sort -u | tee '$output_file'" \
        "robots.txt JS extraction"
    
    if validate_output_file "$output_file" "robots.txt"; then
        local count=$(count_lines "$output_file")
        print_success "robots.txt found $count JS files"
    fi
}

# Extract endpoints using LinkFinder
extract_endpoints_linkfinder() {
    local js_file_list="$1"
    local output_file="$2"
    
    if ! tool_enabled_or_default "linkfinder"; then
        log_info "Skipping LinkFinder because it is disabled by the active profile"
        : > "$output_file"
        return 0
    fi
    
    log_info "Extracting endpoints with LinkFinder"
    echo -e "${PINK}\n[+] Extracting Endpoints using LinkFinder...${NC}"
    
    if [[ ! -f "$js_file_list" ]]; then
        log_error "JS file list not found: $js_file_list"
        return 1
    fi
    
    local linkfinder_path="~/tools/LinkFinder/linkfinder.py"
    linkfinder_path="${linkfinder_path/#\~/$HOME}"
    
    if [[ ! -f "$linkfinder_path" ]]; then
        log_warn "LinkFinder not found at: $linkfinder_path, skipping"
        return 1
    fi
    
    run_interruptible \
        "cat '$js_file_list' | xargs -I{} python3 '$linkfinder_path' -i {} -o cli | tee '$output_file'" \
        "LinkFinder analysis"
    
    if validate_output_file "$output_file" "LinkFinder"; then
        local count=$(count_lines "$output_file")
        print_success "LinkFinder extracted $count endpoints"
    fi
}

# Extract secrets using SecretFinder
extract_secrets_secretfinder() {
    local js_file_list="$1"
    local output_file="$2"
    
    if ! tool_enabled_or_default "secretfinder"; then
        log_info "Skipping SecretFinder because it is disabled by the active profile"
        : > "$output_file"
        return 0
    fi
    
    log_info "Extracting secrets with SecretFinder"
    echo -e "${PINK}[+] Extracting Secrets using SecretFinder...${NC}"
    
    if [[ ! -f "$js_file_list" ]]; then
        log_error "JS file list not found: $js_file_list"
        return 1
    fi
    
    local secretfinder_path="~/tools/SecretFinder/SecretFinder.py"
    secretfinder_path="${secretfinder_path/#\~/$HOME}"
    
    if [[ ! -f "$secretfinder_path" ]]; then
        log_warn "SecretFinder not found at: $secretfinder_path, skipping"
        return 1
    fi
    
    run_interruptible \
        "cat '$js_file_list' | xargs -I{} python3 '$secretfinder_path' -i {} -o cli | tee '$output_file'" \
        "SecretFinder analysis"
    
    if validate_output_file "$output_file" "SecretFinder"; then
        local count=$(count_lines "$output_file")
        print_success "SecretFinder found $count potential secrets"
    fi
}

# Run GF patterns on JS files
run_gf_patterns() {
    local js_file_list="$1"
    local output_dir="$2"
    
    log_info "Running GF patterns on JS files"
    echo -e "${CG}\n[+] Running GF Patterns on JS files...${NC}"
    
    if [[ ! -f "$js_file_list" ]]; then
        log_error "JS file list not found: $js_file_list"
        return 1
    fi
    
    if ! check_tool_installed "gf"; then
        log_warn "gf tool not found, skipping GF patterns"
        return 1
    fi
    
    if ! tool_enabled_or_default "gf"; then
        log_info "Skipping JS GF patterns because gf is disabled by the active profile"
        return 0
    fi
    
    # Run patterns
    run_interruptible "cat '$js_file_list' | gf apikeys | tee '$output_dir/api_keys.txt'" "GF apikeys"
    run_interruptible "cat '$js_file_list' | gf aws-keys | tee '$output_dir/aws_keys.txt'" "GF aws-keys"
    run_interruptible "cat '$js_file_list' | gf json | tee '$output_dir/json_leaks.txt'" "GF json"
    run_interruptible "cat '$js_file_list' | gf urls | tee '$output_dir/urls.txt'" "GF urls"
    
    print_success "GF patterns completed"
}

# Manual secret grepping
grep_manual_secrets() {
    local js_file_list="$1"
    local output_file="$2"
    
    log_info "Grepping for secrets manually"
    echo -e "${ORANGE}\n[+] Grepping for secrets manually...${NC}"
    
    if [[ ! -f "$js_file_list" ]]; then
        log_error "JS file list not found: $js_file_list"
        return 1
    fi
    
    run_interruptible \
        "grep -E -o \"(apiKey|authToken|client_secret|accessToken|api_key|API_KEY|secret|SECRET)[\\\"':= ]+[^\\\"' ]+\" '$js_file_list' | tee '$output_file'" \
        "Manual secret grep"
    
    if validate_output_file "$output_file" "manual grep"; then
        local count=$(count_lines "$output_file")
        print_success "Manual grep found $count potential secrets"
    fi
}

# Complete JavaScript analysis workflow
run_js_analysis() {
    local domain="$1"
    local parallel_mode="${2:-true}"
    local output_root="${3:-$domain}"
    local domains_file="${4:-}"
    local httpx_file="${5:-}"
    local js_dir="$output_root/js"
    local targets_file="$js_dir/targets.txt"
    local live_urls_file="$js_dir/live_urls.txt"
    
    log_info "Starting JavaScript analysis for: $domain"
    echo -e "${NEW}\n[+] Starting JavaScript Enumeration & Analysis...\n${NC}"
    
    # Create directory
    create_directory "$js_dir"
    
    : > "$targets_file"
    if [[ -n "$domains_file" && -s "$domains_file" ]]; then
        cat "$domains_file"
    elif [[ -n "$httpx_file" && -s "$httpx_file" ]]; then
        cat "$httpx_file"
    else
        echo "$domain"
    fi | sed 's|^https\?://||;s|/.*$||;s|:[0-9]\+$||' | sed '/^[[:space:]]*$/d' | sort -u > "$targets_file"
    
    : > "$live_urls_file"
    if [[ -n "$httpx_file" && -s "$httpx_file" ]]; then
        grep -E '^https?://' "$httpx_file" | sort -u > "$live_urls_file"
    else
        sed 's|^|https://|' "$targets_file" > "$live_urls_file"
    fi
    
    # 1. Find JS files
    if [[ "$parallel_mode" == "true" ]] && [[ "$PARALLEL_ENABLED" == "true" ]]; then
        echo -e "${GREEN}[i] Running JS file discovery in parallel mode${NC}"
        
        run_parallel_job "find_js_gau '$targets_file' '$js_dir/js_gau.txt'" "gau JS discovery"
        run_parallel_job "find_js_waybackurls '$targets_file' '$js_dir/js_wayback.txt'" "waybackurls JS discovery"
        run_parallel_job "find_js_katana '$live_urls_file' '$js_dir/js_katana.txt'" "katana JS discovery"
        run_parallel_job "find_js_robots '$targets_file' '$js_dir/js_robots.txt'" "robots.txt JS discovery"
        
        wait_for_all_jobs
    else
        echo -e "${YELLOW}[i] Running JS file discovery in sequential mode${NC}"
        
        find_js_gau "$targets_file" "$js_dir/js_gau.txt"
        find_js_waybackurls "$targets_file" "$js_dir/js_wayback.txt"
        find_js_katana "$live_urls_file" "$js_dir/js_katana.txt"
        find_js_robots "$targets_file" "$js_dir/js_robots.txt"
    fi
    
    # 2. Combine and deduplicate JS files
    echo -e "${CPO}[+] Combining and deduplicating JS files...${NC}"
    cat "$js_dir"/js_*.txt 2>/dev/null | sort -u | anew "$js_dir/all_js.txt" 2>/dev/null || \
        cat "$js_dir"/js_*.txt 2>/dev/null | sort -u > "$js_dir/all_js.txt"
    
    if [[ ! -s "$js_dir/all_js.txt" ]]; then
        log_warn "No JS files found"
        echo -e "${RED}[-] No JS files found. Skipping analysis.${NC}"
        return 1
    fi
    
    local total_js=$(count_lines "$js_dir/all_js.txt")
    print_success "Total unique JS files found: $total_js"
    
    # 3. Extract endpoints and secrets
    if module_skipped_or_default "js_analysis_deep"; then
        log_info "Skipping deep JavaScript analysis due to active profile"
    else
        if [[ "$parallel_mode" == "true" ]] && [[ "$PARALLEL_ENABLED" == "true" ]]; then
            run_parallel_job "extract_endpoints_linkfinder '$js_dir/all_js.txt' '$js_dir/endpoints.txt'" "LinkFinder"
            run_parallel_job "extract_secrets_secretfinder '$js_dir/all_js.txt' '$js_dir/secrets.txt'" "SecretFinder"
            run_parallel_job "grep_manual_secrets '$js_dir/all_js.txt' '$js_dir/found_keys.txt'" "Manual secret grep"
            
            wait_for_all_jobs
        else
            extract_endpoints_linkfinder "$js_dir/all_js.txt" "$js_dir/endpoints.txt"
            extract_secrets_secretfinder "$js_dir/all_js.txt" "$js_dir/secrets.txt"
            grep_manual_secrets "$js_dir/all_js.txt" "$js_dir/found_keys.txt"
        fi
    fi
    
    # 4. Run GF patterns
    run_gf_patterns "$js_dir/all_js.txt" "$js_dir"
    
    log_info "JavaScript analysis completed for: $domain"
    echo -e "${GREEN}[+] JavaScript Enumeration Completed.${NC}\n"
}

# Export functions
export -f find_js_gau
export -f find_js_waybackurls
export -f find_js_katana
export -f find_js_robots
export -f extract_endpoints_linkfinder
export -f extract_secrets_secretfinder
export -f run_gf_patterns
export -f grep_manual_secrets
export -f run_js_analysis
