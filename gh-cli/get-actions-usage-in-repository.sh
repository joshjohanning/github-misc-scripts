#!/bin/bash

gh api repos/joshjohanning-org/Second-Repository/dependency-graph/sbom --jq '.sbom.packages[].externalRefs.[0].referenceLocator' | grep "pkg:githubactions" | sed 's/pkg:githubactions\///'
