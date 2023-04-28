#!/bin/bash

# searches for results that have fakecompany.com AND (token or password) in the file

# note this api is likely to trip secondary rate limits for frequent queries

# the new code search via the UI is better https://github.com/search?q=fakecompany.com+AND+%28token+OR+password%29&type=code

results=$(gh api --paginate "/search/code?q=fakecompany.com+token+in:file&per_page=100")
results+=$(gh api --paginate "/search/code?q=fakecompany.com+password+in:file&per_page=100")

# remove duplicates
echo $results | jq '.items[].html_url' | sort | uniq 
