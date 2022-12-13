#!/bin/bash

# gh auth refresh -h github.com -s read:packages

# packageType (https://docs.github.com/en/graphql/reference/enums#packagetype)
# - DEBIAN
# - DOCKER
# - MAVEN
# - NPM
# - NUGET
# - PYPI
# - RUBYGEMS

gh api graphql -f packageType="NUGET" -f owner="joshjohanning-org" -f repo="Wolfringo-github-packages" -f packageName="Wolfringo.Core" -f query='
query ($packageType: PackageType!, $owner: String!, $repo: String!, $packageName: [String!]) {
  repository(owner: $owner, name: $repo) {
    packages(first: 10, packageType: $packageType, names: $packageName) {
      edges {
        node {
          id
          name
          packageType
          versions(first: 100) {
            nodes {
              id
              version
              files(first: 10) {
                nodes {
                  name
                  url
                }
              }
            }
          }
        }
      }
    }
  }
}' -q '.data.repository.packages.edges[].node.versions.nodes[].files.nodes[].url'
