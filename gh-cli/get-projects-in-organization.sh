#!/bin/bash

# needs: gh auth login -s read:project

if [ -z "$1" ]
  then
    echo "Usage: $0 <org>"
    exit 1
fi

org=$1

gh api graphql --paginate -f organization="$org" -f query='
  query ($organization: String!) {
    organization (login: $organization) {
			login
      projectsV2 (first: 100) {
				totalCount
        nodes {
					title
					shortDescription
					id
					url
					number
					updatedAt
					creator {
						login
					}
					closed
					closedAt
					repositories (first: 100) {
						totalCount
						nodes {
							name
						}
          }
					items {
						totalCount
					}
					views {
						totalCount
					}
        }
      }
    }
  }
'
