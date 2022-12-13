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

gh api graphql -f packageType="NUGET" -f owner="joshjohanning-org-packages" -f repo="packages-repo1" -f packageName="NUnit3.DotNetNew.Template" -f packageVersion="1.7.0" -f query='
query ($packageType: PackageType!, $owner: String!, $repo: String!, $packageName: [String!], $packageVersion: String!) {
  repository(owner: $owner, name: $repo) {
    packages(first: 100, packageType: $packageType, names: $packageName) {
      edges {
        node {
          id
          name
          packageType
          version(version: $packageVersion) {
            id
            version
            files(first: 10) {
              nodes {
                name
                updatedAt
                size
                url
              }
            }
          }
        }
      }
    }
  }
}' -q '.data.repository.packages.edges[].node.version.files.nodes[].url'
