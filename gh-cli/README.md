# gh-cli

This directory contains scripts for interacting with the GitHub API / GraphQL using the [gh cli](https://cli.github.com/) 🚀.

## CLI Setup

### Installation

#### macOS

```bash
$ brew install gh # install gh cli on mac with brew
$ brew upgrade gh # upgrade
```

#### Windows

```bash
$ choco install gh # install gh cli on windows with chocolatey
$ choco upgrade gh # upgrade
```

MSI installer is available [here](https://github.com/cli/cli/releases/latest)

#### Linux/other

Other operating systems and install methods can be found [here](https://github.com/cli/cli#installation)

### Authentication 

#### Authenticate in the CLI

```bash
# start interactive authentication
$ gh auth login

# start interactive authentication specifying additional scopes
$ gh auth login -s admin:org

# add additional scopes to existing token
$ gh auth refresh -s admin:org

# authenticate to github.com by reading the token from a file
$ gh auth login --with-token < mytoken.txt

# authenticate from standard input
$ echo ${{ secrets.GITHUB_TOKEN }} | gh auth login --with-token

# authenticate by setting an environment variable
$ export GH_TOKEN=${{ secrets.GITHUB_TOKEN }}

# authenticate to a GitHub Enterprise Server instance
$ gh auth login -h github.mycompany.com # -h github.com is the default
```

#### Authenticate in GitHub Actions

```yml
- run: gh api -X GET --paginate /repos/joshjohanning/github-misc-scripts/pulls -f state=all --jq '.[].title'
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

See the [docs](https://cli.github.com/manual/gh_auth_login) for further information.

## Scripts

### add-branch-protection-status-checks.sh

Adds a status check to the branch protection status check contexts.

See the [docs](https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#add-status-check-contexts) for more information.

### add-codeowners-file-to-repositories.sh

Adds a `CODEOWNERS` file to a list of repositories.

1. Run: `./generate-repositories-list.sh <org> > repos.csv`
    - Or create a list of repos in a csv file, 1 per line, with a trailing empty line at the end of the file
2. Run: `./add-codeowners-file-to-repositories.sh repos.csv ./CODEOWNERS false`
    - For the 3rd argument, pass `true` if you want to overwrite existing file, otherwise it appends to existing

> [!NOTE]
> This checks for a `CODEOWNERS` file in the 3 possible locations (root, `.github`, and `docs`)

### add-collaborator-to-repository.sh

Adds a user with a specified role to a repository. Used in the `./copy-permissions-between-org-repos.sh` script.

### add-enterprise-organization-member.sh

Adds a user from an Enterprise into an org. See: [Documentation](https://docs.github.com/en/graphql/reference/mutations#addenterpriseorganizationmember)

### add-gitignore-file-to-repositories.sh

Adds a `.gitignore` file to a list of repositories.

1. Run: `./generate-repositories-list.sh <org> > repos.csv`
    - Or create a list of repos in a csv file, 1 per line, with a trailing empty line at the end of the file
2. Run: `./add-gitignore-file-to-repositories.sh repos.csv ./.gitignore false`
    - For the 3rd argument, pass `true` if you want to overwrite existing file, otherwise it appends to existing

### add-ip-allow-list.sh

Adds an IP to an enterprise's or organization's [IP allow list](https://docs.github.com/en/enterprise-cloud@latest/organizations/keeping-your-organization-secure/managing-security-settings-for-your-organization/managing-allowed-ip-addresses-for-your-organization).

Use the [get-enterprise-id.sh](./get-enterprise-id.sh) or [get-organization-id.sh](./get-organization-id.sh) script to get the owner ID.

See the [docs](https://docs.github.com/en/graphql/reference/mutations#createipallowlistentry) for further information.

### add-team-to-repository.sh

Adds a team to a repository with a given permission level

### add-user-to-team.sh

Adds (invites) a user to an organization team

### add-users-to-team-from-list.sh

Invites users to a GitHub team from a list.

1. Create a new csv file with the users you want to add, 1 per line
2. Make sure to leave a trailing line at the end of the csv
3. Run: `./add-users-to-team-from-list.sh users.csv <org> <team>`

Example input file:

```csv
joshjohanning
FluffyCarlton

```

### archive-repositories.sh

Archives/unarchives repositories in bulk.

Given a file with a list of repository names, it will archive/unarchive the repositories.

The repos files list should be a file with the repository names, one per line in the format `owner/repo`.

By default it archives the repository, but if you pass `false` as the second argument it will unarchive the repositories.

usage: :

```shell
archive-repositories.sh <file> <archive state (true|false)>`
```

Example input file:

```csv
mona/octocat
mona/lisa
octocat/octocat
```

### change-repository-visibility.sh

Change a repository visibility to internal, for example

### copy-organization-members.sh

Copy organization members from one organization to the other, the member will **retain** the source role (owner or member), member cannot be demoted, if they already exist at the target with an owner role they cannot be demoted to member.

On Enterprise Managed Users organizations the users are only added if they are part of the Enterprise already (they need to be provisioned by the IDP)

On GitHub Enterprise Cloud the added users will get an invitation to join the organization.

> [!WARNING]
> For GitHub Enterprise Cloud the number of users you can copy in a day is limited per target org. See [API note on rate limits](https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/members?apiVersion=2022-11-28#set-organization-membership-for-a-user) for the limit values.

This script requires 2 environment variables (with another optional one):

- SOURCE_TOKEN - A GitHub Token to access data from the source organization. Requires `org:read` and `repo` scopes.
- TARGET_TOKEN - A GitHub Token to set data on the target organization. Requires `org:admin` and `repo` scopes.
- MAP_USER_SCRIPT - path to a script to map user login. This is optional, if you set this environment value it will call the script to map user logins before adding them on the target repo. The script will receive the user login as the first argument and it should return the new login. For example, if you want to add a suffix to the user login:

```shell
#!/bin/bash

echo "$1"_SHORTCODE
```

You can have more complex mappings this just a basic example, where a copy is being done between a GHEC and a GHEC EMU instance where the logins are going to be exactly the same, but the EMU instance has a suffix on the logins.

### copy-organization-team-members.sh

Copy organization team members from one organization to the other, the member will **retain** the source role (maintainer, member).

It copies the members of team members of teams in the source organization but only for teams that also exist in the target organization.

This script requires 2 environment variables (with another optional one):

- SOURCE_TOKEN - A GitHub Token to access data from the source organization. Requires `org:read` scopes.
- TARGET_TOKEN - A GitHub Token to set data on the target organization. Requires `org:admin` and `repo` scopes.
- MAP_USER_SCRIPT - path to a script to map user login. This is optional, if you set this environment value it will call the script to map user logins before adding them on the target repo. The script will receive the user login as the first argument and it should return the new login. For example, if you want to add a suffix to the user login:

```shell
#!/bin/bash

echo "$1"_SHORTCODE
```

You can have more complex mappings this just a basic example, where a copy is being done between a GHEC and a GHEC EMU instance where the logins are going to be exactly the same, but the EMU instance has a suffix on the logins.

> [!WARNING]
> If users are not members of the target organizations they will not be added to the target team but may receive an invite to join the org.

### copy-organization-variables.sh

Copy organization variables from one organization to another.

If the variable already exists on the target organization it will be updated.

> [!WARNING]
> If the variable is available to selected repositories and a repository with the same doesn't exist on the target organization that association is ignored.

### copy-permissions-between-org-repos.sh

Copy user and team repository member permissions to another repository (it can be in the same or on different organizations).

External collaborators are not copied intentionally.

If the team (or children of that team) on the target organization doesn't exist, one will be created (same name, description, privacy, and notification settings ONLY),if the team has children teams those will also be created (full tree, not only direct children).

> [!NOTE]
> The created team will not be a full copy, **Only** name, description and visibilility are honored. If the team is is associated with an IDP group it will not be honored. If you want to change this behavior, you can modify the `internal/__copy_team_and_children_if_not_exists_at_target.sh` script.

This script requires 2 environment variables (with another optional one):

- SOURCE_TOKEN - A GitHub Token to access data from the source organization. Requires `org:read` and `repo` scopes.
- TARGET_TOKEN - A GitHub Token to set data on the target organization. Requires `org:admin` and `repo` scopes.
- MAP_USER_SCRIPT - path to a script to map user login. This is optional, if you set this environment value it will call the script to map user logins before adding them on the target repo. The script will receive the user login as the first argument and it should return the new login. For example, if you want to add a suffix to the user login:

```shell
#!/bin/bash

echo "$1"_SHORTCODE
```

You can have more complex mappings this just a basic example, where a copy is being done between a GHEC and a GHEC EMU instance where the logins are going to be exactly the same, but the EMU instance has a suffix on the logins.

### copy-repository-environments.sh

Copy environments from one repo to another.

It copies all [environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) and copies the following settings:

- [Required Reviewers](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#required-reviewers)
- [Wait Timer](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#wait-timer)
- [Deployment Branches](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#deployment-branches)

> [!NOTE]
> The following settings are **not** copied:
>  - [Environment Variables](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#environment-variables)
>  - [Custom Deployment Protection Rules](https://docs.github.com/en/actions/deployment/protecting-deployments/configuring-custom-deployment-protection-rules#using-existing-custom-deployment-protection-rules)
>  - Secrets

### copy-repository-variables.sh

Copy repository variables from one repo to another.

This script requires 2 environment variables:

- SOURCE_TOKEN - A GitHub Token to access data from the source organization. Requires `repo` scope.
- TARGET_TOKEN - A GitHub Token to set data on the target organization. Requires `repo` scope.

The user running the command needs to be a repo admin or an organization owner on the target repository.

### copy-team-members.sh

Copy team member from one team to another, it respect source role type (maintainer, member).

> [!NOTE]
> Only direct members are copied, child team members are not copied.

If the target team already has user they will be preserved, this **doesn't** synch members between teams, it merely copies them. If you want a synch then you need to delete the existem team members in the target team before running this script.

This script requires 2 environment variables (with another optional one):

- SOURCE_TOKEN - A GitHub Token to access data from the source organization. Requires `org:read` scopes.
- TARGET_TOKEN - A GitHub Token to set data on the target organization. Requires `org:admin` and `repo` scopes.
- MAP_USER_SCRIPT - path to a script to map user login. This is optional, if you set this environment value it will call the script to map user logins before adding them on the target repo. The script will receive the user login as the first argument and it should return the new login. For example, if you want to add a suffix to the user login:

```shell
#!/bin/bash

echo "$1"_SHORTCODE
```

You can have more complex mappings this just a basic example, where a copy is being done between a GHEC and a GHEC EMU instance where the logins are going to be exactly the same, but the EMU instance has a suffix on the logins.

> [!WARNING]
> If users are not members of the target organizations they will not be added to the target team but may receive an invite to join the org.

### create-enterprise-organization.sh

Creates an organization in an enterprise

### create-enterprise-organizations-from-list.sh

Creates organizations in an enterprise from a CSV input list

### create-organization-webhook.sh

Creates an organization webhook, with a secret, with some help from `jq`

### create-repository-from-template.sh

Create a new repo from a repo template - note that it only creates as public or private, if you want internal you have to do a subsequent call (see `change-repository-visibility.sh`)

### create-teams-from-list.sh

Loops through a list of teams and creates them.

1. Create a list of teams in a csv file, 1 per line, with a trailing empty line at the end of the file
    - Child teams should have a slash in the name, e.g. `test1-team/test1-1-team`
    - Build out the parent structure in the input file before creating the child teams; e.g. have the `test1-team` come before `test1-team/test1-1-team` in the file
2. Run: `./create-teams-from-list.sh teams.csv <org>`

Example input file:

```csv
test11-team
test22-team
test11-team/test11111-team
test11-team/test11111-team/textxxx-team

```

### delete-packages-in-organization.sh

Deletes all packages in an organization for a given package type.

> [!WARNING]
> This is a destructive operation and cannot be undone.

### delete-release.sh

Deletes a release from a repository - need the [ID](#get-releasessh) of the release

### delete-repos-from-list.sh

Deletes a list of repositories.

1. Run: `./generate-repositories-list.sh <org> > repos.csv`
2. Clean up the `repos.csv` file and remove the repos you **don't want to delete**
3. Run `./delete-repositories-from-list.sh repos.csv`
4. If you need to restore, [you have 90 days to restore](https://docs.github.com/en/repositories/creating-and-managing-repositories/restoring-a-deleted-repository)

### delete-repository.sh

Deletes a repo - also works if the repository is locked from a failed migration, etc.

May need to run this first in order for the gh cli to be able to have delete repo permissions:

```
gh auth refresh -h github.com -s delete_repo
```

### delete-repository-webhooks.sh

Deletes all webhooks from a repository.

> [!WARNING]
> This operation is not reversible.

### delete-teams-from-list.sh

Loops through a list of teams and deletes them.

1. Create a list of teams in a csv file, 1 per line, with a trailing empty line at the end of the file
    - Child teams should have a slash in the name, e.g. `test1-team/test1-1-team`
    - `!!! Important !!!` Note that if a team has child teams, all of the child teams will be deleted as well
2. Run: `./delete-teams-from-list.sh teams.csv <org>`

Example input file:

```csv
test11-team
test22-team
test11-team/test11111-team
test11-team/test11111-team/textxxx-team

```

> [!IMPORTANT]
> If deleting a team with child teams, all of the child teams will be deleted as well

### delete-workflow-runs-for-workflow.sh

This DELETES *ALL* workflow runs for a particular workflow in a repo. Can pass in a workflow file name or workflow ID.

### download-private-release-artifact.sh

Downloads a release artifact from a private/internal repository. Can either download latest version or specific version, and supports file pattern matching to download one or multiple files. See [docs](https://cli.github.com/manual/gh_release_download) for more info.

### download-public-release-artifact.sh

Using `curl`, `wget`, or `gh release download` to download public release assets.

### enable-actions-on-repository.sh

Enable actions on repository - similar to [API example](./../api/enable-actions-on-repository.sh), but using `gh cli`

### generate-release-notes-from-tags.sh

Generates release notes between two tags. See the [release notes docs](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes) on further customizations and the [API docs](https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#generate-release-notes-content-for-a-release) for info on the API.

### generate-repositories-list.sh

Generates a list of repos in the organization - has many uses, but the exported repos can be used in the `delete-repos-from-list.sh` script.

Credits to @tspascoal from this repo: https://github.com/tspascoal/dependabot-alerts-helper

1. Run: `./generate-repositories.sh <org> > repos.csv`

### generate-users-from-team.sh

Generates a list of users from a team in the organization - has many uses, but the exported users can be used in the `remove-users-from-org.sh` script.

1. Run: `./generate-users-from-team <org> <team> > users.csv`

### get-actions-permissions-on-repository.sh

Gets the status of Actions on a repository (ie, if Actions are disabled)

### get-actions-usage-in-organization.sh

Returns a list of all actions used in an organization using the SBOM API

Example output:

```csv
71 actions/checkout@3
42 actions/checkout@2
13 actions/upload-artifact@2
13 actions/setup-node@3
```

Or (`count-by-action` option to count by action as opposed to action@version):

```csv
130 actions/checkout
35 actions/upload-artifact
27 actions/github-script
21 actions/setup-node
```

> [!NOTE]
> The count returned is the # of repositories that use the action - if single a repository uses the action 2x times, it will only be counted 1x

### get-actions-usage-in-repository.sh

Returns a list of all actions used in a repository using the SBOM API

Example output:

```csv
actions/checkout@3
github/codeql-action/analyze@2
github/codeql-action/autobuild@2
github/codeql-action/init@2
actions/dependency-review-action@3
```

### get-all-users-in-repository.sh

Gets all users who have created an issue, pull request, issue comment, or pull request comment in a repository.

### get-app-tokens-for-each-installation.sh

Generates a JWT for a GitHub app and use that JWT to generate installation tokens for each org installation. The installation tokens, returned as `ghs_abc`, can then be used for normal API calls. It requires the App ID and Private Key `pem` file as input.

> [!NOTE]
> - Not using `gh-cli` since we have to pass in JWT using `curl` (but otherwise no PAT required)
> - Similar script to [get-apps-installed-in-organization.sh](./../scripts/get-app-tokens-for-each-installation.sh), but this one doesn't have a python dependency
> - Thanks [@kenmuse](https://github.com/kenmuse) for the [starter](https://gist.github.com/kenmuse/9429221d6944c087deaed2ec5075d0bf)! 

### get-apps-installed-in-organization.sh

Get the slug of the apps installed in an organization.

### get-branch-protection-rule.sh

Gets a branch protection rule for a given branch.

### get-branch-protection-status-checks.sh

Gets the branch protection status check contexts.

See the [docs](https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#get-all-status-check-contexts) for more information.

### get-code-scanning-status-for-every-repository.sh

Get code scanning analyses status for every repository in an organization.

Example output:

```csv
"joshjohanning-org/ghas-demo","CodeQL","refs/pull/140/merge","2023-04-28T07:08:36Z",".github/workflows/codeql-analysis.yml:analyze"
"joshjohanning-org/zero-to-hero-codeql-test","CodeQL","refs/heads/main","2023-04-23T20:28:16Z",".github/workflows/codeql-analysis.yml:analyze"
"joshjohanning-org/Python_scripts_examples","CodeQL","refs/heads/main","2023-04-24T14:21:16Z",".github/workflows/codeql-analysis.yml:analyze"
joshjohanning-org/.github, no code scanning results
"joshjohanning-org/azdo-terraform-tailspin","defsec","refs/heads/main","2023-04-22T21:35:22Z",".github/workflows/tfsec-analysis.yml:tfsec"
```

### get-commits-since-date.sh

Gets the commits of since a certain date - date should be in [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) format, ie: `since=2022-03-28T16:00:49Z`

### get-dependencies-in-repository.sh

Gets dependencies used in the repository, including the ecosystem and version number.

Example output: 

```csv
npm/source-list-map@2.0.1
pypi/keyring@17.1.1
maven/io.jsonwebtoken/jjwt@0.7.0
golang/github.com/mattn/go-sqlite3@1.14.4
githubactions/actions/checkout@3
```

### get-earliest-restricted-contribution-date.sh

In a 1 year block, return the date of the first non-public contribution

> The date of the first restricted contribution the user made in this time period. Can only be non-null when the user has enabled private contribution counts.

See also: [Another example](https://github.com/orgs/community/discussions/24427#discussioncomment-3244093)

### get-enterprise-audit-log-for-organization.sh

This queries the [Enterprise audit log API](https://docs.github.com/en/enterprise-cloud@latest/admin/monitoring-activity-in-your-enterprise/reviewing-audit-logs-for-your-enterprise/using-the-audit-log-api-for-your-enterprise) to specifically return if features have been enabled or disabled in an organization since a given date.

Additional resources:

- [Using the audit log API for your enterprise](https://docs.github.com/en/enterprise-cloud@latest/admin/monitoring-activity-in-your-enterprise/reviewing-audit-logs-for-your-enterprise/using-the-audit-log-api-for-your-enterprise)
- [Searching the audit log for your enterprise](https://docs.github.com/en/enterprise-cloud@latest/admin/monitoring-activity-in-your-enterprise/reviewing-audit-logs-for-your-enterprise/searching-the-audit-log-for-your-enterprise)
- [Get the audit log for an enterprise](https://docs.github.com/en/enterprise-cloud@latest/rest/enterprise-admin/audit-log?apiVersion=2022-11-28#get-the-audit-log-for-an-enterprise)

### get-enterprise-id.sh

Get the enterprise ID used for other GraphQL calls. Use the URL slug of the Enterprise as the input.

Adding `-H X-Github-Next-Global-ID:1` per the documentation here to get the new ID format:

- https://github.blog/changelog/2022-11-10-graphql-legacy-global-id-deprecation-message/
- https://docs.github.com/en/graphql/guides/migrating-graphql-global-node-ids

### get-enterprise-ip-allow-list.sh

Gets the current IP allow list for an enterprise.

See the [docs](https://docs.github.com/en/graphql/reference/objects#enterpriseownerinfo) for further information.

### get-enterprise-organizations.sh

Gets all organizations for a given enterprise, requires the enterprise slug. Handles pagination and returns the organization id and login.

To get the list of all org names you can use `jq` to parse the JSON output:

```shell
./get-enterprise-organizations.sh octocat-corp | jq -r '.data.enterprise.organizations.nodes[].login'
```

### get-enterprise-roles-in-organizations-all-roles.sh

Queries every organization in an enterprise and returns whether the user is a member or a member + admin of the organization.

### get-enterprise-roles-in-organizations-with-named-role.sh

Queries the enterprise for all organizations given the specified role (e.g.: which organizations is the user an admin of)

### get-enterprise-settings.sh

Gets info about an enterprise using the [EnterpriseOwnerInfo](https://docs.github.com/en/graphql/reference/objects#enterpriseownerinfo) GraphQL object.

### get-gei-migration-status.sh

Gets the status of a [GitHub Enterprise Importer (GEI) migration](https://docs.github.com/en/enterprise-cloud@latest/migrations/using-github-enterprise-importer/migrating-organizations-with-github-enterprise-importer/migrating-organizations-from-githubcom-to-github-enterprise-cloud?tool=api#step-3-check-the-status-of-your-migration).

### get-label-usage-in-repository.sh

Gets the usage of a label in a repository. Returns data in table format.

### get-organization-active-repositories.sh

Gets a list of repositories in an organization that have had code pushed to it in the last X days.

### get-organization-codeowner-errors-tsv.sh

Gets a TSV with a list of [CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) files that have errors in them, this will allow to identify which CODEOWNERS requires fixing.

The list will contain the repository name, source (CODEOWNERS file), and kind of error.

Repositories with no CODEONWERS files or CODEOWNERS errors will not be listed.

### get-organization-id.sh

Get the organization ID used for other GraphQL calls. Use the login of the Organization as the input.

Adding `-H X-Github-Next-Global-ID:1` per the documentation here to get the new ID format:

- https://github.blog/changelog/2022-11-10-graphql-legacy-global-id-deprecation-message/
- https://docs.github.com/en/graphql/guides/migrating-graphql-global-node-ids

### get-organization-ip-allow-list.sh

Gets the current IP allow list for an organization.

See the [docs](https://docs.github.com/en/graphql/reference/objects#ipallowlistentry) for further information.

### get-organization-language-count.sh

Get a total count of the primary language of repositories in an organization.

Example output:

```
  21 Shell
  11 JavaScript
  11 Dockerfile
  10 C#
   4 Java
```

### get-organization-members-api.sh

Gets a list of members in an organization using the REST API (able to get their ID to tie to Git event audit log)

### get-organization-members.sh

Gets a list of members (via GraphQL) and their role in an organization

### get-organization-migrations-summary.sh

Gets a summary of all migrations against a given organization with [GitHub Enterprise Importer](https://docs.github.com/en/migrations/using-github-enterprise-importer)

example:

```bash
$ ./get-organization-migrations-summary.sh  octocat
Not started          0
Pending validation   0
Failed validation    0
Queued               0
In progress          0
Succeeded            3
Failed               7
========================
Total                10
```

### get-organization-migrations-tsv.sh

Gets a TSV with a list of migrations performed (or being performed) on a given organization with [GitHub Enterprise Importer](https://docs.github.com/en/migrations/using-github-enterprise-importer)

It contains the following data:

- Migration Id
- Source URL of the migration source repo
- Created At
- Migration State
- Failure Reason
- Warnings Count in case the migration succeeded with warnings
- Migration Log URL to download the migration logs, you can use [gh-gei](https://github.com/github/gh-gei) to download the logs (note the logs are only available 24h)

By default, it returns all migrations, but there is an optional `max-migrations` parameter to limit the number of migrations returned (must lower or equal to 100)).

## get-organization-repositories-by-property.sh

Gets a list of repositories in an organization that have one or more given [custom properties](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/managing-custom-properties-for-repositories-in-your-organization) values.

There are two mandatory parameters. The organization name and one property (with value).

The property is defined with the format PROPERTYNAME=VALUE (the property name is case insensitive, but the value is case sensitive), you can specify more than one property. If you specify more than one property, repos with the conjunction of all properties will be returned.

prints all repo names that have a property with name `production` and value `true`:

```shell
./get-organization-repositories-by-property.sh octocat production=true
```

prints all repo names that have a property with name `production` and value `true` and a property wth name `cloud` and value `true`:

```shell
./get-organization-repositories-by-property.sh octocat production=true cloud=true
```

### get-organization-repository-count.sh

Gets the repository count in an organization

### get-organizations-projects-count.sh

Gets the count of projects in all organizations in a given enterprise

### get-organization-team-members.sh

Gets the members of a team

### get-organization-team.sh

Gets a team

### get-outside-collaborators-added-to-repository.sh

Get outside collaborators added to a repository

### get-package-download-url-for-latest-version

Retrieve the download URL for the latest version of a package in GitHub Packages. See: [Documentation](https://docs.github.com/en/graphql/reference/objects#package)

> [!NOTE]
> No longer works for GitHub.com and deprecated for GHES 3.7+. See [Changelog post](https://github.blog/changelog/2022-08-18-deprecation-notice-graphql-for-packages/), [GraphQL breaking changes](https://docs.github.com/en/graphql/overview/breaking-changes#changes-scheduled-for-2022-11-21-1), and [GHES 3.7 deprecations](https://docs.github.com/en/enterprise-server@3.7/admin/release-notes#3.7.0-deprecations)

### get-package-download-url-for-specific-version-maven.sh

Retrieve the download URL for a specific version of an Maven package in GitHub Packages.

### get-package-download-url-for-specific-version-npm.sh

Retrieve the download URL for a specific version of an NPM package in GitHub Packages.

### get-package-download-url-for-specific-version-nuget.sh

Retrieve the download URL for a specific version of an Maven package in GitHub Packages.

### get-package-download-url-for-specific-version.sh

Retrieve the download URL for a specific version of a package in GitHub Packages. See: [Documentation](https://docs.github.com/en/graphql/reference/objects#package)

> [!NOTE]
> No longer works for GitHub.com and deprecated for GHES 3.7+. See [Changelog post](https://github.blog/changelog/2022-08-18-deprecation-notice-graphql-for-packages/), [GraphQL breaking changes](https://docs.github.com/en/graphql/overview/breaking-changes#changes-scheduled-for-2022-11-21-1), and [GHES 3.7 deprecations](https://docs.github.com/en/enterprise-server@3.7/admin/release-notes#3.7.0-deprecations)

### get-pull-requests-in-organization.sh

Gets the pull requests in an organization

### get-pull-requests-in-repository.sh

Gets the pull requests in a repository

### get-releases.sh

Gets a list of releases for a repository

### get-repositories-not-using-actions.sh

Get repositories not using actions, by files committed in the `.github/workflows` directory

### get-repositories-using-actions.sh

Get repositories using actions, by files committed in the `.github/workflows` directory

### get-repositories-using-circleci.sh

Get repositories that have a CircleCI configuration file `.circleci/config.yml`

(not perfect, doesn't search for `codeql*.yml`)

### get-repositories-using-codeql.sh

Get repositories that have a CodeQL configuration file `.github/workflows/codeql.yml`

### get-repository-languages-for-organization.sh

Get the repository language information (ie: JavaScript, Python, etc) for all repositories in an organization. Can specify how many language results to return (top X).

Example output:

```csv
repo,language
ghas-demo,Java
zero-to-hero-codeql-test,C#
Python_scripts_examples,Python
```

### get-repository-licenses-for-organization.sh

Get the repository license information (ie: MIT, Apache 2.0, etc) for all repositories in an organization.

### get-repository-topics.sh

Gets a list of topics for a repository

### get-repository-users-by-permission-for-organization.sh

Similar to `get-repository-users-by-permission.sh` except that it loops through all repositories. See the below note about cumulative permissions; if you query for `push` you will also get users for `maintain` and `admin`, but you can pass in a `false` and retrieve only users who have `push`.

Example output:

```csv
repo,login,permission
ghas-demo,joshgoldfishturtle,admin
ghas-demo,joshjohanning,admin
zero-to-hero-codeql-test,joshjohanning,admin
Python_scripts_examples,joshjohanning,admin
```

### get-repository-users-by-permission.sh

Gets a list of users by permission level for a repository (ie: retrieve the list of users who have admin access to a repository). For write access, use `push` as the permission. There is a flag to either cumulatively return permissions (ie: `push` returns those with `maintain` and `admin` as well), but the default is explicitly return users with the permission you specify.

Example output:

```csv
login,permission
joshgoldfishturtle,admin
joshjohanning,admin
```

### get-repository-users-permission-and-source.sh

Returns the permission for everyone who can access the repo and how they access it (direct, team, org)

### get-repositories-webhooks-csv.sh

Gets a CSV with the list of repository webhooks in a GitHub organization.

Generates a CSV with 4 columns:

- repo name - The repository name
- is active - If the webhook is active or not
- webhook url - The url of the weehook
- secret - Webhook secret, it will be masked since the API doesn't return the actual secret.

This script is useful when doing migrations, to determine the kind of actions that might be needed based on the webhooks inventory.

### get-repositories-autolinks-csv.sh

Gets a CSV with the list of repository autolinks in a GitHub organization.

Generates a CSV with 4 columns:

- repo name - The repository name
- preffix - The autolink prefix
- url template - The autolink url template
- autonumeric - If the autolink is autonumeric or not (true/false)

### get-repository.sh

Gets details about a repo

### get-saml-identities-in-enterprise.sh

Retrieves the SAML linked identity of a user in a GitHub Enterprise.

May need to run this first in order for the gh cli to be able to retrieve the SAML information for organizations:

```
gh auth refresh -h github.com -s admin:enterprise
```

### get-saml-identities-in-organization.sh

Retrieves the SAML linked identity of a user in a GitHub organization.

May need to run this first in order for the gh cli to be able to retrieve the SAML information for organizations:

```
gh auth refresh -h github.com -s admin:org
```

### get-sbom-in-repository.sh

Gets the SBOM for a repository.

### get-search-results.sh

Uses the search API for code search.

### sso-credential-authorizations.sh

Retrieves a list of users who have SSO-enabled personal access tokens in an organization.

### get-sso-enabled-pats.sh

Retrieves all SSO enabled PATs users have created for an organization.

### get-sso-enabled-ssh-keys.sh

Retrieves all SSO-enabled SSH keys users have created for an organization.

### get-user-id.sh

Retrieves the ID of a user for other GraphQL calls

### get-users-directly-added-to-repositories.sh

Gets a list of users directly added to repositories

Example output:

```csv
"ghas-demo", "joshjohanning", "ADMIN"
"ghas-demo", "FluffyCarlton", "WRITE"
"Test-Migrate", "joshjohanning", "ADMIN"
```

### get-workflow-dispatch-inputs.sh

Gets a list of `workflow_dispatch` inputs used to queue a workflow run since it's not available otherwise in the API

Example output:

```json
[
  {
    "workflowName": "workflow-b",
    "workflowId": "5870059990",
    "inputs": {
      "animal": "bee",
      "color": "orange",
      "food": "avocado"
    },
    "createdAt": "2023-08-15T17:45:21Z",
    "conclusion": "success"
  }
],
```

### parent-organization-teams.sh

Sets the parents of teams in an target organization based on existing child/parent relationship on a source organization teams.

This is useful to mirror a parent child/relationship between teams on two organizations.

This script requires 2 environment variables;

- SOURCE_TOKEN - A GitHub Token to access data from the source organization. Requires `org:read` scopes.
- TARGET_TOKEN - A GitHub Token to set data on the target organization. Requires `org:admin` and `repo` scopes.

The script has three parameters:

- `source-org` - The source organization name from which team hierarchy will be read
- `target-org` - The target organization name to which teams will be updated OR created
- `create parent(s) if not exist` - OPTIONAL (default `false`) if set to true, the teams which have parents that do not exist in the target org, they will be created. (also creates parents of parents) otherwise it will print a message parent doesn't exist and it will skipped.

### remove-branch-protection-status-checks.sh

Removes a status check from the branch protection status check contexts.

See the [docs](https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#remove-status-check-contexts) for more information.

### remove-enterprise-user.sh

Removes an enterprise user. See notes:

1. Get enterprise id: `./get-enterprise-id.sh`
2. Get user id by one of the following:
    1. List org members and get the id from there: `./get-organization-members.sh`
    2. Get user id: `./get-user-id.sh`

### remove-sso-enabled-pat.sh

Revokes an SSO-enabled PAT that a user created in an organization.

### remove-users-from-org.sh

Removes a list of users from the organization.

1. Create a list of users in a csv file, 1 per line, with a trailing empty line at the end of the file (or use `./generate-users-from-team <org> <team>`)
2. Run: `./remove-users-from-org.sh <file> <org>`

### rename-repository.sh

Renaming a repo

### search-organization-for-code.sh

Code search in an organization.

See the [docs](https://docs.github.com/en/rest/search?apiVersion=2022-11-28#search-code) and [StackOverflow](https://stackoverflow.com/questions/24132790/how-to-search-for-code-in-github-with-github-api) for more information.

### set-branch-protection-status-checks.sh

Set the branch protection status check contexts.

See the [docs](https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#set-status-check-contexts) for more information.

### set-ip-allow-list-rules.sh

Sets the IP allow list rules for an enterprise or organization from a set of rules defined in a file. The script is idempotent; running it multiple times will only make the changes needed to match the rules in the file.

In order to ensure availability of the service, the script first adds all necessary rules and only after that will delete rules no longer applicable. This ensures no disruption of service if the change has an (partial) overlapping set of rules.

Optionally, you can opt-in in to save a backup of rules on GitHub before the changes are applied.

> [!WARNING]
> The script doesn't take into account if existing rules are active. If changes are made to an inactive rule it will be become active. If no changes are made, then active status will be ignored.

This script requires `org:admin` scope.

The file with the rules should be in the following format:

```json
{
    "list": [
        {
            "name": "proxy-us",
            "ip": "192.168.1.1"
        },
        {
            "name": "proxy-us",
            "ip": "192.168.1.2"
        },
        {
            "name": "proxy-eu",
            "ip": "192.168.88.0/23"
        }
    ]
}
```

> [!NOTE]
> The script logic is independent of the rules format since the file is normalized before comparisons are performed. If you want to use a different format, a surgical change to the rules normalization can be made (see script source code,search for `CUSTOMIZE` keyword)

Run the script in `dry-run` to get a preview of the changes without actually applying them.

### set-ip-allow-list-setting.sh

Sets the IP allow list to enabled/disable for an enterprise or organization. You can't enable the IP allow list unless the IP running the script is in the list.

See the [docs](https://docs.github.com/en/graphql/reference/mutations#updateipallowlistenabledsetting) for further information.

### set-organization-membership-for-a-user.sh

Sets (or adds) a user to an organization with a specified role

Notable caps on the API:
- 50 requests per 24 hours for free plans
- 500 requests per 24 hours for organizations on paid plans
- these caps do not apply to Enterprise Managed Users (EMU)

### update-branch-protection-rule.sh

Updates a branch protection rule for a given branch.

### update-enterprise-owner-organizational-role.sh

Adds your account to an organization in an enterprise as an owner, member, or leave the organization. This requires the user running the script to be an Enterprise Owner.

### verify-team-membership.sh

Simple script to verify that a user is a member of a team
