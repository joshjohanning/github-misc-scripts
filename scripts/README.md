# scripts

## add-dependabot-file-to-repositories.js

Add `dependabot.yml` file to a list of repositories.

The script is expecting:

- an environment variable named `GITHUB_TOKEN` with a GitHub PAT that has `repo` scope
- dependencies installed via `npm i octokit fs`
- Update the `gitUsername`, `gitEmail`, and `overwrite` const at the top of the script accordingly

Script usage:

```bash
export GITHUB_TOKEN=ghp_abc
npm i octokit fs papaparse
node ./add-dependabot-file-to-repositories.js ./repos.txt ./dependabot.yml
```

The `repos.txt` should be in the following format:

```
joshjohanning-org/test-repo-1
joshjohanning-org/test-repo-2
joshjohanning-org/test-repo-3
```

## ado_workitems_to_github_issues.ps1

Migrate work items from Azure DevOps to GitHub issues - this just links out to a [separate repo](https://github.com/joshjohanning/ado_workitems_to_github_issues)

## delete-branch-protection-rules.ps1

Delete branch protection rules programmatically based on a pattern.

## gei-clean-up-azure-storage-account.sh

Clean up Azure Storage Account Containers from GEI migrations.

## get-app-jwt.py

This script will generate a JWT for a GitHub App. It will use the private key and app ID from the GitHub App's settings page.

1. Run: `python3 get-jwt.py ./<private-key>.pem <app-id>`
    - You can also just run `python3 get-jwt.py` and it will prompt you for the private key and app ID
    - You will need to have the `jwt` package installed via `pip3`: `pip3 install jwt`
    - The JWT is valid for 10 minutes (maximum)

Script sourced from [GitHub docs](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app#example-using-python-to-generate-a-jwt).

## get-app-tokens-for-each-installation.sh

This script will generate generate a JWT for a GitHub app and use that JWT to generate installation tokens for each org installation. The installation tokens, returned as `ghs_abc`, can then be used for normal API calls. It will use the private key and app ID from the GitHub App's settings page and the `get-app-jwt.py` script to generate the JWT, and then use the JWT to generate the installation tokens for each org installation.

1. Run: `./get-app-tokens-for-each-installation.sh <app_id> <private_key_path>"`
    - Requires `python3` and `pip3 install jwt` to run the `get-jwt.py` script to generate the JWT
    - The installation access token will expire after 1 hour

Output example:

> Getting installation token for: Josh-Test ...
> 
>  ... token: ghs_abc
> 
> Getting installation token for: joshjohanning-org ...
> 
>  ... token: ghs_xyz

Docs:
- [Generate a JWT for a GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app#example-using-python-to-generate-a-jwt)
- [Generating an installation access token for a GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app#generating-an-installation-access-token)
- [List installations for the authenticated app](https://docs.github.com/en/rest/apps/apps?apiVersion=2022-11-28#list-installations-for-the-authenticated-app)

## get-new-outside-collaborators-added-to-repository.sh

This script will generate a list of new outside collaborators added to a repository. It uses a database file specified to determine if any new users were added to the repository and echo them to the console for review.

My use case is to use this list to determine who needs to be added to a organization's project board (ProjectsV2).

1. Run: `./new-users-to-add-to-project.sh <org> <repo> <file>`
2. Don't delete the `<file>` as it functions as your user database

## migrate-maven-packages-between-github-instances

Migrate Maven packages in GitHub Packages from one GitHub organization to another.

1. Define the source GitHub PAT env var: export GH_SOURCE_PAT=ghp_abc (must have at least `read:packages`, `read:org` scope)
2. Define the target GitHub PAT env var: export GH_TARGET_PAT=ghp_abc (must have at least `write:packages`, `read:org` scope)
3. Run: `./migrate-npm-packages-between-github-instances.sh joshjohanning-org github.com joshjohanning-emu github.com`

## migrate-npm-packages-between-github-instances.sh

Migrate npm packages in GitHub Packages from one GitHub organization to another.

1. Define the source GitHub PAT env var: `export GH_SOURCE_PAT=ghp_abc` (must have at least `read:packages`, `read:org` scope)
2. Define the target GitHub PAT env var: `export GH_TARGET_PAT=ghp_abc` (must have at least `write:packages`, `read:org`, `repo` scope)
3. Run: `./migrate-maven-packages-between-github-instances.sh joshjohanning-org github.com joshjohanning-emu github.com`

## migrate-nuget-packages-between-github-instances

Migrate NuGet packages in GitHub Packages from one GitHub organization to another. Runs script from upstream [source](https://github.com/joshjohanning/github-packages-migrate-nuget-packages-between-github-instances). 

1. Define the source GitHub PAT env var: `export GH_SOURCE_PAT=ghp_abc` (must have at least `read:packages`, `read:org` scope)
2. Define the target GitHub PAT env var: `export GH_TARGET_PAT=ghp_abc` (must have at least `write:packages`, `read:org` scope)
3. Run: `./migrate-maven-packages-between-github-instances.sh joshjohanning-org github.com joshjohanning-emu`

## update-codeowners-mappings.js

Update CODEOWNERS mappings of teams in a GitHub repository (e.g.: after a migration if the team/org names change). This script will update the CODEOWNERS file in a GitHub repository with the mappings provided in the `codeowners-mappings.csv` file.

The script is expecting:

- an environment variable named `GITHUB_TOKEN` with a GitHub PAT that has `repo` scope
- an environment variable named `REPOSITORIES` with a list of repositories to update (separated by a new line)
- dependencies installed via `npm i octokit fs papaparse`

Using/testing the script:

```bash
export GITHUB_TOKEN=ghp_abc
export REPOSITORIES="https://github.com/joshjohanning-org/codeowners-scripting-test
https://github.com/joshjohanning-org/codeowners-scripting-test-2
"
npm i octokit fs papaparse
node ./update-codeowners-mappings.js

```

The `codeowners-mappings.csv` (hardcoded file name) should be in the following format:

```csv
oldValue,newValue
approvers-team,compliance-team
admin-team,compliance-team
joshjohanning-org,joshjohanning-new-org
```

## update-repo-visibility-from-server-to-cloud.ps1

Compares the repo visibility of a repo in GitHub Enterprise Server and update the visibility in GitHub Enterprise Cloud. This is useful since migrated repos are always brought into cloud as private.
