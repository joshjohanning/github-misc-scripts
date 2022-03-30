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

## enable-actions-on-repository.sh

Enable actions on repository - similar to [API example](./../api/enable-actions-on-repository.sh), but using `gh cli`

## sso-credential-authorizations.sh

Retrieves a list of users who have SSO-enabled personal access tokens in an organization.
