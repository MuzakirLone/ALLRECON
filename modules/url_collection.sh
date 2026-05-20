#!/bin/bash
# ALLRECON - URL Collection Module
# Collect and process URLs from various sources

MODULE_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$MODULE_ROOT_DIR/lib/colors.sh"
source "$MODULE_ROOT_DIR/lib/logger.sh"
source "$MODULE_ROOT_DIR/lib/utils.sh"
source "$MODULE_ROOT_DIR/lib/parallel.sh"

tool_enabled_or_default() {
    local tool="$1"
    if declare -F is_tool_enabled >/dev/null 2>&1; then
        is_tool_enabled "$tool"
        return $?
    fi
    return 0
}

# Collect URLs with gau
collect_urls_gau() {
    local domains_file="$1"
    local output_file="$2"
    
    : > "$output_file"
    
    if [[ ! -f "$domains_file" ]]; then
        log_warn "Domain input file not found: $domains_file"
        return 1
    fi
    
    if ! tool_enabled_or_default "gau"; then
        log_info "Skipping gau URL collection because it is disabled by the active profile"
        return 0
    fi
    
    log_info "Collecting URLs with gau"
    echo -e "${CPO}\n[+] Collecting URLS with gau:${NC}"
    
    run_interruptible "cat '$domains_file' | gau | tee '$output_file'" "GAU URL collection"
}

# Filter and process URLs
filter_urls() {
    local input_file="$1"
    local output_file="$2"
    
    log_info "Filtering URLs"
    : > "$output_file"
    
    run_interruptible "cat '$input_file' | grep -E -v \"\\.woff|\\.ttf|\\.svg|\\.eot|\\.png|\\.jpeg|\\.css|\\.ico|\\.jpg\" | sed 's/:80//g;s/:443//g' | sort -u > '$output_file'" "URL filtering"
}

# Validate URLs with FFUF
validate_urls_ffuf() {
    local input_file="$1"
    local output_file="$2"
    
    log_info "Validating URLs with FFUF"
    echo -e "${CNC}\n[+] FFUF Started On URLS:${NC}"
    : > "$output_file"
    
    if ! tool_enabled_or_default "ffuf"; then
        log_info "Skipping FFUF URL validation because it is disabled by the active profile"
        return 0
    fi
    
    local temp_file="$output_file.tmp"
    run_interruptible "ffuf -c -u \"FUZZ\" -w '$input_file' -of csv -o '$temp_file'" "FFUF validation"
    
    if [[ -f "$temp_file" ]]; then
        cat "$temp_file" | grep http | awk -F "," '{print $1}' >> "$output_file"
        rm "$temp_file" 2>/dev/null
    fi
}

# Generate target-based wordlists
generate_wordlists() {
    local wayback_file="$1"
    local output_dir="$2"
    
    log_info "Generating target-based wordlists"
    echo -e "${PINK}\n[+] Generating Target Based Wordlist:${NC}"
    
    if [[ -f "$wayback_file" ]]; then
        if ! tool_enabled_or_default "unfurl"; then
            log_info "Skipping wordlist generation because unfurl is disabled by the active profile"
            : > "$output_dir/paths.txt"
            : > "$output_dir/param.txt"
            return 0
        fi
        
        cat "$wayback_file" | unfurl -unique paths > "$output_dir/paths.txt"
        cat "$wayback_file" | unfurl -unique keys > "$output_dir/param.txt"
    fi
}

# Run GF patterns
run_gf_patterns_urls() {
    local valid_urls_file="$1"
    local output_dir="$2"
    
    log_info "Running GF patterns on URLs"
    echo -e "${BLUE}\n[+] Gf Patterns Started on Valid URLS:${NC}"
    
    if [[ ! -f "$valid_urls_file" ]]; then
        log_warn "Valid URLs file not found: $valid_urls_file"
        return 1
    fi
    
    if ! tool_enabled_or_default "gf"; then
        log_info "Skipping URL GF patterns because gf is disabled by the active profile"
        return 0
    fi
    
    gf xss "$valid_urls_file" | tee "$output_dir/xss.txt"
    gf ssrf "$valid_urls_file" | tee "$output_dir/ssrf.txt"
    gf sqli "$valid_urls_file" | tee "$output_dir/sql.txt"
    gf lfi "$valid_urls_file" | tee "$output_dir/lfi.txt"
    gf ssti "$valid_urls_file" | tee "$output_dir/ssti.txt"
    gf aws-keys "$valid_urls_file" | tee "$output_dir/awskeys.txt"
    gf redirect "$valid_urls_file" | tee "$output_dir/redirect.txt"
    cat "$output_dir/redirect.txt" | sed 's/\=.*/=/' | tee "$output_dir/purered.txt"
    gf idor "$valid_urls_file" | tee "$output_dir/idor.txt"
}

# Complete URL collection workflow
run_url_collection() {
    local domain="$1"
    local domains_file="$2"
    local output_root="${3:-$domain}"
    
    log_info "Starting URL collection for: $domain"
    
    local wayback_dir="$output_root/waybackurls"
    local wordlist_dir="$output_root/target_wordlist"
    local gf_dir="$output_root/gf"
    local targets_file="$wayback_dir/targets.txt"
    
    create_directory "$wayback_dir"
    create_directory "$wordlist_dir"
    create_directory "$gf_dir"
    
    : > "$targets_file"
    if [[ -f "$domains_file" && -s "$domains_file" ]]; then
        cat "$domains_file"
    else
        echo "$domain"
    fi | sed 's|^https\?://||;s|/.*$||;s|:[0-9]\+$||' | sed '/^[[:space:]]*$/d' | sort -u > "$targets_file"
    
    # Collect URLs
    collect_urls_gau "$targets_file" "$wayback_dir/tmp.txt"
    
    # Filter URLs
    if [[ -f "$wayback_dir/tmp.txt" ]]; then
        filter_urls "$wayback_dir/tmp.txt" "$wayback_dir/wayback.txt"
        safe_delete_file "$wayback_dir/tmp.txt"
    fi
    
    # Validate URLs
    if [[ -f "$wayback_dir/wayback.txt" ]]; then
        validate_urls_ffuf "$wayback_dir/wayback.txt" "$wayback_dir/valid.txt"
    fi
    
    # Generate wordlists
    generate_wordlists "$wayback_dir/wayback.txt" "$wordlist_dir"
    
    # Run GF patterns
    if [[ -f "$wayback_dir/valid.txt" ]]; then
        run_gf_patterns_urls "$wayback_dir/valid.txt" "$gf_dir"
    fi
    
    log_info "URL collection completed"
}

export -f collect_urls_gau
export -f filter_urls
export -f validate_urls_ffuf
export -f generate_wordlists
export -f run_gf_patterns_urls
export -f run_url_collection
