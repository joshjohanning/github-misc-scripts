#!/bin/bash

# Exports all repository variables from all repositories in an organization to a CSV file

# Usage function
usage() {
  echo "Usage: $0 <organization> [output-file] [--repos-file=FILE]"
  echo ""
  echo "Exports all repository variables from all repositories in an organization to CSV"
  echo ""
  echo "Examples:"
  echo "  ./get-actions-repository-variables-in-organization.sh my-org"
  echo "  ./get-actions-repository-variables-in-organization.sh my-org repo-variables.csv"
  echo "  ./get-actions-repository-variables-in-organization.sh my-org output.csv --repos-file=repos.txt"
  echo ""
  echo "Notes:"
  echo "  - Default output file is 'actions-repository-variables-ORGANIZATION-TIMESTAMP.csv'"
  echo "  - Requires write access to repositories to retrieve variables and their values"
  echo "  - --repos-file: Optional file containing repository names (one per line, format: owner/repo)"
  exit 1
}

# Check if organization is provided
if [ -z "$1" ]; then
  usage
fi

org="$1"
output_file=""
repos_file=""

# Parse arguments
shift  # Remove organization from arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --repos-file=*)
      repos_file="${1#*=}"
      shift
      ;;
    *)
      # If no output file set yet, this is the output file
      if [ -z "$output_file" ]; then
        output_file="$1"
      fi
      shift
      ;;
  esac
done

# Set default output file if not provided
if [ -z "$output_file" ]; then
  timestamp=$(date +"%Y%m%d_%H%M%S")
  output_file="actions-repository-variables-${org}-${timestamp}.csv"
fi

echo "🔍 Fetching all repositories in organization: $org"
echo "📄 Output file: $output_file"
echo ""

# Get list of repositories - either from file or from organization
if [ -n "$repos_file" ]; then
  if [ ! -f "$repos_file" ]; then
    echo "❌ Repository file '$repos_file' not found"
    exit 1
  fi
  echo "📁 Using repository list from file: $repos_file"
  repos=$(cat "$repos_file" | grep -v '^#' | grep -v '^[[:space:]]*$')
else
  # Get list of all repositories in the organization
  # Capture both output and errors to check for authentication issues
  repos_output=$(gh api graphql --paginate -f org="$org" -f query='
query($org: String!, $endCursor: String) {
  organization(login: $org) {
    repositories(first: 100, after: $endCursor) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        owner {
          login
        }
        name
      }
    }
  }
}' --template '{{range .data.organization.repositories.nodes}}{{printf "%s/%s\n" .owner.login .name}}{{end}}' 2>&1)
  
  # Check for authentication errors
  if echo "$repos_output" | grep -q "Bad credentials\|HTTP 401"; then
    echo "🔐❌ Authentication failed! Please check your GitHub CLI authentication."
    echo "Run 'gh auth login' to authenticate or 'gh auth status' to check current authentication."
    exit 1
  fi
  
  repos="$repos_output"
fi

# Check if repositories were found or if there were other errors
if [ -z "$repos" ] || echo "$repos" | grep -q "message.*status.*401"; then
  if echo "$repos" | grep -q "401"; then
    echo "🔐❌ Authentication failed! Please check your GitHub CLI authentication."
    echo "Run 'gh auth login' to authenticate or 'gh auth status' to check current authentication."
  else
    echo "❌ No repositories found in organization '$org' or insufficient permissions"
  fi
  exit 1
fi

repo_count=$(echo "$repos" | wc -l | tr -d ' ')
echo "📊 Found $repo_count repositories"
echo ""

# Create CSV header
echo "Repository,Variable Name,Value,Created At,Updated At" > "$output_file"

processed_repos=0

# Process each repository
echo "$repos" | while IFS= read -r repo; do
  if [ -n "$repo" ]; then
    ((processed_repos++))
    echo "🔄 Processing repository $processed_repos/$repo_count: $repo"
    
    # Get list of variables for this repository (names only)
    variable_names=$(gh api repos/"$repo"/actions/variables --paginate 2>/dev/null | jq -r '.variables[]? | .name' 2>/dev/null)
    
    if [ -n "$variable_names" ]; then
      repo_var_count=$(echo "$variable_names" | wc -l | tr -d ' ')
      echo "  ✅ Found $repo_var_count variables"
      
      # Get each variable individually to retrieve its value
      echo "$variable_names" | while IFS= read -r var_name; do
        if [ -n "$var_name" ]; then
          # Get individual variable details including value
          var_details=$(gh api repos/"$repo"/actions/variables/"$var_name" 2>/dev/null)
          
          if [ -n "$var_details" ]; then
            name=$(echo "$var_details" | jq -r '.name // ""')
            value=$(echo "$var_details" | jq -r '.value // ""')
            created_at=$(echo "$var_details" | jq -r '.created_at // ""')
            updated_at=$(echo "$var_details" | jq -r '.updated_at // ""')
            
            # Sanitize value for CSV: remove CR/LF, escape quotes/commas, and guard against CSV injection
            escaped_value=$(printf "%s" "$value" | tr '\r\n' '  ' | sed 's/"/\\"/g; s/,/\\,/g')
            if [[ "$escaped_value" =~ ^[=+\-@] ]]; then
              escaped_value="'$escaped_value'"
            fi
            
            echo "\"$repo\",\"$name\",\"$escaped_value\",\"$created_at\",\"$updated_at\"" >> "$output_file"
          fi
        fi
      done
    else
      echo "  ℹ️  No variables found"
    fi
  fi
done

# Get final count of variables
final_total=$(tail -n +2 "$output_file" | wc -l | tr -d ' ')

echo ""
echo "✅ Export completed successfully!"
echo "📊 Summary:"
echo "  - Repositories processed: $repo_count"
echo "  - Total variables exported: $final_total"
echo "  - Output file: $output_file"
