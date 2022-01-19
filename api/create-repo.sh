#!/bin/bash

curl -X POST 'https://api.github.com/orgs/joshjohanning-test-api2/repos' \
  --header 'Accept: application/vnd.github.v3+json' \
  --header 'Authorization: Bearer xxx' \
  -d '{"name":"myrepo2","visibility":"internal"}'
