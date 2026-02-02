#!/bin/bash
# ALLRECON - Configuration Parser
# Parse YAML configuration files and environment variables

# Source dependencies
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/logger.sh"

# Global config storage
declare -A CONFIG

# Default configuration values
set_default_config() {
    CONFIG[scan_threads]=30
    CONFIG[scan_timeout]=300
    CONFIG[scan_parallel_enabled]=true
    CONFIG[scan_max_parallel_jobs]=5
    
    CONFIG[logging_level]="INFO"
    CONFIG[logging_file]="logs/allrecon.log"
    CONFIG[logging_console]=true
    
    CONFIG[output_timestamp_folders]=true
    CONFIG[output_generate_report]=true
    
    CONFIG[wordlist_subdomain_bruteforce]="/usr/share/seclists/Discovery/DNS/deepmagic.com-prefixes-top50000.txt"
    CONFIG[wordlist_resolvers]="~/tools/resolvers/resolver.txt"
    
    CONFIG[tools_enabled]="all"
}

# Simple YAML parser (handles basic key: value pairs)
parse_yaml_file() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        log_error "Config file not found: $yaml_file"
        return 1
    fi
    
    log_info "Loading configuration from: $yaml_file"
    
    local section=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Detect sections
        if [[ "$line" =~ ^([a-z_]+):$ ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi
        
        # Parse key-value pairs
        if [[ "$line" =~ ^[[:space:]]+([a-z_]+):[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove quotes
            value=$(echo "$value" | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
            
            # Store with section prefix
            if [[ -n "$section" ]]; then
                CONFIG[${section}_${key}]="$value"
            else
                CONFIG[$key]="$value"
            fi
        fi
    done < "$yaml_file"
    
    log_debug "Configuration loaded: ${#CONFIG[@]} settings"
    return 0
}

# Load configuration from file
load_config() {
    local config_file="${1:-config/default.yaml}"
    
    # Set defaults first
    set_default_config
    
    # Load from file if exists
    if [[ -f "$config_file" ]]; then
        parse_yaml_file "$config_file"
    else
        log_warn "Config file not found: $config_file, using defaults"
    fi
    
    # Override with environment variables
    load_env_overrides
    
    return 0
}

# Load environment variable overrides
load_env_overrides() {
    # Scan threads
    [[ -n "${ALLRECON_THREADS:-}" ]] && CONFIG[scan_threads]="$ALLRECON_THREADS"
    
    # Timeout
    [[ -n "${ALLRECON_TIMEOUT:-}" ]] && CONFIG[scan_timeout]="$ALLRECON_TIMEOUT"
    
    # Parallel settings
    [[ -n "${ALLRECON_PARALLEL:-}" ]] && CONFIG[scan_parallel_enabled]="$ALLRECON_PARALLEL"
    [[ -n "${ALLRECON_MAX_JOBS:-}" ]] && CONFIG[scan_max_parallel_jobs]="$ALLRECON_MAX_JOBS"
    
    # Logging
    [[ -n "${ALLRECON_LOG_LEVEL:-}" ]] && CONFIG[logging_level]="$ALLRECON_LOG_LEVEL"
    [[ -n "${ALLRECON_LOG_FILE:-}" ]] && CONFIG[logging_file]="$ALLRECON_LOG_FILE"
    
    # Wordlists
    [[ -n "${ALLRECON_WORDLIST_SUBDOMAINS:-}" ]] && CONFIG[wordlist_subdomain_bruteforce]="$ALLRECON_WORDLIST_SUBDOMAINS"
    [[ -n "${ALLRECON_RESOLVERS:-}" ]] && CONFIG[wordlist_resolvers]="$ALLRECON_RESOLVERS"
    
    log_debug "Environment overrides applied"
}

# Load profile configuration
load_profile() {
    local profile_name="$1"
    local profile_file="config/profiles/${profile_name}.yaml"
    
    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile not found: $profile_name"
        return 1
    fi
    
    log_info "Loading profile: $profile_name"
    parse_yaml_file "$profile_file"
    
    return 0
}

# Get configuration value
get_config() {
    local key="$1"
    local default="${2:-}"
    
    echo "${CONFIG[$key]:-$default}"
}

# Set configuration value
set_config() {
    local key="$1"
    local value="$2"
    
    CONFIG[$key]="$value"
    log_debug "Config set: $key = $value"
}

# Check if configuration key exists
has_config() {
    local key="$1"
    [[ -n "${CONFIG[$key]:-}" ]]
}

# Print all configuration
print_config() {
    echo -e "${BOLD}Current Configuration:${NC}"
    echo "===================="
    
    for key in "${!CONFIG[@]}"; do
        echo "$key = ${CONFIG[$key]}"
    done | sort
}

# Validate configuration
validate_config() {
    local errors=0
    
    # Validate threads
    local threads=$(get_config "scan_threads")
    if ! [[ "$threads" =~ ^[0-9]+$ ]] || [[ $threads -lt 1 ]] || [[ $threads -gt 100 ]]; then
        log_error "Invalid scan_threads value: $threads (must be 1-100)"
        errors=$((errors + 1))
    fi
    
    # Validate timeout
    local timeout=$(get_config "scan_timeout")
    if ! [[ "$timeout" =~ ^[0-9]+$ ]] || [[ $timeout -lt 1 ]]; then
        log_error "Invalid scan_timeout value: $timeout (must be positive integer)"
        errors=$((errors + 1))
    fi
    
    # Validate parallel jobs
    local max_jobs=$(get_config "scan_max_parallel_jobs")
    if ! [[ "$max_jobs" =~ ^[0-9]+$ ]] || [[ $max_jobs -lt 1 ]] || [[ $max_jobs -gt 50 ]]; then
        log_error "Invalid scan_max_parallel_jobs value: $max_jobs (must be 1-50)"
        errors=$((errors + 1))
    fi
    
    # Validate log level
    local log_level=$(get_config "logging_level")
    if ! [[ "$log_level" =~ ^(DEBUG|INFO|WARN|ERROR|CRITICAL)$ ]]; then
        log_error "Invalid logging_level value: $log_level"
        errors=$((errors + 1))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Configuration validation failed with $errors error(s)"
        return 1
    fi
    
    log_info "Configuration validated successfully"
    return 0
}

# Apply configuration to global variables
apply_config() {
    # Apply parallel settings
    MAX_PARALLEL_JOBS=$(get_config "scan_max_parallel_jobs" "5")
    PARALLEL_ENABLED=$(get_config "scan_parallel_enabled" "true")
    
    # Apply logging settings
    LOG_FILE=$(get_config "logging_file" "logs/allrecon.log")
    LOG_LEVEL_NAME=$(get_config "logging_level" "INFO")
    
    # Initialize logging with config
    init_logging "$LOG_FILE" "$LOG_LEVEL_NAME"
    
    log_info "Configuration applied to runtime"
}

# Save configuration to file
save_config() {
    local output_file="$1"
    
    log_info "Saving configuration to: $output_file"
    
    {
        echo "# ALLRECON Configuration"
        echo "# Generated on $(date)"
        echo ""
        
        echo "scan:"
        echo "  threads: $(get_config 'scan_threads')"
        echo "  timeout: $(get_config 'scan_timeout')"
        echo "  parallel_enabled: $(get_config 'scan_parallel_enabled')"
        echo "  max_parallel_jobs: $(get_config 'scan_max_parallel_jobs')"
        echo ""
        
        echo "logging:"
        echo "  level: $(get_config 'logging_level')"
        echo "  file: $(get_config 'logging_file')"
        echo "  console: $(get_config 'logging_console')"
        echo ""
        
        echo "output:"
        echo "  timestamp_folders: $(get_config 'output_timestamp_folders')"
        echo "  generate_report: $(get_config 'output_generate_report')"
        echo ""
        
        echo "wordlists:"
        echo "  subdomain_bruteforce: $(get_config 'wordlist_subdomain_bruteforce')"
        echo "  resolvers: $(get_config 'wordlist_resolvers')"
        
    } > "$output_file"
    
    log_info "Configuration saved"
}

# Export functions
export -f set_default_config
export -f parse_yaml_file
export -f load_config
export -f load_env_overrides
export -f load_profile
export -f get_config
export -f set_config
export -f has_config
export -f print_config
export -f validate_config
export -f apply_config
export -f save_config
