#!/bin/bash

# No longer works for GitHub.com and deprecated for GHES 3.7+
#
# See:
# - https://github.blog/changelog/2022-08-18-deprecation-notice-graphql-for-packages/
# - https://docs.github.com/en/graphql/overview/breaking-changes#changes-scheduled-for-2022-11-21-1
# - https://docs.github.com/en/enterprise-server@3.7/admin/release-notes#3.7.0-deprecations

# gh auth refresh -h github.com -s read:packages

# packageType (https://docs.github.com/en/graphql/reference/enums#packagetype)
# - DOCKER
# - MAVEN
# - NPM
# - NUGET
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
