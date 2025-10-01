#!/bin/bash

# Creates a runner group in an organization
#
# Usage: ./create-runner-groups-in-organization.sh <organization> <runner-group-name> <visibility> [--allow-public] [--repo-file <file>]
#
# Arguments:
#   organization       - The organization name
#   runner-group-name  - The name for the runner group
#   visibility         - The visibility of the runner group (all or selected)
#   --allow-public     - Optional flag: Allow public repositories to use this runner group
#   --repo-file        - Optional: File containing repository names (one per line) when visibility is 'selected'
#
# Example: ./create-runner-groups-in-organization.sh my-org "Production Runners" all
# Example: ./create-runner-groups-in-organization.sh my-org "Production Runners" selected --repo-file repos.txt
# Example: ./create-runner-groups-in-organization.sh my-org "Production Runners" selected --allow-public --repo-file repos.txt
#
# Note: When visibility is 'selected', you must provide --repo-file with repository names.
#       The file should contain one repository name per line (e.g., "repo1" or "my-org/repo1")

if [ $# -lt 3 ]; then
  echo "Usage: $0 <organization> <runner-group-name> <visibility> [--allow-public] [--repo-file <file>]"
  echo "Example: ./create-runner-groups-in-organization.sh my-org \"Production Runners\" all"
  echo "Example: ./create-runner-groups-in-organization.sh my-org \"Production Runners\" selected --repo-file repos.txt"
  exit 1
fi

org="$1"
runner_group_name="$2"
visibility="$3"
allow_public="false"
repos_file=""

# Parse optional arguments
shift 3
while [ $# -gt 0 ]; do
  case "$1" in
    --allow-public)
      allow_public="true"
      shift
      ;;
    --repo-file)
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        repos_file="$2"
        shift 2
      else
        echo "❌  Error: --repo-file requires a file path argument"
        exit 1
      fi
      ;;
    *)
      echo "❌  Error: Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Validate visibility parameter
if [[ ! "$visibility" =~ ^(all|selected)$ ]]; then
  echo "❌  Error: visibility must be one of: all or selected"
  exit 1
fi

# Check if repos file is provided when visibility is selected
if [ "$visibility" = "selected" ] && [ -z "$repos_file" ]; then
  echo "⚠️  Warning: --repo-file not provided for 'selected' visibility"
  echo "The runner group will be created but no repositories will be selected."
  echo "You can add repositories later using the GitHub UI or API."
fi

# Check if repos file exists
if [ -n "$repos_file" ] && [ ! -f "$repos_file" ]; then
  echo "❌  Error: Repository file not found: $repos_file"
  exit 1
fi

echo "Creating runner group '$runner_group_name' in organization: $org"
echo "  Visibility: $visibility"
echo "  Allow public repositories: $allow_public"

# Build the JSON payload
json_payload=$(jq -n \
  --arg name "$runner_group_name" \
  --arg visibility "$visibility" \
  --argjson allows_public "$allow_public" \
  '{name: $name, visibility: $visibility, allows_public_repositories: $allows_public}')

# Add selected repository IDs if provided
if [ -n "$repos_file" ]; then
  echo "  Looking up repository IDs..."
  repo_ids_array=()
  public_repos_found=()
  
  while IFS= read -r repo_name || [ -n "$repo_name" ]; do
    # Skip empty lines
    if [ -z "$repo_name" ]; then
      continue
    fi
    
    # Remove any leading/trailing whitespace
    repo_name=$(echo "$repo_name" | xargs)
    
    # If the repo name includes the org (org/repo), extract just the repo name
    if [[ "$repo_name" == *"/"* ]]; then
      repo_name=$(echo "$repo_name" | cut -d'/' -f2)
    fi
    
    echo "    Looking up ID for: $repo_name"
    repo_info=$(gh api "/repos/$org/$repo_name" 2>/dev/null)
    
    if [ -z "$repo_info" ]; then
      echo "    ⚠️  Warning: Could not find repository '$repo_name', skipping..."
      continue
    fi
    
    repo_id=$(echo "$repo_info" | jq -r '.id')
    repo_visibility=$(echo "$repo_info" | jq -r '.visibility')
    
    # Check if repository is public and --allow-public is not set
    if [ "$repo_visibility" = "public" ] && [ "$allow_public" = "false" ]; then
      public_repos_found+=("$repo_name")
    fi
    
    repo_ids_array+=("$repo_id")
  done < "$repos_file"
  
  if [ ${#repo_ids_array[@]} -eq 0 ]; then
    echo "Error: No valid repository IDs found"
    exit 1
  fi
  
  echo "  Selected repositories: ${#repo_ids_array[@]} repositories"
  
  # Add repository IDs to JSON payload as proper array of numbers
  repo_ids_json=$(printf '%s\n' "${repo_ids_array[@]}" | jq -s 'map(tonumber)')
  json_payload=$(echo "$json_payload" | jq --argjson ids "$repo_ids_json" '. + {selected_repository_ids: $ids}')
fi

# Create the runner group
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "/orgs/$org/actions/runner-groups" \
  --input - <<< "$json_payload"

# Check if the command was successful
if [ $? -ne 0 ]; then
  echo "Failed to create runner group: $runner_group_name"
  exit 1
fi

echo "Successfully created runner group: $runner_group_name"

# Show warning about public repositories at the end if any were found
if [ -n "$repos_file" ] && [ ${#public_repos_found[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  Warning: Found ${#public_repos_found[@]} public repository(ies) but --allow-public flag is not set:"
  for public_repo in "${public_repos_found[@]}"; do
    echo "  - $public_repo"
  done
  echo "These repositories will be added to the runner group, but the group won't allow public repositories."
  echo "Consider using --allow-public flag if you want to allow public repositories to use this runner group."
fi
