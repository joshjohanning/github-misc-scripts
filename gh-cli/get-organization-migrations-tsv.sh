#!/bin/bash

if [ $# -lt "1" ]; then
    echo "Usage: $0 <organization> [max migrations]"
    echo "[max migrations] is optional max value is 100. Use if you do not want to get all migrations"
    exit 1
fi

organization=$1
if [ $# -eq "2" ]; then
    max_migrations=$2
else
    max_migrations=100
    paginate="--paginate"
fi

if [ "$max_migrations" -gt 100 ]; then
    echo "Max migrations is 100"
    echo "This parameter is only used to limit the number of migrations to get instead of getting all of them"
    exit 1
fi

# shellcheck disable=SC2086,SC2016
gh api graphql $paginate -f org="$organization" -F page_size="$max_migrations" -f query='query ($org: String!, $page_size: Int $endCursor: String) {
	organization(login: $org) {
		repositoryMigrations(first: $page_size after: $endCursor) {
            pageInfo { hasNextPage endCursor }
			nodes {
				id
				sourceUrl
				createdAt
				state
				failureReason
				warningsCount
				migrationLogUrl
			}
		}
	}
}' | jq -r '.data.organization.repositoryMigrations.nodes[] | [.id, .createdAt, .sourceUrl, .repositoryName, .state, .failureReason, .warningsCount, .migrationLogUrl] | @tsv'