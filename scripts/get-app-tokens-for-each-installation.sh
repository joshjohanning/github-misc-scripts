#!/bin/bash

# Get app tokens for each organization installation of a GitHub app

# example usage: `./get-app-tokens-for-each-installation.sh 314893 ./test-for-jwt-app-auth.2023-04-06.private-key.pem`

if [ -z "$2" ]; then
    echo "Usage: $0 <app_id> <private_key_path>"
    exit 1
fi

APP_ID=$1
PRIVATE_KEY_PATH=$2

# get jwt
JWT=$(python3 get-app-jwt.py $PRIVATE_KEY_PATH $APP_ID)

INSTALLATIONS=$(curl -s --request GET \
  --url "https://api.github.com/app/installations" \
  --header "Accept: application/vnd.github+json" \
  --header "Authorization: Bearer $JWT" \
  --header "X-GitHub-Api-Version: 2022-11-28" | jq -r '.[] | {id: .id, org: .account.login}')

for obj in $(jq -c '.' <<< "$INSTALLATIONS"); do
  ID=$(jq -r '.id' <<< $obj)
  ORG=$(jq -r '.org' <<< $obj)
  echo "Getting installation token for: $ORG ..."

  TOKEN=$(curl -s --request POST \
    --url "https://api.github.com/app/installations/$ID/access_tokens" \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer $JWT" \
    --header "X-GitHub-Api-Version: 2022-11-28" | jq -r '.token')
  
  echo " ... token: $TOKEN"
  echo ""
done
