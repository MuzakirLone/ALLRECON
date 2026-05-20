#!/bin/bash
# ALLRECON - Parallel Execution Manager
# Manage background jobs and parallel task execution

# Source dependencies
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/logger.sh"

# Configuration
MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-5}
PARALLEL_ENABLED=${PARALLEL_ENABLED:-true}

# Track running jobs
declare -A RUNNING_JOBS
declare -A JOB_START_TIMES
JOB_COUNTER=0

# Function to get current job count
get_job_count() {
    jobs -r | wc -l
}

# Function to wait for job slot
wait_for_slot() {
    while [[ $(get_job_count) -ge $MAX_PARALLEL_JOBS ]]; do
        sleep 0.5
    done
}

# Function to run command in background with job management
run_parallel_job() {
    local cmd="$1"
    local description="${2:-Job $JOB_COUNTER}"
    
    if [[ "$PARALLEL_ENABLED" != "true" ]]; then
        # Run synchronously if parallel is disabled
        log_info "Running (sync): $description"
        eval "$cmd"
        return $?
    fi
    
    # Wait for available slot
    wait_for_slot
    
    # Start job
    JOB_COUNTER=$((JOB_COUNTER + 1))
    local job_id=$JOB_COUNTER
    
    log_debug "Starting parallel job $job_id: $description"
    
    # Run in background
    (
        eval "$cmd"
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            log_debug "Job $job_id completed successfully: $description"
        else
            log_warn "Job $job_id failed with exit code $exit_code: $description"
        fi
        exit $exit_code
    ) &
    
    local pid=$!
    RUNNING_JOBS[$job_id]=$pid
    JOB_START_TIMES[$job_id]=$(date +%s)
    
    log_info "Started job $job_id (PID: $pid): $description"
}

# Function to wait for all parallel jobs to complete
wait_for_all_jobs() {
    local timeout=${1:-600}  # Default 10 minutes
    local start_time=$(date +%s)
    
    log_info "Waiting for all parallel jobs to complete (timeout: ${timeout}s)..."
    
    local total_jobs=${#RUNNING_JOBS[@]}
    local completed=0
    
    while [[ $(get_job_count) -gt 0 ]]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        # Check timeout
        if [[ $elapsed -gt $timeout ]]; then
            log_error "Timeout waiting for jobs after ${timeout}s"
            kill_all_jobs
            return 1
        fi
        
        # Update progress
        local current_running=$(get_job_count)
        completed=$((total_jobs - current_running))
        
        if [[ $total_jobs -gt 0 ]]; then
            echo -ne "\r${BLUE}[i]${NC} Progress: $completed/$total_jobs jobs completed ($current_running running)...  "
        fi
        
        sleep 1
    done
    
    echo ""
    log_info "All parallel jobs completed"
    
    # Reset
    RUNNING_JOBS=()
    JOB_START_TIMES=()
    
    return 0
}

# Function to kill all running jobs
kill_all_jobs() {
    log_warn "Killing all running jobs..."
    
    for job_id in "${!RUNNING_JOBS[@]}"; do
        local pid=${RUNNING_JOBS[$job_id]}
        if ps -p $pid > /dev/null 2>&1; then
            kill -9 $pid 2>/dev/null
            log_debug "Killed job $job_id (PID: $pid)"
        fi
    done
    
    RUNNING_JOBS=()
    JOB_START_TIMES=()
}

# Function to run multiple commands in parallel
run_parallel() {
    local commands=("$@")
    
    log_info "Running ${#commands[@]} commands in parallel (max jobs: $MAX_PARALLEL_JOBS)"
    
    local job_num=1
    for cmd in "${commands[@]}"; do
        run_parallel_job "$cmd" "Parallel job $job_num"
        job_num=$((job_num + 1))
    done
    
    wait_for_all_jobs
}

# Function to run commands on each line of a file in parallel
run_parallel_on_file() {
    local file="$1"
    local command_template="$2"  # Use {} as placeholder
    local max_jobs="${3:-$MAX_PARALLEL_JOBS}"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    log_info "Processing file in parallel: $file"
    
    local line_num=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        line_num=$((line_num + 1))
        local cmd=$(echo "$command_template" | sed "s|{}|$line|g")
        
        run_parallel_job "$cmd" "Line $line_num: $line"
    done < "$file"
    
    wait_for_all_jobs
}

# Function to run tool in parallel across multiple inputs
parallel_tool() {
    local tool="$1"
    shift
    local inputs=("$@")
    
    for input in "${inputs[@]}"; do
        run_parallel_job "$tool $input" "$tool on $input"
    done
    
    wait_for_all_jobs
}

# Function to set max parallel jobs
set_max_parallel_jobs() {
    local count="$1"
    
    if [[ $count -gt 0 ]]; then
        MAX_PARALLEL_JOBS=$count
        log_info "Max parallel jobs set to: $MAX_PARALLEL_JOBS"
    else
        log_error "Invalid job count: $count"
        return 1
    fi
}

# Function to enable/disable parallel execution
set_parallel_mode() {
    local mode="$1"
    
    case "${mode,,}" in
        true|enable|on|1)
            PARALLEL_ENABLED=true
            log_info "Parallel execution enabled"
            ;;
        false|disable|off|0)
            PARALLEL_ENABLED=false
            log_info "Parallel execution disabled"
            ;;
        *)
            log_error "Invalid parallel mode: $mode"
            return 1
            ;;
    esac
}

# Function to get job statistics
get_job_stats() {
    local current_jobs=$(get_job_count)
    local total_started=$JOB_COUNTER
    
    echo "Current running: $current_jobs"
    echo "Total started: $total_started"
    echo "Max parallel: $MAX_PARALLEL_JOBS"
    echo "Parallel mode: $PARALLEL_ENABLED"
}

# Cleanup on exit
cleanup_parallel() {
    if [[ $(get_job_count) -gt 0 ]]; then
        log_warn "Cleaning up background jobs..."
        kill_all_jobs
    fi
}

# Set trap for cleanup
trap cleanup_parallel EXIT INT TERM

# Export functions
export -f get_job_count
export -f wait_for_slot
export -f run_parallel_job
export -f wait_for_all_jobs
export -f kill_all_jobs
export -f run_parallel
export -f run_parallel_on_file
export -f parallel_tool
export -f set_max_parallel_jobs
export -f set_parallel_mode
export -f get_job_stats
export -f cleanup_parallel
