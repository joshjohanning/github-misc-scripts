#!/bin/bash

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
# - This script assumes that the target org's repo name is the same as the source
# - If the repo doesn't exist, the package will still import but won't be mapped to a repo
#

set -e

if [ $# -ne "3" ]; then
    echo "Usage: $0 <source-org> <source-host> <target-org>"
    exit 1
fi

echo "..."

SOURCE_ORG=$1
SOURCE_HOST=$2
TARGET_ORG=$3

# make sure env variables are defined
if [ -z "$GH_SOURCE_PAT" ]; then
    echo "Error: set GH_SOURCE_PAT env var"
    exit 1
fi

if [ -z "$GH_TARGET_PAT" ]; then
    echo "Error: set GH_TARGET_PAT env var"
    exit 1
fi

# create temp dir
mkdir -p ./temp
cd ./temp
temp_dir=$(pwd)
GPR_PATH="$temp_dir/tool/gpr"

# check if dotnet is installed
if ! command -v dotnet &> /dev/null
then
    echo "Error: dotnet could not be found"
    exit
fi

# install gpr locally
if [ ! -f "$GPR_PATH" ]; then
  echo "Installing gpr locally to $GPR_PATH"
  dotnet tool install gpr --tool-path ./tool
fi

packages=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api "/orgs/$SOURCE_ORG/packages?package_type=nuget" --paginate -q '.[] | .name + " " + .repository.name')

if [ -z "$packages" ]; then
  echo "No nuget packages found in $SOURCE_ORG"
  exit 0
fi

echo "$packages" | while IFS= read -r response; do

  packageName=$(echo "$response" | cut -d ' ' -f 1)
  repoName=$(echo "$response" | cut -d ' ' -f 2)
  
  # If the package is not attached to a repo just use the package name
  if [ -z "$repoName"]; then
    repoName=$packageName
  fi
  echo "$repoName --> $packageName"

  versions=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api "/orgs/$SOURCE_ORG/packages/nuget/$packageName/versions" --paginate -q '.[] | .name')
  for version in $versions
  do
    echo "$version"
    url="https://nuget.pkg.$SOURCE_HOST/$SOURCE_ORG/download/$packageName/$version/$packageName.$version.nupkg"
    echo $url
    curl -Ls -H "Authorization: token $GH_SOURCE_PAT" $url --output "${packageName}_${version}.nupkg" -s

    # must do this otherwise there is errors (multiple of each file)
    zip -d "${packageName}_${version}.nupkg" "_rels/.rels" "\[Content_Types\].xml" # there seemed to be duplicate of these files in the nupkg that led to errors in gpr
    
    eval $GPR_PATH push ./"${packageName}_${version}.nupkg" --repository https://github.com/$TARGET_ORG/$repoName -k $GH_TARGET_PAT || echo "ERROR: Could not publish version $version of $package_name. Skipping version."
  done

  echo "..."

done

echo "Run this to clean up your working dir: rm -rf ./temp"