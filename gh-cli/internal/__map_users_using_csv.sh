#!/bin/bash

# ./__map_users_using_csv.sh oldusername csvfile.csv.

# CSV File - mappings.csv, should exist in same folder as this script
# oldusername,newusername

# NOTE: not meant to be called directly

oldusername=$1
csvfile="../../gh-cli/internal/user_mappings.csv"

newusername=$(grep "^$oldusername," $csvfile | awk -F ',' '{print $2}')

if [ -z "$newusername" ]; then
    echo "Error: oldusername not found in csvfile"
    echo  "oldusername: $oldusername"
    exit 1
fi

echo $newusername