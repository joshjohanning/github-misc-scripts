#!/bin/bash

# This is an example of searching an org for the deprecated `save-output` workflow command

gh api --paginate "/search/code?q=set-output+language:yaml+org:joshjohanning-org" --jq '.items[].html_url'
