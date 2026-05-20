#!/bin/bash
# ALLRECON - Basic Reporting Module
# Generate summary reports of scan results

MODULE_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$MODULE_ROOT_DIR/lib/colors.sh"
source "$MODULE_ROOT_DIR/lib/logger.sh"
source "$MODULE_ROOT_DIR/lib/utils.sh"

# Generate basic text report
generate_text_report() {
    local domain="$1"
    local output_file="$2"
    local scan_duration="$3"
    local output_root="${4:-$domain}"
    
    log_info "Generating report for: $domain"
    
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  ALLRECON - Reconnaissance Report"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Target: $domain"
        echo "Scan Date: $(date)"
        echo "Duration: $(format_duration $scan_duration)"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Subdomain Enumeration Results"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        if [[ -f "$output_root/domain_enum/all.txt" ]]; then
            echo "Total Subdomains Found: $(count_lines "$output_root/domain_enum/all.txt")"
        fi
        
        if [[ -f "$output_root/final_domains/domains.txt" ]]; then
            echo "Live Subdomains: $(count_lines "$output_root/final_domains/domains.txt")"
        fi
        
        if [[ -f "$output_root/final_domains/httpx.txt" ]]; then
            echo "HTTP/HTTPS Services: $(count_lines "$output_root/final_domains/httpx.txt")"
        fi
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  JavaScript Analysis Results"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        if [[ -f "$output_root/js/all_js.txt" ]]; then
            echo "JavaScript Files: $(count_lines "$output_root/js/all_js.txt")"
        fi
        
        if [[ -f "$output_root/js/endpoints.txt" ]]; then
            echo "Endpoints Found: $(count_lines "$output_root/js/endpoints.txt")"
        fi
        
        if [[ -f "$output_root/js/secrets.txt" ]]; then
            echo "Potential Secrets: $(count_lines "$output_root/js/secrets.txt")"
        fi
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  URL Collection Results"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        if [[ -f "$output_root/waybackurls/wayback.txt" ]]; then
            echo "Total URLs: $(count_lines "$output_root/waybackurls/wayback.txt")"
        fi
        
        if [[ -f "$output_root/waybackurls/valid.txt" ]]; then
            echo "Valid URLs: $(count_lines "$output_root/waybackurls/valid.txt")"
        fi
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Vulnerability Scan Results"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        if [[ -f "$output_root/nuclei_scan/cves.txt" ]]; then
            echo "CVEs: $(count_lines "$output_root/nuclei_scan/cves.txt")"
        fi
        
        if [[ -f "$output_root/nuclei_scan/vulnerabilities.txt" ]]; then
            echo "Vulnerabilities: $(count_lines "$output_root/nuclei_scan/vulnerabilities.txt")"
        fi
        
        if [[ -f "$output_root/nuclei_scan/misconfiguration.txt" ]]; then
            echo "Misconfigurations: $(count_lines "$output_root/nuclei_scan/misconfiguration.txt")"
        fi
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  File Locations"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "All results saved in: $output_root/"
        echo ""
        
    } > "$output_file"
    
    log_info "Report generated: $output_file"
    
    # Also print to console
    cat "$output_file"
}

export -f generate_text_report
