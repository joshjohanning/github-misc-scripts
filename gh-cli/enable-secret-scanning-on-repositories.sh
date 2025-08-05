#!/bin/bash

# Enable secret scanning features on repositories
# Supports both organization-wide processing and file-based repository lists
# Can enable multiple secret scanning features: basic scanning, push protection, AI detection, non-provider patterns
# Uses the repository update API to enable secret scanning features
# Usage: <org|file> [features] [--dry-run]

# Define features in a structured way (name|api_field|display_name|enable_var|status_var)
declare -a FEATURES=(
  "scanning|secret_scanning|Secret scanning|enable_scanning|secret_scanning_enabled"
  "push-protection|secret_scanning_push_protection|Push protection|enable_push_protection|push_protection_enabled"
  "ai-detection|secret_scanning_ai_detection|AI detection|enable_ai_detection|ai_detection_enabled"
  "non-provider-patterns|secret_scanning_non_provider_patterns|Non-provider patterns|enable_non_provider_patterns|non_provider_patterns_enabled"
  "validity-checks|secret_scanning_validity_checks|Validity checks|enable_validity_checks|validity_checks_enabled"
)

# Helper function to build JSON payload for secret scanning features
build_json_payload() {
  local include_advanced_security="$1"
  local payload='{"security_and_analysis":{'
  local has_changes=false
  
  # Add Advanced Security if requested
  if [ "$include_advanced_security" = true ] && [ "$repo_private" = "true" ] && [ "$advanced_security_enabled" != "enabled" ]; then
    payload+='"advanced_security":{"status":"enabled"},'
    has_changes=true
  fi
  
  # Process all features
  for feature_def in "${FEATURES[@]}"; do
    IFS='|' read -r _ api_field _ enable_var status_var <<< "$feature_def"
    local enable_value="${!enable_var}"
    local status_value="${!status_var}"
    
    if [ "$enable_value" = true ] && [ "$status_value" != "enabled" ]; then
      payload+='"'"$api_field"'":{"status":"enabled"},'
      has_changes=true
    fi
  done
  
  # Remove trailing comma and close JSON
  payload=$(echo "$payload" | sed 's/,$//')
  payload+='}}'
  
  # Return both payload and whether there are changes
  echo "$has_changes|$payload"
}

# Helper function to check if any feature needs updating
check_if_updates_needed() {
  for feature_def in "${FEATURES[@]}"; do
    IFS='|' read -r _ _ _ enable_var status_var <<< "$feature_def"
    local enable_value="${!enable_var}"
    local status_value="${!status_var}"
    
    if [ "$enable_value" = true ] && [ "$status_value" != "enabled" ]; then
      echo "true"
      return 0
    fi
  done
  echo "false"
}

# Helper function to build status messages
build_status_messages() {
  for feature_def in "${FEATURES[@]}"; do
    IFS='|' read -r _ _ display_name enable_var status_var <<< "$feature_def"
    local enable_value="${!enable_var}"
    local status_value="${!status_var}"
    
    if [ "$enable_value" = true ]; then
      if [ "$status_value" != "enabled" ]; then
        status_messages+=("$display_name")
      else
        status_messages+=("✅ $display_name already enabled")
      fi
    fi
  done
}

# Helper function to display dry-run information
show_dry_run_info() {
  echo "  🔍 Would enable the following features:"
  
  for feature_def in "${FEATURES[@]}"; do
    IFS='|' read -r _ _ display_name enable_var status_var <<< "$feature_def"
    local enable_value="${!enable_var}"
    local status_value="${!status_var}"
    
    if [ "$enable_value" = true ] && [ "$status_value" != "enabled" ]; then
      echo "      - $display_name (currently: ${status_value:-disabled})"
    fi
  done
  
  if [ "$repo_private" = "true" ] && [ "$advanced_security_enabled" != "enabled" ]; then
    echo "      Note: Private repo requires Advanced Security to be enabled first"
  fi
}

function print_usage {
  echo "Usage: $0 <org|file> [features] [--dry-run]"
  echo "Example: ./enable-secret-scanning-on-repositories.sh joshjohanning-org"
  echo "Example: ./enable-secret-scanning-on-repositories.sh joshjohanning-org --dry-run"
  echo "Example: ./enable-secret-scanning-on-repositories.sh repos.csv all --dry-run"
  echo "Example: ./enable-secret-scanning-on-repositories.sh repos.csv scanning,push-protection,validity-checks --dry-run"
  echo ""
  echo "org: Organization name to process all repositories"
  echo "file: CSV file with repository names (one per line, format: owner/repo)"
  echo "features: Comma-separated list of features to enable (defaults to 'scanning')"
  echo "  - scanning: Basic secret scanning"
  echo "  - push-protection: Secret scanning push protection"
  echo "  - ai-detection: Secret scanning AI detection"
  echo "  - non-provider-patterns: Secret scanning non-provider patterns"
  echo "  - validity-checks: Secret scanning validity checks"
  echo "  - all: Enable all available features"
  echo "--dry-run: Only show what would be updated without making changes"
  echo ""
  echo "Note: This requires admin access to the repositories and the organization must have"
  echo "GitHub Advanced Security enabled to use secret scanning on private repositories."
  exit 1
}

if [ -z "$1" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  print_usage
fi

org_or_file="$1"
dry_run=false
features="scanning"

# Parse parameters: <org|file> [features] [--dry-run]
# Check if --dry-run is present
if [[ "$*" == *"--dry-run"* ]]; then
  dry_run=true
  # Remove --dry-run from parameters and get features
  params=()
  for param in "$@"; do
    if [ "$param" != "--dry-run" ]; then
      params+=("$param")
    fi
  done
  
  # Get features (second parameter after removing --dry-run)
  if [ ${#params[@]} -gt 1 ]; then
    features="${params[1]}"
  fi
else
  # No --dry-run flag: second parameter is features
  features="${2:-scanning}"
fi

# Parse features parameter
enable_scanning=false
enable_push_protection=false
enable_ai_detection=false
enable_non_provider_patterns=false
enable_validity_checks=false

if [ "$features" = "all" ]; then
  enable_scanning=true
  enable_push_protection=true
  enable_ai_detection=true
  enable_non_provider_patterns=true
  enable_validity_checks=true
else
  IFS=',' read -ra FEATURE_ARRAY <<< "$features"
  for feature in "${FEATURE_ARRAY[@]}"; do
    case "$feature" in
      scanning)
        enable_scanning=true
        ;;
      push-protection)
        enable_push_protection=true
        ;;
      ai-detection)
        enable_ai_detection=true
        ;;
      non-provider-patterns)
        enable_non_provider_patterns=true
        ;;
      validity-checks)
        enable_validity_checks=true
        ;;
      *)
        echo "Error: Unknown feature '$feature'"
        echo "Valid features: scanning, push-protection, ai-detection, non-provider-patterns, validity-checks, all"
        exit 1
        ;;
    esac
  done
fi

echo "Features to enable:"
[ "$enable_scanning" = true ] && echo "  - Secret scanning"
[ "$enable_push_protection" = true ] && echo "  - Push protection"
[ "$enable_ai_detection" = true ] && echo "  - AI detection"
[ "$enable_non_provider_patterns" = true ] && echo "  - Non-provider patterns"
[ "$enable_validity_checks" = true ] && echo "  - Validity checks"
echo ""

# Check if the first parameter is a file or organization
if [ -f "$org_or_file" ]; then
  echo "Reading repositories from file: $org_or_file"
  echo ""
  
  # Read repositories from file (expecting format: owner/repo)
  repos_full=$(grep -v '^#' "$org_or_file" | grep -v '^$' | tr -d '\r')
  
  if [ -z "$repos_full" ]; then
    echo "No repositories found in file: $org_or_file"
    echo "Expected format: owner/repo (one per line)"
    exit 1
  fi
elif [[ "$org_or_file" == *.txt ]] || [[ "$org_or_file" == *.csv ]] || [[ "$org_or_file" == */* ]]; then
  echo "Error: File '$org_or_file' not found."
  echo "Please ensure the file exists and use the correct path."
  echo "Current working directory: $(pwd)"
  exit 1
else
  org="$org_or_file"
  echo "Getting repositories for organization: $org"
  echo ""
  
  # Get all repositories in the organization
  repos=$(gh api --paginate "/orgs/$org/repos" --jq '.[] | select(.archived == false) | .name')
  
  if [ -z "$repos" ]; then
    echo "No repositories found or no access to organization: $org"
    exit 1
  fi
  
  # Convert to full repo format (org/repo)
  repos_full=""
  while IFS= read -r repo; do
    if [ -n "$repo" ]; then
      repos_full="${repos_full}${org}/${repo}"$'\n'
    fi
  done <<< "$repos"
fi

total_repos=$(echo "$repos_full" | grep -c '^[^[:space:]]*$')
echo "Found $total_repos repositories to process"

if [ "$dry_run" = "true" ]; then
  echo ""
  echo "DRY RUN MODE - No changes will be made"
fi

echo ""

success_count=0
error_count=0

while IFS= read -r repo_full; do
  if [ -n "$repo_full" ]; then
    echo "Processing repository: $repo_full"
    
    # Get current repository settings to check if secret scanning is already enabled
    current_settings=$(gh api "/repos/$repo_full" --jq '{security_and_analysis}' 2>/dev/null)
    
    if [ $? -ne 0 ]; then
      echo "  ❌ Error: Could not access repository $repo_full (insufficient permissions or repo doesn't exist)"
      ((error_count++))
      echo ""
      continue
    fi
    
    # Check current secret scanning status
    secret_scanning_enabled=$(echo "$current_settings" | jq -r '.security_and_analysis.secret_scanning.status' 2>/dev/null)
    push_protection_enabled=$(echo "$current_settings" | jq -r '.security_and_analysis.secret_scanning_push_protection.status' 2>/dev/null)
    ai_detection_enabled=$(echo "$current_settings" | jq -r '.security_and_analysis.secret_scanning_ai_detection.status' 2>/dev/null)
    non_provider_patterns_enabled=$(echo "$current_settings" | jq -r '.security_and_analysis.secret_scanning_non_provider_patterns.status' 2>/dev/null)
    validity_checks_enabled=$(echo "$current_settings" | jq -r '.security_and_analysis.secret_scanning_validity_checks.status' 2>/dev/null)
    advanced_security_enabled=$(echo "$current_settings" | jq -r '.security_and_analysis.advanced_security.status' 2>/dev/null)
    
    # Check if repository is private
    repo_private=$(gh api "/repos/$repo_full" --jq '.private' 2>/dev/null)
    
    # Check what needs to be enabled
    needs_update=false
    status_messages=()
    
    # Build status messages and check if updates are needed
    build_status_messages
    needs_update=$(check_if_updates_needed)
    
    # Display current status
    for msg in "${status_messages[@]}"; do
      echo "  $msg"
    done
    
    if [ "$needs_update" = false ]; then
      echo "  ✅ All requested features already enabled"
    else
      if [ "$dry_run" = "true" ]; then
        show_dry_run_info
      else
        echo "  🔄 Enabling features..."
        
        # Build JSON payload for API call (include Advanced Security if needed)
        result=$(build_json_payload true)
        has_changes=$(echo "$result" | cut -d'|' -f1)
        json_payload=$(echo "$result" | cut -d'|' -f2)
        
        # Only send API request if there are actual changes to make
        if [ "$has_changes" = "true" ]; then
          if [ "$repo_private" = "true" ] && [ "$advanced_security_enabled" != "enabled" ]; then
            echo "      Private repository detected - enabling Advanced Security..."
          fi
          
          echo "      Sending API request..."
          response=$(echo "$json_payload" | gh api -X PATCH "/repos/$repo_full" --input - 2>&1)
          
          if [ $? -eq 0 ]; then
            echo "  ✅ Successfully enabled requested features"
            ((success_count++))
          else
            # Check if error is about Advanced Security not being available
            if echo "$response" | grep -q "not available.*pre-requisite"; then
              echo "      Advanced Security not required - retrying without it..."
              
              # Rebuild payload without Advanced Security
              retry_result=$(build_json_payload false)
              has_retry_changes=$(echo "$retry_result" | cut -d'|' -f1)
              retry_payload=$(echo "$retry_result" | cut -d'|' -f2)
              
              if [ "$has_retry_changes" = "true" ]; then
                echo "      Retrying API request without Advanced Security..."
                retry_response=$(echo "$retry_payload" | gh api -X PATCH "/repos/$repo_full" --input - 2>&1)
                
                if [ $? -eq 0 ]; then
                  echo "  ✅ Successfully enabled requested features"
                  ((success_count++))
                else
                  echo "  ❌ Error enabling features:"
                  echo "     $retry_response"
                  ((error_count++))
                fi
              else
                echo "  ✅ No additional features to enable"
              fi
            else
              echo "  ❌ Error enabling features:"
              echo "     $response"
              ((error_count++))
            fi
          fi
        else
          echo "  ✅ All requested features already enabled (no API call needed)"
        fi
      fi
    fi
    
    echo ""
  fi
done <<< "$repos_full"

# Summary
echo "=================================================="
echo "SUMMARY"
echo "=================================================="
echo "Total repositories processed: $total_repos"

if [ "$dry_run" = "true" ]; then
  echo "Mode: DRY RUN (no changes made)"
else
  echo "Successfully updated: $success_count"
  echo "Errors encountered: $error_count"
  
  if [ $error_count -gt 0 ]; then
    echo ""
    echo "Note: Errors may occur due to:"
    echo "- Insufficient permissions (need admin access to repository)"
    echo "- GitHub Advanced Security not enabled for private repositories"
    echo "- Repository settings that don't allow secret scanning"
    echo "- API rate limits"
  fi
fi
