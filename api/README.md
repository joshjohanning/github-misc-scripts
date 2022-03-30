# api

## create-repo.sh

Create an internal repo in an organization

[Documentation](https://docs.github.com/en/rest/reference/repos#create-an-organization-repository)

## download-file-from-github-packages.sh

This appears to be an undocumented API to download a file from GitHub Packages - use this as a reference to form your own url.

In the UI, you can download a file as well but you'll notice that the download string has an expiring key in the url. This works around that with the `-L` to follow redirects.

[GraphQL](https://github.com/joshjohanning/github-misc-scripts/tree/main/graphql#download-latest-package-from-github-packagessh) also works, but this may be easier.

## download-file-from-github-releases.sh

Download a file from a GitHub release - if it's a public repo, you wouldn't have to use a bearer token to authenticate

[Documentation](https://docs.github.com/en/rest/reference/releases)

## download-file-from-private-repo.sh

Download a file from a non-public repository

[Documentation](https://docs.github.com/en/rest/reference/repos#get-repository-content)

## download-workflow-artifacts.sh

Download a workflow artifact (e.g.: downloading the artifact from the build workflow for the deploy workflow to use)

[Documentation](https://docs.github.com/en/rest/reference/actions#download-an-artifact)

## enable-actions-on-repository.sh

Enables actions on a repository - similar to [gh cli example](./../api/enable-actions-on-repository.sh), but using `curl`

[Documentation](https://docs.github.com/en/rest/reference/actions#set-github-actions-permissions-for-a-repository)
