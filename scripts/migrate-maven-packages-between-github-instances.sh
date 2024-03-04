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
# - Only supports JARs right now
# - Only grabs the latest SNAPSHOT version, not all versions
# - Only grabs the jar named artifactId-version.jar (not sure how to detect more if using a release)
# - Kinda cursed
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

# For local testing
if [ -z "$GITHUB_ACTION_PATH" ]; then
  GITHUB_ACTION_PATH="."
fi

temp_dir=$(mktemp -d)
echo "temp_dir: $temp_dir"

function create_settings_xml () {
  ORG="${1}"
  REPO="${2}"
  USER="${3}"
  PASS="${4}"
  OUTFILE="${5}"
  cat ${GITHUB_ACTION_PATH}/resources/m2-settings.xml.tmpl | sed "s/{{.*ORG.*}}\//${ORG}\//g" | sed "s/{{.*REPO.*}}/${REPO}/g" | sed "s/{{.*USER.*}}/${USER}/g" | sed "s/{{.*PASS.*}}/${PASS}/g" > ${OUTFILE}
}

packages=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages?package_type=maven" -q '.[] | .name + " " + .repository.name')

if [ -z "$packages" ]; then
  echo "No maven packages found in $SOURCE_ORG"
  exit 0
fi

echo "Checking for XMLlint"
if ! command -v xmllint &> /dev/null
then
  echo "XMLlint could not be found, installing"
  sudo apt-get update
  sudo apt-get -y install libxml2-utils
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

  echo "Creating settings XML for source and destination"
  create_settings_xml "$TARGET_ORG" "$repo_name" "$TARGET_USERNAME" "$GH_TARGET_PAT" "$temp_dir/settings-target.xml"

  echo "Iterating through all package versions"
  versions=$(GH_HOST="$SOURCE_HOST" GH_TOKEN=$GH_SOURCE_PAT gh api --paginate "/orgs/$SOURCE_ORG/packages/maven/$package_name/versions" -q '.[] | .name' | sort -V)
  for version in $versions
  do

    # Download the artifact
    name=$(echo $package_com.$package_group:$package_artifact:$version)

    # Maven says: "Be reasonable, resolve dependencies" to which I reply "Where has reason ever gotten me?"
    # I could _ask_ users for a settings xml with all the repos to resolve dependencies but all I want to do is get files out of the registry
    # Instead I have build this, a monumnent to my own hubris
    # I will read your maven-metadata, I will parse the XML in BASH. I will find your snapshots and your releases and I will tell maven "just go for it"
    echo "Pulling: $name"
    mkdir -p $temp_dir/${package_artifact}-${version}

    # For SNAPSHOTs, find the latest snapshot version and download that file (cant download SNAPSHOTs directly, need to know the version)
    if [[ $version == *"SNAPSHOT" ]]; then
      # ex https://maven.pkg.github.com/jcantosz-test-org/incubator-baremaps/com/baremaps/baremaps-osm/0.2.0/baremaps-osm-0.2.0.jar
      #    https://maven.pkg.github.com/jcantosz-test-org/incubator-baremaps/com/baremaps/baremaps-osm/0.1-SNAPSHOT/baremaps-osm-0.1-20240304.162117-1.jar
      echo "Getting maven-metadata.xml"
      curl -o $temp_dir/${package_artifact}-${version}/maven-metadata.xml \
        --retry 5 \
        --retry-max-time 120 \
        -sL \
        -H "Authorization: Token ${GH_SOURCE_PAT}" \
        -H 'Accept: application/vnd.github.v3.raw' \
        "https://maven.pkg.github.com/${SOURCE_ORG}/${repo_name}/${package_com//./\/}/${package_group//./\/}/${package_artifact}/${version}/maven-metadata.xml"

      LATEST_SNAPSHOT=$(xmllint --xpath 'concat(/metadata/versioning/snapshot/timestamp/text(),"-",/metadata/versioning/snapshot/buildNumber/text())' $temp_dir/${package_artifact}-${version}/maven-metadata.xml)
      echo "LATEST_SNAPSHOT: $LATEST_SNAPSHOT"

      # replace -SNAPSHOT with the latest snapshot
      FILE_VERSION=${version/SNAPSHOT/$LATEST_SNAPSHOT}

      # XMLlint, find all extensions where version is JAR_VERSION
      extensions=$(xmllint --xpath "/metadata/versioning/snapshotVersions/snapshotVersion/value[.='${FILE_VERSION}']/../extension/text()" $temp_dir/${package_artifact}-${version}/maven-metadata.xml | grep -v 'md5\|sha1')
    else # For release`s, just download the file
      extensions="jar pom"
      FILE_VERSION=$version
    fi

    for extension in $extensions; do
        echo "getting ${package_artifact}-${FILE_VERSION}.${extension}"
        curl -o $temp_dir/${package_artifact}-${version}/${package_artifact}-${version}.${extension} \
        --retry 5 \
        --retry-max-time 120 \
        -sL \
        -H "Authorization: Token ${GH_SOURCE_PAT}" \
        -H 'Accept: application/vnd.github.v3.raw' \
        "https://maven.pkg.github.com/${SOURCE_ORG}/${repo_name}/${package_com//./\/}/${package_group//./\/}/${package_artifact}/${version}/${package_artifact}-${FILE_VERSION}.${extension}"
    done

    cd $temp_dir/${package_artifact}-${version}

    # Deploy the artifact
    echo "Deploying ${package_name}:${version} to ${TARGET_ORG}/${repo_name}"
    # Find the file to upload if its a jar, war or ear, doesnt need to be a for loop, but easier
    for file in $(ls ${package_artifact}-${version}.[jwe]ar); do
      mvn deploy:deploy-file \
        --no-transfer-progress \
        --settings "${temp_dir}/settings-target.xml" \
        -Dfile=${file} \
        -DpomFile=${package_artifact}-${version}.pom \
        -DrepositoryId=github \
        -Durl=https://maven.pkg.github.com/${TARGET_ORG}/${repo_name}
    done
    # Clean up
    cd $temp_dir
    echo "removing old package"
    rm -rf "${package_artifact}-${version}"
  done

  echo "..."
done

echo "cleaning up temp dir"
rm -rf ${temp_dir}

# download url if want to download maven artifact manually:
# curl -H "Authorization: token $GH_SOURCE_PAT" -Ls https://maven.pkg.github.com/$SOURCE_ORG/download/$package_com/$package_group/$package_artifact/$version/$package_artifact-$version.jar
#com.baremaps:baremaps-osm:jar:0.1-SNAPSHOT