# using gh repo edit native cli:
gh repo edit <org>/<repo> --visibility internal
gh repo rename --repo <org>/<old-repo-name> <new-repo-name>

# alternative with gh api (can be used to modify multiple properties of repo at once):
gh api \
  --method PATCH \
  -H "Accept: application/vnd.github+json" \
  /repos/<org>/<old-repo-name> \
 -f name='<new-repo-name>'
