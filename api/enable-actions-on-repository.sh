#!/bin/bash

curl -LX PUT 'https://api.github.com/repos/joshjohanning-ghas-enablement/MyShuttle/actions/permissions' \
    --header 'Accept: application/vnd.github.v3+json' \
    --header "Authorization: Bearer ${PAT}" \
    -d '{"enabled":true}' \
    -v # should expect 204 if successful