#!/bin/bash

# Usage: ./migrate-maven-packages-between-github-instances.sh <source-org> <source-host> <target-org> <target-host>
#
#
# Prereqs:
# 1. [gh cli](https://cli.github.com) installed
# 2. Set the source GitHub PAT env var: `export GH_SOURCE_PAT=ghp_abc` (must have at least `read:packages`, `read:org` scope)
# 3. Set the target GitHub PAT env var: `export GH_TARGET_PAT=ghp_xyz` (must have at least `write:packages`, `read:org`, `repo` scope)
#
# Example: ./migrate-maven-packages-between-github-instances.sh joshjohanning-org github.com joshjohanning-emu github.com
#
# Notes:
# - Until Maven supports the new GitHub Packages type, mvnfeed requires the target repo to exist 
# - This scripts creates the repo if it doesn't exist
# - Otherwise, if the repo doesn't exist, receive "example-1.0.5.jar was not found in the repository" error
# - Link to [GitHub public roadmap item](https://github.com/github/roadmap/issues/578)
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

# log in to gh cli with source pat
export GH_TOKEN=$GH_SOURCE_PAT

# create temp dir
mkdir -p ./temp
cd ./temp
temp_dir=$(pwd)

# check if mvnfeed is installed
if ! command -v mvnfeed &> /dev/null
then
  # check if python3 is installed
  if ! command -v python3 &> /dev/null
  then
    echo "Error: python3 could not be found"
    exit
  fi
  if [ -d "./tool/mvnfeed-cli" ]; then rm -rf ./tool/mvnfeed-cli; fi
  git clone https://github.com/microsoft/mvnfeed-cli.git ./tool/mvnfeed-cli
  cd ./tool/mvnfeed-cli
  python3 ./scripts/dev_setup.py
  cd $temp_dir
fi

# get current user for source/target
current_user_source=$(curl -s -H "Authorization: Bearer $GH_SOURCE_PAT" https://api.$SOURCE_HOST/user | jq -r '.login')
current_user_target=$(curl -s -H "Authorization: Bearer $GH_TARGET_PAT" https://api.$TARGET_HOST/user | jq -r '.login')

# base64 encode auth for mvnfeed
auth_source=$(echo -n "$current_user_source:$GH_SOURCE_PAT" | base64 -w0)
auth_target=$(echo -n "$current_user_target:$GH_TARGET_PAT" | base64 -w0)

packages=$(GH_HOST="$SOURCE_HOST" gh api --paginate "/orgs/$SOURCE_ORG/packages?package_type=maven" -q '.[] | .name + " " + .repository.name')

echo "$packages" | while IFS= read -r response; do

  package_name=$(echo "$response" | cut -d ' ' -f 1)
  repo_name=$(echo "$response" | cut -d ' ' -f 2)

  echo "org: $SOURCE_ORG repo: $repo_name --> package name $package_name"

  # set up source and target registries for mvnfeed
  mvnfeed config repo list >/dev/null 2>&1
  rm ~/.mvnfeed/mvnfeed.ini
  mvnfeed config repo list >/dev/null 2>&1
  echo "[repository.githubsource]" >> ~/.mvnfeed/mvnfeed.ini
  echo "url = https://maven.pkg.github.com/$SOURCE_ORG/$repo_name" >> ~/.mvnfeed/mvnfeed.ini
  echo "authorization = Basic $auth_source" >> ~/.mvnfeed/mvnfeed.ini
  echo "" >> ~/.mvnfeed/mvnfeed.ini
  echo "[repository.githubtarget]" >> ~/.mvnfeed/mvnfeed.ini
  echo "url = https://maven.pkg.github.com/$TARGET_ORG/$repo_name" >> ~/.mvnfeed/mvnfeed.ini
  echo "authorization = Basic $auth_target" >> ~/.mvnfeed/mvnfeed.ini
  echo "" >> ~/.mvnfeed/mvnfeed.ini

  mvnfeed config stage_dir set --path $temp_dir/artifacts

  # check if $TARGET_ORG/$repo_name exists in GitHub - if not, create it
  if ! GH_HOST="$TARGET_HOST" gh api "/repos/$TARGET_ORG/$repo_name" >/dev/null 2>&1
  then
    echo "creating repo $TARGET_ORG/$repo_name"
    GH_HOST="$TARGET_HOST" gh repo create "$TARGET_ORG/$repo_name" --private --confirm
  fi

  versions=$(GH_HOST="$SOURCE_HOST" gh api --paginate "/orgs/$SOURCE_ORG/packages/maven/$package_name/versions" -q '.[] | .name' | sort -V)
  for version in $versions
  do
    echo "$version"
    package_com=$(echo "$package_name" | cut -d '.' -f 1)
    package_group=$(echo "$package_name" | cut -d '.' -f 2- | rev | cut -d '.' -f 2- | rev)
    package_artifact=$(echo "$package_name" | rev | cut -d '.' -f 1 | rev)

    name=$(echo $package_com.$package_group:$package_artifact:$version)
    echo $name

    mvnfeed artifact transfer --from=githubsource --to=githubtarget --name=$package_com.$package_group:$package_artifact:$version

  done

  echo "..."

done

echo "Run this to clean up your working dir: rm -rf ./temp"
