#!/bin/bash

# gh cli's token needs to be able to delete repos - run this first if it can't
# gh auth refresh -h github.com -s delete_repo

gh api --method DELETE /repos/joshjohanning-org/hello-world
