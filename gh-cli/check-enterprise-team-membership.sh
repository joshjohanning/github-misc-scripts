#!/bin/bash

# API GET /enterprises/{enterprise}/teams/{enterprise-team}/memberships/{username}
# NOTE: Enterprise Teams is a private preview feature, API may subject to change without notice
#
# Check if a user is a member of an enterprise team
# Response Code: 200 if user is a member, otherwise not 

# Function to display usage
usage() {
    echo "Usage: $0 <enterprise> <team-slug> <username>"
    echo ""
    echo "Parameters:"
    echo "  enterprise  - The enterprise slug"
    echo "  team-slug   - The enterprise team slug"
    echo "  username    - The username to check"
    echo ""
    echo "Example:"
    echo "  $0 my-enterprise dev-team octocat"
    exit 1
}

# Check if required parameters are provided
if [ $# -ne 3 ]; then
    echo "Error: Missing required parameters"
    usage
fi

ENTERPRISE="$1"
TEAM_SLUG="$2"
USERNAME="$3"

echo "Checking if user '$USERNAME' is a member of enterprise team '$TEAM_SLUG' in enterprise '$ENTERPRISE'..."

# Make the API call using gh api and capture both response and HTTP status code
TEMP_DIR=$(mktemp -d)
RESPONSE_FILE="$TEMP_DIR/response.json"
HEADERS_FILE="$TEMP_DIR/headers.txt"

# Use gh api with --include flag to get headers, then parse status code
gh api "/enterprises/$ENTERPRISE/teams/$TEAM_SLUG/memberships/$USERNAME" \
    --include > "$TEMP_DIR/full_response.txt" 2>&1
API_EXIT_CODE=$?

# Extract HTTP status code from the response headers
if [ $API_EXIT_CODE -eq 0 ]; then
    # Split headers and body
    sed '/^$/q' "$TEMP_DIR/full_response.txt" > "$HEADERS_FILE"
    sed '1,/^$/d' "$TEMP_DIR/full_response.txt" > "$RESPONSE_FILE"
    
    # Extract status code from first line of headers
    HTTP_STATUS=$(head -n1 "$HEADERS_FILE" | grep -o '[0-9]\{3\}' | head -n1)
    RESPONSE=$(cat "$RESPONSE_FILE")
else
    # If gh api failed, set status as non-200
    RESPONSE=$(cat "$TEMP_DIR/full_response.txt")
    HTTP_STATUS="non-200"
fi

echo "HTTP Status Code: $HTTP_STATUS"

# Check response based on HTTP status code - only 200 indicates membership
if [ "$HTTP_STATUS" = "200" ]; then
    # 200 OK - User is a member
    TYPE=$(echo "$RESPONSE" | jq -r '.type // "unknown"' 2>/dev/null)
    
    echo "✅ User '$USERNAME' is a member of team '$TEAM_SLUG'"
    if [ "$TYPE" != "null" ] && [ "$TYPE" != "unknown" ]; then
        echo "   Type: $TYPE"
    fi
    
    # Display full response if verbose
    if [ "$VERBOSE" = "true" ]; then
        echo ""
        echo "Full response:"
        echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    exit 0
else
    # Any non-200 status code means user is not a member
    echo "❌ User '$USERNAME' is not a member of team '$TEAM_SLUG' in enterprise '$ENTERPRISE'"
    rm -rf "$TEMP_DIR"
    exit 1
fi
