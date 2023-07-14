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

## add-branch-protection-status-checks.sh

Adds a status check to the branch protection status check contexts.

See the [docs](https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#add-status-check-contexts) for more information.

## add-enterprise-organization-member.sh

Adds a user from an Enterprise into an org. See: [Documentation](https://docs.github.com/en/graphql/reference/mutations#addenterpriseorganizationmember)

## add-ip-allow-list.sh

Adds an IP to an enterprise's or organization's [IP allow list](https://docs.github.com/en/enterprise-cloud@latest/organizations/keeping-your-organization-secure/managing-security-settings-for-your-organization/managing-allowed-ip-addresses-for-your-organization).

Use the [get-enterprise-id.sh](./get-enterprise-id.sh) or [get-organization-id.sh](./get-organization-id.sh) script to get the owner ID.

See the [docs](https://docs.github.com/en/graphql/reference/mutations#createipallowlistentry) for further information.

## add-team-to-repository.sh

Adds a team to a repository with a given permission level

## add-user-to-team.sh

Adds (invites) a user to an organization team

## change-repository-visibility.sh

Change a repository visibility to internal, for example

## create-enterprise-organization.sh

Creates an enterprise organization - you just need to pass in the enterprise ID (obtained [via](./get-enterprise-id.sh)) along with billing email, admin logins, and organization name

## create-organization-webhook.sh

Creates an organization webhook, with a secret, with some help from `jq`. 

## create-repository-from-template.sh

Create a new repo from a repo template - note that it only creates as public or private, if you want internal you have to do a subsequent call (see `change-repository-visibility.sh`)

## delete-release.sh

Deletes a release from a repository - need the [ID](#get-releasessh) of the release

## delete-repository.sh

Deletes a repo - also works if the repository is locked from a failed migration, etc.

May need to run this first in order for the gh cli to be able to have delete repo permissions:

```
gh auth refresh -h github.com -s delete_repo
```

## download-private-release-artifact.sh

Downloads a release artifact from a private/internal repository. Can either download latest version or specific version, and supports file pattern matching to download one or multiple files. See [docs](https://cli.github.com/manual/gh_release_download) for more info.

## download-public-release-artifact.sh

Using `curl`, `wget`, or `gh release download` to download public release assets.

## enable-actions-on-repository.sh

Enable actions on repository - similar to [API example](./../api/enable-actions-on-repository.sh), but using `gh cli`

## generate-release-notes-from-tags.sh

Generates release notes between two tags. See the [release notes docs](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes) on further customizations and the [API docs](https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#generate-release-notes-content-for-a-release) for info on the API.

## get-actions-permissions-on-repository.sh

Gets the status of Actions on a repository (ie, if Actions are disabled)

## get-actions-usage-in-repository.sh

Gets the usage of Actions on a repository; example output:

```csv
actions/checkout@3
github/codeql-action/analyze@2
github/codeql-action/autobuild@2
github/codeql-action/init@2
actions/dependency-review-action@3
```

## get-apps-installed-in-organization.sh

Get the slug of the apps installed in an organization.

## get-branch-protection-rule.sh

Gets a branch protection rule for a given branch.

## get-branch-protection-status-checks.sh

Gets the branch protection status check contexts.

See the [docs](https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#get-all-status-check-contexts) for more information.

## get-code-scanning-status-for-every-repository.sh

Get code scanning analyses status for every repository in an organization.

Example output:

```csv
"joshjohanning-org/ghas-demo","CodeQL","refs/pull/140/merge","2023-04-28T07:08:36Z",".github/workflows/codeql-analysis.yml:analyze"
"joshjohanning-org/zero-to-hero-codeql-test","CodeQL","refs/heads/main","2023-04-23T20:28:16Z",".github/workflows/codeql-analysis.yml:analyze"
"joshjohanning-org/Python_scripts_examples","CodeQL","refs/heads/main","2023-04-24T14:21:16Z",".github/workflows/codeql-analysis.yml:analyze"
joshjohanning-org/.github, no code scanning results
"joshjohanning-org/azdo-terraform-tailspin","defsec","refs/heads/main","2023-04-22T21:35:22Z",".github/workflows/tfsec-analysis.yml:tfsec"
```

## get-commits-since-date.sh

Gets the commits of since a certain date - date should be in [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) format, ie: `since=2022-03-28T16:00:49Z`

## get-dependencies-in-repository.sh

Gets dependencies used in the repository, including the ecosystem and version number.

Example output: 

```csv
npm/source-list-map@2.0.1
pypi/keyring@17.1.1
maven/io.jsonwebtoken/jjwt@0.7.0
golang/github.com/mattn/go-sqlite3@1.14.4
githubactions/actions/checkout@3
```

## get-earliest-restricted-contribution-date.sh

In a 1 year block, return the date of the first non-public contribution

> The date of the first restricted contribution the user made in this time period. Can only be non-null when the user has enabled private contribution counts.

See also: [Another example](https://github.com/orgs/community/discussions/24427#discussioncomment-3244093)

## get-enterprise-id.sh

Get the enterprise ID used for other GraphQL calls. Use the URL slug of the Enterprise as the input.

Adding `-H X-Github-Next-Global-ID:1` per the documentation here to get the new ID format:

- https://github.blog/changelog/2022-11-10-graphql-legacy-global-id-deprecation-message/
- https://docs.github.com/en/graphql/guides/migrating-graphql-global-node-ids

## get-enterprise-ip-allow-list.sh

Gets the current IP allow list for an enterprise.

See the [docs](https://docs.github.com/en/graphql/reference/objects#enterpriseownerinfo) for further information.

## get-enterprise-organizations.sh

Gets all organizations for a given enterprise. Handles pagination.

## get-enterprise-roles-in-organizations-all-roles.sh

Queries every organization in an enterprise and returns whether the user is a member or a member + admin of the organization.

## get-enterprise-roles-in-organizations-with-named-role.sh

Queries the enterprise for all organizations given the specified role (e.g.: which organizations is the user an admin of)

## get-enterprise-settings.sh

Gets info about an enterprise using the [EnterpriseOwnerInfo](https://docs.github.com/en/graphql/reference/objects#enterpriseownerinfo) GraphQL object.

## get-label-usage-in-repository.sh

Gets the usage of a label in a repository. Returns data in table format.

## get-organization-id.sh

Get the organization ID used for other GraphQL calls. Use the login of the Organization as the input.

Adding `-H X-Github-Next-Global-ID:1` per the documentation here to get the new ID format:

- https://github.blog/changelog/2022-11-10-graphql-legacy-global-id-deprecation-message/
- https://docs.github.com/en/graphql/guides/migrating-graphql-global-node-ids

## get-organization-ip-allow-list.sh

Gets the current IP allow list for an organization.

See the [docs](https://docs.github.com/en/graphql/reference/objects#ipallowlistentry) for further information.

## get-organization-language-count.sh

Get a total count of the primary language of repositories in an organization.

Example output:

```
  21 Shell
  11 JavaScript
  11 Dockerfile
  10 C#
   4 Java
```

## get-organization-members-api.sh

Gets a list of members in an organization using the REST API (able to get their ID to tie to Git event audit log)

## get-organization-members.sh

Gets a list of members (via GraphQL) and their role in an organization

## get-organization-repository-count.sh

Gets the repository count in an organization

## get-organization-team-members.sh

Gets the members of a team

## get-organization-team.sh

Gets a team

## get-outside-collaborators-added-to-repository.sh

Get outside collaborators added to a repository

## get-package-download-url-for-latest-version

Retrieve the download URL for the latest version of a package in GitHub Packages. See: [Documentation](https://docs.github.com/en/graphql/reference/objects#package)

> **Note:**
> No longer works for GitHub.com and deprecated for GHES 3.7+. See [Changelog post](https://github.blog/changelog/2022-08-18-deprecation-notice-graphql-for-packages/), [GraphQL breaking changes](https://docs.github.com/en/graphql/overview/breaking-changes#changes-scheduled-for-2022-11-21-1), and [GHES 3.7 deprecations](https://docs.github.com/en/enterprise-server@3.7/admin/release-notes#3.7.0-deprecations)

## get-package-download-url-for-specific-version-maven.sh

Retrieve the download URL for a specific version of an Maven package in GitHub Packages.

## get-package-download-url-for-specific-version-npm.sh

Retrieve the download URL for a specific version of an NPM package in GitHub Packages.

## get-package-download-url-for-specific-version-nuget.sh

Retrieve the download URL for a specific version of an Maven package in GitHub Packages.

## get-package-download-url-for-specific-version.sh

Retrieve the download URL for a specific version of a package in GitHub Packages. See: [Documentation](https://docs.github.com/en/graphql/reference/objects#package)

> **Note:**
> No longer works for GitHub.com and deprecated for GHES 3.7+. See [Changelog post](https://github.blog/changelog/2022-08-18-deprecation-notice-graphql-for-packages/), [GraphQL breaking changes](https://docs.github.com/en/graphql/overview/breaking-changes#changes-scheduled-for-2022-11-21-1), and [GHES 3.7 deprecations](https://docs.github.com/en/enterprise-server@3.7/admin/release-notes#3.7.0-deprecations)

## get-releases.sh

Gets a list of releases for a repository

## get-repositories-not-using-actions.sh

Get repositories not using actions, by files committed in the `.github/workflows` directory

## get-repositories-using-actions.sh

Get repositories using actions, by files committed in the `.github/workflows` directory

## get-repositories-using-circleci.sh

Get repositories that have a CircleCI configuration file `.circleci/config.yml`

(not perfect, doesn't search for `codeql*.yml`)

## get-repositories-using-codeql.sh

Get repositories that have a CodeQL configuration file `.github/workflows/codeql.yml`

## get-repository-languages-for-organization.sh

Get the repository language information (ie: JavaScript, Python, etc) for all repositories in an organization. Can specify how many language results to return (top X).

Example output:

```csv
repo,language
ghas-demo,Java
zero-to-hero-codeql-test,C#
Python_scripts_examples,Python
```

## get-repository-licenses-for-organization.sh

Get the repository license information (ie: MIT, Apache 2.0, etc) for all repositories in an organization.

## get-repository-topics.sh

Gets a list of topics for a repository

## get-repository.sh

Gets details about a repo

## get-repository-users-by-permission-for-organization.sh

Similar to `get-repository-users-by-permission.sh` except that it loops through all repositories. See the below note about cumulative permissions; if you query for `push` you will also get users for `maintain` and `admin`, but you can pass in a `false` and retrieve only users who have `push`.

Example output:

```csv
repo,login,permission
ghas-demo,joshgoldfishturtle,admin
ghas-demo,joshjohanning,admin
zero-to-hero-codeql-test,joshjohanning,admin
Python_scripts_examples,joshjohanning,admin
```

## get-repository-users-by-permission.sh

Gets a list of users by permission level for a repository (ie: retrieve the list of users who have admin access to a repository). For write access, use `push` as the permission. There is a flag to either cumulatively return permissions (ie: `push` returns those with `maintain` and `admin` as well), but the default is explicitly return users with the permission you specify.

Example output:

```csv
login,permission
joshgoldfishturtle,admin
joshjohanning,admin
```

## get-repository-users-permission-and-source.sh

Returns the permission for everyone who can access the repo and how they access it (direct, team, org)

## get-saml-identities-in-enterprise.sh

Retrieves the SAML linked identity of a user in a GitHub Enterprise.

May need to run this first in order for the gh cli to be able to retrieve the SAML information for organizations:

```
gh auth refresh -h github.com -s admin:enterprise
```

## get-saml-identities-in-organization.sh

Retrieves the SAML linked identity of a user in a GitHub organization.

May need to run this first in order for the gh cli to be able to retrieve the SAML information for organizations:

```
gh auth refresh -h github.com -s admin:org
```

## get-sbom-in-repository.sh

Gets the SBOM for a repository.

## get-search-results.sh

Uses the search API for code search.

## get-sso-enabled-pats.sh

Retrieves all SSO enabled PATs users have created for an organization.

## get-sso-enabled-ssh-keys.sh

Retrieves all SSO-enabled SSH keys users have created for an organization.

## get-user-id.sh

Retrieves the ID of a user for other GraphQL calls

## get-users-directly-added-to-repositories.sh

Gets a list of users directly added to repositories

Example output:

```csv
"ghas-demo", "joshjohanning", "ADMIN"
"ghas-demo", "FluffyCarlton", "WRITE"
"Test-Migrate", "joshjohanning", "ADMIN"
```

## remove-branch-protection-status-checks.sh

Removes a status check from the branch protection status check contexts.

See the [docs](https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#remove-status-check-contexts) for more information.

## remove-enterprise-user.sh

Removes an enterprise user. See notes:

1. Get enterprise id: `./get-enterprise-id.sh`
2. Get user id by one of the following:
    1. List org members and get the id from there: `./get-organization-members.sh`
    2. Get user id: `./get-user-id.sh`

## remove-sso-enabled-pat.sh

Revokes an SSO-enabled PAT that a user created in an organization.

## rename-repository.sh

Renaming a repo

## search-organization-for-code.sh

Code search in an organization.

See the [docs](https://docs.github.com/en/rest/search?apiVersion=2022-11-28#search-code) and [StackOverflow](https://stackoverflow.com/questions/24132790/how-to-search-for-code-in-github-with-github-api) for more information.

## set-branch-protection-status-checks.sh

Set the branch protection status check contexts.

See the [docs](https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#set-status-check-contexts) for more information.

## set-ip-allow-list-setting.sh

Sets the IP allow list to enabled/disable for an enterprise or organization. You can't enable the IP allow list unless the IP running the script is in the list.

See the [docs](https://docs.github.com/en/graphql/reference/mutations#updateipallowlistenabledsetting) for further information.

## sso-credential-authorizations.sh

Retrieves a list of users who have SSO-enabled personal access tokens in an organization.

## update-branch-protection-rule.sh

Updates a branch protection rule for a given branch.

## update-enterprise-owner-organizational-role.sh

Adds your account to an organization in an enterprise as an owner, member, or leave the organization.

## get-repositories-webhooks-csv.sh

Gets a CSV with the list of repository webhooks in a GitHub organization.

Generates a CSV with 4 columns:

- repo name - The repository name
- is active - If the webhook is active or not
- webhook url - The url of the weehook
- secret - Webhook secret, it will be masked since the API doesn't return the actual secret.

This script is useful when doing migrations, to determine the kind of actions that might be needed based on the webhooks inventory.
