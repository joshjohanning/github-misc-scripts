#!/bin/bash

# creates a dependabot.yml with github-actions as an ecosystem
# if dependabot.yml already exists, adds github-actions as an ecosystem if it isn't already there

# Relative path to the file to be replaced
FILE="./.github/dependabot.yml"

# Full path to the file to copy in
REPLACE_WITH_FILE=~/Repos/github-misc-scripts/scripts/dependabot.yml

# Check if the file exists
if [ -f "$FILE" ]; then
  echo "File $FILE exists."
  # Check if "package-ecosystem: github-actions" exists in the file
  if [[ $(yq e '[.updates[] | select(.package-ecosystem == "github-actions")] | length' $FILE) -gt 0 ]]; then
    echo '"package-ecosystem: github-actions" exists in the file.'
  else
    echo '"package-ecosystem: github-actions" does not exist in the file.'
    yq e '.updates += [{"package-ecosystem": "github-actions", "directory": "/", "schedule": {"interval": "daily"}}]' -i $FILE
    echo '"package-ecosystem: github-actions" added to the file.'
  fi
else
  echo "File $FILE does not exist. Creating..."
  mkdir -p ./.github
  # Create the file with initial content
  yq e '.version = "2"' - | \
  yq e '.updates = [{"package-ecosystem": "github-actions", "directory": "/", "schedule": {"interval": "daily"}}]' - > "$FILE"
  echo "File $FILE created."
fi
