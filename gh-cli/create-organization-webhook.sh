#!/bin/bash

# credits: @andyfeller

# gh cli's token needs to be able to admin org - run this first if it can't
# gh auth refresh -h github.com -s admin:org

gh api orgs/joshjohanning-org/hooks | jq --arg newSecret "SECRET" 'map({ name: .name, active: .active, events: .events, config: (.config | .secret=$newSecret) })' 
[
  {
    "name": "web",
    "active": true,
    "events": [
      "push"
    ],
    "config": {
      "content_type": "json",
      "insecure_ssl": "0",
      "secret": "SECRET",
      "url": "https://smee.io/abcdefg"
    }
  }
]
