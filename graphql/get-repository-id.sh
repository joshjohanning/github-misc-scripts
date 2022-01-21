#!/bin/bash

curl -X POST 'https://api.github.com/graphql' \
  -H "Authorization: bearer ${PAT}" \
  --data '{"query":"{ repository(owner: \"joshjohanning-org\", name: \"test-repo\") { id, url }}","variables":{}}'
