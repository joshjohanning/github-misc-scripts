#!/bin/bash

# modified from https://learn.microsoft.com/en-us/azure/storage/scripts/storage-blobs-container-delete-by-prefix-cli#run-the-script
# requires GNU date.
# if using a mac: `brew install coreutils`

# set up env var before running
# export AZURE_STORAGE_CONNECTION_STRING=DefaultEndpointsProtocol=https;AccountName=geijosh;AccountKey=abcde;EndpointSuffix=core.windows.net

PREFIX="migration-archives"
TIME_DELETE_SECS="3600"

OS=$(uname -s)
case "$OS" in
    Linux*)     datecmd=date ;; # use date if linux
    Darwin*)    datecmd=gdate ;; # use gdate if macos
    *)          echo "Unknown operating system" ;;
esac

echo "Using date command: $(which $datecmd)"

echo "Deleting migration-archives containers..."
for container in `az storage container list \
	--connection-string $AZURE_STORAGE_CONNECTION_STRING \
	--prefix "${PREFIX}" \
	--query "[].name" \
	--output tsv`; do

	container_original_date=$(az storage container show --name $container --connection-string $AZURE_STORAGE_CONNECTION_STRING --output tsv --query "properties.lastModified")
	container_date=$($datecmd -d $container_original_date '+%s')
	date_now=$($datecmd '+%s')
	date_diff=$(($date_now - $container_date))
	
	if [[ $date_diff -gt $TIME_DELETE_SECS ]]; then
		echo "Removing container: $container"
		del_container=$(az storage container delete --name $container --connection-string $AZURE_STORAGE_CONNECTION_STRING)
	fi
done

echo "Remaining containers..."
az storage container list --connection-string $AZURE_STORAGE_CONNECTION_STRING --output table
