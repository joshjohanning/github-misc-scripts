#!/bin/bash

gh api --paginate --method GET "/repos/joshjohanning-org/azure-key-vault-test/commits?since=2022-04-07T16:00:49Z" 

# or - if you use -f, you have to explicity specify the --method GET otherwise it defaults to POST
gh api --paginate --method GET “/repos/joshjohanning-org/azure-key-vault-test/commits” -f 'since=2022-04-07T16:00:49Z'
