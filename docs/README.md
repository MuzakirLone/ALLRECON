# ALLRECON - Modern Bug Bounty Reconnaissance Framework

![Version](https://img.shields.io/badge/version-2.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Bash](https://img.shields.io/badge/bash-4.0%2B-orange)

**ALLRECON** is a comprehensive, modular reconnaissance framework designed for bug bounty hunters and security researchers. It automates the entire recon workflow with parallel execution, intelligent error handling, and extensive customization options.

## 🚀 Features

### Core Capabilities
- **Modular Architecture**: Clean separation of concerns with reusable modules
- **Parallel Execution**: Run multiple tools simultaneously for 60-70% faster scans
- **Configuration System**: YAML-based config with profiles (quick, deep)
- **Comprehensive Logging**: Multiple log levels with file and console output
- **Error Handling**: Graceful failure recovery and detailed error messages
- **Progress Tracking**: Real-time progress indicators and job statistics

### Reconnaissance Modules

#### 🔍 Subdomain Enumeration
- crt.sh certificate transparency logs
- SubFinder (passive subdomain discovery)
- Assetfinder (cross-platform subdomain finder)
- dnsx (brute-force and resolver)
- DNS resolution and validation
- HTTP/HTTPS service detection
- Subdomain takeover detection (subzy, subjack)

#### 📜 JavaScript Analysis
- Multi-source JS file discovery (gau, waybackurls, katana, robots.txt)
- Endpoint extraction (LinkFinder)
- Secret detection (SecretFinder + custom regex)
- API key extraction
- GF pattern matching (API keys, AWS keys, sensitive data)

#### 🌐 URL Collection
- Historical URL gathering (gau, waybackurls)
- URL validation (FFUF)
- Custom wordlist generation
- Parameter extraction
- GF pattern matching (XSS, SQLi, LFI, SSRF, IDOR, etc.)

#### 🔐 Vulnerability Scanning
- **CORS** misconfiguration detection
- **Nuclei** - CVEs, vulnerabilities, misconfigurations
- **XSS** - kxss + dalfox scanning
- **SQLi** - SQLMap integration
- **LFI** - Local file inclusion detection
- **Open Redirect** - OpenRedireX scanning

#### 📊 Reporting
- Summary text reports
- Scan statistics and metrics
- File location mapping
- Scan duration tracking

## 📦 Installation

### Prerequisites
- Bash 4.0+
- Go 1.19+ (for Go-based tools)
- Python 3.6+ (for Python tools)
- curl, jq, grep, sed, awk

### Quick Start

```bash
# Clone or download ALLRECON
cd /path/to/ALLRECON

# Check dependencies
chmod +x install.sh
./install.sh --check

# Install missing tools
./install.sh --install

# Run ALLRECON
chmod +x allrecon.sh
./allrecon.sh
```

For detailed installation instructions, see [INSTALLATION.md](INSTALLATION.md)

## 🎯 Usage

### Basic Usage

```bash
# Interactive menu (default)
./allrecon.sh

# Single domain reconnaissance
Select option [1] and enter domain: example.com

# Massive recon with subdomains
Select option [2] and enter domain: example.com
```

### Advanced Usage

```bash
# Use custom configuration
./allrecon.sh --config my-config.yaml

# Use quick scan profile
./allrecon.sh --profile quick

# Enable debug logging
./allrecon.sh --log-level DEBUG

# Disable parallel execution
./allrecon.sh --no-parallel

# Disable colors (for piping)
./allrecon.sh --no-color
```

For more examples, see [USAGE.md](USAGE.md)

## 📁 Output Structure

```
example.com/
├── domain_enum/          # Subdomain enumeration results
│   ├── crt.txt
│   ├── subfinder.txt
│   ├── assetfinder.txt
│   ├── dnsx.txt
│   └── all.txt
├── final_domains/        # Resolved and validated domains
│   ├── domains.txt
│   └── httpx.txt
├── js/                   # JavaScript analysis
│   ├── all_js.txt
│   ├── endpoints.txt
│   ├── secrets.txt
│   └── api_keys.txt
├── waybackurls/          # URL collection
│   ├── wayback.txt
│   └── valid.txt
├── gf/                   # GF pattern results
│   ├── xss.txt
│   ├── sqli.txt
│   └── lfi.txt
├── vulnerabilities/      # Vulnerability scan results
│   ├── cors/
│   ├── xss_scan/
│   ├── sqli/
│   ├── LFI/
│   └── openredirect/
├── nuclei_scan/          # Nuclei results
│   ├── cves.txt
│   ├── vulnerabilities.txt
│   └── misconfiguration.txt
├── takeovers/            # Subdomain takeover results
└── report.txt            # Summary report
```

## ⚙️ Configuration

ALLRECON uses YAML configuration files for flexibility:

```yaml
# config/default.yaml
scan:
  threads: 30
  timeout: 300
  parallel_enabled: true
  max_parallel_jobs: 5

logging:
  level: "INFO"
  file: "logs/allrecon.log"
```

### Profiles

**Quick Scan** (`--profile quick`):
- Fast, essential tools only
- Limited to subfinder, httpx, nuclei
- Timeout: 60s

**Deep Scan** (`--profile deep`):
- Comprehensive, all tools
- Increased parallelism
- Timeout: 3600s

**Create custom profiles** in `config/profiles/`

## 🔧 Technical Details

### Architecture

```
allrecon.sh (Main Entry Point)
├── lib/
│   ├── colors.sh         # Color management
│   ├── logger.sh         # Logging system
│   ├── utils.sh          # Utility functions
│   ├── parallel.sh       # Parallel execution
│   ├── validators.sh     # Input validation
│   └── config_parser.sh  # YAML config parser
└── modules/
    ├── subdomain_enum.sh # Subdomain discovery
    ├── js_analysis.sh    # JavaScript analysis
    ├── vuln_scan.sh      # Vulnerability scanning
    ├── url_collection.sh # URL gathering
    └── reporting.sh      # Report generation
```

### Parallel Execution

ALLRECON can run multiple tools concurrently:
- Job pooling with configurable max workers
- Progress tracking
- Timeout handling
- Resource monitoring

## 📸 Screenshots
  <img width="1229" height="485" alt="image" src="https://github.com/user-attachments/assets/ce4c7dd5-e5d6-4d66-8ca1-08c9062bd3ca" />
  <img width="1213" height="533" alt="image" src="https://github.com/user-attachments/assets/750119b6-02c3-4698-997e-43726df3a64a" />
  <img width="1420" height="553" alt="image" src="https://github.com/user-attachments/assets/6ad65cce-a477-4b45-808e-b84fdef63a77" />
  <img width="1100" height="609" alt="image" src="https://github.com/user-attachments/assets/55cc4915-4abe-4532-ab57-4c5df7ac2307" />

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 📄 License

MIT License - See [LICENSE](LICENSE.md) file for details

## 👤 Author

**Muzakir Lone**

## 🙏 Acknowledgments

Thanks to all the amazing tool creators:
- ProjectDiscovery team (subfinder, httpx, nuclei, katana, dnsx)
- Tom Hudson (assetfinder, gau, waybackurls, anew, qsreplace, unfurl, gf)
- Various security researchers for specialized tools

## 📚 Resources

- [Installation Guide](INSTALLATION.md)
- [Usage Examples](USAGE.md)
- [Configuration Reference](config/default.yaml)

## ⚠️ Disclaimer

This tool is for authorized security testing only. Always obtain proper permission before testing any systems you don't own.

---

**Version 2.0.0** - Complete rewrite with modular architecture, parallel execution, and professional tooling.
