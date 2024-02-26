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
# - The `mvnfeed-cli` tool doesn't appear to support copying `.war` files (only `.jar`)
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

SOURCE_USERNAME="user"
TARGET_USERNAME="user"
temp_dir=$(mktemp -d)

function create_settings_xml () {
  ORG="${1}"
  REPO="${2}"
  USER="${3}"
  PASS="${4}"
  OUTFILE="${5}"
  cat resources/m2-settings.xml.templ | sed "s/{{.*ORG.*}}\//${ORG}\//g" | sed "s/{{.*REPO.*}}/${REPO}/g" | sed "s/{{.*USER.*}}/${USER}/g" | sed "s/{{.*USER.*}}/${PASS}/g" > ${OUTFILE}
}

packages=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages?package_type=maven" -q '.[] | .name + " " + .repository.name')

if [ -z "$packages" ]; then
  echo "No maven packages found in $SOURCE_ORG"
  exit 0
fi

echo "$packages" | while IFS= read -r response; do
  package_name=$(echo "$response" | cut -d ' ' -f 1)
  repo_name=$(echo "$response" | cut -d ' ' -f 2)

  # Split package to components on '.'s
  package_com=$(echo "$package_name" | cut -d '.' -f 1)
  package_group=$(echo "$package_name" | cut -d '.' -f 2- | rev | cut -d '.' -f 2- | rev)
  package_artifact=$(echo "$package_name" | rev | cut -d '.' -f 1 | rev)

  echo "org: $SOURCE_ORG repo: $repo_name --> package name $package_name"

  # check if $TARGET_ORG/$repo_name exists in GitHub - if not, create it
  if ! GH_HOST="$TARGET_HOST" GH_TOKEN=$GH_TARGET_PAT gh api "/repos/$TARGET_ORG/$repo_name" >/dev/null 2>&1
  then
    echo "creating repo $TARGET_ORG/$repo_name"
    GH_HOST="$TARGET_HOST" GH_TOKEN=$GH_TARGET_PAT gh repo create "$TARGET_ORG/$repo_name" --private --confirm
  fi

  #create_settings_xml "$SOURCE_ORG" "$repo_name" "$GH_SOURCE_USERNAME" "$GH_SOURCE_PAT" "$temp_dir/settings-source.xml"
  echo "Creating settings XML for source and destination"
  create_settings_xml "$SOURCE_ORG" "$repo_name" "$SOURCE_USERNAME" "$GH_SOURCE_PAT" "$temp_dir/settings-source.xml"
  create_settings_xml "$TARGET_ORG" "$repo_name" "$TARGET_USERNAME" "$GH_TARGET_PAT" "$temp_dir/settings-target.xml"

  echo "Iterating through all package versions"
  versions=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages/maven/$package_name/versions" -q '.[] | .name' | sort -V)
  for version in $versions
  do

    # Download the artifact
    name=$(echo $package_com.$package_group:$package_artifact:$version)
    echo "Pulling: $name"
    mvn org.apache.maven.plugins:maven-dependency-plugin:RELEASE:get \
      --settings "${temp_dir}/settings-source.xml" \
      -DartifactId="${package_artifact}" \
      -DgroupId="${package_com}.${package_group}" \
      -Dversion="${version}"

    # Move artifact to the temp dir
    # deploy-file wont let you do this from the cache dir
    mv ~/.m2/repository/${package_com//./\/}/${package_group//./\/}/${package_artifact}/${version} $temp_dir/${package_artifact}-${version}
    cd $temp_dir/${package_artifact}-${version}


    echo "Deploying ${package_name}:${version} to ${TARGET_ORG}/${repo_name}"
    # Find the file to upload if its a jar, war or ear, doesnt need to be a for loop, but easier
    for file in $(ls ${package_artifact}-${version}.[jwe]ar)
      mvn deploy:deploy-file \
        --settings "${temp_dir}/settings-target.xml" \
        -Dfile=${file} \
        -DpomFile=${package_artifact}-${version}.pom \
        -DrepositoryId=github \
        -Durl=https://maven.pkg.github.com/${TARGET_ORG}/${repo_name}
    done

    # Clean up
    cd $temp_dir
    echo "removeing old package"
    rm -rf "${package_artifact}-${version}"
  done

  # Clean up the package group dir
  rm -rf ~/.m2/repository/${package_com//./\/}/${package_group//./\/}/

  echo "..."

rm -rf ${temp_dir}

# download url if want to download maven artifact manually:
# curl -H "Authorization: token $GH_SOURCE_PAT" -Ls https://maven.pkg.github.com/$SOURCE_ORG/download/$package_com/$package_group/$package_artifact/$version/$package_artifact-$version.jar
