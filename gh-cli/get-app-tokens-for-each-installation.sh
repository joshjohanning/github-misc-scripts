#!/bin/bash

# Get app tokens for each organization installation of a GitHub app
# 
# example usage: `./get-app-tokens-for-each-installation.sh 314893 ./test-for-jwt-app-auth.2023-04-06.private-key.pem`
#

# credits to @kenmuse, starter here: https://gist.github.com/kenmuse/9429221d6944c087deaed2ec5075d0bf

set -euo pipefail

if [ -z "$2" ]; then
    echo "Usage: $0 <APP_ID> <private_key_path>"
    exit 1
fi

APP_ID=$1
PRIVATE_KEY_PATH=$2

encode() {
    openssl enc -base64 -A -e |  tr '+/' '-_' | tr -d '='
}

trim_encode() {
    tr -d '\n' | encode
}

jwt() {
    local header payload enc_header enc_payload sig token
    header=$(jq -n -j -c \
                --arg alg RS256 \
                --arg type JWT \
                '{alg: $alg, typ: $type }')
    payload=$(jq -n -j -c \
                --argjson iat "$(date +%s)" \
                --argjson appId $APP_ID \
                --arg alg RS256 \
                --arg type JWT \
                '{iat: ($iat - 60), exp: ($iat + 600), iss: $appId}')
    enc_header=$(trim_encode <<< $header)
    enc_payload=$(trim_encode <<< $payload)
    sig=$(printf '%s.%s' $enc_header $enc_payload | openssl dgst -binary -sha256 -sign $PRIVATE_KEY_PATH | encode)
    token=$enc_header.$enc_payload.$sig
    printf $token
}

###

jwt_token=$(jwt)

echo "printing app info ..."
curl --request GET \
     --url 'https://api.github.com/app' \
     --header "Authorization: Bearer ${jwt_token}" \
     --header "Accept: application/vnd.github+json" \
     --header "X-GitHub-Api-Version: 2022-11-28"
echo " ..." && echo ""

INSTALLATIONS=$(curl -s --request GET \
     --url 'https://api.github.com/app/installations' \
     --header "Authorization: Bearer ${jwt_token}" \
     --header "Accept: application/vnd.github+json" \
     --header "X-GitHub-Api-Version: 2022-11-28" | jq -r '.[] | {id: .id, org: .account.login}')

# repo token
# curl --request GET \
#      --url 'https://api.github.com/repos/YOUR-ORG/YOUR-REPO/installation' \
#      --header "Authorization: Bearer ${jwt_token}" \
#      --header "Accept: application/vnd.github+json" \
#      --header "X-GitHub-Api-Version: 2022-11-28"

for obj in $(jq -c '.' <<< "$INSTALLATIONS"); do
  ID=$(jq -r '.id' <<< $obj)
  ORG=$(jq -r '.org' <<< $obj)
  echo "Getting installation token for: $ORG ..."

  TOKEN=$(curl -s --request POST \
    --url "https://api.github.com/app/installations/$ID/access_tokens" \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer $jwt_token" \
    --header "X-GitHub-Api-Version: 2022-11-28" | jq -r '.token')
  
  echo " ... token: $TOKEN" && echo ""
done
