#!/bin/bash

#v1.0.0

# This script checks the GitHub App's rate limit status by generating a JWT (JSON Web Token),
# obtaining an installation access token, and then querying the GitHub API for the rate limit information.
# It is useful for developers and administrators to monitor and manage their GitHub App's API usage.

# Inputs:
# 1. APP_ID: The unique identifier for the GitHub App. This should be passed as the first argument.
# 2. PRIVATE_KEY_PATH: The file path to the private key of the GitHub App. This should be passed as the second argument.
# 3. --debug (optional): A flag that can be included to enable debug output. This can be placed anywhere in the command line.

# How to call:
# ./checking-github-app-rate-limits.sh [APP_ID] [PRIVATE_KEY_PATH]
# ./checking-github-app-rate-limits.sh --debug [APP_ID] [PRIVATE_KEY_PATH]
# ./checking-github-app-rate-limits.sh [APP_ID] [PRIVATE_KEY_PATH] --debug

# Important Notes:
# - The script requires `openssl`, `curl`, and `jq` to be installed on the system.
# - The JWT generated by this script is valid for 10 minutes from its creation time.
# - The script outputs the remaining API call count, which helps in understanding the current rate limit status.
# - Ensure that the private key file path is correct and the file has appropriate read permissions.
# - The `--debug` flag is useful for troubleshooting and understanding the script's flow.


# Initialize debug mode to off
DEBUG_MODE=0

# Function to handle debug messages
debug() {
    if [ "$DEBUG_MODE" -eq 1 ]; then
        echo "DEBUG: $*"
    fi
}

# Initialize an array to hold the remaining arguments after removing recognized flags
REMAINING_ARGS=()

# Process each argument
while [ "$#" -gt 0 ]; do
    case "$1" in
        --debug)
            DEBUG_MODE=1
            shift # Remove --debug from the list of arguments
            ;;
        *)
            # Collect unrecognized arguments
            REMAINING_ARGS+=("$1")
            shift # Move to the next argument
            ;;
    esac
done

# Check if we have at least two remaining arguments for APP_ID and PRIVATE_KEY_PATH
if [ "${#REMAINING_ARGS[@]}" -lt 2 ]; then
    echo "Usage: $0 [--debug] APP_ID PRIVATE_KEY_PATH"
    exit 1
fi

# Assign the remaining arguments
# GitHub App's ID
APP_ID="${REMAINING_ARGS[0]}"
# Path to your GitHub App's private key
PRIVATE_KEY_PATH="${REMAINING_ARGS[1]}"

# Generate JWT Header
header=$(echo -n '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
debug "Header: $header"

# Generate JWT Payload with issued at time and expiration time
iat=$(date +%s)
debug "Issued At Time: $iat"

exp=$((iat + 600)) # JWT expiration time (10 minutes from now)
debug "Expiration Time: $exp"

payload=$(echo -n "{\"iat\":$iat,\"exp\":$exp,\"iss\":\"$APP_ID\"}" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
debug "Payload: $payload"

# Sign the Header and Payload
signature=$(echo -n "$header.$payload" | openssl dgst -binary -sha256 -sign "$PRIVATE_KEY_PATH" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
debug "Signature: $signature"

# Concatenate Header, Payload, and Signature to form the JWT
jwt_token="$header.$payload.$signature"
debug "JWT Token: $jwt_token"

# GitHub API URL to obtain an installation access token
access_token_url="https://api.github.com/app/installations/51711334/access_tokens"
debug "Access Token URL: $access_token_url"

# Obtain an installation access token
response=$(curl -X POST -s -H "Authorization: Bearer ${jwt_token}" -H "Accept: application/vnd.github.v3+json" "${access_token_url}")
debug "Response: $response"

# Extract the token from the response
installation_token=$(echo "${response}" | jq -r '.token')

# Use the installation token for API calls
debug "Installation Token: ${installation_token}"

# Correct GitHub API URL for checking the app's rate limit
api_url="https://api.github.com/rate_limit"
debug "API URL: $api_url"

# Make a request to the GitHub API to get the rate limit status
response=$(curl -s -H "Authorization: Bearer ${installation_token}" -H "Accept: application/vnd.github.machine-man-preview+json" "${api_url}")
debug "Response: $response"

# Parse the JSON response to get the remaining rate limit
remaining_calls=$(echo "${response}" | jq '.resources.core.remaining')

# Output the remaining API call count
echo "Remaining API calls: ${remaining_calls}"
