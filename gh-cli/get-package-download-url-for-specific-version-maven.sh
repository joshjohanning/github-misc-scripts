#!/bin/bash

# gh auth refresh -h github.com -s read:packages

if [ $# -ne "4" ]; then
    echo "Usage: $0 <org> <package_name> <version> <file-type>"
    echo "Example: ./get-package-download-url-for-specific-version-maven.sh joshjohanning-org com.sherlock.herokupoc 1.0.0-202202122241 jar"
    exit 1
fi


org="$1"
package_name="$2"
version="$3"
filetype="$4"
token=$(gh auth token)

# get everything after com.[word].*
package_name_short=$(echo $package_name | sed 's/.*\.\(.*\)/\1/g')
echo "artifactId: $package_name_short"

# convert . to /
package_name_slashes=$(echo $package_name | sed 's/\./\//g')
echo "groupID and artifactId converted to slashes format: $package_name_slashes"

# download 
curl -H "Authorization: token $token" -L -O https://maven.pkg.github.com/$org/download/$package_name_slashes/$version/$package_name_short-$version.$filetype
