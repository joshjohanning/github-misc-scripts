#!/bin/bash

# Sets the required status checks for a branch

# Find and specify the APP ID for the check source as a best practice (so the check can't be spoofed by another source/app)
# 15368 is the App ID for GitHub Actions as a check source
# 57789 is the App ID for GitHub Advanced Security as a check source
# 9426 is the App ID for Azure Pipelines as a check source
# 302869 is the App ID for CircleCI as a check source

set -e

org="joshjohanning-org"
repo="circleci-test"
branch="main" # wildcards are supported in GraphQL but not the API we're calling to set the status checks
strict=true # if true, branch needs to be up to date before merging
 # `skip_branch_protection_rule_exists_check` checks to see if:
  # 1) there is a branch protection rule that exists and 
  # 2) that the rule has required status checks enabled 
  # it will create the rule if it doesn't exist or enable the required status checks if they are not enabled
skip_branch_protection_rule_exists_check=false

# if skip_branch_protection_rule_exists_check = true
if [ "$skip_branch_protection_rule_exists_check" == "false" ]; then

  # see if branch protection status checks are enabled
  echo "Checking if branch protection status checks are enabled for $branch"

branch_protection_rule=$(gh api graphql -H X-Github-Next-Global-ID:1 -f owner="$org" -f repository="$repo" -f query='
    query ($owner: String!, $repository: String!) {
      repository(owner: $owner, name: $repository) {
        branchProtectionRules(first: 100) {
          nodes {
            id
            pattern
            requiresStatusChecks
          }
        }
        id
      }
    }' --jq "{repositoryId: .data.repository.id, branchProtectionRules: (.data.repository.branchProtectionRules.nodes | map(select(.pattern == \"$branch\") | {id: .id, pattern: .pattern, requiresStatusChecks: .requiresStatusChecks}))}")

  requires_status_checks=$(echo $branch_protection_rule | jq -r '.branchProtectionRules[0].requiresStatusChecks')
  branch_protection_rule_id=$(echo $branch_protection_rule | jq -r '.branchProtectionRules[0].id')
  branch_protection_pattern=$(echo $branch_protection_rule | jq -r '.branchProtectionRules[0].pattern')
  repo_id=$(echo $branch_protection_rule | jq -r '.repositoryId')

  if [ "$branch_protection_rule_id" == "null" ]; then
    echo " ... No branch protection rule exists for $branch, we need to create one quick 🕔"
    gh api graphql -H X-Github-Next-Global-ID:1 -f repositoryId="$repo_id" -f pattern="$branch" -f query='
      mutation ($repositoryId: ID!, $pattern: String!) {
        createBranchProtectionRule(input: {repositoryId: $repositoryId, pattern: $pattern, requiresStatusChecks: true}) {
          branchProtectionRule {
            id
            pattern
            requiresStatusChecks
          }
        }
      }' --jq '.data.createBranchProtectionRule.branchProtectionRule'
    echo " ... okay now that's done, let's set the required status checks"
  fi

  if [ "$requires_status_checks" == "false" ]; then
    echo " ... Branch protection status checks are not enabled for $branch, we need to set that quick 🕖"
    gh api graphql -f id="$branch_protection_rule_id" -f query='
      mutation ($id: ID!) { 
        updateBranchProtectionRule(input: {branchProtectionRuleId: $id, requiresStatusChecks: true} ) {
          branchProtectionRule {
            id
            pattern
            requiresStatusChecks
          }
        } 
      }' --jq '.data.updateBranchProtectionRule.branchProtectionRule'
    echo " ... okay now that's done, let's set the required status checks"
    else
      echo " ... Branch protection status checks are already enabled ✅"
  fi
fi

gh api -X PATCH /repos/$org/$repo/branches/$branch/protection/required_status_checks \
  --input - << EOF
{
  "checks": [
    {
      "context": "ci/circleci: say-hello",
      "app_id": 302869
    },
    {
      "context": "ci/circleci: test-go-2",
      "app_id": 302869
    },
    {
      "context": "build",
      "app_id": 15368
    },
    {
      "context": "CodeQL",
      "app_id": 57789
    },
    {
      "context": "joshjohanning-org.tailspin-spacegame-web-demo (Build BuildJob)",
      "app_id": 9426
    }
  ],
  "strict": true
}
EOF

echo "required status checks set ✅"
