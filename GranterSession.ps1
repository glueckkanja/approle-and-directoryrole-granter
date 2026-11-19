# Shared by the granter scripts: sign in to Microsoft Graph, or reuse the session that is already open.
# Dot-source it, then call Connect-GranterGraph.

function Connect-GranterGraph {
    param(
        # Scopes the calling script needs (delegated scopes, or app roles of an app-only session)
        [Parameter(Mandatory = $true)]
        [string[]] $Scopes,
        # Use the session from an earlier Connect-MgGraph instead of signing in again
        [switch] $UseExistingSession
    )

    if (-not $UseExistingSession) {
        ## Authenticate as admin (delegated). Use MS Graph PowerShell SDK to leverage existing (well known) clientId/app.
        ## Will sign you in using your browser and ask for granting permissions if needed.
        Connect-MgGraph -Scopes ($Scopes -join ",")
        return
    }

    $context = Get-MgContext
    if (-not $context) {
        throw "## -useExistingSession: there is no Microsoft Graph session. Connect first, e.g. Connect-MgGraph -TenantId <tenant> -Scopes '$($Scopes -join "','")'"
    }

    $identity = if ("$($context.AuthType)" -eq "AppOnly") { "app '$($context.AppName)' ($($context.ClientId))" } else { "account '$($context.Account)'" }
    "## Using the existing Microsoft Graph session: tenant $($context.TenantId), $identity"

    ## A scope is covered by itself or by its ReadWrite counterpart (Application.ReadWrite.All covers Application.Read.All)
    $granted = @($context.Scopes)
    $missing = @(foreach ($scope in $Scopes) {
            if ($scope -notin $granted -and ($scope -replace '\.Read\.', '.ReadWrite.') -notin $granted) { $scope }
        })
    if ($missing.Count -gt 0) {
        throw "## -useExistingSession: the session lacks $($missing -join ', '). Reconnect with these scopes (or grant these app roles), then run the script again."
    }
}
