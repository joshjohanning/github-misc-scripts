## recreate-security-in-repos-and-teams.sh

This script will:

- Mirror team membership from source org/target org
- Add the teams to the repositories with the correct permissions
- Add individual users to the repositories with the correct permissions

### Usage

```bash
./recreate-security-in-repositories-and-teams.sh --source-org mickeygoussetorg --target-org mickeygoussetpleaseworkmigrationorg --team-mapping-file team_mappings.csv --repo-mapping-file repo_mappings.csv
```

### Notes

- This assumes the target teams have already been created - see other scripts in this repo for help on that [[1](https://github.com/mickeygousset/github-misc-scripts/tree/main/gh-cli#parent-organization-teamssh)], [[2](https://github.com/mickeygousset/github-misc-scripts/tree/main/gh-cli#create-teams-from-listsh)]
  - If using GEI to migrate the org, the teams will be created but will not have any members
- The users have to already be members of the target organization
- See additional assumptions as documented in the script
