#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage: $0 <repo list file> [archive state]"
  echo "<archive state> is true or false (defaults to true)"
  exit 1
fi

repo_list_file="$1"
archive_state="${2:-true}"

if [ ! -f "$repo_list_file" ]; then
  echo "File not found: $repo_list_file"
  exit 1
fi

if [ "$archive_state" != "true" ] && [ "$archive_state" != "false" ]; then
  echo "Invalid archive state: $archive_state"
  exit 1
fi

operation="Archiving"
if [ "$archive_state" == "false" ]; then
  operation="Unarchiving"
fi

while read -r repofull ; 
do
    echo "$operation $repofull"

    gh api -X PATCH "/repos/$repofull" -F archived="$archive_state" --silent
done < "$repo_list_file"

