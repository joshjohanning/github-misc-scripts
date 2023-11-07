#!/bin/bash

# ./__map_users_using_csv.sh oldusername csvfile.csv.

# CSV File
# oldusername,newusername

# NOTE: not meant to be called directly

oldusername=$1
csvfile=$2

newusername=$(grep "^$oldusername," $csvfile | awk -F ',' '{print $2}')

if [ -z "$newusername" ]; then
    echo "Error: oldusername not found in csvfile"
    exit 1
fi

echo $newusername