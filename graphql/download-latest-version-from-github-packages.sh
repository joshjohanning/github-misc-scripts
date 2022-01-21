#!/bin/bash

# Uses the GraphQL to retrieve the download link of the latest version of the package and then use curl to download
link=$(curl 'https://api.github.com/graphql' \
  -s \
  -X POST \
  -H 'content-type: application/json' \
  -H "Authorization: Bearer xxx" \
  --data '{"query":"{ repository(owner: \"joshjohanning-org\", name: \"Wolfringo-github-packages\") {packages(first: 10, packageType: NUGET, names: \"Wolfringo.Commands\") {edges {node {id name packageType versions(first: 100) {nodes { id version files(first: 10) { nodes { name url}}}}}}}}}","variables":{}}' \
  | jq -r '.data.repository.packages.edges[].node.versions.nodes[].files.nodes[].url')

echo $link

curl $link -o package.nupkg
