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

```text
joshjohanning-org/test-repo-1
joshjohanning-org/test-repo-2
joshjohanning-org/test-repo-3
```

Configuration values to change in the script:

- `gitUsername`: If using a GitHub App, use the name of GitHub App with `[bot]` appended, e.g.: `josh-issueops-bot[bot]`
- `gitEmail` = If using a GitHub App, combine the App's user ID (⚠️ this is different than App ID!) and name to form an email like: `149130343+josh-issueops-bot[bot]@users.noreply.github.com`. You can find the App's user ID number by calling: `gh api '/users/josh-issueops-bot[bot]' --jq .id`
- `overwrite`: use `false` or `true` on whether it should overwrite the existing `dependabot.yml` file

## ado-workitems-to-github-issues.ps1

Migrate work items from Azure DevOps to GitHub issues - this just links out to a [separate repo](https://github.com/joshjohanning/ado_workitems_to_github_issues)

## code-scanning-coverage-report

See: [code-scanning-coverage-report](./code-scanning-coverage-report/README.md)

## create-app-jwt.py

This script will generate a JWT for a GitHub App. It will use the private key and app ID from the GitHub App's settings page.

1. Run: `python3 get-jwt.py ./<private-key>.pem <app-id>`
    - You can also just run `python3 get-jwt.py` and it will prompt you for the private key and app ID
    - You will need to have the `jwt` package installed via `pip3`: `pip3 install jwt`
    - The JWT is valid for 10 minutes (maximum)

Script sourced from [GitHub docs](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app#example-using-python-to-generate-a-jwt).

## create-app-jwt.sh

Generate a JWT (JSON Web Token) for a GitHub App using bash. This is a shell script alternative to `create-app-jwt.py`.

Usage:

```bash
./create-app-jwt.sh <client-id> <path-to-private-key.pem>
```

The script generates a JWT that is valid for 10 minutes, which can be used to authenticate as a GitHub App and obtain installation tokens.

> [!NOTE]
> Requires `openssl` to be installed. The JWT can be used with the GitHub API to generate installation access tokens.

## delete-branch-protection-rules.ps1

Delete branch protection rules programmatically based on a pattern.

## dismiss-code-scanning-alerts

See: [dismiss-code-scanning-alerts](./dismiss-code-scanning-alerts/README.md)

## gei-clean-up-azure-storage-account.sh

Clean up Azure Storage Account Containers from GEI migrations.

## get-app-tokens-for-each-installation.sh

This script will generate generate a JWT for a GitHub app and use that JWT to generate installation tokens for each org installation. The installation tokens, returned as `ghs_abc`, can then be used for normal API calls. It will use the private key and app ID from the GitHub App's settings page and the `get-app-jwt.py` script to generate the JWT, and then use the JWT to generate the installation tokens for each org installation.

1. Run: `./get-app-tokens-for-each-installation.sh <app_id> <private_key_path>"`
    - Requires `python3` and `pip3 install jwt` to run the `get-jwt.py` script to generate the JWT
    - The installation access token will expire after 1 hour

Output example:

```text
Getting installation token for: Josh-Test ...

 ... token: ghs_abc

Getting installation token for: joshjohanning-org ...

 ... token: ghs_xyz
```

Docs:

- [Generate a JWT for a GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app#example-using-python-to-generate-a-jwt)
- [Generating an installation access token for a GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app#generating-an-installation-access-token)
- [List installations for the authenticated app](https://docs.github.com/en/rest/apps/apps?apiVersion=2022-11-28#list-installations-for-the-authenticated-app)

## get-list-of-resolved-secret-scanning-alerts.sh

This script retrieves and lists all resolved secret scanning alerts for a specified GitHub repository. It uses the GitHub API to fetch the alerts and displays them in a tabular format.

## get-new-outside-collaborators-added-to-repository.sh

This script will generate a list of new outside collaborators added to a repository. It uses a database file specified to determine if any new users were added to the repository and echo them to the console for review.

My use case is to use this list to determine who needs to be added to a organization's project board (ProjectsV2).

1. Run: `./new-users-to-add-to-project.sh <org> <repo> <file>`
2. Don't delete the `<file>` as it functions as your user database

## github-app-manifest-flow

Scripts to create GitHub Apps using the [GitHub App Manifest flow](https://docs.github.com/en/apps/sharing-github-apps/registering-a-github-app-from-a-manifest). The manifest flow allows you to create a GitHub App by posting a JSON manifest to GitHub, which then generates the app credentials.

**Workflow:**

1. **Generate HTML form**: Run `generate-github-app-manifest-form.sh [organization]` to create an HTML file
2. **Start local server**: Serve the HTML file (e.g., `python3 -m http.server 8000`)
3. **Create app via browser**: Open the form, submit it to GitHub, and get redirected back with a manifest code
4. **Convert manifest code**: Use `create-github-app-from-manifest.sh` to convert the code into app credentials

**Scripts:**

- **generate-github-app-manifest-form.sh**: Generates an HTML form for the manifest flow
- **create-github-app-from-manifest.sh**: Converts manifest code into app credentials with detailed output and error handling
- **github-app-manifest-form-example.html**: Example HTML form (generated output)

> [!NOTE]
> Requires `curl`, `jq`, and a classic GitHub personal access token (`ghp_*`). Fine-grained tokens are not supported for the manifest conversion endpoint.

## migrate-discussions

See: [migrate-discussions](./migrate-discussions/README.md)

## migrate-docker-containers-between-github-instances.sh

Migrate Docker Containers in GitHub Packages (GitHub Container Registry) from one GitHub organization to another.

1. Define the source GitHub PAT env var: export GH_SOURCE_PAT=ghp_abc (must have at least `read:packages`, `read:org` scope)
2. Define the target GitHub PAT env var: export GH_TARGET_PAT=ghp_abc (must have at least `write:packages`, `read:org` scope)
3. Run: `./migrate-docker-containers-between-github-instances joshjohanning-org github.com joshjohanning-emu github.com true`

## migrate-maven-packages-between-github-instances.sh

Migrate Maven packages in GitHub Packages from one GitHub organization to another.

1. Define the source GitHub PAT env var: export GH_SOURCE_PAT=ghp_abc (must have at least `read:packages`, `read:org` scope)
2. Define the target GitHub PAT env var: export GH_TARGET_PAT=ghp_abc (must have at least `write:packages`, `read:org` scope)
3. Run: `./migrate-npm-packages-between-github-instances.sh joshjohanning-org github.com joshjohanning-emu github.com`

## migrate-npm-packages-between-github-instances.sh

Migrate npm packages in GitHub Packages from one GitHub organization to another.

1. Define the source GitHub PAT env var: `export GH_SOURCE_PAT=ghp_abc` (must have at least `read:packages`, `read:org` scope)
2. Define the target GitHub PAT env var: `export GH_TARGET_PAT=ghp_abc` (must have at least `write:packages`, `read:org`, `repo` scope)
3. Run: `./migrate-maven-packages-between-github-instances.sh joshjohanning-org github.com joshjohanning-emu github.com`

## migrate-nuget-packages-between-github-instances.sh

Migrate NuGet packages in GitHub Packages from one GitHub organization to another. Runs script from upstream [source](https://github.com/joshjohanning/github-packages-migrate-nuget-packages-between-github-instances).

1. Define the source GitHub PAT env var: `export GH_SOURCE_PAT=ghp_abc` (must have at least `read:packages`, `read:org` scope)
2. Define the target GitHub PAT env var: `export GH_TARGET_PAT=ghp_abc` (must have at least `write:packages`, `read:org` scope)
3. Run: `./migrate-maven-packages-between-github-instances.sh joshjohanning-org github.com joshjohanning-emu`

## multi-gitter-add-dependabot-file-to-repositories.sh

Uses [`multi-gitter`](https://github.com/lindell/multi-gitter) to create a `dependabot.yml` if it doesn't exist, but if it does exist, only check to see if there is a `package-ecosystem: github-actions` section and if not, add it.

## multi-gitter-replace-dependabot-file-in-repositories.sh

Uses [`multi-gitter`](https://github.com/lindell/multi-gitter) to add/replace the `dependabot.yml` file.

## multi-gitter-scripts

These are scripts used with [`multi-gitter`](https://github.com/lindell/multi-gitter) and the scripts here prefixed with `multi-gitter-`. They aren't intended to be run directly, but it could be ran inside a `git` repo standalone for testing.

## recreate-security-in-repositories-and-teams

See: [recreate-security-in-repositories-and-teams](./recreate-security-in-repositories-and-teams/README.md)

## set-secret-scanning-alert-to-open-state.sh

This script reopens a resolved secret scanning alert in a specified GitHub repository and optionally adds a comment.

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

## update-repository-visibility-from-server-to-cloud.ps1

Compares the repo visibility of a repo in GitHub Enterprise Server and update the visibility in GitHub Enterprise Cloud. This is useful since migrated repos are always brought into cloud as private.
