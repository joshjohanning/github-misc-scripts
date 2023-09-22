#!/bin/bash

# Usage: ./migrate-npm-packages-between-github-instances.sh <source-org> <source-host> <target-org> <target-host>
#
#
# Prereqs:
# 1. [gh cli](https://cli.github.com) installed
# 2. Set the source GitHub PAT env var: `export GH_SOURCE_PAT=ghp_abc` (must have at least `read:packages`, `read:org` scope)
# 3. Set the target GitHub PAT env var: `export GH_TARGET_PAT=ghp_xyz` (must have at least `write:packages`, `read:org` scope)
#
# Example: ./migrate-npm-packages-between-github-instances.sh joshjohanning-org github.com joshjohanning-emu github.com

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

# log in to gh cli with source pat
export GH_TOKEN=$GH_SOURCE_PAT

# create temp dir
mkdir -p ./temp
cd ./temp
temp_dir=$(pwd)

# set up .npmrc for target org
echo @$TARGET_ORG:https://npm.pkg.$TARGET_HOST/ > $temp_dir/.npmrc && echo "//npm.pkg.$TARGET_HOST/:_authToken=$GH_TARGET_PAT" >> $temp_dir/.npmrc

packages=$(GH_HOST="$SOURCE_HOST" gh api --paginate "/orgs/$SOURCE_ORG/packages?package_type=npm" -q '.[] | .name + " " + .repository.name')

echo "$packages" | while IFS= read -r response; do

  package_name=$(echo "$response" | cut -d ' ' -f 1)
  repo_name=$(echo "$response" | cut -d ' ' -f 2)

  echo "org: $SOURCE_ORG repo: $repo_name --> package name $package_name"
  
  versions=$(GH_HOST="$SOURCE_HOST" gh api --paginate "/orgs/$SOURCE_ORG/packages/npm/$package_name/versions" -q '.[] | .name' | sort -V)
  for version in $versions
  do
    echo "$version"

    # get url of tarball
    url=$(curl -H "Authorization: token $GH_SOURCE_PAT" -Ls https://npm.pkg.github.com/@$SOURCE_ORG/$package_name | jq --arg version $version -r '.versions[$version].dist.tarball')

    # check for error
    if [ "$url" == "null" ]; then
        echo "ERROR: version $version not found for package $package_name"
        echo "NOTE: Make sure you have the proper scopes for gh; ie run this: gh auth refresh -h github.com -s read:packages"
        exit 1
    fi

    # download 
    curl -H "Authorization: token $GH_SOURCE_PAT" -L -o $package_name-$version.tgz $url
  
    # untar
    mkdir -p ./$package_name-$version
    tar xzf $package_name-$version.tgz -C $package_name-$version
    cd $package_name-$version/package
    perl -pi -e "s/$SOURCE_ORG/$TARGET_ORG/g" package.json
    npm publish --userconfig $temp_dir/.npmrc
    cd ./../../

  done

  echo "..."

done

echo "Run this to clean up your working dir: rm -rf ./temp"
