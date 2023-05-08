#!/bin/bash

# gh auth refresh -h github.com -s read:packages

if [ $# -ne "3" ]; then
    echo "Usage: $0 <org> <package_name> <version>"
    echo "Example: ./get-package-download-url-for-specific-version-npm.sh joshjohanning-org npm-package-example 0.0.3"
    exit 1
fi


org="$1"
package_name="$2"
version="$3"
token=$(gh auth token)

# get url
url=$(curl -H "Authorization: token $token" -Ls https://npm.pkg.github.com/@$org/$package_name | jq --arg version $version -r '.versions[$version].dist.tarball')

# check for error
if [ "$url" == "null" ]; then
    echo "ERROR: version $version not found for package $package_name"
    echo "NOTE: Make sure you have the proper scopes for gh; ie run this: gh auth refresh -h github.com -s read:packages"
    exit 1
fi

# download 
curl -H "Authorization: token $token" -L -o $package_name-$version.tgz $url
