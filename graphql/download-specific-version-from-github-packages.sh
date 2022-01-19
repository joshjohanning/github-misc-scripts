#!/bin/bash


# Uses the GraphQL to retrieve the download link of a specific version of the package and then use curl to download
# IE: this is downloading version 1.1.2

link=$(curl 'https://api.github.com/graphql' \
 -s \
 -X POST \
 -H 'content-type: application/json' \
 -H "Authorization: Bearer ***REMOVED***" \
 --data '{"query":"{\n repository(owner: \"joshjohanning\", name: \"Wolfringo-github-packages\") {\n packages(first: 10, packageType: NUGET, names: \"Wolfringo.Commands\") {\n edges {\n node {\n id\n name\n packageType\n version(version: \"1.1.2\") {\n id\n version\n files(first: 10) {\n nodes {\n name\n updatedAt\n size\n url\n }\n }\n }\n }\n }\n }\n }\n}","variables":{}}' \
 | jq -r '.data.repository.packages.edges[].node.version.files.nodes[].url')

echo $link

curl $link -o package.nupkg
