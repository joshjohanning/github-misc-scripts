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
```

See the [docs](https://cli.github.com/manual/gh_auth_login) for further information.

## sso-credential-authorizations.sh

Retrieves a list of users who have SSO-enabled personal access tokens in an organization.
