#!/bin/bash

# See: https://github.com/joshjohanning/github-packages-migrate-nuget-packages-between-github-instances
#
# Usage: ./migrate-nuget-packages-between-orgs.sh <source-org> <source-host> <target-org>
#
#
# Prereqs:
# 1. [gh cli](https://cli.github.com) installed
# 2. Set the source GitHub PAT env var: `export GH_SOURCE_PAT=ghp_abc` (must have at least `read:packages`, `read:org` scope)
# 3. Set the target GitHub PAT env var: `export GH_TARGET_PAT=ghp_xyz` (must have at least `write:packages`, `read:org` scope)
#
# Notes:
# - This script installs [gpr](https://github.com/jcansdale/gpr) locally to the `./temp/tools` directory
# - This script assumes that the target org's repo name is the same as the source (the target repo doesn't _need_ to exist, the package just won't be mapped to a repo)
#

if [ $# -ne "3" ]; then
    echo "Usage: $0 <source-org> <source-host> <target-org>"
    exit 1
fi

echo "..."

SOURCE_ORG=$1
SOURCE_HOST=$2
TARGET_ORG=$3

curl -L https://raw.githubusercontent.com/joshjohanning/github-packages-migrate-nuget-packages-between-github-instances/main/migrate-nuget-packages-between-orgs.sh -O
chmod +x migrate-nuget-packages-between-orgs.sh

./migrate-nuget-packages-between-orgs.sh $SOURCE_ORG $SOURCE_HOST $TARGET_ORG
