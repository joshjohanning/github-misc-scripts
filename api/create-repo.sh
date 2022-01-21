#!/bin/bash

curl -X POST 'https://api.github.com/orgs/joshjohanning-org/repos' \
  --header "Accept: application/vnd.github.v3+json" \
  --header "Authorization: Bearer ${PAT}" \
  -d '{"name":"myrepo2","visibility":"internal"}'
