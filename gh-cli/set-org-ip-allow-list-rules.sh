#!/bin/bash

set -e

## This script synchronizes the IP allow list rules in an organization with rules defined in a JSON file
## The script ignores if the rules are active or not, it only checks if the rule exists or not
## It doesn't validate the IP addresses nor checks if there are overlapping rules it does
## exact matches.
## All rules are added before any rules are deleted to avoid unavailability of the service
## in case you change the name of the rules, so a duplicate rule will be added and then only 
## then the older will be removed.
## NOTE: The name of the rules are case sensitive

## Assumes the rules configuration file us a json file with the following format:
# {
#     "list": [
#         {
#             "name": "proxy-us",
#             "ip": "192.168.1.1"
#         },
#         {
#             "name": "proxy-us",
#             "ip": "192.168.1.2"
#         },
#         {
#             "name": "proxy-eu",
#             "ip": "192.168.88.0/23"
#         }
#     ]
# }
# If your format is different, you change the normalization step below without the need to change the 
# script

# The name is used as a key to identify the rule, so if you change the name, the rule will added (as a duplicated value) and then be deleted 
# The key doesn't need to be unique, the same name can be used for multiple rules


# check if comm is installed
if ! command -v comm &> /dev/null
then
    echo "comm could not be found. Please install this required dependency"
    exit 1
fi

# check if jq is installed
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install this required dependency"
    exit 1
fi

PrintUsage()
{
  cat <<EOM
Usage: migrate [options]

Options:
    -h, --help                    : Show script help
    -r, --rules-file              : The file with IP Allow List rules to apply
    --backup-rules-file           : The file to backup the current rules to (optional)
    --org                         : The organization to apply the rules to    
    --dry-run                     : Run the script without making any changes
    
Description:

Example:
  ./set-ip-allow-list-setting.sh --org fabrikam -r rules.json --dry-run

EOM
  exit 0
}

####################################
# Read in the parameters if passed #
####################################
PARAMS=""
while (( "$#" )); do
  case "$1" in
    -h|--help)
      PrintUsage;
      ;;
    --org)
      organization_name=$2
      shift 2
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    -r|--rules-file)
      rules_file=$2
      shift 2
      ;;
    --backup-rules-file)
      backup_rules_file=$2
      shift 2
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
  PARAMS="$PARAMS $1"
  shift
  ;;
  esac
done

if [ -z "$organization_name" ] || [ -z "$rules_file" ]; then
  PrintUsage
fi

# check if file exists
if [ ! -f "$rules_file" ]; then
  echo "File $rules_file does not exist"
  exit 1
fi

# https://docs.github.com/en/graphql/reference/input-objects#deleteipallowlistentryinput
delete_ip_allow_list_entry() {
  local id=$1

   if [ "$dry_run" == "true" ]; then
    return
   fi

  gh api graphql -f id="$id" -f query='mutation ($id: ID!) { deleteIpAllowListEntry(input: { ipAllowListEntryId : $id }) { clientMutationId }  }' --silent
}

# https://docs.github.com/en/graphql/reference/mutations#createipallowlistentry
create_ip_allow_list_entry() {
  local owner_id=$1
  local allow_list_value=$2
  local name=$3

   if [ "$dry_run" == "true" ]; then
    return
   fi

  gh api graphql -f owner_id="$owner_id" -f allow_list_value="$allow_list_value" -f name="$name" -f query='mutation ($owner_id: ID! $allow_list_value: String! $name: String!) { 
    createIpAllowListEntry(input: { ownerId: $owner_id allowListValue: $allow_list_value name: $name isActive: true }) { 
        ipAllowListEntry { id }
        }
    }' --silent
}

#################################### Begin script ####################################

if [ "$dry_run" == "true" ]; then
  echo "Running in dry-run mode. No changes will be made"
fi

# get org id
org_id=$(gh api graphql -f organizationName="$organization_name" \
    -f query='query getOrganizationId($organizationName: String!) { organization(login: $organizationName) { id  } }' \
    --jq '.data.organization.id')

if [ "$org_id" == "null" ]  || [ "$org_id" == "" ]; then
  echo "Organization $organization_name does not exist"
  exit 1
fi

ipallow_file="_ip-allow-list.$$.json"
ipallow_normalized_file="_ip-allow-list-normalized.$$.json"
rules_normalized_file="_rules-normalized.$$.json"

gh api graphql --paginate -f organizationName="$organization_name" -f query='
query getOrganizationIpAllowList($organizationName: String! $endCursor: String) {
  organization(login: $organizationName) {
    ipAllowListEntries(first: 100, after: $endCursor) {
      nodes {
        id
        allowListValue
        name
        isActive
        createdAt
        updatedAt
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}' --jq '.data.organization.ipAllowListEntries.nodes[]' | jq -s '.' > "$ipallow_file"


echo -e "\nCurrent number of rules in $organization_name: $(jq '. | length' < "$ipallow_file")"
echo "Number of rules in $rules_file: $(jq '.list | length' < "$rules_file")"

if [ -n "$backup_rules_file" ]; then
  echo "Writing backup of rules to $backup_rules_file"
  cp "$ipallow_file" "$backup_rules_file"
fi

# The normalized files (JSON) are used to compare the GH rules with the rules to configure and 
# both HAVE to have the same format, so we normalize the rules to configure to match the format of the rules in GH
# for comparison. They need to have the same format (including order) because we make textual comparisons and not semantic ones

# BEGIN NORMALIZATION RULES CUSTOMIZE if needed
# NOTE: If you change the normalization step, you need to ensure it's the EXACT same format as the normalized rules in GitHub
# Since a textual comparison is made NOT a semantic one.
jq -c '.list[] | {name: .name , allowListValue: .ip}' < "$rules_file" > "$rules_normalized_file"
# END NORMALIZATION

# Normalize the rules we have in GitHub
jq -c '.[] | {name, allowListValue}' < "$ipallow_file" > "$ipallow_normalized_file"

################# Add new rules #################

# Get the list of rules that exist in the source but not in the target and add them 

echo -e "\nChecking new or updated rules to add"

comm -23 <(sort "$rules_normalized_file") <(sort "$ipallow_normalized_file") | while read -r line; do
  name=$(echo "$line" | jq -r '.name')
  allowListValue=$(echo "$line" | jq -r '.allowListValue')
  
  echo "  Adding rule: $name with value: $allowListValue"

  create_ip_allow_list_entry "$org_id" "$allowListValue" "$name"
done

################# Remove rules #################
# This deletes the rules that are either different or just don't exist anymore

# Print number of rules


echo -e "\nChecking rules no longer relevant for deletion"

comm -23 <(sort "$ipallow_normalized_file") <(sort "$rules_normalized_file") | sort | uniq | while read -r line; do

    name=$(echo "$line" | jq -r '.name')
    allowListValue=$(echo "$line" | jq -r '.allowListValue')

    # now we need to get the IDs of the rules (there can be more than one in case of duplicates) that we want to delete
    jq -r --arg name "$name" --arg allowListValue "$allowListValue" '.[] | select(.name == $name and .allowListValue == $allowListValue) | .id' < "$ipallow_file" | while read -r id; do
        echo "  Deleting rule: $name with value: $allowListValue with id: $id"
        delete_ip_allow_list_entry "$id"
    done
done

echo -e "\nDone"

################### Cleanup
rm "$ipallow_file" "$ipallow_normalized_file" "$rules_normalized_file"