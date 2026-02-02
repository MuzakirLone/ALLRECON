# ALLRECON - Usage Guide

## Table of Contents
- [Basic Usage](#basic-usage)
- [Command-Line Options](#command-line-options)
- [Scan Types](#scan-types)
- [Configuration](#configuration)
- [Profiles](#profiles)
- [Advanced Features](#advanced-features)
- [Best Practices](#best-practices)

## Basic Usage

### Interactive Mode (Default)

```bash
./allrecon.sh
```

This launches the interactive menu:
```
[1] Single Target Recon
[2] Full Target Recon With Subdomains
[3] Exit
```

### Single Target Recon

Select option **[1]** and enter a domain:
```
Enter Single domain (e.g evil.com): example.com
```

**What it does:**
- Checks HTTP/HTTPS services on the domain
- JavaScript file discovery and analysis
- URL collection from archives
- Vulnerability scanning (CORS, XSS, SQLi, LFI, etc.)
- Generates summary report

**Best for:**
- Single domains without subdomain enumeration
- Quick vulnerability assessments
- APIs or specific web applications

### Massive Recon

Select option **[2]** and enter a domain:
```
Full Recon with subdomains (e.g *.example.com): example.com
```

**What it does:**
Everything in single target recon PLUS:
- Subdomain enumeration (crt.sh, subfinder, assetfinder, shuffledns)
- DNS resolution
- Subdomain takeover detection
- HTTP service detection on all subdomains
- Parallel processing of all subdomains

**Best for:**
- Complete reconnaissance on a target
- Bug bounty programs
- Comprehensive security assessments

## Command-Line Options

### Configuration Options

```bash
# Use custom configuration file
./allrecon.sh --config /path/to/custom.yaml

# Use predefined profile
./allrecon.sh --profile quick
./allrecon.sh --profile deep
```

### Execution Options

```bash
# Enable parallel execution (default)
./allrecon.sh --parallel

# Disable parallel execution (sequential)
./allrecon.sh --no-parallel
```

### Logging Options

```bash
# Set log level
./allrecon.sh --log-level DEBUG   # Most verbose
./allrecon.sh --log-level INFO    # Default
./allrecon.sh --log-level WARN    # Warnings only
./allrecon.sh --log-level ERROR   # Errors only

# Disable colors (for piping or logging)
./allrecon.sh --no-color
```

### Combined Options

```bash
# Quick scan with debug logging
./allrecon.sh --profile quick --log-level DEBUG

# Custom config with no parallel
./allrecon.sh --config my-config.yaml --no-parallel

# Deep scan with colored output
./allrecon.sh --profile deep --log-level INFO
```

## Scan Types

### Quick Scan (--profile quick)

**Duration**: ~5-15 minutes
**Tools used**: subfinder, httpx, nuclei
**Use case**: Initial reconnaissance, time-sensitive testing

```bash
./allrecon.sh --profile quick
```

### Standard Scan (default)

**Duration**: ~30-60 minutes
**Tools used**: All enabled tools
**Use case**: Regular bug bounty reconnaissance

```bash
./allrecon.sh
```

### Deep Scan (--profile deep)

**Duration**: ~2-4 hours
**Tools used**: All tools with extended timeouts
**Use case**: Comprehensive security assessment

```bash
./allrecon.sh --profile deep
```

## Configuration

### Using Custom Configuration

Create a custom YAML file:

```yaml
# my-config.yaml
scan:
  threads: 50              # More threads
  timeout: 600             # Longer timeout
  parallel_enabled: true
  max_parallel_jobs: 10    # More parallel jobs

logging:
  level: "DEBUG"
  file: "logs/custom-scan.log"

wordlists:
  subdomain_bruteforce: "/path/to/my/wordlist.txt"
  resolvers: "/path/to/resolvers.txt"
```

Use it:
```bash
./allrecon.sh --config my-config.yaml
```

### Environment Variable Overrides

You can override config with environment variables:

```bash
# Override threads
export ALLRECON_THREADS=50

# Override parallel settings
export ALLRECON_PARALLEL=true
export ALLRECON_MAX_JOBS=10

# Override logging
export ALLRECON_LOG_LEVEL=DEBUG
export ALLRECON_LOG_FILE=logs/my-scan.log

# Run
./allrecon.sh
```

## Profiles

### Creating Custom Profiles

Create a profile in `config/profiles/`:

```yaml
# config/profiles/stealth.yaml
scan:
  timeout: 120
  parallel_enabled: false  # Sequential for stealth
  max_parallel_jobs: 1
  
tools_enabled:
  - subfinder
  - httpx
  
skip_modules:
  - bruteforce          # Skip noisy bruteforce
  - port_scanning       # Skip port scanning
```

Use it:
```bash
./allrecon.sh --profile stealth
```

## Advanced Features

### Parallel vs Sequential Execution

**Parallel (default)**:
- Runs multiple tools concurrently
- 60-70% faster
- Higher resource usage
- Best for powerful machines

**Sequential**:
- Runs tools one at a time
- Slower but more controlled
- Lower resource usage
- Best for VPS or limited resources

```bash
# Parallel (fast)
./allrecon.sh --parallel

# Sequential (controlled)
./allrecon.sh --no-parallel
```

### Logging and Debugging

```bash
# Debug mode (very verbose)
./allrecon.sh --log-level DEBUG

# Check logs
tail -f logs/allrecon.log

# Search for errors
grep "ERROR" logs/allrecon.log

# Watch specific module
grep "subdomain_enum" logs/allrecon.log
```

### Interrupting Scans

During a scan, press **Ctrl+C**:
- You'll be prompted to skip the current command or continue
- Type `exit` to skip to next command
- Press Enter to continue current command

## Best Practices

### 1. Start with Quick Scan

```bash
# First run: quick scan
./allrecon.sh --profile quick

# Review results, then deep scan
./allrecon.sh --profile deep
```

### 2. Use Appropriate Profiles

- **Bug Bounty**: Use default or deep profile
- **CTF/Practice**: Use quick profile
- **Enterprise Assessment**: Use deep profile with custom config

### 3. Monitor Resource Usage

```bash
# Watch resources while scanning
htop

# If system is slow, reduce parallel jobs
./allrecon.sh --config low-resource.yaml
```

Example `low-resource.yaml`:
```yaml
scan:
  max_parallel_jobs: 2
  threads: 10
```

### 4. Organize Outputs

```bash
# Create timestamped directories
mkdir scans/$(date +%Y-%m-%d)
cd scans/$(date +%Y-%m-%d)
/path/to/allrecon.sh
```

### 5. Review Reports

After scan completion:
```bash
# Read summary report
cat target.com/report.txt

# Check specific findings
cat target.com/nuclei_scan/cves.txt
cat target.com/js/secrets.txt
cat target.com/gf/xss.txt
```

## Examples

### Example 1: Quick Bug Bounty Recon

```bash
./allrecon.sh --profile quick
# Select [2] Massive Recon
# Enter: bugbounty-target.com
```

### Example 2: Deep Custom Scan

```bash
./allrecon.sh --config my-config.yaml --log-level DEBUG --profile deep
```

### Example 3: Stealth Scan

```bash
# Create stealth config with delays
./allrecon.sh --no-parallel --profile quick
```

### Example 4: CI/CD Integration

```bash
#!/bin/bash
# recon-automation.sh

DOMAIN=$1
./allrecon.sh <<EOF
2
$DOMAIN
EOF

# Process results
if grep -q "CRITICAL" $DOMAIN/nuclei_scan/*.txt; then
    echo "Critical vulnerabilities found!"
    exit 1
fi
```

## Common Workflows

### Workflow 1: Continuous Monitoring

```bash
while true; do
    ./allrecon.sh --profile quick
    sleep 3600  # Every hour
done
```

### Workflow 2: Multi-Target Scan

```bash
#!/bin/bash
targets=(
    "target1.com"
    "target2.com"
    "target3.com"
)

for target in "${targets[@]}"; do
    ./allrecon.sh <<EOF
2
$target
3
EOF
done
```

## Output Interpretation

### Understanding Reports

The summary report (`domain/report.txt`) contains:
- Total subdomains found vs live
- HTTP/HTTPS services count
- JavaScript files and secrets
- URL collection stats
- Vulnerability counts by type

### Priority Findings

**High Priority**:
1. `nuclei_scan/cves.txt` - Known CVEs
2. `js/secrets.txt` - Exposed secrets
3. `vulnerabilities/xss_scan/` - XSS vulnerabilities
4. `takeovers/` - Subdomain takeovers

**Medium Priority**:
5. `nuclei_scan/misconfiguration.txt` - Misconfigurations
6. `vulnerabilities/sqli/` - SQL injection
7. `gf/` - Pattern-matched vulnerabilities

**Low Priority**:
8. `nuclei_scan/tech.txt` - Technology fingerprinting
9. `target_wordlist/` - Custom wordlists

## Troubleshooting

### Scan is slow
```bash
# Increase parallel jobs
./allrecon.sh --config <(echo 'scan:
  max_parallel_jobs: 15')
```

### Out of memory
```bash
# Reduce parallel jobs
./allrecon.sh --no-parallel
```

### Tools not found
```bash
# Check dependencies
./install.sh --check

# Install missing tools
./install.sh --install
```

---

**For more information**, see [README.md](README.md) and [INSTALLATION.md](INSTALLATION.md)
