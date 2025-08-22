#!/bin/bash

# Returns a list of all actions used in an organization using the SBOM API

# Example usage:
#  - ./get-actions-usage-in-organization.sh joshjohanning-org count-by-version txt > output.txt
#  - ./get-actions-usage-in-organization.sh joshjohanning-org count-by-action md > output.md
#  - ./get-actions-usage-in-organization.sh joshjohanning-org count-by-version txt --resolve-shas > output.txt
#  - ./get-actions-usage-in-organization.sh joshjohanning-org count-by-action txt --dedupe-by-repo > output.txt

# count-by-version (default): returns a count of actions by version; actions/checkout@v2 would be counted separately from actions/checkout@v3
# count-by-action: returns a count of actions by action name; only care about actions/checkout usage, not the version

# Notes:
# - The count returned is the # of repositories that use the action - if a single repository uses the action 2x times, it will only be counted 1x
# - The script will take about 1 minute per 100 repositories
# - Using --resolve-shas will add significant time to resolve commit SHAs to their corresponding tags

if [ $# -lt 1 ] || [ $# -gt 5 ] ; then
    echo "Usage: $0 <org> <count-by-version (default) | count-by-action> <report format: txt (default) | csv | md> [--resolve-shas] [--dedupe-by-repo]"
    exit 1
fi

org=$1
count_method=$2
report_format=$3
resolve_shas=""
dedupe_by_repo=""

# Parse parameters and flags
for arg in "$@"; do
    if [ "$arg" == "--resolve-shas" ]; then
        resolve_shas="true"
    elif [ "$arg" == "--dedupe-by-repo" ]; then
        dedupe_by_repo="true"
    fi
done

if [ -z "$count_method" ]; then
    count_method="count-by-version"
fi

if [ -z "$report_format" ]; then
    report_format="txt"
fi

# Validate that --resolve-shas only works with count-by-version
if [ "$resolve_shas" == "true" ] && [ "$count_method" == "count-by-action" ]; then
    echo "Error: --resolve-shas can only be used with count-by-version (not count-by-action)" >&2
    exit 1
fi

# Validate that --dedupe-by-repo only works with count-by-action
if [ "$dedupe_by_repo" == "true" ] && [ "$count_method" != "count-by-action" ]; then
    echo "Error: --dedupe-by-repo can only be used with count-by-action" >&2
    exit 1
fi

# Function to resolve SHA to tag for a given action
resolve_sha_to_tag() {
    local action_with_sha="$1"
    local action_name
    local sha
    
    action_name=$(echo "$action_with_sha" | cut -d'@' -f1)
    sha=$(echo "$action_with_sha" | cut -d'@' -f2)
    
    # Only process if it looks like a SHA (40 character hex string)
    if [[ ${#sha} -eq 40 && "$sha" =~ ^[a-f0-9]+$ ]]; then
        # Try to find a tag that points to this commit SHA
        local tag_name
        # First try to find a semantic version tag (prefer v1.2.3 over v1)
        tag_name=$(gh api repos/"$action_name"/git/refs/tags --paginate 2>/dev/null | jq -r --arg sha "$sha" '.[] | select(.object.sha == $sha) | .ref | sub("refs/tags/"; "")' 2>/dev/null | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        
        # If no semantic version found, fall back to any tag
        if [ -z "$tag_name" ]; then
            tag_name=$(gh api repos/"$action_name"/git/refs/tags --paginate 2>/dev/null | jq -r --arg sha "$sha" '.[] | select(.object.sha == $sha) | .ref | sub("refs/tags/"; "")' 2>/dev/null | head -1)
        fi
        
        if [ -n "$tag_name" ] && [ "$tag_name" != "null" ]; then
            echo "$action_with_sha # $tag_name"
        else
            echo "$action_with_sha # sha not associated to tag"
        fi
    else
        echo "$action_with_sha"
    fi
}

repos=$(gh api graphql --paginate -F org="$org" -f query='query($org: String!$endCursor: String){
organization(login:$org) {
    repositories(first:100,after: $endCursor) {
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
}' --template '{{range .data.organization.repositories.nodes}}{{printf "%s/%s\n" .owner.login .name}}{{end}}')

# if report_format = md
if [ "$report_format" == "md" ]; then
    echo "## 🚀 Actions Usage in Organization: $org"
    echo ""
    echo "| Count | Action |"
    echo "| --- | --- |"
elif [ "$report_format" == "csv" ]; then
    echo "Count,Action"
fi

actions=""
repos_without_dependency_graph=()

for repo in $repos; do
    # Try to get SBOM data - if it fails, dependency graph is likely disabled
    sbom_data=$(gh api repos/$repo/dependency-graph/sbom --jq '.sbom.packages[].externalRefs.[0].referenceLocator' 2>&1)
    
    # Also check if the API call returned an HTTP error code
    if echo "$sbom_data" | grep -q "HTTP "; then
        repos_without_dependency_graph+=("$repo")
        continue
    fi
    
    repo_actions=$(echo "$sbom_data" | grep "pkg:githubactions" | sed 's/pkg:githubactions\///' | sed 's/%2A/*/g' 2>/dev/null || true)
    if [ "$dedupe_by_repo" == "true" ]; then
        # For dedupe mode, prefix each action with the repo name so we can track repo usage
        # Use awk to avoid sed delimiter issues with special characters
        repo_actions=$(echo "$repo_actions" | awk -v repo="$repo" '{print repo "|" $0}')
    fi
    actions+="$repo_actions"$'\n'
done

# clean up extra spaces
results=$(echo -e "$actions" | tr -s '\n' '\n' | sed 's/\n\n/\n/g')

# convert version patterns like 4.*.* to v4 format
results=$(echo -e "$results" | sed 's/@\([0-9]\)\.\*\.\*/@v\1/g')

# convert semantic version numbers like @4.3.0 to @v4.3.0 (but not if they already have v, are branches, or are SHAs)
results=$(echo -e "$results" | sed 's/@\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)/@v\1/g')

# resolve SHAs to tags if requested
if [ "$resolve_shas" == "true" ]; then
    # Create temporary file to store resolved results
    temp_results=""
    
    # Process each line and resolve SHAs
    while IFS= read -r line; do
        if [ -n "$line" ] && [ "$line" != " " ]; then
            resolved_line=$(resolve_sha_to_tag "$line")
            if [ -n "$resolved_line" ] && [ "$resolved_line" != " " ]; then
                temp_results+="$resolved_line"$'\n'
            fi
        fi
    done <<< "$results"
    
    # Clean up any trailing newlines
    results=$(echo -e "$temp_results" | sed '/^$/d')
fi

# if count_method=count-by-action, then remove the version from the action name
if [ "$count_method" == "count-by-action" ]; then
    results=$(echo -e "$results" | sed 's/@.*//g')
    
    # If dedupe-by-repo is enabled, count unique repositories per action
    if [ "$dedupe_by_repo" == "true" ]; then
        # Each line now looks like: "repo|action"
        # We want to count unique repos per action
        temp_results=""
        for action in $(echo -e "$results" | cut -d'|' -f2 | sort | uniq); do
            repo_count=$(echo -e "$results" | grep "|$action$" | cut -d'|' -f1 | sort | uniq | wc -l)
            temp_results+="$repo_count $action"$'\n'
        done
        results="$temp_results"
    else
        # Strip repo prefixes if they exist (but shouldn't in non-dedupe mode)
        results=$(echo -e "$results" | sed 's/^[^|]*|//')
    fi
fi

if [ "$count_method" == "count-by-action" ] && [ "$dedupe_by_repo" == "true" ]; then
    # Results are already formatted as "count action" from the dedupe logic
    results=$(echo -e "$results" | sed '/^$/d' | sort -nr | awk '{$1=$1; print $1 " " substr($0, index($0, $2))}')
else
    # Standard processing: count occurrences
    results=$(echo -e "$results" | sed '/^$/d' | sort | uniq -c | sort -nr | awk '{$1=$1; print $1 " " substr($0, index($0, $2))}')
fi

# if report_format = md
if [ "$report_format" == "md" ]; then
  echo -e "$results" | awk '{print "| " $1 " | " substr($0, index($0, $2)) " |"}'
elif [ "$report_format" == "csv" ]; then
  echo -e "$results" | awk '{print $1 "," substr($0, index($0, $2))}'
else
  echo -e "$results"
fi

# Add explanatory note for count-by-action mode (but not for CSV)
if [ "$count_method" == "count-by-action" ] && [ "$report_format" != "csv" ]; then
  if [ "$dedupe_by_repo" == "true" ]; then
    note_text="Count represents the number of repositories using each action (deduplicated per repository)."
  else
    note_text="Count represents unique action@version combinations (versions stripped). Each repository using different versions of the same action contributes multiple counts."
  fi
  echo ""
  if [ "$report_format" == "md" ]; then
    echo "📝 **Note**: $note_text"
  elif [ "$report_format" == "txt" ]; then
    echo "📝 Note: $note_text"
  fi
fi

# Add explanatory note for count-by-version mode (but not for CSV)
if [ "$count_method" == "count-by-version" ] && [ "$report_format" != "csv" ]; then
  note_text="Count represents unique action@version combinations (with each unique action@version combination only showing up once per repository)."
  echo ""
  if [ "$report_format" == "md" ]; then
    echo "📝 **Note**: $note_text"
  elif [ "$report_format" == "txt" ]; then
    echo "📝 Note: $note_text"
  fi
fi

# Show warning about repos that couldn't be analyzed (but not for CSV)
if [ ${#repos_without_dependency_graph[@]} -gt 0 ] && [ "$report_format" != "csv" ]; then
  echo "" >&2
  echo "⚠️  Warning: The following repositories could not be analyzed (likely due to disabled Dependency Graph or permissions):" >&2
  for repo in "${repos_without_dependency_graph[@]}"; do
    echo "  - $repo" >&2
  done
  echo "" >&2
fi
