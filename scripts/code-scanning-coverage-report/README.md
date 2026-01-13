# code-scanning-coverage-report

Generate a comprehensive code scanning coverage report for all repositories in a GitHub organization.

## Features

- Reports CodeQL enablement status, last scan date, and scanned languages
- Identifies CodeQL-supported languages that are not being scanned
- Shows open alert counts and analysis errors/warnings
- Generates actionable sub-reports for remediation
- Supports parallel API calls for faster processing
- Works with GitHub.com and GitHub Enterprise Server

## Prerequisites

- Node.js 18 or later
- A GitHub token with `repo` scope, or GitHub App credentials

## Installation

```shell
cd scripts/code-scanning-coverage-report
npm install
```

## Usage

```shell
# Set your GitHub token
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx

# Note: If you are authenticated with the GitHub CLI, you can use `gh auth token` to get your token:
# export GITHUB_TOKEN=$(gh auth token)

# Basic usage - output to stdout
node code-scanning-coverage-report.js my-org

# Output to file (also generates sub-reports)
node code-scanning-coverage-report.js my-org --output report.csv

# Check a single repository
node code-scanning-coverage-report.js my-org --repo my-repo

# Sample 25 random repositories
node code-scanning-coverage-report.js my-org --sample --output sample.csv

# Include workflow status column
node code-scanning-coverage-report.js my-org --check-workflow-status --output report.csv

# Check for unscanned GitHub Actions workflows
node code-scanning-coverage-report.js my-org --check-unscanned-actions --output report.csv

# Use with GitHub Enterprise Server
export GITHUB_API_URL=https://github.example.com/api/v3
node code-scanning-coverage-report.js my-org --output report.csv

# Adjust concurrency (default: 10)
node code-scanning-coverage-report.js my-org --concurrency 5 --output report.csv

# Process multiple organizations from a file
node code-scanning-coverage-report.js --orgs-file orgs.txt --output report.csv

# Customize stale threshold (default: 90 days)
node code-scanning-coverage-report.js my-org --stale-days 60 --output report.csv
```

## Options

| Option | Description |
|--------|-------------|
| `--orgs-file <file>` | File containing list of organizations (one per line) |
| `--output <file>` | Write CSV to file (also generates sub-reports) |
| `--repo <repo>` | Check a single repository instead of all repos |
| `--sample` | Sample 25 random repositories |
| `--fetch-alerts` | Include alert counts in report (increases API usage) |
| `--check-workflow-status` | Check CodeQL workflow run status (success/failure) |
| `--check-unscanned-actions` | Check if repos have Actions workflows not being scanned |
| `--concurrency <n>` | Number of concurrent API calls (default: 10) |
| `--stale-days <n>` | Days after last scan to consider repo stale (default: 90) |
| `--help` | Show help message |

## API Usage

Default options use approximately **2 API calls per repository**:

- With a **Personal Access Token** (5,000 requests/hour): supports up to ~2,500 repos
- With **GitHub App authentication** (15,000 requests/hour): supports up to ~7,500 repos

Optional flags increase API usage:

| Flag | Additional Calls |
|------|------------------|
| `--fetch-alerts` | +1 call per repo (paginated for repos with many alerts) |
| `--check-workflow-status` | +1-2 calls per repo |
| `--check-unscanned-actions` | +1 call per repo |

The script displays your current rate limit at startup and total API calls used at completion.

## Environment Variables

Two authentication methods are supported:

- **Personal Access Token (PAT)**: Simple setup, good for testing or small organizations
- **GitHub App**: Recommended for production use - provides higher rate limits (5,000 vs 15,000 requests/hour)

### Token Authentication

| Variable | Description |
|----------|-------------|
| `GITHUB_TOKEN` | GitHub token with `repo` scope |
| `GITHUB_API_URL` | API endpoint (defaults to `https://api.github.com`) |

### GitHub App Authentication (recommended)

| Variable | Description |
|----------|-------------|
| `GITHUB_APP_ID` | GitHub App ID |
| `GITHUB_APP_PRIVATE_KEY_PATH` | Path to GitHub App private key file (.pem) |
| `GITHUB_API_URL` | API endpoint (defaults to `https://api.github.com`) |

The script automatically looks up the installation ID for each organization being processed. This enables scanning multiple organizations with a single command using `--orgs-file`.

**Required GitHub App Permissions:**

Repository permissions:

| Permission | Access | Required For |
|------------|--------|--------------|
| Code scanning alerts | Read | Code scanning status, analyses, and alert counts |
| Contents | Read | Listing repositories and checking for workflow files |
| Metadata | Read | Detecting repository languages (this is automatically added) |
| Actions | Read | Workflow run status (only if using --check-workflow-status) |

Organization permissions:

| Permission | Access | Required For |
|------------|--------|--------------|
| Administration | Read | Listing all repositories in the organization |

**Note:** The app must be installed on the organization with access to the repositories you want to scan (either "All repositories" or selected repositories). The app can only report on repositories it has been granted access to.

**Note:** If GitHub App credentials are provided, they take precedence over `GITHUB_TOKEN`.

### GitHub App Usage Example

```shell
# Set GitHub App credentials
export GITHUB_APP_ID=123456
export GITHUB_APP_PRIVATE_KEY_PATH=/path/to/private-key.pem

# Run the report for a single org
node code-scanning-coverage-report.js my-org --output report.csv

# Run the report for multiple orgs (installation ID is looked up automatically)
node code-scanning-coverage-report.js --orgs-file orgs.txt --output report.csv
```

## Output Columns

| Column | Description |
|--------|-------------|
| Organization | Organization name |
| Repository | Repository name |
| Default Branch | The default branch of the repository |
| Last Updated | When the repository was last updated |
| Languages | Languages detected in the repository (semicolon-separated) |
| CodeQL Enabled | `Yes`, `No Scans`, `Disabled`, `Requires GHAS`, or `No` |
| Last Default Branch Scan Date | Date of most recent scan on default branch |
| Scanned Languages | Languages scanned by CodeQL (semicolon-separated) |
| Unscanned CodeQL Languages | CodeQL-supported languages not being scanned |
| Open Alerts | (with `--fetch-alerts`) Total number of open code scanning alerts |
| Critical Alerts | (with `--fetch-alerts`) Number of critical severity alerts |
| Analysis Errors | Errors from most recent analysis |
| Analysis Warnings | Warnings from most recent analysis |
| Workflow Status | (with `--check-workflow-status`) `OK`, `Failing`, `No workflow`, or `Unknown` |

## Sub-reports

When using `--output`, the script generates actionable sub-reports:

| File | Description |
|------|-------------|
| `*-disabled.csv` | Repos with CodeQL disabled or no scans |
| `*-stale.csv` | Repos modified after last scan (configurable with `--stale-days`, default: 90) |
| `*-missing-languages.csv` | Repos scanning but missing some CodeQL languages |
| `*-critical-alerts.csv` | Repos with critical severity code scanning alerts |
| `*-analysis-issues.csv` | Repos with analysis errors or warnings |

## CodeQL Supported Languages

The script recognizes these CodeQL-supported languages:

- C/C++ (reported as `c-cpp`)
- C# (reported as `csharp`)
- Go
- Java/Kotlin (reported as `java-kotlin`)
- JavaScript/TypeScript (reported as `javascript-typescript`)
- Python
- Ruby
- Swift

## Example Output

```csv
Organization,Repository,Default Branch,Last Updated,Archived,Languages,CodeQL Enabled,Last Default Branch Scan Date,Scanned Languages,Unscanned CodeQL Languages,Open Alerts,Critical Alerts,Analysis Errors,Analysis Warnings
my-org,my-app,main,2025-12-01,No,JavaScript;TypeScript;Python,Yes,2025-12-15,javascript-typescript;python,None,5,1,None,None
my-org,legacy-service,master,2024-06-15,No,Java,Yes,2024-01-10,java-kotlin,None,0,0,None,None
my-org,new-project,main,2025-12-20,No,Go;Python,No Scans,Never,,go;python,N/A,N/A,,
```

<!-- Remove this section when the bash script is deleted
## Comparison with Bash Version

This Node.js version offers several advantages over the bash script (`gh-cli/code-scanning-coverage-report.sh`):

- **Faster**: Parallel API calls (configurable concurrency)
- **More reliable**: Proper JSON handling, no regex parsing issues
- **Cross-platform**: Works identically on macOS, Linux, and Windows
- **Easier to maintain**: Clean data structures and error handling

The bash version is still useful if you:

- Don't have Node.js installed
- Prefer no dependencies beyond `gh` CLI
- Need to quickly inspect/modify the script

-->
