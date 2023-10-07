#!/bin/bash

if [ $# -lt "1" ]; then
    echo "Usage: $0 <organization>"
    exit 1
fi

organization=$1

gh api graphql --paginate -f org="$organization" -f query='query ($org: String! $endCursor: String) {
	organization(login: $org) {
		repositories(first: 100, after: $endCursor) {
			pageInfo { hasNextPage endCursor }
			nodes {
				name
				codeowners {
					errors {
						path
						source
						kind
						message
					}
				}
			}
		}
	}
}' | jq -r '.data.organization.repositories.nodes[] | select(.codeowners != null) | select(.codeowners.errors != null) | .name as $name | .codeowners.errors[] | [$name, .path, (.source | gsub("\n"; "")), .kind] | @tsv'
