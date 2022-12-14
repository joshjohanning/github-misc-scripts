#!/bin/bash

# gh cli's token needs to be able to read enterprise - run this first if it can't
# gh auth refresh -h github.com -s read:enterprise

gh api graphql -H X-Github-Next-Global-ID:1 -f enterprise='my-enterprise-name' -f query='
query ($enterprise: String!)
  { enterprise(slug: $enterprise) { 
    id 
  } 
}
'