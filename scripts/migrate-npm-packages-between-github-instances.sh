#!/bin/bash

# Usage: ./migrate-npm-packages-between-github-instances.sh <source-org> <source-host> <target-org> <target-host> | tee output.log
#
#
# Prereqs:
# 1. [gh cli](https://cli.github.com) installed
# 2. Set the source GitHub PAT env var: `export GH_SOURCE_PAT=ghp_abc` (must have at least `read:packages`, `read:org` scope)
# 3. Set the target GitHub PAT env var: `export GH_TARGET_PAT=ghp_xyz` (must have at least `write:packages`, `read:org` scope)
#
# Example: ./migrate-npm-packages-between-github-instances.sh joshjohanning-org github.com joshjohanning-emu github.com | tee output.log
#
# Notes:
# - Mapping the npm package to a repo is optional.
#   - If there is a repo that exists in the target with the same repo name, it will map it
#   - If the repo doesn't exist, the package will still import but won't be mapped to a repo
# - See ./failed-packages.txt for any packages that failed to import

set -e

if [ $# -lt "4" ]; then
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
# Optional: Set CUTOFF_DATE to migrate only package versions created on or after this date.
# Format: YYYY-MM-DDTHH:MM:SSZ (e.g., 2023-03-13T00:00:00Z)
# Example: To migrate versions from the past year, use: $(date -u -v-1y +"%Y-%m-%dT%H:%M:%SZ")
# If CUTOFF_DATE is unset or empty, all available versions will be migrated.
CUTOFF_DATE=$5

# create temp dir
mkdir -p ./temp
cd ./temp
temp_dir=$(pwd)

# set up .npmrc for target org
echo @$TARGET_ORG:registry=https://npm.pkg.$TARGET_HOST/ >$temp_dir/.npmrc && echo "//npm.pkg.$TARGET_HOST/:_authToken=$GH_TARGET_PAT" >>$temp_dir/.npmrc

packages=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages?package_type=npm" -q '.[] | .name + " " + .repository.name')

echo "$packages" | while IFS= read -r response; do

  package_name=$(echo "$response" | cut -d ' ' -f 1)
  repo_name=$(echo "$response" | cut -d ' ' -f 2)

  echo "org: $SOURCE_ORG repo: $repo_name --> package name $package_name"

  # Cache package metadata to avoid multiple API calls for each version
  curl -H "Authorization: token $GH_SOURCE_PAT" -Ls "https://npm.pkg.github.com/@$SOURCE_ORG/$package_name" >"${temp_dir}/${package_name}.json"

  # Fetch versions, filter by date only if CUTOFF_DATE is set
  if [ -n "$CUTOFF_DATE" ]; then
    versions=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages/npm/$package_name/versions" |
      jq -r --arg cutoff "$CUTOFF_DATE" '.[] | select(.created_at >= $cutoff) | .name' |
      sort -V)
  else
    versions=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages/npm/$package_name/versions" |
      jq -r '.[].name' |
      sort -V)
  fi

  for version in $versions; do
    echo "$version"

    # get url of tarball
    url=$(jq --arg version $version -r '.versions[$version].dist.tarball' "${temp_dir}/${package_name}.json")

    # check for error
    if [ "$url" == "null" ]; then
      echo "ERROR: version $version not found for package $package_name"
      echo "NOTE: Make sure you have the proper scopes for gh; ie run this: gh auth refresh -h github.com -s read:packages"
      continue
    fi

    # download
    curl -sS -H "Authorization: token $GH_SOURCE_PAT" -L -o $package_name-$version.tgz $url

    # untar
    mkdir -p ./$package_name-$version
    # if you run into permissions issue, add a `sudo` here
    tar xzf $package_name-$version.tgz -C $package_name-$version
    cd $package_name-$version/package
    perl -pi -e "s/$SOURCE_ORG/$TARGET_ORG/ig" package.json
    npm publish --ignore-scripts --userconfig $temp_dir/.npmrc || echo "skipped package due to failure: $package_name-$version.tgz" >>./failed-packages.txt
    cd ./../../

  done

  echo "..."

done

echo "Run this to clean up your working dir: rm -rf ./temp"

# TODO: Would be nice to capture error messages somewhere:  | tee -a migration.log

# TODO: Ability to delta sync? might be separate script

# TODO: Concept for parallelization to speed up the process
