##############################################################
# Migrate work items to GitHub Issues
##############################################################

# Prerequisites:
# 1. create a label for EACH work item type that is being migrated (as lower case) 
#      - ie: "user story", "bug", "task", "feature"
# 2. add a tag to eaach work item you want to migrate - ie: "migrate"
#      - You can modify the WIQL if you want to use a different way to migrate work items, such as UNDER [Area Path]

# How to run:
# ./ado_workitems_to_github_issues.ps1 -ado_pat "xxx" -ado_org "jjohanning0798" -ado_project "PartsUnlimited" -ado_tag "migrate" -gh_pat "xxx" -gh_org "joshjohanning-org" -gh_repo "migrate-ado-workitems" -gh_update_assigned_to $true -gh_assigned_to_user_suffix "_corp"

#
# Things it migrates:
# 1. Title
# 2. Description (or repro steps + system info for a bug
# 3. State (if the work item is done / closed, it will be closed in GitHub)
# 4. It will try to assign the work item to the correct user in GitHub - based on ADO email (-gh_update_assigned_to and -gh_assigned_to_user_suffix options)
# 5. Migrate acceptance criteria as part of issue body (if present)
# 6. It also migrates the entire work item as JSON as a comment
#

# 
# To Do:
# 1. Migrate acceptance criteria as part of issue body
# 2. Create a comment on the Azure DevOps work item that says "Migrated to GitHub Issue #"
#

#
# Things it won't ever migrate:
# 1. Created date/update dates
# 

[CmdletBinding()]
param (
    [string]$ado_pat, # Azure DevOps PAT
    [string]$ado_org, # Azure devops org without the URL, eg: "MyAzureDevOpsOrg"
    [string]$ado_project, # Team project name that contains the work items, eg: "TailWindTraders"
    [string]$ado_tag, # only one tag is supported, would have to add another clause in the $wiql, eg: "migrate")
    [string]$gh_pat,
    [string]$gh_org,
    [string]$gh_repo,
    [bool]$gh_update_assigned_to = $false, # try to update the assigned to field in GitHub
    [string]$gh_assigned_to_user_suffix = "" # the emu suffix, ie: "_corp"
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

    $description=""

    # bug doesn't have Description field - add repro steps and/or system info
    if ($details.fields.{System.WorkItemType} -eq "Bug") {
        if(![string]::IsNullOrEmpty($details.fields.{Microsoft.VSTS.TCM.ReproSteps})) {
            $description="## Repro Steps`n`n" + $details.fields.{Microsoft.VSTS.TCM.ReproSteps} + "`n`n"
        }
        if(![string]::IsNullOrEmpty($details.fields.{Microsoft.VSTS.TCM.SystemInfo})) {
            $description+="## System Info`n`n" + $details.fields.{Microsoft.VSTS.TCM.SystemInfo} + "`n`n"
        }
    } else {
        $description=$details.fields.{System.Description}
        # add in acceptance criteria if it has it
        if(![string]::IsNullOrEmpty($details.fields.{Microsoft.VSTS.Common.AcceptanceCriteria})) {
            $description+="`n`n## Acceptance Criteria`n`n" + $details.fields.{Microsoft.VSTS.Common.AcceptanceCriteria}
        }
    }

    $description | Out-File -FilePath ./temp_issue_body.txt
    # $acceptance_criteria | Add-Content -Path ./temp_issue_body.txt

    $comment_body_json_beginning | Out-File -FilePath ./temp_comment_body.txt
    $details_json | Add-Content -Path ./temp_comment_body.txt
    $comment_body_json_end | Add-Content -Path ./temp_comment_body.txt
    
    $work_item_type = $details.fields.{System.WorkItemType}.ToLower()

    $issue_url=gh issue create --body-file ./temp_issue_body.txt --repo "$gh_org/$gh_repo" --title $details.fields.{System.Title} --label $work_item_type
    write-host "issue created: $issue_url"

    $comment_url=gh issue comment $issue_url --body-file ./temp_comment_body.txt
    write-host "comment created: $comment_url"

    Remove-Item -Path ./temp_comment_body.txt -ErrorAction SilentlyContinue
    Remove-Item -Path ./temp_issue_body.txt -ErrorAction SilentlyContinue

    # close out the issue if it's closed on the Azure Devops side
    if ($details.fields.{System.State} -eq "Done" -or $details.fields.{System.State} -eq "Closed") {
        gh issue close $issue_url
    }

    # update assigned to in GitHub if the option is set - tries to use ado email to map to github username
    if ($gh_update_assigned_to -eq $true) {
        $ado_assignee=$details.fields.{System.AssignedTo}.uniqueName
        $gh_assignee=$ado_assignee.Split("@")[0]
        $gh_assignee=$gh_assignee.Replace(".", "-") + $gh_assigned_to_user_suffix
        write-host "trying to assign to: $gh_assignee"
        $gh_assignee="joshjohanning"
        $assigned=gh issue edit $issue_url --add-assignee "$gh_assignee"
    }
}