#!/bin/bash
# ALLRECON - Input Validators
# Validation functions for domains, URLs, IPs, and file paths

# Source dependencies
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/logger.sh"

# Domain validation
is_valid_domain() {
    local domain="$1"
    
    # Basic regex for domain validation
    local domain_regex='^([a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
    
    if [[ "$domain" =~ $domain_regex ]]; then
        return 0
    else
        return 1
    fi
}

# Domain DNS check
domain_resolves() {
    local domain="$1"
    
    if host "$domain" &>/dev/null || nslookup "$domain" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Validate and sanitize domain
validate_domain() {
    local domain="$1"
    
    # Remove protocol if present
    domain=$(echo "$domain" | sed 's|^https\?://||' | sed 's|/.*$||')
    
    # Remove port if present
    domain=$(echo "$domain" | sed 's|:[0-9]*$||')
    
    # Convert to lowercase
    domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]')
    
    # Validate format
    if is_valid_domain "$domain"; then
        echo "$domain"
        return 0
    else
        log_error "Invalid domain format: $domain"
        return 1
    fi
}

# IP address validation
is_valid_ip() {
    local ip="$1"
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ "$ip" =~ $ip_regex ]]; then
        # Check each octet is <= 255
        IFS='.' read -ra OCTETS <<< "$ip"
        for octet in "${OCTETS[@]}"; do
            if [[ $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# URL validation
is_valid_http_url() {
    local url="$1"
    local url_regex='^https?://[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*'
    
    if [[ "$url" =~ $url_regex ]]; then
        return 0
    else
        return 1
    fi
}

# File path validation
is_valid_path() {
    local path="$1"
    
    # Check if path exists
    if [[ -e "$path" ]]; then
        return 0
    else
        # Check if directory of path exists (for files not yet created)
        local dir=$(dirname "$path")
        if [[ -d "$dir" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# Check if file is readable
is_readable_file() {
    local file="$1"
    [[ -f "$file" && -r "$file" ]]
}

# Check if file is writable
is_writable_file() {
    local file="$1"
    
    if [[ -f "$file" ]]; then
        [[ -w "$file" ]]
    else
        # Check if directory is writable
        local dir=$(dirname "$file")
        [[ -d "$dir" && -w "$dir" ]]
    fi
}

# Validate port number
is_valid_port() {
    local port="$1"
    
    if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
        return 0
    else
        return 1
    fi
}

# Email validation
is_valid_email() {
    local email="$1"
    local email_regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    
    if [[ "$email" =~ $email_regex ]]; then
        return 0
    else
        return 1
    fi
}

# Scope checking
is_in_scope() {
    local target="$1"
    local scope_file="${2:-inscope.txt}"
    
    if [[ ! -f "$scope_file" ]]; then
        # No scope file means everything is in scope
        return 0
    fi
    
    # Check if target matches any line in scope file
    while IFS= read -r scope_item; do
        [[ -z "$scope_item" ]] && continue
        
        # Support wildcards
        if [[ "$target" == $scope_item ]] || [[ "$target" =~ $scope_item ]]; then
            return 0
        fi
    done < "$scope_file"
    
    return 1
}

is_out_of_scope() {
    local target="$1"
    local exclude_file="${2:-exclude.txt}"
    
    if [[ ! -f "$exclude_file" ]]; then
        # No exclude file means nothing is excluded
        return 1
    fi
    
    # Check if target matches any line in exclude file
    while IFS= read -r exclude_item; do
        [[ -z "$exclude_item" ]] && continue
        
        if [[ "$target" == $exclude_item ]] || [[ "$target" =~ $exclude_item ]]; then
            return 0
        fi
    done < "$exclude_file"
    
    return 1
}

# Validate wordlist file
is_valid_wordlist() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "Wordlist not found: $file"
        return 1
    fi
    
    if [[ ! -s "$file" ]]; then
        log_error "Wordlist is empty: $file"
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        log_error "Wordlist is not readable: $file"
        return 1
    fi
    
    return 0
}

# Sanitize filename
sanitize_filename() {
    local filename="$1"
    
    # Remove dangerous characters
    filename=$(echo "$filename" | tr -d '[:cntrl:]' | tr '/' '_' | tr ' ' '_')
    
    # Remove leading dots
    filename=$(echo "$filename" | sed 's/^\.*//')
    
    echo "$filename"
}

# Validate tool output file
validate_output_file() {
    local file="$1"
    local tool_name="${2:-unknown}"
    
    if [[ ! -f "$file" ]]; then
        log_warn "$tool_name output file not found: $file"
        return 1
    fi
    
    if [[ ! -s "$file" ]]; then
        log_warn "$tool_name output file is empty: $file"
        return 1
    fi
    
    log_debug "$tool_name output validated: $file ($(wc -l < "$file") lines)"
    return 0
}

# Validate JSON format
is_valid_json() {
    local json_file="$1"
    
    if [[ ! -f "$json_file" ]]; then
        return 1
    fi
    
    if command -v jq &>/dev/null; then
        jq empty "$json_file" &>/dev/null
        return $?
    else
        # Basic check without jq
        [[ -s "$json_file" ]]
    fi
}

# Export functions
export -f is_valid_domain
export -f domain_resolves
export -f validate_domain
export -f is_valid_ip
export -f is_valid_http_url
export -f is_valid_path
export -f is_readable_file
export -f is_writable_file
export -f is_valid_port
export -f is_valid_email
export -f is_in_scope
export -f is_out_of_scope
export -f is_valid_wordlist
export -f sanitize_filename
export -f validate_output_file
export -f is_valid_json
