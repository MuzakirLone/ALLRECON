#!/bin/bash
# ALLRECON - Dependency Installer and Checker
# Checks for required tools and provides installation guidance

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Required tools
REQUIRED_TOOLS=(
    "subfinder:go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    "assetfinder:go install github.com/tomnomnom/assetfinder@latest"
    "httpx:go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
    "nuclei:go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    "gau:go install github.com/lc/gau/v2/cmd/gau@latest"
    "waybackurls:go install github.com/tomnomnom/waybackurls@latest"
    "katana:go install github.com/projectdiscovery/katana/cmd/katana@latest"
    "anew:go install github.com/tomnomnom/anew@latest"
    "qsreplace:go install github.com/tomnomnom/qsreplace@latest"
    "unfurl:go install github.com/tomnomnom/unfurl@latest"
    "ffuf:go install github.com/ffuf/ffuf/v2@latest"
    "dalfox:go install github.com/hahwul/dalfox/v2@latest"
    "kxss:go install github.com/Emoe/kxss@latest"
    "sqlmap:apt install sqlmap -y (or pip install sqlmap)"
    "jq:apt install jq -y"
    "curl:apt install curl -y"
    "gf:go install github.com/tomnomnom/gf@latest"
)

OPTIONAL_TOOLS=(
    "shuffledns:go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest"
    "subzy:go install -v github.com/LukaSikic/subzy@latest"
    "subjack:go install github.com/haccer/subjack@latest"
)

check_tool() {
    local tool=$1
    if command -v "$tool" &> /dev/null; then
        echo -e "${GREEN}[✓]${NC} $tool"
        return 0
    else
        echo -e "${RED}[✗]${NC} $tool"
        return 1
    fi
}

show_installation() {
    local tool_info=$1
    local tool=$(echo "$tool_info" | cut -d':' -f1)
    local install_cmd=$(echo "$tool_info" | cut -d':' -f2-)
    
    echo -e "${YELLOW}Installation command for $tool:${NC}"
    echo -e "  $install_cmd"
    echo ""
}

check_all_tools() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  ALLRECON - Dependency Checker${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${YELLOW}Required Tools:${NC}"
    local missing_required=0
    for tool_info in "${REQUIRED_TOOLS[@]}"; do
        local tool=$(echo "$tool_info" | cut -d':' -f1)
        if ! check_tool "$tool"; then
            ((missing_required++))
        fi
    done
    
    echo ""
    echo -e "${YELLOW}Optional Tools:${NC}"
    local missing_optional=0
    for tool_info in "${OPTIONAL_TOOLS[@]}"; do
        local tool=$(echo "$tool_info" | cut -d':' -f1)
        if ! check_tool "$tool"; then
            ((missing_optional++))
        fi
    done
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [[ $missing_required -eq 0 ]]; then
        echo -e "${GREEN}✓ All required tools are installed!${NC}"
    else
        echo -e "${RED}✗ $missing_required required tool(s) missing${NC}"
        echo ""
        echo -e "${YELLOW}To install missing tools, run:${NC}"
        echo -e "  $0 --install"
    fi
    
    if [[ $missing_optional -gt 0 ]]; then
        echo -e "${YELLOW}⚠ $missing_optional optional tool(s) missing (will skip if not found)${NC}"
    fi
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

show_install_commands() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Installation Commands${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${YELLOW}Required Tools:${NC}"
    echo ""
    for tool_info in "${REQUIRED_TOOLS[@]}"; do
        local tool=$(echo "$tool_info" | cut -d':' -f1)
        if ! command -v "$tool" &> /dev/null; then
            show_installation "$tool_info"
        fi
    done
    
    echo -e "${YELLOW}Optional Tools:${NC}"
    echo ""
    for tool_info in "${OPTIONAL_TOOLS[@]}"; do
        local tool=$(echo "$tool_info" | cut -d':' -f1)
        if ! command -v "$tool" &> /dev/null; then
            show_installation "$tool_info"
        fi
    done
}

show_help_install() {
    cat << EOF
ALLRECON Dependency Installer

Usage: $0 [OPTIONS]

Options:
  --check       Check which tools are installed
  --install     Show installation commands for missing tools
  --help        Show this help message

Examples:
  $0 --check               # Check installed tools
  $0 --install             # Show how to install missing tools

Note: This script checks for tools but does not auto-install them.
      You need to manually run the installation commands shown.
EOF
}

# Main
case "${1:-}" in
    --check)
        check_all_tools
        ;;
    --install)
        show_install_commands
        ;;
    --help)
        show_help_install
        ;;
    *)
        check_all_tools
        ;;
esac
