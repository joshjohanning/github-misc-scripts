##############################################################
# Migrate work items to GitHub Issues
##############################################################

# Prerequisites:
# 1. create a label for EACH work item type that is being migrated (as lower case) 
#      - ie: "user story", "bug", "task", "feature"
# 2. add a tag to eaach work item you want to migrate - ie: "migrate"
#      - You can modify the WIQL if you want to use a different way to migrate work items, such as UNDER [Area Path]

# How to run:
# ./ado_workitems_to_github_issues.ps1 -ado_pat "xxx" -ado_org "jjohanning0798" -ado_project "PartsUnlimited" -ado_tag "migrate" -gh_pat "xxx" -gh_org "joshjohanning-org" -gh_repo "migrate-ado-workitems"

[CmdletBinding()]
param (
    [string]$ado_pat, # Azure DevOps PAT
    [string]$ado_org, # Azure devops org without the URL, eg: "MyAzureDevOpsOrg"
    [string]$ado_project, # Team project name that contains the work items, eg: "TailWindTraders"
    [string]$ado_tag, # only one tag is supported, would have to add another clause in the $wiql, eg: "migrate")
    [string]$gh_pat,
    [string]$gh_org,
    [string]$gh_repo
)

echo "$ado_pat" | az devops login --organization "https://dev.azure.com/$ado_org"
az devops configure --defaults organization="https://dev.azure.com/$ado_org" project="$ado_project"
echo $gh_pat | gh auth login --with-token

$wiql="select [ID], [Title] from workitems where [Tags] CONTAINS '$ado_tag' order by [ID]"

$query=az boards query --wiql $wiql | ConvertFrom-Json

Remove-Item -Path ./temp_comment_body.txt -ErrorAction SilentlyContinue
Remove-Item -Path ./temp_issue_body.txt -ErrorAction SilentlyContinue

ForEach($workitem in $query) {
    $comment_body_json_beginning="`n`n<details><summary>Original Work Item JSON</summary><p>" + "`n`n" + '```json'
    $comment_body_json_end="`n" + '```' + "`n</p></details>"

    $details_json = az boards work-item show --id $workitem.id --output json
    $details = $details_json | ConvertFrom-Json

    if ($details.fields.{System.WorkItemType} -eq "Bug") {
        $description=$details.fields.{Microsoft.VSTS.TCM.ReproSteps} + "`n`n" + $details.fields.{Microsoft.VSTS.TCM.SystemInfo}
    } else {
        $description=$details.fields.{System.Description}
    }

    $description | Out-File -FilePath ./temp_issue_body.txt

    $comment_body_json_beginning | Out-File -FilePath ./temp_comment_body.txt
    $details_json | Add-Content -Path ./temp_comment_body.txt
    $comment_body_json_end | Add-Content -Path ./temp_comment_body.txt
    
    $work_item_type = $details.fields.{System.WorkItemType}.ToLower()

    $issue_url=gh issue create --body-file ./temp_issue_body.txt --repo "$gh_org/$gh_repo" --title $details.fields.{System.Title} --label $work_item_type
    write-host "issue created: $issue_url"

    $issue_id = ($issue_url -split "/")[-1]

    $comment_url=gh issue comment $issue_id --repo "$gh_org/$gh_repo" --body-file ./temp_comment_body.txt
    write-host "comment created: $comment_url"


    Remove-Item -Path ./temp_comment_body.txt -ErrorAction SilentlyContinue
    Remove-Item -Path ./temp_issue_body.txt -ErrorAction SilentlyContinue
}