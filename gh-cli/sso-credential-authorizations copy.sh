#!/bin/bash

# more info: 
# - https://github.blog/changelog/2019-04-09-credential-authorizations-api/
# - https://github.blog/changelog/2021-11-09-expiration-dates-of-saml-authorized-pats-available-via-api/

gh api --paginate /orgs/{org}/credential-authorizations --jq='.[] | [.login]'

# get an issue creator
users=gh api --paginate /repos/{org}/{repo}/issues --jq='.[] | select(.number == {number}) | .user.login'