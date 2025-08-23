#!/bin/bash

# Returns a list of all actions used in a repository using the SBOM API

# Example usage:
#  - ./get-actions-usage-in-repository.sh joshjohanning-org ghas-demo
#  - ./get-actions-usage-in-repository.sh joshjohanning-org ghas-demo --resolve-shas

# Notes:
# - Using --resolve-shas will add significant time to resolve commit SHAs to their corresponding tags

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <org> <repo> [--resolve-shas]"
    exit 1
fi

org=$1
repo=$2
resolve_shas=""

# Parse parameters and flags
for arg in "$@"; do
    if [ "$arg" == "--resolve-shas" ]; then
        resolve_shas="true"
    fi
done

# Function to resolve SHA to tag for a given action
resolve_sha_to_tag() {
    local action_with_sha="$1"
    local action_name
    local sha
    
    action_name=$(echo "$action_with_sha" | cut -d'@' -f1)
    sha=$(echo "$action_with_sha" | cut -d'@' -f2)
    
    # Only process if it looks like a SHA (40 character hex string)
    if [[ ${#sha} -eq 40 && "$sha" =~ ^[a-f0-9]+$ ]]; then
        # Try to find a tag that points to this commit SHA (handles both lightweight and annotated tags)
        local tag_name
        # First try to find a semantic version tag (prefer v1.2.3 over v1)
        tag_name=$(
            {
                # Get lightweight tags
                gh api repos/"$action_name"/git/refs/tags --paginate 2>/dev/null | \
                    jq -r --arg sha "$sha" '.[] | select(.object.sha == $sha) | .ref | sub("refs/tags/"; "")' 2>/dev/null
                
                # Get annotated tags (dereference to commit SHA)
                gh api repos/"$action_name"/tags --paginate 2>/dev/null | \
                    jq -r --arg sha "$sha" '.[] | select(.commit.sha == $sha) | .name' 2>/dev/null
            } | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+' | head -1
        )
        
        # If no semantic version found, fall back to any tag
        if [ -z "$tag_name" ]; then
            tag_name=$(
                {
                    # Get lightweight tags
                    gh api repos/"$action_name"/git/refs/tags --paginate 2>/dev/null | \
                        jq -r --arg sha "$sha" '.[] | select(.object.sha == $sha) | .ref | sub("refs/tags/"; "")' 2>/dev/null
                    
                    # Get annotated tags (dereference to commit SHA)
                    gh api repos/"$action_name"/tags --paginate 2>/dev/null | \
                        jq -r --arg sha "$sha" '.[] | select(.commit.sha == $sha) | .name' 2>/dev/null
                } | head -1
            )
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

# Try to get SBOM data - if it fails, dependency graph is likely disabled
sbom_data=$(gh api repos/$org/$repo/dependency-graph/sbom --jq '.sbom.packages[].externalRefs.[0].referenceLocator' 2>&1)

# Also check if the API call returned an HTTP error code
if echo "$sbom_data" | grep -q "HTTP "; then
    echo "❌ Error: Unable to access SBOM data for repository $org/$repo" >&2
    echo "   This may be due to insufficient permissions or the Dependency Graph being disabled." >&2
    exit 1
fi

results=$(echo "$sbom_data" | grep "pkg:githubactions" | sed 's/pkg:githubactions\///' | sed 's/%2A/*/g' 2>/dev/null || true)

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

# Sort results alphabetically
results=$(echo -e "$results" | sort)

echo -e "$results"
