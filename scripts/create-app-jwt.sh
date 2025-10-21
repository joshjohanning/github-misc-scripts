#!/bin/bash

# -----------------------------------------------------------------------------
# Script to create a JWT (JSON Web Token) signed with a private RSA key.
#
# Usage:
#   ./create-app-jwt.sh <client_id> <private_key_file>
#
# Arguments:
#   <client_id>         The client ID to use as the JWT issuer (iss).
#   <private_key_file>  Path to the PEM-encoded RSA private key file.
#
# Example:
#   ./create-app-jwt.sh my-client-id /path/to/private-key.pem
#
# The script outputs the generated JWT to stdout.
# -----------------------------------------------------------------------------
set -o pipefail

# Input validation for required parameters
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing required parameters." >&2
    echo "Usage: $0 <client_id> <path_to_private_key_pem>" >&2
    exit 1
fi

client_id=$1 # Client ID as first argument

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
    \"iss\":\"${client_id}\"
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
