#!/bin/bash

# use ./get-sso-enabled-pats.sh to get the ID to revoke

if [ -z "$2" ]
  then
    echo "Usage: $0 <org> <credential_id>"
    exit 1
fi

ORG=$1
ID=$2

# credential_type: personal access token, SSH key
gh api -X DELETE /orgs/$ORG/credential-authorizations/$ID
