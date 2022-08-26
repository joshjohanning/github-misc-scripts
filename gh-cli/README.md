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

# authenticate from environment variable
$ export GH_TOKEN=${{ secrets.GITHUB_TOKEN }}
```

See the [docs](https://cli.github.com/manual/gh_auth_login) for further information.

## add-user-to-team.sh

Adds (invites) a user to an organization team

## change-repo-visibility.sh

Change a repository visibility to internal, for example.

## create-repo-from-template.sh

Create a new repo from a repo template - note that it only creates as public or private, if you want internal you have to do a subsequent call (see `change-repo-visibility.sh`)

## delete-release.sh

Deletes a release from a repository - need the [ID](#get-releasessh) of the release

## delete-repo.sh

Deletes a repo - also works if the repository is locked from a failed migration, etc.

May need to run this first in order for the gh cli to be able to have delete repo permissions:

```
gh auth refresh -h github.com -s delete_repo
```

## enable-actions-on-repository.sh

Enable actions on repository - similar to [API example](./../api/enable-actions-on-repository.sh), but using `gh cli`

## get-actions-permissions-on-repository.sh

Gets the status of Actions on a repository (ie, if Actions are disabled)

## get-commits-since-date.sh

Gets the commits of since a certain date - date should be in [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) format, ie: `since=2022-03-28T16:00:49Z`

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

## get-saml-identities-in-org.sh

Retrieves the SAML linked identity of a user in a GitHub organization.

May need to run this first in order for the gh cli to be able to retrieve the SAML information for organizations:

```
gh auth refresh -h github.com -s admin:org
```

## sso-credential-authorizations.sh

Retrieves a list of users who have SSO-enabled personal access tokens in an organization.

## rename-repo.sh

Renaming a repo
