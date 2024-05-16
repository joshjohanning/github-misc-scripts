#!/bin/bash

# more info: 
# - https://github.blog/changelog/2019-04-09-credential-authorizations-api/
# - https://github.blog/changelog/2021-11-09-expiration-dates-of-saml-authorized-pats-available-via-api/
# - https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/orgs?apiVersion=2022-11-28#list-saml-sso-authorizations-for-an-organization

# gets all credential types ("personal access token", "SSH key", "OAuth app token", and "GitHub app token") and their expiration (if applicable)

gh api --paginate /orgs/githubcustomers/credential-authorizations

# old - raw text output, 1 per line
# gh api --paginate /orgs/githubcustomers/credential-authorizations --jq='.[] | "login: \(.login)    expiration: \(.authorized_credential_expires_at)    ID: \(.credential_id)    note: \(.authorized_credential_note) type: \(.credential_type)"'
