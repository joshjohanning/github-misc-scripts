# api

## checking-github-app-rate-limits.sh

This script checks the GitHub App's rate limit status by generating a JWT (JSON Web Token), obtaining an installation access token, and then querying the GitHub API for the rate limit information. It is useful for developers and administrators to monitor and manage their GitHub App's API usage.

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

## generate-jwt-from-github-app-and-find-org-installation-ids.sh

This script generates a JWT (JSON Web Token) for a GitHub App and uses it to list the installations of the App. It is useful for developers and administrators who need to authenticate as a GitHub App to access GitHub API.

## get-repo-info-using-github-app-and-show-api-rate-limit-info.sh

This script is designed to generate a JWT (JSON Web Token) for authenticating as a GitHub App. It then uses this token to perform GitHub API requests, specifically to retrieve information about a specified repository 
and display the current API rate limit status. This is particularly useful for developers and administrators who need to monitor their GitHub App's API usage and ensure it stays within the GitHub API rate limits.