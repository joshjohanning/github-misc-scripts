#!/bin/bash

# This script updates devDependencies in package.json using npm-check-updates
# and runs npm install to update package-lock.json

# Running:
#
# run:
# multi-gitter run ./update-dev-dependencies.sh -m "chore: update devDependencies" -B "Updated devDependencies to their latest versions using npm-check-updates." -b update-dev-dependencies --git-type=cmd --config update-dev-dependencies.yml --dry-run

# merge:
# multi-gitter merge -b update-dev-dependencies --config update-dev-dependencies.yml --merge-type=squash

set -e

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "No package.json found. Skipping."
    exit 0
fi

# Check if there are devDependencies
if ! grep -q '"devDependencies"' package.json; then
    echo "No devDependencies found in package.json. Skipping."
    exit 0
fi

echo "Found package.json with devDependencies"

# Run npm-check-updates to update devDependencies
echo "Running npm-check-updates to update devDependencies..."
npx npm-check-updates --dep dev -u

# Check if package.json was modified
if git diff --quiet package.json; then
    echo "No updates available for devDependencies."
    exit 0
fi

echo "Updated package.json with new devDependencies versions"

# Run npm install to update package-lock.json
echo "Running npm install to update package-lock.json..."
npm install

echo ""
echo "✓ Successfully updated devDependencies"
exit 0
