#!/bin/bash
# ALLRECON - Vulnerability Scanning Module
# Comprehensive vulnerability detection

MODULE_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$MODULE_ROOT_DIR/lib/colors.sh"
source "$MODULE_ROOT_DIR/lib/logger.sh"
source "$MODULE_ROOT_DIR/lib/utils.sh"
source "$MODULE_ROOT_DIR/lib/parallel.sh"

# CORS misconfiguration scan
scan_cors() {
    local httpx_file="$1"
    local output_file="$2"
    
    log_info "Scanning for CORS misconfigurations"
    echo -e "${GREEN}\n[+] Searching For Cors Misconfiguration:${NC}"
    
    local corsy_path="~/tools/Corsy/corsy.py"
    corsy_path="${corsy_path/#\~/$HOME}"
    
    if [[ -f "$corsy_path" ]]; then
        run_interruptible "python3 '$corsy_path' -i '$httpx_file' -t 15 | tee '$output_file'" "Corsy Scan"
    else
        log_warn "Corsy not found, skipping CORS scan"
    fi
}

# Nuclei vulnerability scanning
scan_nuclei() {
    local httpx_file="$1"
    local output_dir="$2"
    local prefix="${3:-}"
    
    log_info "Running Nuclei scanner"
    echo -e "${CP}\n[+] Nuclei Scanner Started:${NC}"
    
    local templates_path="~/tools/nuclei-templates"
    templates_path="${templates_path/#\~/$HOME}"
    
    if [[ ! -d "$templates_path" ]]; then
        log_warn "Nuclei templates not found at: $templates_path"
        return 1
    fi
    
    run_interruptible "cat '$httpx_file' | nuclei -t '${templates_path}/${prefix}cves/' -c 50 -o '$output_dir/cves.txt'" "CVE scanning"
    run_interruptible "cat '$httpx_file' | nuclei -t '${templates_path}/${prefix}vulnerabilities/' -c 50 -o '$output_dir/vulnerabilities.txt'" "Vulnerability scanning"
    run_interruptible "cat '$httpx_file' | nuclei -t '${templates_path}/${prefix}misconfiguration/' -c 50 -o '$output_dir/misconfiguration.txt'" "Misconfiguration scanning"
    run_interruptible "cat '$httpx_file' | nuclei -t '${templates_path}/${prefix}technologies/' -c 50 -o '$output_dir/tech.txt'" "Technology detection"
}

# XSS vulnerability scanning
scan_xss() {
    local gf_xss_file="$1"
    local output_dir="$2"
    
    log_info "Scanning for XSS vulnerabilities"
    echo -e "${GREEN}\n[+] Searching For XSS${NC}"
    
    run_interruptible "cat '$gf_xss_file' | kxss | tee '$output_dir/kxss.txt'" "kxss scanning"
    
    if [[ -s "$output_dir/kxss.txt" ]]; then
        run_interruptible "cat '$output_dir/kxss.txt' | awk -F',' '{print \$1}' | sed 's/^URL: //' | tee '$output_dir/kxss_urls.txt'" "Extracting URLs"
        run_interruptible "cat '$output_dir/kxss_urls.txt' | qsreplace '\"><svg onload=alert(1)>' | tee '$output_dir/kxss_payloads.txt' | dalfox pipe | tee '$output_dir/dalfoxss.txt'" "dalfox scanning"
    fi
}

# SQL injection scanning
scan_sqli() {
    local gf_sqli_file="$1"
    local output_file="$2"
    
    log_info "Scanning for SQL injection"
    echo -e "${CG}\n[+] Searching For SQL Injection${NC}"
    
    run_interruptible "sqlmap -m '$gf_sqli_file' --batch --random-agent --level 1 | tee '$output_file'" "SQLMap scan"
}

# LFI vulnerability scanning
scan_lfi() {
    local gf_lfi_file="$1"
    local output_file="$2"
    
    log_info "Scanning for LFI vulnerabilities"
    echo -e "${BLUE}\n[+] Searching For LFI VULN${NC}"
    
    local lfi_payloads="~/tools/lfipayloads.txt"
    lfi_payloads="${lfi_payloads/#\~/$HOME}"
    
    if [[ -f "$lfi_payloads" ]]; then
        run_interruptible "cat '$gf_lfi_file' | qsreplace FUZZ | while read url ; do ffuf -u \$url -mr \"root:x\" -w '$lfi_payloads' -of csv -o '$output_file' -t 50 -c ; done" "LFI scanning"
    else
        log_warn "LFI payloads not found, skipping"
    fi
}

# Open redirect scanning
scan_open_redirect() {
    local gf_redirect_file="$1"
    local output_dir="$2"
    
    log_info "Scanning for open redirection"
    echo -e "${ORANGE}\n[+] Searching For Open Redirection${NC}"
    
    run_interruptible "cat '$gf_redirect_file' | qsreplace FUZZ | tee '$output_dir/fuzzredirect.txt'" "Preparing URLs"
    
    local openredirex_path="~/tools/OpenRedireX/openredirex.py"
    openredirex_path="${openredirex_path/#\~/$HOME}"
    
    if [[ -f "$openredirex_path" && -f "$output_dir/fuzzredirect.txt" ]]; then
        run_interruptible "python3 '$openredirex_path' -l '$output_dir/fuzzredirect.txt' -p ~/tools/OpenRedireX/payloads.txt --keyword FUZZ | tee '$output_dir/confirmopenred.txt'" "OpenRedireX scan"
    else
        log_warn "OpenRedireX not found or no redirect URLs, skipping"
    fi
}

# Main vulnerability scanning workflow
run_vulnerability_scans() {
    local domain="$1"
    local httpx_file="$2"
    local nuclei_prefix="${3:-}"
    
    log_info "Starting vulnerability scans for: $domain"
    
    # CORS scan
    scan_cors "$httpx_file" "$domain/vulnerabilities/cors/cors_misconfig.txt"
    
    # Nuclei scan
    scan_nuclei "$httpx_file" "$domain/nuclei_scan" "$nuclei_prefix"
    
    # XSS scan
    if [[ -f "$domain/gf/xss.txt" ]]; then
        scan_xss "$domain/gf/xss.txt" "$domain/vulnerabilities/xss_scan"
    fi
    
    # SQLi scan
    if [[ -f "$domain/gf/sql.txt" ]]; then
        scan_sqli "$domain/gf/sql.txt" "$domain/vulnerabilities/sqli/sqlmap.txt"
    fi
    
    # LFI scan
    if [[ -f "$domain/gf/lfi.txt" ]]; then
        scan_lfi "$domain/gf/lfi.txt" "$domain/vulnerabilities/LFI/lfi.txt"
    fi
    
    # Open redirect scan
    if [[ -f "$domain/gf/redirect.txt" ]]; then
        scan_open_redirect "$domain/gf/redirect.txt" "$domain/vulnerabilities/openredirect"
    fi
    
    log_info "Vulnerability scans completed"
}

export -f scan_cors
export -f scan_nuclei
export -f scan_xss
export -f scan_sqli
export -f scan_lfi
export -f scan_open_redirect
export -f run_vulnerability_scans
