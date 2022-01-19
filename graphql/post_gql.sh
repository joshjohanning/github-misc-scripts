#!/bin/bash

####### Setting up options #######
file=${file:-enter-file-name.json}
pat=${pat:-github-pat}

while [ $# -gt 0 ]; do
   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="$2"
   fi
  shift
done
##################################

curl -LX POST 'https://api.github.com/graphql' -H "Authorization: bearer $pat" --data @$file
