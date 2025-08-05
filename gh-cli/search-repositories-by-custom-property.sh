#!/bin/bash

# Search for repositories in an organization with specific custom properties
# Uses GitHub's search API with custom property filters

if [ -z "$1" ]; then
  echo "Usage: $0 <org> [property_query]"
  echo "Example: ./search-repositories-by-custom-property.sh joshjohanning-org"
  echo "Example: ./search-repositories-by-custom-property.sh joshjohanning-org 'RepoType:IssueOps'"
  echo "Example: ./search-repositories-by-custom-property.sh joshjohanning-org 'Environment:Production'"
  echo "Example: ./search-repositories-by-custom-property.sh joshjohanning-org 'RepoType:IssueOps&Environment:Production'"
  echo "Example: ./search-repositories-by-custom-property.sh joshjohanning-org 'RepoType:IssueOps Environment:Production'"
  echo "Example: ./search-repositories-by-custom-property.sh joshjohanning-org 'no:RepoType' # Repos without repo_type property"
  echo "Note that you can't add the same property twice in the same search query"
  exit 1
fi

org="$1"
property_query="${2:-RepoType:IssueOps}"

# Add 'props.' prefix automatically to each property if not already present
# Handle multiple properties separated by & or space
if [[ "$property_query" != *props.* ]]; then
  # Replace property names with props. prefix for multiple formats
  # Handle & separated: RepoType:IssueOps&Environment:Production
  # Handle space separated: RepoType:IssueOps Environment:Production
  # Handle no: qualifier: no:repo_type becomes no:props.repo_type
  # First handle regular properties, then fix the no: qualifier placement
  property_query=$(echo "$property_query" | sed -E 's/(^|[[:space:]&])([A-Za-z][A-Za-z0-9_]*):([^&[:space:]]+)/\1props.\2:\3/g')
  property_query=$(echo "$property_query" | sed -E 's/props\.no:/no:props./g')
fi

echo "Searching for repositories in $org with property: $property_query"
echo ""

# Use the search API to find repositories with custom properties
# The search query combines org filter with custom property filter
search_query="org:$org $property_query"
# Replace spaces with + for proper GitHub search API formatting
search_query=$(echo "$search_query" | sed 's/ /+/g')

echo "search query: $search_query"

# Make the API call - don't URL encode the plus signs, GitHub expects them as literal +
response=$(gh api --paginate "search/repositories?q=$search_query" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
  if echo "$response" | grep -q "HTTP 403\|rate limit"; then
    echo "Error: Rate limit exceeded or authentication issue"
    echo "Make sure you have a valid GitHub token and try again later"
    exit 1
  elif echo "$response" | grep -q "HTTP 422"; then
    echo "Error: Invalid search query"
    echo "Check that the custom property name and value are correct"
    exit 1
  else
    echo "Error: Search failed"
    echo "$response"
    exit 1
  fi
fi

# Parse and display results
# With --paginate, gh returns all items as a single JSON array when there are multiple pages
# For single page, it returns the normal response object
if echo "$response" | jq -e 'type == "array"' >/dev/null 2>&1; then
  # Multiple pages - response is an array of page objects
  actual_count=$(echo "$response" | jq 'map(.items) | add | length' 2>/dev/null | head -1)
  total_count=$(echo "$response" | jq -r '.[0].total_count' 2>/dev/null | head -1)
  echo "Found $actual_count repo(s) (out of $total_count total matching):"
  echo ""
  echo "$response" | jq -r 'map(.items) | add | .[].full_name'
else
  # Single page - normal response object
  total_count=$(echo "$response" | jq -r '.total_count' 2>/dev/null | head -1)
  echo "Found $total_count repo(s) matching the criteria:"
  echo ""
  if [ "$total_count" -gt 0 ] 2>/dev/null; then
    echo "$response" | jq -r '.items[] | .full_name'
  else
    echo "No repositories found with the specified custom property."
    echo ""
    echo "This could mean:"
    echo "- No repositories have this custom property set"
    echo "- The property name or value is incorrect"
    echo "- You don't have access to repositories with this property"
  fi
fi
