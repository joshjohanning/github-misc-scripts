#!/bin/bash

gh api graphql -H X-Github-Next-Global-ID:1 -f enterprise='my-enterprise-name' -f query='
query ($enterprise: String!)
  { enterprise(slug: $enterprise) { 
    id 
  } 
}
'