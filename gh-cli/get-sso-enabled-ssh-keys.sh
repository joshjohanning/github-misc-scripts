#!/bin/bash

# more info: 
# - https://github.blog/changelog/2019-04-09-credential-authorizations-api/
# - https://github.blog/changelog/2021-11-09-expiration-dates-of-saml-authorized-pats-available-via-api/

# credential_type: personal access token, SSH key
gh api --paginate /orgs/githubcustomers/credential-authorizations --jq='.[] | select(.credential_type == "SSH key") | "login: \(.login)    ID: \(.credential_id)    title: \(.authorized_credential_title)    type: \(.credential_type)"'
