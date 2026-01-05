#!/bin/bash

# v1.0.0

# This script generates a comprehensive code scanning coverage report for all repositories
# in an organization. It provides insight into which repositories are actively using Code
# Scanning by showing the last scan date, which helps identify coverage gaps (e.g., a scan
# done 2 years ago indicates the team is not actively using Code Scanning).

# Inputs:
# 1. ORG_NAME: The name of the organization (first positional argument)
# 2. --hostname <HOSTNAME> (optional): GitHub Enterprise Server hostname
# 3. --debug (optional): Enable debug output
# 4. --output <FILE> (optional): Write CSV output to a file instead of stdout
# 5. --check-workflows (optional): Check GitHub Actions workflow status for CodeQL
# 6. --check-actions (optional): Check if .github/workflows exists and report unscanned actions
# 7. --sample (optional): Sample 25 random repositories instead of processing all
# 8. --repo <REPO> (optional): Check a single repository instead of all repos in the organization

# How to call:
# ./get-code-scanning-coverage-report.sh <organization>
# ./get-code-scanning-coverage-report.sh --output report.csv <organization>
# ./get-code-scanning-coverage-report.sh --hostname github.example.com --output report.csv <organization>
# ./get-code-scanning-coverage-report.sh --check-workflows --output report.csv <organization>
# ./get-code-scanning-coverage-report.sh --check-actions --output report.csv <organization>
# ./get-code-scanning-coverage-report.sh --sample --output report.csv <organization>
# ./get-code-scanning-coverage-report.sh --repo my-repo --output report.csv <organization>

# Output format: CSV with the following columns:
# - Repository: Repository name
# - Default Branch: The default branch of the repository
# - Last Updated: When the repository was last updated
# - Languages: Languages detected in the repository
# - CodeQL Enabled: Whether code scanning is enabled and has results:
#     - Yes: Code scanning analyses exist (scans have been uploaded)
#     - No Scans: Code scanning is enabled but no analyses uploaded yet
#     - Disabled: Code Security is disabled on the repository
#     - Requires GHAS: GitHub Advanced Security must be enabled first
#     - No: Code scanning feature is not accessible (404)
# - Last Default Branch Scan Date: Date of the most recent code scanning analysis on the default branch
# - Scanned Languages: Languages that have been scanned by CodeQL
# - Unscanned CodeQL Languages: CodeQL-supported languages in the repo that are NOT being scanned
# - Open Alerts: Number of open code scanning alerts (security vulnerabilities found)
# - Analysis Errors: Any errors reported in the most recent CodeQL analysis result
# - Analysis Warnings: Any warnings reported in the most recent CodeQL analysis result
# - Workflow Status: (optional, with --check-workflows) Status of the most recent CodeQL workflow run

# Important Notes:
# - Requires 'gh' CLI to be installed and authenticated
# - CodeQL supported languages: C/C++, C#, Go, Java/Kotlin, JavaScript/TypeScript, Python, Ruby, Swift

# Tested runtime:
# - bash: 3.2.57(1)-release (arm64-apple-darwin25)
# - gh: gh version 2.83.2 (2025-12-10)
# - awk: 20200816
# - sed: BSD sed (macOS)

DEBUG_MODE=0
OUTPUT_FILE=""
ORG_NAME=""
REPO_NAME=""
HOSTNAME=""
CHECK_WORKFLOWS=0
CHECK_ACTIONS=0
SAMPLE_MODE=0
SAMPLE_SIZE=25

# CodeQL supported languages (normalized to lowercase for comparison)
# See: https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/
CODEQL_SUPPORTED_LANGUAGES="c c++ cpp csharp go java kotlin javascript typescript python ruby swift"

# Function to handle debug messages
debug() {
  if [ "$DEBUG_MODE" -eq 1 ]; then
    echo "DEBUG: $*" >&2
  fi
}

# Function to handle errors
error() {
  echo "ERROR: $*" >&2
  exit 1
}

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --debug)
      DEBUG_MODE=1
      shift
      ;;
    --hostname)
      HOSTNAME="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --check-workflows)
      CHECK_WORKFLOWS=1
      shift
      ;;
    --check-actions)
      CHECK_ACTIONS=1
      shift
      ;;
    --sample)
      SAMPLE_MODE=1
      shift
      ;;
    --repo)
      REPO_NAME="$2"
      shift 2
      ;;
    -*)
      error "Unknown option: $1"
      ;;
    *)
      ORG_NAME="$1"
      shift
      ;;
  esac
done

# Validate inputs
if [ -z "$ORG_NAME" ]; then
  echo "Usage: $0 [--debug] [--hostname <HOSTNAME>] [--output <FILE>] [--check-workflows] [--check-actions] [--sample] [--repo <REPO>] <organization>"
  echo ""
  echo "Options:"
  echo "  --repo <REPO>    Check a single repository instead of all repos in the organization"
  echo "  --sample         Sample 25 random repositories"
  echo "  --check-workflows  Include CodeQL workflow status"
  echo "  --check-actions    Check for unscanned GitHub Actions workflows"
  exit 1
fi

# Check for required tools
command -v gh >/dev/null 2>&1 || error "gh CLI is required but not installed"

# Build hostname flag for gh CLI
GH_HOST_FLAG=""
if [ -n "$HOSTNAME" ]; then
  GH_HOST_FLAG="--hostname $HOSTNAME"
fi

# Function to convert string to lowercase (portable)
to_lowercase() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Function to check if a language is CodeQL scannable
is_codeql_language() {
  local lang
  lang=$(to_lowercase "$1")
  # Handle C# separately since it has a special character
  if [ "$lang" = "c#" ]; then
    return 0
  fi
  # Check if language is in the supported list
  echo " $CODEQL_SUPPORTED_LANGUAGES " | grep -q " $lang "
}

# Function to get all code scanning analyses for a repo (to extract scanned languages)
get_scanning_info() {
  local repo="$1"
  local default_branch="$2"
  debug "Fetching code scanning analyses for $repo (default branch: $default_branch)"

  local response
  # shellcheck disable=SC2086
  response=$(gh api $GH_HOST_FLAG "/repos/$ORG_NAME/$repo/code-scanning/analyses?per_page=100&ref=refs/heads/$default_branch" 2>&1)

  # Check for errors
  if echo "$response" | grep -qi "no analysis found\|not found\|Advanced Security\|HTTP 404\|HTTP 403"; then
    echo "NO_RESULTS||||||"
    return
  fi

  # Check if response is an array with data
  local count
  count=$(echo "$response" | jq -r 'if type == "array" then length else 0 end' 2>/dev/null)

  if [ "$count" = "0" ] || [ -z "$count" ]; then
    echo "NO_RESULTS||||||"
    return
  fi

  # Get the most recent analysis date
  local last_scan_date
  last_scan_date=$(echo "$response" | jq -r '.[0].created_at // empty' 2>/dev/null)

  # Get the tool name from most recent scan
  local tool_name
  tool_name=$(echo "$response" | jq -r '.[0].tool.name // empty' 2>/dev/null)

  # Get error from the most recent analysis (if any)
  local analysis_error
  analysis_error=$(echo "$response" | jq -r '.[0].error // empty' 2>/dev/null)

  # Get warning from the most recent analysis (if any)
  local analysis_warning
  analysis_warning=$(echo "$response" | jq -r '.[0].warning // empty' 2>/dev/null)

  # Extract all unique scanned languages from the analyses
  # The category field often contains language info like "language:python" or "/language:javascript-typescript"
  local scanned_languages
  scanned_languages=$(echo "$response" | jq -r '[.[].category // empty] | unique | .[]' 2>/dev/null | \
    grep -oE 'language:[a-zA-Z0-9_-]+' | \
    sed 's/language://g' | \
    sort -u | \
    tr '\n' ';' | \
    sed 's/;$//')

  # If no languages found in category, try to infer from tool name
  if [ -z "$scanned_languages" ]; then
    scanned_languages=$(echo "$response" | jq -r '[.[].tool.name // empty] | unique | join(";")' 2>/dev/null)
  fi

  echo "${last_scan_date}|${tool_name}|${scanned_languages}|${analysis_error}|${analysis_warning}"
}

# Function to get repository languages
get_repo_languages() {
  local repo="$1"
  debug "Fetching languages for $repo"

  local response
  # shellcheck disable=SC2086
  response=$(gh api $GH_HOST_FLAG "/repos/$ORG_NAME/$repo/languages" 2>/dev/null)

  if [ -z "$response" ] || [ "$response" = "{}" ]; then
    echo ""
    return
  fi

  echo "$response" | jq -r 'keys | join(";")' 2>/dev/null
}

# Function to check CodeQL/code scanning enablement status
check_codeql_status() {
  local repo="$1"
  debug "Checking code scanning status for $repo"

  # Try to access code scanning analyses endpoint
  local response
  # shellcheck disable=SC2086
  response=$(gh api $GH_HOST_FLAG "/repos/$ORG_NAME/$repo/code-scanning/analyses?per_page=1" 2>&1)

  # Check various response scenarios
  if echo "$response" | grep -qi "Advanced Security must be enabled"; then
    echo "Requires GHAS"
    return
  fi

  # Code Security disabled (newer GitHub terminology)
  if echo "$response" | grep -qi "Code Security must be enabled"; then
    echo "Disabled"
    return
  fi

  # "no analysis found" means code scanning IS enabled, just no scans uploaded yet
  if echo "$response" | grep -qi "no analysis found"; then
    echo "No Scans"
    return
  fi

  # 404 typically means code scanning feature is not accessible
  if echo "$response" | grep -qi "HTTP 404\|not found"; then
    echo "No"
    return
  fi

  # If we got an array response (even empty), code scanning is accessible
  if echo "$response" | jq -e 'type == "array"' 2>/dev/null | grep -q true; then
    local count
    count=$(echo "$response" | jq 'length' 2>/dev/null)
    if [ "$count" -gt 0 ]; then
      echo "Yes"
    else
      # Empty array means enabled but no scans yet
      echo "No Scans"
    fi
    return
  fi

  echo "Unknown"
}

# Function to get open code scanning alerts count
get_open_alerts_count() {
  local repo="$1"
  debug "Fetching open alerts for $repo"

  local response
  # shellcheck disable=SC2086
  response=$(gh api $GH_HOST_FLAG "/repos/$ORG_NAME/$repo/code-scanning/alerts?state=open&per_page=1" 2>&1)

  # Check for errors
  if echo "$response" | grep -qi "no analysis found\|not found\|Advanced Security\|HTTP 404\|HTTP 403"; then
    echo "N/A"
    return
  fi

  # Get total count using pagination to handle repos with >100 alerts
  # shellcheck disable=SC2086
  local count_response
  count_response=$(gh api $GH_HOST_FLAG --paginate "/repos/$ORG_NAME/$repo/code-scanning/alerts?state=open&per_page=100" --jq 'length' 2>/dev/null | awk '{sum += $1} END {print sum}')

  if [ -z "$count_response" ] || [ "$count_response" = "0" ]; then
    echo "0"
  else
    echo "$count_response"
  fi
}

# Function to check the most recent CodeQL workflow run status
get_codeql_workflow_status() {
  local repo="$1"
  debug "Checking CodeQL workflow status for $repo"

  # Find CodeQL workflow(s)
  local workflows
  # shellcheck disable=SC2086
  workflows=$(gh api $GH_HOST_FLAG "/repos/$ORG_NAME/$repo/actions/workflows" --jq '.workflows[] | select(.name | test("codeql|CodeQL"; "i")) | .id' 2>/dev/null)

  if [ -z "$workflows" ]; then
    echo "No workflow"
    return
  fi

  # Check the most recent run for each CodeQL workflow
  local has_failure=false
  local has_success=false
  local last_conclusion=""

  for workflow_id in $workflows; do
    # shellcheck disable=SC2086
    local run_info
    run_info=$(gh api $GH_HOST_FLAG "/repos/$ORG_NAME/$repo/actions/workflows/$workflow_id/runs?per_page=1&branch=main" --jq '.workflow_runs[0] | {conclusion, status}' 2>/dev/null)

    if [ -n "$run_info" ]; then
      local conclusion
      conclusion=$(echo "$run_info" | jq -r '.conclusion // empty' 2>/dev/null)

      if [ "$conclusion" = "failure" ]; then
        has_failure=true
        last_conclusion="failure"
      elif [ "$conclusion" = "success" ]; then
        has_success=true
        if [ -z "$last_conclusion" ]; then
          last_conclusion="success"
        fi
      fi
    fi
  done

  if [ "$has_failure" = true ]; then
    echo "Failing"
  elif [ "$has_success" = true ]; then
    echo "OK"
  else
    echo "Unknown"
  fi
}

# Function to check if .github/workflows directory exists
has_github_workflows() {
  local repo="$1"
  debug "Checking for .github/workflows in $repo"

  local response
  # shellcheck disable=SC2086
  response=$(gh api $GH_HOST_FLAG "/repos/$ORG_NAME/$repo/contents/.github/workflows" 2>&1)

  # If we get an array response, workflows exist
  if echo "$response" | jq -e 'type == "array"' 2>/dev/null | grep -q true; then
    echo "true"
  else
    echo "false"
  fi
}

# Function to get CodeQL-supported languages that are NOT being scanned
get_unscanned_codeql_languages() {
  local repo_languages="$1"
  local scanned_languages="$2"
  local has_workflows="$3"

  local unscanned=""
  local scanned_lower
  scanned_lower=$(to_lowercase "$scanned_languages")

  # Check if actions workflows exist but aren't being scanned
  if [ "$has_workflows" = "true" ]; then
    if [[ ! "$scanned_lower" =~ actions ]]; then
      unscanned="actions"
    fi
  fi

  # If no languages detected
  if [ -z "$repo_languages" ]; then
    if [ -n "$unscanned" ]; then
      echo "$unscanned"
    elif [ -n "$scanned_languages" ]; then
      echo "None"
    else
      echo "N/A"
    fi
    return
  fi

  IFS=';' read -ra LANGS <<< "$repo_languages"
  for lang in "${LANGS[@]}"; do
    lang=$(echo "$lang" | sed 's/^ *//;s/ *$//')
    local lang_lower
    lang_lower=$(to_lowercase "$lang")

    # Normalize C# to csharp for comparison
    if [ "$lang_lower" = "c#" ]; then
      lang_lower="csharp"
    fi

    # Check if this language is CodeQL-supported
    if is_codeql_language "$lang_lower"; then
      # Check if it's being scanned (case-insensitive)
      # Handle CodeQL combined languages: javascript-typescript, java-kotlin
      # Note: "javascript" alone covers both JS and TS, same for "java" covering Kotlin
      local is_scanned=0
      local unscanned_name="$lang"

      if [[ "$scanned_lower" =~ $lang_lower ]]; then
        is_scanned=1
      elif [ "$lang_lower" = "csharp" ]; then
        # Normalize C# to csharp for output
        if [[ "$scanned_lower" =~ csharp ]]; then
          is_scanned=1
        else
          unscanned_name="csharp"
        fi
      elif [ "$lang_lower" = "javascript" ] || [ "$lang_lower" = "typescript" ]; then
        # CodeQL's javascript extractor handles both JS and TS
        if [[ "$scanned_lower" =~ javascript ]]; then
          is_scanned=1
        else
          # Normalize to CodeQL language name
          unscanned_name="javascript-typescript"
        fi
      elif [ "$lang_lower" = "java" ] || [ "$lang_lower" = "kotlin" ]; then
        # CodeQL's java extractor handles both Java and Kotlin
        if [[ "$scanned_lower" =~ java ]]; then
          is_scanned=1
        else
          # Normalize to CodeQL language name
          unscanned_name="java-kotlin"
        fi
      elif [ "$lang_lower" = "c" ] || [ "$lang_lower" = "c++" ] || [ "$lang_lower" = "cpp" ]; then
        # CodeQL's cpp extractor handles both C and C++
        if [[ "$scanned_lower" =~ c-cpp ]] || [[ "$scanned_lower" =~ cpp ]]; then
          is_scanned=1
        else
          # Normalize to CodeQL language name
          unscanned_name="c-cpp"
        fi
      fi

      if [ "$is_scanned" -eq 0 ]; then
        # Avoid duplicates (e.g., if both JavaScript and TypeScript are in repo)
        if [ -z "$unscanned" ]; then
          unscanned="$unscanned_name"
        elif [[ ! ";$unscanned;" =~ ";$unscanned_name;" ]]; then
          unscanned="$unscanned;$unscanned_name"
        fi
      fi
    fi
  done

  if [ -z "$unscanned" ]; then
    echo "None"
  else
    echo "$unscanned"
  fi
}

# CSV header (conditionally include Workflow Status column)
if [ "$CHECK_WORKFLOWS" -eq 1 ]; then
  CSV_HEADER="Repository,Default Branch,Last Updated,Archived,Languages,CodeQL Enabled,Last Default Branch Scan Date,Scanned Languages,Unscanned CodeQL Languages,Open Alerts,Analysis Errors,Analysis Warnings,Workflow Status"
else
  CSV_HEADER="Repository,Default Branch,Last Updated,Archived,Languages,CodeQL Enabled,Last Default Branch Scan Date,Scanned Languages,Unscanned CodeQL Languages,Open Alerts,Analysis Errors,Analysis Warnings"
fi

# Output function
output_line() {
  local line="$1"
  if [ -n "$OUTPUT_FILE" ]; then
    echo "$line" >> "$OUTPUT_FILE"
  else
    echo "$line"
  fi
}

# Initialize output file if specified
if [ -n "$OUTPUT_FILE" ]; then
  > "$OUTPUT_FILE"
fi

output_line "$CSV_HEADER"

debug "Fetching repositories for organization: $ORG_NAME"

# Fetch repositories - either single repo or all repos in org
total_repos=0

if [ -n "$REPO_NAME" ]; then
  # Single repo mode - fetch just that repo's info
  echo "Generating code scanning coverage report for: $ORG_NAME/$REPO_NAME" >&2

  # shellcheck disable=SC2086
  repo_info=$(gh api graphql $GH_HOST_FLAG -F org="$ORG_NAME" -F repo="$REPO_NAME" -f query='
  query($org: String!, $repo: String!) {
    repository(owner: $org, name: $repo) {
      name
      updatedAt
      isArchived
      defaultBranchRef {
        name
      }
    }
  }' --template '{{.data.repository.name}}|{{.data.repository.updatedAt}}|{{if .data.repository.defaultBranchRef}}{{.data.repository.defaultBranchRef.name}}{{else}}main{{end}}|{{.data.repository.isArchived}}')

  if [ -z "$repo_info" ] || [ "$repo_info" = "||" ]; then
    error "Repository $ORG_NAME/$REPO_NAME not found or not accessible"
  fi

  repos="$repo_info"
else
  # All repos mode
  echo "Generating code scanning coverage report for: $ORG_NAME" >&2

  # shellcheck disable=SC2086
  repos=$(gh api graphql $GH_HOST_FLAG --paginate -F org="$ORG_NAME" -f query='
query($org: String!, $endCursor: String) {
  organization(login: $org) {
    repositories(first: 100, after: $endCursor) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        name
        updatedAt
        isArchived
        defaultBranchRef {
          name
        }
      }
    }
  }
}' --template '{{range .data.organization.repositories.nodes}}{{.name}}|{{.updatedAt}}|{{if .defaultBranchRef}}{{.defaultBranchRef.name}}{{else}}main{{end}}|{{.isArchived}}{{"\n"}}{{end}}')

  # If sample mode, randomly select SAMPLE_SIZE repos
  if [ "$SAMPLE_MODE" -eq 1 ]; then
    total_available=$(echo "$repos" | grep -c .)
    echo "Sample mode: selecting $SAMPLE_SIZE random repos from $total_available available" >&2
    repos=$(echo "$repos" | sort -R | head -n "$SAMPLE_SIZE")
  fi
fi

while IFS='|' read -r repo_name repo_updated_raw default_branch is_archived; do
  if [ -z "$repo_name" ]; then
    continue
  fi

  repo_updated=$(echo "$repo_updated_raw" | cut -d'T' -f1)
  # Default to 'main' if no default branch is set (empty repos)
  if [ -z "$default_branch" ]; then
    default_branch="main"
  fi
  # Normalize archived status to Yes/No
  if [ "$is_archived" = "true" ]; then
    archived_display="Yes"
  else
    archived_display="No"
  fi

  total_repos=$((total_repos + 1))
  echo "[$total_repos] Processing: $repo_name (default branch: $default_branch)" >&2

  # Get repository languages
  languages=$(get_repo_languages "$repo_name")

  # Check CodeQL status
  codeql_status=$(check_codeql_status "$repo_name")

  # Get scanning info (date, scanned languages, errors, and warnings) for default branch
  scanning_info=$(get_scanning_info "$repo_name" "$default_branch")
  IFS='|' read -r last_scan_date tool_name scanned_languages analysis_error analysis_warning <<< "$scanning_info"

  # Format last scan date, analysis error, and warning
  if [ "$last_scan_date" = "NO_RESULTS" ] || [ -z "$last_scan_date" ]; then
    last_scan_display="Never"
    scanned_languages=""
    analysis_error=""
    analysis_warning=""
  else
    last_scan_display=$(echo "$last_scan_date" | cut -d'T' -f1)
    # Format analysis error
    if [ -z "$analysis_error" ]; then
      analysis_error="None"
    fi
    # Format analysis warning
    if [ -z "$analysis_warning" ]; then
      analysis_warning="None"
    fi
  fi

  # Check for .github/workflows if --check-actions is enabled
  has_workflows="false"
  if [ "$CHECK_ACTIONS" -eq 1 ]; then
    has_workflows=$(has_github_workflows "$repo_name")
  fi

  # Get unscanned CodeQL languages
  unscanned=$(get_unscanned_codeql_languages "$languages" "$scanned_languages" "$has_workflows")

  # Get open alerts count
  open_alerts=$(get_open_alerts_count "$repo_name")

  # Build CSV line (no quotes except for error/warning fields which may contain commas)
  if [ "$CHECK_WORKFLOWS" -eq 1 ]; then
    # Get CodeQL workflow status (only when --check-workflows is enabled)
    workflow_status=$(get_codeql_workflow_status "$repo_name")
    csv_line="$repo_name,$default_branch,$repo_updated,$archived_display,$languages,$codeql_status,$last_scan_display,$scanned_languages,$unscanned,$open_alerts,\"$analysis_error\",\"$analysis_warning\",$workflow_status"
  else
    csv_line="$repo_name,$default_branch,$repo_updated,$archived_display,$languages,$codeql_status,$last_scan_display,$scanned_languages,$unscanned,$open_alerts,\"$analysis_error\",\"$analysis_warning\""
  fi
  output_line "$csv_line"

done <<< "$repos"

echo "" >&2
echo "Report complete. Processed $total_repos repositories." >&2

if [ -n "$OUTPUT_FILE" ]; then
  echo "Report saved to: $OUTPUT_FILE" >&2

  # Generate sub-reports for actionable items
  # Get the base name without extension for sub-reports
  base_name="${OUTPUT_FILE%.csv}"

  # Sub-report 1: Repos with disabled CodeQL (Disabled, No, Requires GHAS, No Scans)
  # Excludes archived repos since they can't be remediated
  disabled_report="${base_name}-disabled.csv"
  echo "$CSV_HEADER" > "$disabled_report"
  # Column 4 is Archived, Column 6 is CodeQL Enabled
  awk -F',' 'NR>1 && $4 != "Yes" && ($6 ~ /Disabled|^No$|Requires GHAS|No Scans/) {print $0}' "$OUTPUT_FILE" >> "$disabled_report"
  disabled_count=$(($(wc -l < "$disabled_report") - 1))
  echo "  - Disabled/Not scanning: $disabled_report ($disabled_count repos)" >&2

  # Sub-report 2: Repos with stale scans (repo modified more than 90 days after last scan)
  stale_report="${base_name}-stale.csv"
  echo "$CSV_HEADER" > "$stale_report"
  # Column 3 is Last Updated, Column 7 is Last Default Branch Scan Date
  # Stale = repo was modified more than 90 days after the last scan
  awk -F',' 'NR>1 && $7 != "Never" && $7 != "" {
    last_updated = $3
    last_scan = $7
    if (last_updated != "" && last_scan != "") {
      # Add 90 days to last_scan and compare with last_updated
      split(last_scan, d, "-")
      scan_year = d[1]; scan_month = d[2]; scan_day = d[3]
      # Add 90 days (approximate as 3 months)
      scan_month += 3
      if (scan_month > 12) { scan_month -= 12; scan_year += 1 }
      cutoff = sprintf("%04d-%02d-%02d", scan_year, scan_month, scan_day)
      if (last_updated > cutoff) print $0
    }
  }' "$OUTPUT_FILE" >> "$stale_report"
  stale_count=$(($(wc -l < "$stale_report") - 1))
  echo "  - Stale scans (modified >90 days after scan): $stale_report ($stale_count repos)" >&2

  # Sub-report 3: Repos with missing CodeQL languages (only if already scanning something)
  missing_langs_report="${base_name}-missing-languages.csv"
  echo "$CSV_HEADER" > "$missing_langs_report"
  # Column 6 is CodeQL Enabled (must be "Yes"), Column 9 is Unscanned CodeQL Languages
  # Only include repos that are actively scanning but missing some languages
  awk -F',' 'NR>1 && $6 == "Yes" && $9 != "" && $9 != "None" && $9 != "N/A" {print $0}' "$OUTPUT_FILE" >> "$missing_langs_report"
  missing_count=$(($(wc -l < "$missing_langs_report") - 1))
  echo "  - Missing CodeQL languages: $missing_langs_report ($missing_count repos)" >&2

  # Sub-report 4: Repos with open alerts
  alerts_report="${base_name}-open-alerts.csv"
  echo "$CSV_HEADER" > "$alerts_report"
  # Column 10 is Open Alerts - filter where > 0
  awk -F',' 'NR>1 && $10 ~ /^[0-9]+$/ && $10 > 0 {print $0}' "$OUTPUT_FILE" >> "$alerts_report"
  alerts_count=$(($(wc -l < "$alerts_report") - 1))
  echo "  - Repos with open alerts: $alerts_report ($alerts_count repos)" >&2

  # Sub-report 5: Repos with analysis errors or warnings
  errors_report="${base_name}-analysis-issues.csv"
  echo "$CSV_HEADER" > "$errors_report"
  # Column 11 is Analysis Errors (quoted), Column 12 is Analysis Warnings (quoted)
  # Filter where not "None" and not empty (accounting for quotes)
  awk -F',' 'NR>1 {
    err = $11; warn = $12
    gsub(/"/, "", err); gsub(/"/, "", warn)
    if ((err != "" && err != "None") || (warn != "" && warn != "None")) print $0
  }' "$OUTPUT_FILE" >> "$errors_report"
  errors_count=$(($(wc -l < "$errors_report") - 1))
  echo "  - Analysis errors/warnings: $errors_report ($errors_count repos)" >&2
fi
