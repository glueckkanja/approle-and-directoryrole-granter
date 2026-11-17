# Allow assigning MS Graph and similar permissions to an App Regsitration - without using the AzureAD module
# Input should be readble (claim names in JSON), parsed from a file

#Requires -modules Microsoft.Graph.Applications,Microsoft.Graph.Authentication

param(
    # Please give the app registration's object id. 
    [Parameter(Mandatory = $true)]
    [string] $appRegObjectId,
    [string] $permissionsTemplate = "RealmJoinVnext\RjvNextPermissions.json",
    [switch] $updateEnterpriseApp = $false,
    # Add the template's permissions to the ones the app registration already has, instead of replacing them.
    # Use it to combine templates, e.g. Workplace-Foundation_ManagedIntune_Apply.json, then Workplace-Foundation_ManagedEntra_Apply.json.
    [switch] $merge = $false,
    [switch] $disconnectAfterExecution = $false,
    [switch] $showErrors = $false
)

## Authenticate as admin (delegated). Use MS Graph PowerShell SDK to leverage existing (well known) clientId/app.
## Will sign you in using your browser and ask for granting permissions if needed.
Connect-MgGraph -Scopes "Application.ReadWrite.All" 

## Read the permission template
$permissions = Get-Content -Path $permissionsTemplate | ConvertFrom-Json

$requiredResourceAccess = @()

$permissions | ForEach-Object {
    $appId = $_.Id

    ## Get Service Principal from Application:
    $resourceApp = Get-MgServicePrincipal -Filter "AppId eq '$appId'" 

    ## Get all AppRoles. Create a hashtable giving "Claim -> AppRoleId"
    $appRoles = @{}
    $resourceApp.AppRoles | ForEach-Object {
        $appRoles.add($_.Value, $_.Id)
    }

    ## Stop before changing anything if the template names an app role the resource does not have
    $unknownRoles = @($_.AppRoleAssignments | Where-Object { -not $appRoles.ContainsKey($_) })
    if ($unknownRoles.Count -gt 0) {
        throw "## Unknown app roles for '$($_.Name)' ($appId): $($unknownRoles -join ', ')"
    }

    $requiredResourceAccessItem = @{
        "resourceAppId"  = $appId
        "resourceAccess" = [array]($_.AppRoleAssignments | ForEach-Object { @{"Id" = $appRoles[$_]; "Type" = "Role" } } )
    }

    $requiredResourceAccess += $requiredResourceAccessItem

}
if ($merge) {
    ## Keep every permission the app registration already has (other resources, delegated scopes included)
    "## Merging with the permissions already on the App Registration..."
    $existingAccess = (Get-MgApplication -ApplicationId $appRegObjectId -Property RequiredResourceAccess).RequiredResourceAccess
    foreach ($existing in $existingAccess) {
        $existingEntries = @($existing.ResourceAccess | ForEach-Object { @{ "Id" = $_.Id; "Type" = $_.Type } })
        $item = $requiredResourceAccess | Where-Object { $_.resourceAppId -eq $existing.ResourceAppId } | Select-Object -First 1
        if ($item) {
            $known = @($item.resourceAccess | ForEach-Object { "$($_.Id)|$($_.Type)" })
            $item.resourceAccess = [array](@($item.resourceAccess) + @($existingEntries | Where-Object { "$($_.Id)|$($_.Type)" -notin $known }))
        }
        else {
            $requiredResourceAccess += @{
                "resourceAppId"  = $existing.ResourceAppId
                "resourceAccess" = [array]$existingEntries
            }
        }
    }
}

""
"## Setting new permissions on the App Registration..."
try {
    Update-MgApplication -ApplicationId $appRegObjectId -RequiredResourceAccess $requiredResourceAccess -ErrorAction Stop
}
catch {
    "## - Assignment failed."
    if ($showErrors) {
        $_
    }
}
""

if ($updateEnterpriseApp) {
    ## Option 1 - Use Graph on the linked enterprise app to grant.
    ## Get linked enterprise app
    $entApp = Get-MgServicePrincipal -Filter "AppId eq '$((Get-MgApplication -ApplicationId $appRegObjectId).AppId)'"

    ## Granting the permission to the managed/linked enterprise app
    . $PSScriptRoot\GrantAppPermToEntApp.ps1 -enterpriseAppObjId $entApp.Id -permissionsTemplate $permissionsTemplate
}
else {
    ## Option 2 - Grant new permissions manually:
    #"## Wating 30 sec. AzureAD needs a moment tp update the permissions..."
    #Start-Sleep 30
    #""
    "## To enable the new permissions, please wait some seconds and visit the follwing URL to grant the updated permissions."
    ""
    "https://login.microsoftonline.com/$((Get-MgContext).TenantId)/adminconsent?client_id=$((Get-MgApplication -ApplicationId $appRegObjectId).AppId)"
    ""
    "It is ok if this shows a 'No reply address is registered for the application' error."
}

if ($disconnectAfterExecution) {
    Disconnect-MgGraph | Out-Null
}