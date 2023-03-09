#!/usr/bin/env bash

# modified from https://learn.microsoft.com/en-us/azure/storage/scripts/storage-blobs-container-delete-by-prefix-cli#run-the-script
# requires GNU date.
# if using a mac, brew install coreutils.

PREFIX="migration-archives"
TIME_DELETE_SECS="3600"

#IF USING MAC
#alias date=`gdate`

echo "Deleting migration-archives containers..."
for container in `az storage container list \
	--connection-string $AZURE_STORAGE_CONNECTION_STRING \
	--prefix "${PREFIX}" \
	--query "[].name" \
	--output tsv`; do
	
	container_original_date=$(az storage container show --name $container --connection-string $AZURE_STORAGE_CONNECTION_STRING --output tsv --query "properties.lastModified")
	container_date=$(date -d $container_original_date '+%s')
	date_now=$(date '+%s')
	date_diff=$(($date_now - $container_date))
	
	if [[ $date_diff -gt $TIME_DELETE_SECS ]]; then
		echo "Removing container: $container"
		del_container=$(az storage container delete --name $container --connection-string $AZURE_STORAGE_CONNECTION_STRING)
	fi
	

	# az storage container delete --connection-string $AZURE_STORAGE_CONNECTION_STRING --name $container;
done

echo "Remaining containers..."
az storage container list --connection-string $AZURE_STORAGE_CONNECTION_STRING --output table
