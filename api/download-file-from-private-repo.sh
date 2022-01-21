#!/bin/bash

curl -LX GET 'https://raw.githubusercontent.com/joshjohanning-org/composite-caller-1/main/README.md' \
--header "Accept: application/vnd.github.v3+json" \
--header "Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}" -O
