# using gh repo edit native cli:
gh repo edit <org>/<repo> --visibility internal

# alternative with gh api (can be used to modify multiple properties of repo at once):
gh api \
  --method PATCH \
  -H "Accept: application/vnd.github+json" \
  /repos/<org>/<repo> \
 -f visibility='internal'
