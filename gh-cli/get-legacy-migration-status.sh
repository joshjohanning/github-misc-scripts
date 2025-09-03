#!/bin/bash

# gh cli's token needs to be able to admin org - run this if it fails
# gh auth refresh -h github.com -s admin:org

# see also: https://github.github.com/enterprise-migrations/#/3.1.2-import-using-graphql-api?id=import-troubleshooting

# note this is not GEI, and you should be using GEI to do future imports

# note: this endpoint is shut down as of March 31, only adding here for historical purposes
# https://github.blog/changelog/2025-03-30-closing-down-enterprise-cloud-importer-eci-effective-march-31-2025

gh api graphql --paginate -H 'GraphQL-Features: gh_migrator_import_to_dotcom' -f organization='joshjohanning-org-bbs-migration' -f guid='f7843360-db96-4026-ac04-7beeaef562eb'  -f query='
query ($organization: String!, $guid: String!) {
  organization (login: $organization) {
    migration (guid: $guid) {
      state
      databaseId
      migratableResources { totalCount }
    }
  }
}'
