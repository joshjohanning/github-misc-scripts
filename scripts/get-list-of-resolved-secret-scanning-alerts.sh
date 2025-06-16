#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: get-list-of-resolved-secret-scanning-alerts.sh
# Description: This script retrieves and lists all resolved secret scanning 
#              alerts for a specified GitHub repository. It uses the GitHub API 
#              to fetch the alerts and displays them in a tabular format.
#
# Usage:
#   ./get-list-of-resolved-secret-scanning-alerts.sh -o <organization> -r <repository> [-t <token>]
#
# Parameters:
#   -o <organization>  GitHub organization name (required)
#   -r <repository>    GitHub repository name (required)
#   -t <token>         GitHub personal access token (optional, will use GITHUB_TOKEN 
#                      environment variable if not provided)
#   -h                 Display help message
#
# Requirements:
#   - curl: Command-line tool for making HTTP requests
#   - jq: Command-line JSON processor
#
# Notes:
#   - The script supports pagination to handle repositories with a large number 
#     of resolved alerts.
#   - The GitHub token must have the necessary permissions to access secret 
#     scanning alerts for the specified repository.
# -----------------------------------------------------------------------------

# Function to display usage information
function display_usage {
    echo "Usage: $0 -o <organization> -r <repository> [-t <token>]"
    echo "  -o <organization>  GitHub organization name"
    echo "  -r <repository>    GitHub repository name" 
    echo "  -t <token>         GitHub personal access token (optional, will use GITHUB_TOKEN env var if not provided)"
    echo "  -h                 Display this help message"
    exit 1
}

# Parse command line arguments
while getopts "o:r:t:h" opt; do
    case ${opt} in
        o ) org_name=$OPTARG ;;  # GitHub organization name
        r ) repo_name=$OPTARG ;; # GitHub repository name
        t ) github_token=$OPTARG ;; # GitHub personal access token
        h ) display_usage ;; # Display help message
        \? ) display_usage ;; # Handle invalid options
    esac
done

# Check if required parameters are provided
if [ -z "$org_name" ] || [ -z "$repo_name" ]; then
    echo "Error: Organization name and repository name are required."
    display_usage
fi

# If token not provided as argument, try to use GITHUB_TOKEN environment variable
if [ -z "$github_token" ]; then
    github_token=$GITHUB_TOKEN
    if [ -z "$github_token" ]; then
        echo "Error: GitHub token not provided. Either provide it with -t option or set the GITHUB_TOKEN environment variable."
        exit 1
    fi
fi

# Set API URL for secret scanning alerts with state=resolved
api_url="https://api.github.com/repos/$org_name/$repo_name/secret-scanning/alerts?state=resolved&per_page=100"
page=1
total_alerts=0

# Display header for the output table
echo "Retrieving resolved secret scanning alerts for $org_name/$repo_name..."
echo "--------------------------------------------------------------------"
echo "| Alert ID | Created At | Resolved At | Secret Type | Resolution |"
echo "--------------------------------------------------------------------"

# Loop through paginated results
while true; do
    # Make API request
    response=$(curl -s -H "Authorization: token $github_token" \
                    -H "Accept: application/vnd.github.v3+json" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    "$api_url&page=$page")
    
    # Check if response contains error
    if echo "$response" | grep -q "message"; then
        error_message=$(echo "$response" | grep -o '"message":"[^"]*' | cut -d'"' -f4)
        echo "Error: $error_message"
        exit 1
    fi
    
    # Check if response is empty array
    if [ "$response" = "[]" ]; then
        break
    fi
    
    # Count the number of alerts in this page and add to total
    page_alerts=$(echo "$response" | jq '. | length')
    total_alerts=$((total_alerts + page_alerts))
    
    # Process and display alerts
    echo "$response" | jq -r '.[] | [.number, .created_at, .resolved_at, .secret_type, .resolution] | @tsv' | 
    while read -r alert_id created_at resolved_at secret_type resolution; do
        # Format dates for better readability
        created_date=$(date -d "$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$created_at")
        resolved_date=$(date -d "$resolved_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$resolved_at")
        
        printf "| %-8s | %-19s | %-19s | %-20s | %-10s |\n" \
               "$alert_id" "$created_date" "$resolved_date" "$secret_type" "$resolution"
    done
    
    # Check if there are more pages
    link_header=$(curl -s -I -H "Authorization: token $github_token" \
                       -H "Accept: application/vnd.github.v3+json" \
                       -H "X-GitHub-Api-Version: 2022-11-28" \
                       "$api_url&page=$page" | grep -i "link:")
    
    if ! echo "$link_header" | grep -q 'rel="next"'; then
        break
    fi
    
    ((page++))
done

# Display footer and total count
echo "--------------------------------------------------------------------"
echo "Total resolved secret scanning alerts found: $total_alerts"
echo ""
echo "Note: This script requires 'curl' and 'jq' to be installed."