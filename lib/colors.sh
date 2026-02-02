#!/bin/bash
# ALLRECON - Color Definitions and Formatting
# Centralized color management for consistent terminal output

# Color Codes
export NC='\033[0m'
export RED='\033[1;38;5;196m'
export GREEN='\033[1;38;5;040m'
export ORANGE='\033[1;38;5;202m'
export BLUE='\033[1;38;5;012m'
export BLUE2='\033[1;38;5;032m'
export PINK='\033[1;38;5;013m'
export GRAY='\033[1;38;5;004m'
export NEW='\033[1;38;5;154m'
export YELLOW='\033[1;38;5;214m'
export CG='\033[1;38;5;087m'
export CP='\033[1;38;5;221m'
export CPO='\033[1;38;5;205m'
export CN='\033[1;38;5;247m'
export CNC='\033[1;38;5;051m'

# Additional Formatting
export BOLD='\033[1m'
export DIM='\033[2m'
export UNDERLINE='\033[4m'
export BLINK='\033[5m'
export REVERSE='\033[7m'
export HIDDEN='\033[8m'

# Background Colors
export BG_BLACK='\033[40m'
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'
export BG_MAGENTA='\033[45m'
export BG_CYAN='\033[46m'
export BG_WHITE='\033[47m'

# Global color enable/disable
COLOR_ENABLED=true

# Function to disable colors (for piping or non-TTY)
disable_colors() {
    COLOR_ENABLED=false
    NC=''
    RED=''
    GREEN=''
    ORANGE=''
    BLUE=''
    BLUE2=''
    PINK=''
    GRAY=''
    NEW=''
    YELLOW=''
    CG=''
    CP=''
    CPO=''
    CN=''
    CNC=''
    BOLD=''
    DIM=''
    UNDERLINE=''
    BLINK=''
    REVERSE=''
    HIDDEN=''
    BG_BLACK=''
    BG_RED=''
    BG_GREEN=''
    BG_YELLOW=''
    BG_BLUE=''
    BG_MAGENTA=''
    BG_CYAN=''
    BG_WHITE=''
}

# Function to enable colors
enable_colors() {
    COLOR_ENABLED=true
    # Re-source this file to restore colors
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
}

# Auto-detect if terminal supports colors
if [[ ! -t 1 ]] || [[ "${NO_COLOR:-}" != "" ]]; then
    disable_colors
fi

# Utility functions for colored output
print_red() { echo -e "${RED}$*${NC}"; }
print_green() { echo -e "${GREEN}$*${NC}"; }
print_yellow() { echo -e "${YELLOW}$*${NC}"; }
print_blue() { echo -e "${BLUE}$*${NC}"; }
print_orange() { echo -e "${ORANGE}$*${NC}"; }
print_pink() { echo -e "${PINK}$*${NC}"; }
print_cyan() { echo -e "${CNC}$*${NC}"; }
print_bold() { echo -e "${BOLD}$*${NC}"; }

# Status indicators
print_success() { echo -e "${GREEN}[✓]${NC} $*"; }
print_error() { echo -e "${RED}[✗]${NC} $*"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
print_info() { echo -e "${BLUE}[i]${NC} $*"; }
print_progress() { echo -e "${ORANGE}[+]${NC} $*"; }

# Export functions
export -f print_red
export -f print_green
export -f print_yellow
export -f print_blue
export -f print_orange
export -f print_pink
export -f print_cyan
export -f print_bold
export -f print_success
export -f print_error
export -f print_warning
export -f print_info
export -f print_progress
