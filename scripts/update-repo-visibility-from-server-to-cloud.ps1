# Compares the repo visibility of a repo in GitHub Enterprise Server and update the visibility in GitHub Enterprise Cloud.
# This is useful since migrated repos are always brought into cloud as private.
#
# Requires: gh cli
#
# Update the GH_ENTERPRISE_TOKEN, GH_TOKEN, sourceOrg, targetOrg, and GH_HOST variables
# 

## start updating the repo visibility ##
write-host "Updating repos' visibility"

$env:GH_ENTERPRISE_TOKEN="xxx"
$env:GH_TOKEN="xxx"
$sourceOrg="joshjohanning-org"
$targetOrg="joshjohanning-testgei"

$repoNames = @("myrepo1","myrepo2","myrepo3")

foreach ($repoName in $repoNames) {
    $env:GH_HOST="github.mycompany.com"
    $visibility=gh api repos/$sourceOrg/$repoName | jq -r '.visibility'
    if ($visibility -eq "internal") {
        $env:GH_HOST="github.com"
        
        write-host "$repoName is set to internal in server, updating to internal in cloud"
        $var=gh api repos/$targetOrg/$repoName -f visibility='internal'
    }
    elseif ($visibility -eq "public") {
        $env:GH_HOST="github.com"
        
        write-host "$repoName is set to public in server, updating to internal in cloud"
        $var=gh api repos/$targetOrg/$repoName -f visibility='internal'
    }
    else {
        Write-Host "$repoName is set to private in server, NOT updating in cloud"
    }
}
## end updating the repo visibility ##
