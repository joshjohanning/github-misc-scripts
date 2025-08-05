#!/bin/bash

# invites a collaborator to a repository
# this is a wrapper script that calls add-collaborator-to-repository.sh

# sample:
# ./invite-user-to-repository.sh my-org my-repo push joshjohanning

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Call the add-collaborator-to-repository.sh script with all arguments
exec "$SCRIPT_DIR/add-user-to-repository.sh" "$@"
