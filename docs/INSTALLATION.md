# ALLRECON - Installation Guide

## System Requirements

- **OS**: Linux, macOS, or WSL2 (Windows Subsystem for Linux)
- **Bash**: Version 4.0 or higher
- **Go**: Version 1.19 or higher (for Go-based tools)
- **Python**: Version 3.6 or higher (for Python tools)
- **Disk Space**: ~5GB (for all tools and dependencies)
- **RAM**: Minimum 4GB recommended

## Installation Steps

### 1. Install System Dependencies

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y curl jq git wget build-essential
```

#### CentOS/RHEL
```bash
sudo yum install -y curl jq git wget gcc
```

#### macOS
```bash
brew install curl jq git wget
```

### 2. Install Go

If Go is not installed:

```bash
# Download and install Go
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz

# Add to PATH
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
source ~/.bashrc

# Verify installation
go version
```

### 3. Install Python and pip

```bash
# Ubuntu/Debian
sudo apt install -y python3 python3-pip

# Verify
python3 --version
pip3 --version
```

### 4. Download ALLRECON

```bash
# Navigate to your tools directory
cd ~/tools

# Option 1: If you have git repository
git clone https://github.com/yourusername/ALLRECON.git

# Option 2: If downloaded as ZIP
# Extract the ALLRECON directory

cd ALLRECON
chmod +x allrecon.sh install.sh
```

### 5. Check Dependencies

```bash
./install.sh --check
```

This will show you which tools are installed and which are missing.

### 6. Install Required Tools

#### Install Go-based Tools

```bash
# Essential recon tools
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/tomnomnom/assetfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# URL collection
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/projectdiscovery/katana/cmd/katana@latest

# Utilities
go install github.com/tomnomnom/anew@latest
go install github.com/tomnomnom/qsreplace@latest
go install github.com/tomnomnom/unfurl@latest
go install github.com/tomnomnom/gf@latest

# Vulnerability scanners
go install github.com/ffuf/ffuf/v2@latest
go install github.com/hahwul/dalfox/v2@latest
go install github.com/Emoe/kxss@latest
```

#### Install Optional Tools

```bash
# DNS tools
go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest

# Subdomain takeover
go install -v github.com/LukaSikic/subzy@latest
go install github.com/haccer/subjack@latest
```

#### Install Python Tools

```bash
# SQLMap
sudo apt install sqlmap -y
# OR
pip3 install sqlmap

# Create tools directory
mkdir -p ~/tools

# LinkFinder
cd ~/tools
git clone https://github.com/GerbenJavado/LinkFinder.git
cd LinkFinder
pip3 install -r requirements.txt

# SecretFinder
cd ~/tools
git clone https://github.com/m4ll0k/SecretFinder.git
cd SecretFinder
pip3 install -r requirements.txt

# Corsy
cd ~/tools
git clone https://github.com/s0md3v/Corsy.git
cd Corsy
pip3 install -r requirements.txt

# OpenRedireX
cd ~/tools
git clone https://github.com/devanshbatham/OpenRedireX.git
cd OpenRedireX
pip3 install -r requirements.txt
```

### 7. Install GF Patterns

```bash
# Install gf
go install github.com/tomnomnom/gf@latest

# Setup gf patterns
mkdir -p ~/.gf
cd ~/.gf

# Clone gf-patterns repository
git clone https://github.com/1ndianl33t/Gf-Patterns.git
cp Gf-Patterns/*.json .
```

### 8. Setup Resolvers (for DNS resolution)

```bash
# Create resolvers directory
mkdir -p ~/tools/resolvers

# Download resolvers listcd ~/tools/resolvers
wget https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt -O resolver.txt
```

### 9. Download Wordlists

```bash
# SecLists (Essential wordlists)
cd /usr/share
sudo git clone https://github.com/danielmiessler/SecLists.git seclists

# OR for user installation
cd ~/tools
git clone https://github.com/danielmiessler/SecLists.git
```

### 10. Update Nuclei Templates

```bash
# Nuclei will auto-download templates on first run, or manually:
nuclei -update-templates
```

### 11. Verify Installation

```bash
cd /path/to/ALLRECON
./install.sh --check
```

All required tools should show green checkmarks ✓

## Post-Installation Configuration

### 1. Update Configuration

Edit `config/default.yaml` to update paths:

```yaml
wordlists:
  subdomain_bruteforce: "/usr/share/seclists/Discovery/DNS/deepmagic.com-prefixes-top50000.txt"
  resolvers: "~/tools/resolvers/resolver.txt"
```

### 2. Test Run

```bash
./allrecon.sh --help
```

## Troubleshooting

### Go tools not found in PATH

```bash
# Add Go bin to PATH
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
source ~/.bashrc
```

### Python tools not found

```bash
# Ensure tools are in the correct location
ls ~/tools/LinkFinder/linkfinder.py
ls ~/tools/SecretFinder/SecretFinder.py
```

### Permission denied errors

```bash
chmod +x allrecon.sh install.sh
chmod +x ~/go/bin/*
```

### Nuclei templates not found

```bash
mkdir -p ~/tools/nuclei-templates
nuclei -update-templates
```

## Updating ALLRECON

```bash
cd /path/to/ALLRECON

# If using git
git pull origin main

# Update tools
./install.sh --check
go install -v <tool>@latest  # For each outdated tool

# Update nuclei templates
nuclei -update-templates
```

## Minimal Installation (Quick Start)

For a quickly working setup with core tools only:

```bash
# Install only essential tools
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/lc/gau/v2/cmd/gau@latest

# Run with quick profile
./allrecon.sh --profile quick
```

## Support

If you encounter issues:
1. Check `logs/allrecon.log` for detailed error messages
2. Run with `--log-level DEBUG` for verbose output
3. Ensure all paths in `config/default.yaml` are correct
4. Verify tool versions are compatible

---

**Next Steps**: See [USAGE.md](USAGE.md) for usage examples and workflows.
