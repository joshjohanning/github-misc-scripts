#!/bin/bash

# more info: 
# - https://github.blog/changelog/2019-04-09-credential-authorizations-api/
# - https://github.blog/changelog/2021-11-09-expiration-dates-of-saml-authorized-pats-available-via-api/
# - https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/orgs?apiVersion=2022-11-28#list-saml-sso-authorizations-for-an-organization

# credential_type: personal access token, SSH key, OAuth app token, GitHub app token
gh api --paginate /orgs/githubcustomers/credential-authorizations --jq='.[] | select(.credential_type == "SSH key")'

# old - raw text output, 1 per line
# gh api --paginate /orgs/githubcustomers/credential-authorizations --jq='.[] | select(.credential_type == "SSH key") | "login: \(.login)    ID: \(.credential_id)    title: \(.authorized_credential_title)    type: \(.credential_type)"'
