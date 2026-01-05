# get-code-scanning-coverage-report

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
- A GitHub token with `repo` scope

## Installation

```shell
cd scripts/get-code-scanning-coverage-report
npm install
```

## Usage

```shell
# Set your GitHub token
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx

# Note: If you are authenticated with the GitHub CLI, you can use `gh auth token` to get your token:
# export GITHUB_TOKEN=$(gh auth token)

# Basic usage - output to stdout
node get-code-scanning-coverage-report.js my-org

# Output to file (also generates sub-reports)
node get-code-scanning-coverage-report.js my-org --output report.csv

# Check a single repository
node get-code-scanning-coverage-report.js my-org --repo my-repo

# Sample 25 random repositories
node get-code-scanning-coverage-report.js my-org --sample --output sample.csv

# Include workflow status column
node get-code-scanning-coverage-report.js my-org --check-workflows --output report.csv

# Check for unscanned GitHub Actions workflows
node get-code-scanning-coverage-report.js my-org --check-actions --output report.csv

# Use with GitHub Enterprise Server
export GITHUB_API_URL=https://github.example.com/api/v3
node get-code-scanning-coverage-report.js my-org --output report.csv

# Adjust concurrency (default: 10)
node get-code-scanning-coverage-report.js my-org --concurrency 5 --output report.csv
```

## Options

| Option | Description |
|--------|-------------|
| `--output <file>` | Write CSV to file (also generates sub-reports) |
| `--repo <repo>` | Check a single repository instead of all repos |
| `--sample` | Sample 25 random repositories |
| `--check-workflows` | Include CodeQL workflow run status column |
| `--check-actions` | Check for unscanned GitHub Actions workflows |
| `--concurrency <n>` | Number of concurrent API calls (default: 10) |
| `--help` | Show help message |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `GITHUB_TOKEN` | GitHub token with `repo` scope (required) |
| `GITHUB_API_URL` | API endpoint (defaults to `https://api.github.com`) |

## Output Columns

| Column | Description |
|--------|-------------|
| Repository | Repository name |
| Default Branch | The default branch of the repository |
| Last Updated | When the repository was last updated |
| Languages | Languages detected in the repository (semicolon-separated) |
| CodeQL Enabled | `Yes`, `No Scans`, `Disabled`, `Requires GHAS`, or `No` |
| Last Default Branch Scan Date | Date of most recent scan on default branch |
| Scanned Languages | Languages scanned by CodeQL (semicolon-separated) |
| Unscanned CodeQL Languages | CodeQL-supported languages not being scanned |
| Open Alerts | Number of open code scanning alerts |
| Analysis Errors | Errors from most recent analysis |
| Analysis Warnings | Warnings from most recent analysis |
| Workflow Status | (with `--check-workflows`) `OK`, `Failing`, `No workflow`, or `Unknown` |

## Sub-reports

When using `--output`, the script generates actionable sub-reports:

| File | Description |
|------|-------------|
| `*-disabled.csv` | Repos with CodeQL disabled or no scans |
| `*-stale.csv` | Repos modified >90 days after last scan |
| `*-missing-languages.csv` | Repos scanning but missing some CodeQL languages |
| `*-open-alerts.csv` | Repos with open code scanning alerts |
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
Repository,Default Branch,Last Updated,Languages,CodeQL Enabled,Last Default Branch Scan Date,Scanned Languages,Unscanned CodeQL Languages,Open Alerts,Analysis Errors,Analysis Warnings
my-app,main,2025-12-01,JavaScript;TypeScript;Python,Yes,2025-12-15,javascript-typescript;python,None,3,"None","None"
legacy-service,master,2024-06-15,Java,Yes,2024-01-10,java-kotlin,None,0,"None","None"
new-project,main,2025-12-20,Go;Python,No Scans,Never,,go;python,N/A,"",""
```

<!-- Remove this section when the bash script is deleted
## Comparison with Bash Version

This Node.js version offers several advantages over the bash script (`gh-cli/get-code-scanning-coverage-report.sh`):

- **Faster**: Parallel API calls (configurable concurrency)
- **More reliable**: Proper JSON handling, no regex parsing issues
- **Cross-platform**: Works identically on macOS, Linux, and Windows
- **Easier to maintain**: Clean data structures and error handling

The bash version is still useful if you:

- Don't have Node.js installed
- Prefer no dependencies beyond `gh` CLI
- Need to quickly inspect/modify the script

-->
