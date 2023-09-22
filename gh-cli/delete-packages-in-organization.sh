#!/bin/bash

# This deletes ALL packages in an organization for a given package type
#
# Example: ./delete-packages-in-organization.sh josh-johanning-test maven
#
# package types: 
# - docker
# - maven
# - npm
# - nuget
# - rubygems
#

if [ $# -ne "2" ]; then
    echo "Usage: $0 <org> <package_type>"
    exit 1
fi

org=$1
package_type=$2

echo "⛔️ WARNING: This is going to delete all $package_type packages in the $org organization in 10 seconds"
echo ". . ... ..."
sleep 10

packages=$(gh api /orgs/$org/packages?package_type=$package_type -q '.[].name')

for package in $packages
do
  echo "deleting package: $package"
  gh api --method DELETE /orgs/$org/packages/$package_type/$package
done
