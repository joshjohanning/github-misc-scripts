#!/bin/bash

# replaces the dependabot.yml file with a new one 

# note: 
# - update the `--repo-search` parameter to match the repositories you want to update
# - install the utility: `brew install lindell/multi-gitter/multi-gitter`

multi-gitter run ./multi-gitter-scripts/replace-dependabot-file.sh --repo-search "org:joshjohanning-org topic:gitter" -m "adding github-actions to dependabot.yml"

# run this to merge: 
# multi-gitter merge --repo-search "org:joshjohanning-org topic:gitter"

# other commands:
# multi-gitter close --repo-search "org:joshjohanning-org topic:gitter"
# multi-gitter status --repo-search "org:joshjohanning-org topic:gitter"
