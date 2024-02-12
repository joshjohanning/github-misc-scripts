#!/bin/bash

## NOTE: ONLY MIGRATES TAGS, NOT SHAs. UNTAGGED IMAGES WILL BE LEFT BEHIND
#
# Usage: ./migrate-npm-packages-between-github-instances.sh <source-org> <source-host> <target-org> <target-host>
#
#
# Prereqs:
# 1. [gh cli](https://cli.github.com) installed
# 2. Set the source GitHub PAT env var: `export GH_SOURCE_PAT=ghp_abc` (must have at least `read:packages`, `read:org` scope)
# 3. Set the target GitHub PAT env var: `export GH_TARGET_PAT=ghp_xyz` (must have at least `write:packages`, `read:org` scope)
#
# Example: ./migrate-npm-packages-between-github-instances.sh joshjohanning-org github.com joshjohanning-emu github.com
#
# Notes:
# - This script assumes that the target org's repo name is the same as the source
# - If the repo doesn't exist, the package will still import but won't be mapped to a repo
#

set -e

if [ $# -ne "4" ]; then
    echo "Usage: $0 <source-org> <source-host> <target-org> <target-host>"
    exit 1
fi

# make sure env variables are defined
if [ -z "$GH_SOURCE_PAT" ]; then
    echo "Error: set GH_SOURCE_PAT env var"
    exit 1
fi

if [ -z "$GH_TARGET_PAT" ]; then
    echo "Error: set GH_TARGET_PAT env var"
    exit 1
fi

echo "..."

SOURCE_ORG=$1
SOURCE_HOST=$2
TARGET_ORG=$3
TARGET_HOST=$4

export SOURCE_REGISTRY="ghcr.io" 
if [[ $SOURCE_HOST != "github.com" ]]; then
  export SOURCE_REGISTRY="containers.${SOURCE_HOST}"
fi

export TARGET_REGISTRY="ghcr.io" 
if [[ $TARGET_HOST != "github.com" ]]; then
  export TARGET_REGISTRY="containers.${TARGET_HOST}"
fi

packages=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages?package_type=container" -q '.[] | .name + " " + .repository.name')

if [ -z "$packages" ]; then
  echo "No container packages found in $SOURCE_ORG"
  exit 0
fi

echo "$packages" | while IFS= read -r response; do

  package_name=$(echo "$response" | cut -d ' ' -f 1)
  repo_name=$(echo "$response" | cut -d ' ' -f 2)
 
  echo "org: $SOURCE_ORG repo: $repo_name --> package name $package_name"
  
  # Yum yum, get all source packages　美味しい、ね？
  echo ${GH_SOURCE_PAT} | docker login ${SOURCE_REGISTRY} --username USERNAME --password-stdin
  echo docker image pull --all-tags  ${SOURCE_REGISTRY}/${SOURCE_ORG}/${package_name}
  docker image pull --all-tags  ${SOURCE_REGISTRY}/${SOURCE_ORG}/${package_name}

  # retag what we got  
  versions=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages/container/$package_name/versions" -q '.[] | .metadata.container.tags[]' | sort -V)
  for version in $versions
  do
    echo docker tag ${SOURCE_REGISTRY}/${SOURCE_ORG}/${package_name}:${version} ${TARGET_REGISTRY}/${TARGET_ORG}/${package_name}:${version}
    docker tag ${SOURCE_REGISTRY}/${SOURCE_ORG}/${package_name}:${version} ${TARGET_REGISTRY}/${TARGET_ORG}/${package_name}:${version}
  done
  
  # Push all the tags to the target
  echo ${GH_TARGET_PAT} | docker login ${TARGET_REGISTRY} --username USERNAME --password-stdin
  echo docker push --all-tags ${TARGET_REGISTRY}/${TARGET_ORG}/${package_name}
  docker push --all-tags ${TARGET_REGISTRY}/${TARGET_ORG}/${package_name}
  
  # If we want to push all untagged SHAs fix this up and do something like this
  #versions=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages/container/$package_name/versions" -q '.[] | .name' | sort -V)
done