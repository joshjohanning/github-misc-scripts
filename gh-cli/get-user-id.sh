#!/bin/bash

gh api graphql -H X-Github-Next-Global-ID:1 -f user='my-username' -f query='
query ($user: String!)
  { user(login: $user) { 
    id 
  } 
}
'
