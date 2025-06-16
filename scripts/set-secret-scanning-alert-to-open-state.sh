#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: set-secret-scanning-alert-to-open-state.sh
# Description: This script reopens a resolved secret scanning alert in a 
#              specified GitHub repository and optionally adds a comment.
#
# Usage:
#   ./set-secret-scanning-alert-to-open-state.sh -o <organization> -r <repository> -a <alert_id> [-c <comment>] [-t <token>]
#
# Parameters:
#   -o <organization>  GitHub organization name (required)
#   -r <repository>    GitHub repository name (required)
#   -a <alert_id>      Secret scanning alert ID (required)
#   -c <comment>       Comment to add when reopening the alert (optional)
#   -t <token>         GitHub personal access token (optional, will use GITHUB_TOKEN 
#                      environment variable if not provided)
#   -h                 Display help message
#
# Requirements:
#   - curl: Command-line tool for making HTTP requests
#   - jq: Command-line JSON processor
#
# Notes:
#   - The GitHub token must have the necessary permissions to update secret 
#     scanning alerts for the specified repository.
# -----------------------------------------------------------------------------

# Function to display usage information
function display_usage {
    echo "Usage: $0 -o <organization> -r <repository> -a <alert_id> [-c <comment>] [-t <token>]"
    echo "  -o <organization>  GitHub organization name"
    echo "  -r <repository>    GitHub repository name"
    echo "  -a <alert_id>      Secret scanning alert ID"
    echo "  -c <comment>       Comment to add when reopening the alert (optional)"
    echo "  -t <token>         GitHub personal access token (optional, will use GITHUB_TOKEN env var if not provided)"
    echo "  -h                 Display this help message"
    exit 1
}

# Parse command line arguments
while getopts "o:r:a:c:t:h" opt; do
    case ${opt} in
        o ) org_name=$OPTARG ;;  # GitHub organization name
        r ) repo_name=$OPTARG ;; # GitHub repository name
        a ) alert_id=$OPTARG ;;  # Secret scanning alert ID
        c ) comment=$OPTARG ;;   # Optional comment
        t ) github_token=$OPTARG ;; # GitHub personal access token
        h ) display_usage ;;     # Display help message
        \? ) display_usage ;;    # Handle invalid options
    esac
done

# Check if required parameters are provided
if [ -z "$org_name" ] || [ -z "$repo_name" ] || [ -z "$alert_id" ]; then
    echo "Error: Organization name, repository name, and alert ID are required."
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

# Set API URL for the specific secret scanning alert
api_url="https://api.github.com/repos/$org_name/$repo_name/secret-scanning/alerts/$alert_id"

# Make API request to update the alert's state to "open"
response=$(curl -s -X PATCH -H "Authorization: token $github_token" \
                -H "Accept: application/vnd.github.v3+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                -d "{\"state\": \"open\", \"resolution_comment\": \"$comment\"}" \
                "$api_url")

# Check if the response contains an error
if echo "$response" | grep -q "message"; then
    error_message=$(echo "$response" | grep -o '"message":"[^"]*' | cut -d'"' -f4)
    echo "Error: $error_message"
    exit 1
fi

# Confirm the state change
new_state=$(echo "$response" | jq -r '.state')
if [ "$new_state" == "open" ]; then
    echo "Success: Secret scanning alert $alert_id has been changed to 'open'."
else
    echo "Error: Failed to change the state of alert $alert_id to 'open'."
    exit 1
fi