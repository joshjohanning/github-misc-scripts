#!/bin/bash

curl -LX GET 'https://api.github.com/repos/joshjohanning-org/test-permissions/actions/artifacts/140988573/zip' \
--header 'Accept: application/vnd.github.v3+json' \
--header 'Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}' -o artifact.zip
