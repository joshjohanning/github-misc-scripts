#!/bin/bash

# Returns a list of all actions used in a repository using the SBOM API

# Example usage:
#  - ./get-actions-usage-in-repository.sh joshjohanning-org ghas-demo

if [ $# -ne "2" ]; then
    echo "Usage: $0 <org> <repo>"
    exit 1
fi

org=$1
repo=$2

gh api repos/$org/$repo/dependency-graph/sbom --jq '.sbom.packages[].externalRefs.[0].referenceLocator' | grep "pkg:githubactions" | sed 's/pkg:githubactions\///'
