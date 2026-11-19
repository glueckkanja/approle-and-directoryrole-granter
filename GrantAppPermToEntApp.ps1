# Allow assigning MS Graph and similar permissions to a Managed Identity - without using the AzureAD module
# Input should be readble (claim names in JSON), parsed from a file

# based on https://techcommunity.microsoft.com/t5/integrations-on-azure-blog/grant-graph-api-permission-to-managed-identity-object/ba-p/2792127

#Requires -modules Microsoft.Graph.Applications,Microsoft.Graph.Authentication

param(
    # Please give the managed identity's or enterprise app's object id.  
    [Parameter(Mandatory = $true)]
    [string] $enterpriseAppObjId,
    [string] $permissionsTemplate = "RealmJoinVnext\RjvNextPermissions.json",
    # Use the session of an earlier Connect-MgGraph instead of signing in. It needs AppRoleAssignment.ReadWrite.All
    # and Application.Read.All (or Application.ReadWrite.All).
    [switch] $useExistingSession = $false,
    [switch] $disconnectAfterExecution = $false,
    [switch] $showErrors = $false
)

. $PSScriptRoot\GranterSession.ps1
Connect-GranterGraph -Scopes "AppRoleAssignment.ReadWrite.All", "Application.Read.All" -UseExistingSession:$useExistingSession

## Read the permission template
$permissions = Get-Content -Path $permissionsTemplate | ConvertFrom-Json

"## Set permissions on the enterprise app/mgd identity"
$permissions | ForEach-Object {
    $appId = $_.Id

    ## Get Service Principal from Application:
    $resourceApp = Get-MgServicePrincipal -Filter "AppId eq '$appId'"

    ## An API other than Microsoft Graph may have no service principal in the tenant yet
    if (-not $resourceApp) {
        "## - API '$($_.Name)' ($appId) has no service principal in this tenant, skipped: $($_.AppRoleAssignments -join ', '). Create it with: New-MgServicePrincipal -AppId '$appId'"
        return
    }
    $resourceId = $resourceApp.Id

    ## Get all AppRoles. Create a hashtable giving "Claim -> AppRoleId"
    $appRoles = @{}
    $resourceApp.AppRoles | ForEach-Object {
        $appRoles.add($_.Value, $_.Id)
    }

    ## Report app roles the resource does not have, instead of the misleading "already assigned"
    $unknownRoles = @($_.AppRoleAssignments | Where-Object { -not $appRoles.ContainsKey($_) })
    if ($unknownRoles.Count -gt 0) {
        "## - Unknown app roles for '$($resourceApp.DisplayName)', skipped: $($unknownRoles -join ', ')"
    }

    ## Apply each permission to the Ent App/Mgd. Identity
    $_.AppRoleAssignments | Where-Object { $appRoles.ContainsKey($_) } | ForEach-Object {
        "## Assigning $($resourceApp.DisplayName):$_"
        try {
            New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $enterpriseAppObjId -AppRoleId $appRoles[$_] -ResourceId $resourceId -PrincipalId $enterpriseAppObjId -ErrorAction Stop | Out-Null
        }
        catch {
            "## - Permission already assigned or assignment failed. Skipping..."
            if ($showErrors) {
                $_
            }
        }
    }
}

if ($disconnectAfterExecution) {
    Disconnect-MgGraph | Out-Null
}
