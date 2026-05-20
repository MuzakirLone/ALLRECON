#!/bin/bash
# ALLRECON - Logging System
# Comprehensive logging with multiple levels and outputs

# Source colors
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/colors.sh"

# Log levels
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_WARN=2
export LOG_LEVEL_ERROR=3
export LOG_LEVEL_CRITICAL=4

# Default log configuration
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}
LOG_FILE=${LOG_FILE:-""}
LOG_TO_CONSOLE=${LOG_TO_CONSOLE:-true}
LOG_TO_FILE=${LOG_TO_FILE:-true}
LOG_JSON=${LOG_JSON:-false}
LOG_TIMESTAMP_FORMAT=${LOG_TIMESTAMP_FORMAT:-"%Y-%m-%d %H:%M:%S"}

# Function to get current timestamp
get_timestamp() {
    date +"$LOG_TIMESTAMP_FORMAT"
}

# Function to get log level name
get_level_name() {
    case $1 in
        $LOG_LEVEL_DEBUG) echo "DEBUG" ;;
        $LOG_LEVEL_INFO) echo "INFO" ;;
        $LOG_LEVEL_WARN) echo "WARN" ;;
        $LOG_LEVEL_ERROR) echo "ERROR" ;;
        $LOG_LEVEL_CRITICAL) echo "CRITICAL" ;;
        *) echo "UNKNOWN" ;;
    esac
}

# Function to get log level color
get_level_color() {
    case $1 in
        $LOG_LEVEL_DEBUG) echo "$GRAY" ;;
        $LOG_LEVEL_INFO) echo "$BLUE" ;;
        $LOG_LEVEL_WARN) echo "$YELLOW" ;;
        $LOG_LEVEL_ERROR) echo "$RED" ;;
        $LOG_LEVEL_CRITICAL) echo "$BG_RED$BOLD" ;;
        *) echo "$NC" ;;
    esac
}

# Core logging function
_log() {
    local level=$1
    shift
    local message="$*"
    
    # Check if we should log this level
    if [[ $level -lt $LOG_LEVEL ]]; then
        return 0
    fi
    
    local timestamp=$(get_timestamp)
    local level_name=$(get_level_name $level)
    local level_color=$(get_level_color $level)
    
    # Format message
    if [[ "$LOG_JSON" == "true" ]]; then
        local json_msg=$(cat <<EOF
{"timestamp":"$timestamp","level":"$level_name","message":"$message"}
EOF
)
        local formatted_msg="$json_msg"
    else
        local formatted_msg="[$timestamp] [$level_name] $message"
    fi
    
    # Console output
    if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        if [[ "$LOG_JSON" == "true" ]]; then
            echo "$formatted_msg"
        else
            echo -e "${level_color}[$timestamp]${NC} ${level_color}[$level_name]${NC} $message"
        fi
    fi
    
    # File output
    if [[ "$LOG_TO_FILE" == "true" ]] && [[ -n "$LOG_FILE" ]]; then
        # Ensure log directory exists
        local log_dir=$(dirname "$LOG_FILE")
        mkdir -p "$log_dir" 2>/dev/null
        
        # Strip color codes for file output
        local clean_msg=$(echo -e "$formatted_msg" | sed 's/\x1b\[[0-9;]*m//g')
        echo "$clean_msg" >> "$LOG_FILE"
    fi
}

# Public logging functions
log_debug() {
    _log $LOG_LEVEL_DEBUG "$@"
}

log_info() {
    _log $LOG_LEVEL_INFO "$@"
}

log_warn() {
    _log $LOG_LEVEL_WARN "$@"
}

log_error() {
    _log $LOG_LEVEL_ERROR "$@"
}

log_critical() {
    _log $LOG_LEVEL_CRITICAL "$@"
}

# Function to initialize logging
init_logging() {
    local log_file="$1"
    local log_level="${2:-INFO}"
    
    # Set log file
    LOG_FILE="$log_file"
    
    # Set log level
    case "${log_level^^}" in
        DEBUG) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        INFO) LOG_LEVEL=$LOG_LEVEL_INFO ;;
        WARN) LOG_LEVEL=$LOG_LEVEL_WARN ;;
        ERROR) LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        CRITICAL) LOG_LEVEL=$LOG_LEVEL_CRITICAL ;;
        *) LOG_LEVEL=$LOG_LEVEL_INFO ;;
    esac
    
    # Create log file if it doesn't exist
    if [[ -n "$LOG_FILE" ]]; then
        local log_dir=$(dirname "$LOG_FILE")
        mkdir -p "$log_dir" 2>/dev/null
        touch "$LOG_FILE" 2>/dev/null
    fi
    
    log_info "Logging initialized - Level: $(get_level_name $LOG_LEVEL), File: ${LOG_FILE:-none}"
}

# Function to rotate logs
rotate_log() {
    if [[ -z "$LOG_FILE" ]] || [[ ! -f "$LOG_FILE" ]]; then
        return 0
    fi
    
    local max_size=${1:-10485760}  # 10MB default
    local file_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
    
    if [[ $file_size -gt $max_size ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local rotated_file="${LOG_FILE}.${timestamp}"
        mv "$LOG_FILE" "$rotated_file"
        log_info "Log rotated to $rotated_file"
        gzip "$rotated_file" &
    fi
}

# Function to set log level dynamically
set_log_level() {
    local level="${1^^}"
    case "$level" in
        DEBUG) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        INFO) LOG_LEVEL=$LOG_LEVEL_INFO ;;
        WARN) LOG_LEVEL=$LOG_LEVEL_WARN ;;
        ERROR) LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        CRITICAL) LOG_LEVEL=$LOG_LEVEL_CRITICAL ;;
        *) log_error "Invalid log level: $1" ; return 1 ;;
    esac
    log_info "Log level changed to $(get_level_name $LOG_LEVEL)"
}

# Export functions
export -f _log
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_critical
export -f init_logging
export -f rotate_log
export -f set_log_level
export -f get_timestamp
export -f get_level_name
export -f get_level_color
