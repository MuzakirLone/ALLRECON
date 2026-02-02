#!/bin/bash
# ALLRECON - URL Collection Module
# Collect and process URLs from various sources

MODULE_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$MODULE_ROOT_DIR/lib/colors.sh"
source "$MODULE_ROOT_DIR/lib/logger.sh"
source "$MODULE_ROOT_DIR/lib/utils.sh"
source "$MODULE_ROOT_DIR/lib/parallel.sh"

# Collect URLs with gau
collect_urls_gau() {
    local domains_file="$1"
    local output_file="$2"
    
    log_info "Collecting URLs with gau"
    echo -e "${CPO}\n[+] Collecting URLS with gau:${NC}"
    
    run_interruptible "cat '$domains_file' | gau | tee '$output_file'" "GAU URL collection"
}

# Filter and process URLs
filter_urls() {
    local input_file="$1"
    local output_file="$2"
    
    log_info "Filtering URLs"
    
    run_interruptible "cat '$input_file' | grep -E -v \"\\.woff|\\.ttf|\\.svg|\\.eot|\\.png|\\.jpeg|\\.css|\\.ico|\\.jpg\" | sed 's/:80//g;s/:443//g' | sort -u >> '$output_file'" "URL filtering"
}

# Validate URLs with FFUF
validate_urls_ffuf() {
    local input_file="$1"
    local output_file="$2"
    
    log_info "Validating URLs with FFUF"
    echo -e "${CNC}\n[+] FFUF Started On URLS:${NC}"
    
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
    
    log_info "Starting URL collection for: $domain"
    
    local wayback_dir="$domain/waybackurls"
    local wordlist_dir="$domain/target_wordlist"
    local gf_dir="$domain/gf"
    
    create_directory "$wayback_dir"
    create_directory "$wordlist_dir"
    create_directory "$gf_dir"
    
    # Collect URLs
    collect_urls_gau "$domains_file" "$wayback_dir/tmp.txt"
    
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
