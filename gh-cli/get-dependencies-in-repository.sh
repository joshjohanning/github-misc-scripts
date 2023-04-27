#!/bin/bash

gh api repos/joshjohanning-org/ghas-demo/dependency-graph/sbom --jq '.sbom.packages[].externalRefs.[0].referenceLocator' | grep "pkg:" | sed 's/pkg://'
