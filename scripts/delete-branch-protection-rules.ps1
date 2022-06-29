##############################################################
# Delete branch protection rules
##############################################################

[CmdletBinding()]
param (
    [parameter (Mandatory = $true)][string]$PersonalAccessToken,
    [parameter (Mandatory = $true)][string]$GitHubOrg,
    [parameter (Mandatory = $true)][string]$GitHubRepo,
    [parameter (Mandatory = $true)][string]$PatternToDelete # If you want to delete all branch protection rules that start with "feature", pass in "feature*". If you want to delete ALL branch protection rules, pass in "*"
)

# Example that deletes ALL branch protection rules:
# ./github-delete-branch-protection.ps1 -PersonalAccessToken "xxx" -GitHubOrg "myorg" -GitHubRepo "myrepo" -PatternToDelete "*"

# Example that deletes branch protection rules that start with feature:
# ./github-delete-branch-protection.ps1 -PersonalAccessToken "xxx" -GitHubOrg "myorg" -GitHubRepo "myrepo" -PatternToDelete "feature*"

# Set up API Header
$AuthenticationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($PersonalAccessToken)")) }

####### Script #######

### GRAPHQL
# Get body
$body = @{
    query = "query BranchProtectionRule {
        repository(owner:`"$GitHubOrg`", name:`"$GitHubRepo`") { 
          branchProtectionRules(first: 100) { 
              nodes { 
                  pattern,
                  id
                      matchingRefs(first: 100) {
                          nodes {
                              name
                          }
                      }
                  }
              }
          }
      }"
}

write-host "Getting policies for repo: $GitHubRepo ..."
$graphql = Invoke-RestMethod -Uri "https://api.github.com/graphql" -Method POST -Headers $AuthenticationHeader -ContentType 'application/json' -Body ($body | ConvertTo-Json) # | ConvertTo-Json -Depth 10
write-host ""

foreach($policy in $graphql.data.repository.branchProtectionRules.nodes) {
    if($policy.pattern -like $PatternToDelete) {
        write-host "Deleting branch policy: $($policy.pattern) ..."
        $bodyDelete = @{
            query = "mutation {
                deleteBranchProtectionRule(input:{branchProtectionRuleId: `"$($policy.id)`"}) {
                clientMutationId
                }
            }"
        }
        $toDelete = Invoke-RestMethod -Uri "https://api.github.com/graphql" -Method POST -Headers $AuthenticationHeader -ContentType 'application/json' -Body ($bodyDelete | ConvertTo-Json)
        
        if($toDelete -like "*errors*") {
            write-host "Error deleting policy: $($policy.pattern)" -f red
        }
        else {
            write-host "Policy deleted: $($policy.pattern)"
        }
    }
}
