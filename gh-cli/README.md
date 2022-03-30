# gh cli

## CLI Setup

### Install

```bash
brew install gh # install gh cli on mac with brew
brew upgrade gh # upgrade
```

Other OS's can find instructions [here](https://cli.github.com/manual/installation)

### Authentication 

```bash
# start interactive setup
$ gh auth login

# authenticate to github.com by reading the token from a file
$ gh auth login --with-token < mytoken.txt

# authenticate from standard input
$ echo ${{ secrets.GITHUB_TOKEN }} | gh auth login --with-token
```

See the [docs](https://cli.github.com/manual/gh_auth_login) for further information.

## delete-release.sh

Deletes a release from a repository - need the [ID](#get-releasessh) of the release

## delete-repo.sh

Deletes a repo - also works if the repository is locked from a failed migration, etc.

## enable-actions-on-repository.sh

Enable actions on repository - similar to [API example](./../api/enable-actions-on-repository.sh), but using `gh cli`

## get-actions-permissions-on-repository.sh

Gets the status of Actions on a repository (ie, if Actions are disabled)

## get-org-team-members.sh

Gets a list of members on a team

## get-org-team.sh

Gets a team

## get-releases.sh

Gets a list of releases for a repository

## get-repo.sh

Gets details about a repo

## get-repository-topics.sh

Gets a list of topics for a repository

## sso-credential-authorizations.sh

Retrieves a list of users who have SSO-enabled personal access tokens in an organization.
