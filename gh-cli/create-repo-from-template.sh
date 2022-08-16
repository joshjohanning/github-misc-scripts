gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  /repos/joshjohanning-org/template-repo/generate \
 -f owner='joshjohanning-org' \
 -f name='deletemeeeeeeeeee' \
 -f description='This is your first repository' \
 -F include_all_branches=false \
 -F private=true # either do true for private or false for public

# use change-repo-visibility.sh to change visibility to internal if needed
