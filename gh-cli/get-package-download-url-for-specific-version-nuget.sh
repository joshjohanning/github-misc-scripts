#!/bin/bash

# gh auth refresh -h github.com -s read:packages

if [ $# -ne "3" ]; then
    echo "Usage: $0 <org> <package_name> <version>"
    echo "Example: ./get-package-download-url-for-specific-version-nuget.sh joshjohanning-org Wolfringo.Hosting 1.1.1"
    exit 1
fi


org="$1"
package_name="$2"
version="$3"
token=$(gh auth token)

# download 
curl -H "Authorization: token $token" -L -O https://nuget.pkg.github.com/$org/download/$package_name/$version/$package_name.$version.nupkg
