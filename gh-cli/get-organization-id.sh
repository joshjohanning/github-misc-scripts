#!/bin/bash

gh api graphql -H X-Github-Next-Global-ID:1 -f organization='my-org' -f query='
query ($organization: String!)
  { organization(login: $organization) { 
    id 
  } 
}
'