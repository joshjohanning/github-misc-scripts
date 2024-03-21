#!/bin/bash

# Usage: ./migrate-docker-containers-between-github-instances.sh <source-org> <source-host> <target-org> <target-host> <link-to-repository: true|false>
#
#
# Prereqs:
# 1. [gh cli](https://cli.github.com) installed
# 2. Set the source GitHub PAT env var: `export GH_SOURCE_PAT=ghp_abc` (must have at least `read:packages`, `read:org` scope)
# 3. Set the target GitHub PAT env var: `export GH_TARGET_PAT=ghp_xyz` (must have at least `write:packages`, `read:org` scope)
#
# Example: ./migrate-docker-containers-between-github-instances.sh joshjohanning-org github.com joshjohanning-emu github.com
#
# Notes:
# - Pass in `true` as the 5th parameter if you want to attempt to re-link the package to the repo in the target organization
#   - This script assumes that the target org's repo name is the same as the source repo's name - add in logic or mapping file if this isn't the case
#   - If you pass in true and the repo doesn't exist, the package will still import but won't be mapped to a repo
#

set -e

if [ $# -lt "4" ]; then
    echo "Usage: $0 <source-org> <source-host> <target-org> <target-host> <link-to-repository: true|false>"
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

LINK_TO_REPOSITORY=${5:-false}

echo "..."

SOURCE_ORG=$1
SOURCE_HOST=$2
TARGET_ORG=$3
TARGET_HOST=$4

# set registry urls
if [ "$SOURCE_HOST" = "github.com" ]; then
  SOURCE_CONTAINER_REGISTRY="ghcr.io"
else
  SOURCE_CONTAINER_REGISTRY="containers.$SOURCE_HOST"
fi
if [ "$TARGET_HOST" = "github.com" ]; then
  TARGET_CONTAINER_REGISTRY="ghcr.io"
else
  TARGET_CONTAINER_REGISTRY="containers.$TARGET_HOST"
fi

USER=(GH_HOST="$SOURCE_HOST" GH_TOKEN=GH_SOURCE_PAT gh api /user -q '.login')
echo $GH_SOURCE_PAT | docker login $SOURCE_CONTAINER_REGISTRY -u $USER --password-stdin
echo ""

packages=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages?package_type=container" -q '.[] | .name + " " + .repository.name')

echo "$packages" | while IFS= read -r response; do

  package_name=$(echo "$response" | cut -d ' ' -f 1)
  repo_name=$(echo "$response" | cut -d ' ' -f 2)

  echo "org: $SOURCE_ORG repo: $repo_name --> package name $package_name"
  
  versions=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages/container/$package_name/versions" -q '.[].metadata.container.tags[]' | sort -V)
  for version in $versions
  do
    echo " ... running docker pull $SOURCE_CONTAINER_REGISTRY/$SOURCE_ORG/$package_name:$version"
    docker pull $SOURCE_CONTAINER_REGISTRY/$SOURCE_ORG/$package_name:$version || echo "$SOURCE_CONTAINER_REGISTRY/$SOURCE_ORG/$package_name:$version pull failed" >> ghcr_source_failures.txt
    echo " ... running docker tag $SOURCE_CONTAINER_REGISTRY/$SOURCE_ORG/$package_name:$version $TARGET_CONTAINER_REGISTRY/$TARGET_ORG/$package_name:$version"
    docker tag $SOURCE_CONTAINER_REGISTRY/$SOURCE_ORG/$package_name:$version $TARGET_CONTAINER_REGISTRY/$TARGET_ORG/$package_name:$version || true

    # re-attach to repo if it exists
    if [ "$LINK_TO_REPOSITORY" = "true" ]; then
      echo " ... attempting to re-attach to target repo: $TARGET_ORG/$repo_name"
      # First, create a container from the image
      container_id=$(docker create $TARGET_CONTAINER_REGISTRY/$TARGET_ORG/$package_name:$version || true)
      # Then, commit the container to a new image with the label
      docker commit --change "LABEL org.opencontainers.image.source=https://$TARGET_HOST/$TARGET_ORG/$repo_name" $container_id $TARGET_CONTAINER_REGISTRY/$TARGET_ORG/$package_name:$version || true
      # can also use  --label "org.opencontainers.image.description=My container image" --label "org.opencontainers.image.licenses=MIT"
      # Remove the temporary container
      docker rm $container_id | true
    fi

    echo " ... running docker push $TARGET_CONTAINER_REGISTRY/$TARGET_ORG/$package_name:$version"
    docker push $TARGET_CONTAINER_REGISTRY/$TARGET_ORG/$package_name:$version || echo "$TARGET_CONTAINER_REGISTRY/$TARGET_ORG/$package_name:$version push failed" >> ghcr_target_failures.txt 
    echo ""
  done

  echo "... next container/package"

done

echo 'All done! Run this to remove all local docker images post-migration, if desired: docker rmi -f $(docker images -q)'
