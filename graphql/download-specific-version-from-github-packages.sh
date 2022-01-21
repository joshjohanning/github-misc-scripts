#!/bin/bash


# Uses the GraphQL to retrieve the download link of a specific version of the package and then use curl to download
# IE: this is downloading version 1.1.2

link=$(curl 'https://api.github.com/graphql' \
 -s \
 -X POST \
 -H 'content-type: application/json' \
 -H "Authorization: Bearer ${PAT}" \
 --data '{"query":"{ repository(owner: \"joshjohanning\", name: \"Wolfringo-github-packages\") { packages(first: 10, packageType: NUGET, names: \"Wolfringo.Commands\") { edges { node { id name packageType version(version: \"1.1.2\") { id version files(first: 10) { nodes { name updatedAt size url } } } } } } }}","variables":{}}' \
 | jq -r '.data.repository.packages.edges[].node.version.files.nodes[].url')

echo $link

curl $link -o package.nupkg
