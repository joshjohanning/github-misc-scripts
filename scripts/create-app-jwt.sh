#!/bin/bash

# -----------------------------------------------------------------------------
# Script to create a JWT (JSON Web Token) signed with a private RSA key.
#
# Usage:
#   ./create-app-jwt.sh <app_id_or_client_id> <private_key_file>
#
# Arguments:
#   <app_id_or_client_id>  The GitHub App ID (integer) or Client ID (Iv1.xxx)
#                          to use as the JWT issuer (iss). Both work.
#   <private_key_file>     Path to the PEM-encoded RSA private key file.
#
# Example:
#   ./create-app-jwt.sh 123456 /path/to/private-key.pem
#   ./create-app-jwt.sh Iv1.abc123def456 /path/to/private-key.pem
#
# The script outputs the generated JWT to stdout.
# -----------------------------------------------------------------------------
set -o pipefail

# Input validation for required parameters
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing required parameters." >&2
    echo "Usage: $0 <app_id_or_client_id> <path_to_private_key_pem>" >&2
    exit 1
fi

app_id_or_client_id=$1 # App ID (integer) or Client ID (Iv1.xxx) - both work

# Check if the private key file exists and is readable
if [ ! -f "$2" ] || [ ! -r "$2" ]; then
    echo "Error: Private key file '$2' does not exist or is not readable." >&2
    exit 1
fi
pem=$( cat "$2" ) # file path of the private key as second argument

now=$(date +%s)
iat=$((${now} - 60)) # Issues 60 seconds in the past
exp=$((${now} + 600)) # Expires 10 minutes in the future

b64enc() { openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }

header_json='{
    "typ":"JWT",
    "alg":"RS256"
}'
# Header encode
header=$( echo -n "${header_json}" | b64enc )

payload_json="{
    \"iat\":${iat},
    \"exp\":${exp},
    \"iss\":\"${app_id_or_client_id}\"
}"
# Payload encode
payload=$( echo -n "${payload_json}" | b64enc )

# Signature
header_payload="${header}"."${payload}"
signature=$(
    openssl dgst -sha256 -sign <(echo -n "${pem}") \
    <(echo -n "${header_payload}") | b64enc
)

# Create JWT
JWT="${header_payload}"."${signature}"
printf '%s\n' "$JWT"
