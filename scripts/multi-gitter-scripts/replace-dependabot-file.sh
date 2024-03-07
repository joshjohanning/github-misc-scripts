#!/bin/bash

# replaces the dependabot.yml file with a new one

# Relative path to the file to be replaced
FILE="./.github/dependabot.yml"

# Full path to the file to copy in
REPLACE_WITH_FILE=~/Repos/github-misc-scripts/scripts/dependabot.yml

if [ -f "$FILE" ]; then
  echo "File $FILE exists."
else
  echo "File $FILE does not exist. Creating..."
  mkdir -p ./.github
  cp $REPLACE_WITH_FILE $FILE
  echo "File $FILE created."
fi
