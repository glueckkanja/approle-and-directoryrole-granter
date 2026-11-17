# AppRole and DirectoryRole Granter

Mass-Grant MS Graph and AzureAD permissions to App Registrations, Enterprise Apps and Mgd. Identities.

You don't need the legacy AzureAD / AzureADPreview modules. These scripts use Microsoft's Graph PowerShell SDK. 

## Known issues

### Connect-MGGraph authenticates every time

This is a [known issue](https://github.com/microsoftgraph/msgraph-sdk-powershell#known-issues) of the Microsoft Graph PowerShell SDK.

Either clean up the token cache:
- Use `Disconnect-MgGraph` to sign out of the current session.
- Run `Remove-Item "$env:USERPROFILE\.graph -Recurse -Force` to delete your token cache.
- Run `Connect-MgGraph` to reconstruct a clean token cache.

If you run commands manually, you can use `Connect-MgGraph -ContextScope Process` to avoid using the cache.

## RealmJoin vNext 

### Prepare an Azure Automation Account (Managed Identity) for RJ vNext

Get the AzureAD object id of the Managed Identity belonging to Automation Account (e.g. `a489c529-c750-4100-91e4-c4cbeee96143`).

```powershell
cd RealmJoinVnext
. .\AllInOneManagedId.ps1 -entAppObjectId "a489c529-c750-4100-91e4-c4cbeee96143" 
``` 

This will open a browser to let a GA (or similiar admin) sign in and grant access to the Microsoft Graph Powershell. 

You can reapply these permissions at any time; for example if new permissions were added to the JSON files. Existing permissions will create (non-terminating) errors. You can ignore those. Currently, existing additional roles and permissions are not removed by this script.

## Workplace Foundation

Templates for the two app registrations of a Workplace Foundation tenant: the **apply** app (writes) and the **plan** app (read-only). They follow the wiki page *MS - Graph API Permissions*: the Managed Intune and Managed Entra templates contain what the wiki marks for that service, and `FullFeatureSet` contains every permission a module on Workplace Foundation's `main` needs, including optional features such as Exchange Online. The mapping of permissions to services is discussed in Workplace-Foundation/workplace-foundation#2770.

| Template (folder `Workplace-Foundation`) | App | Contains |
| --- | --- | --- |
| `Workplace-Foundation_ManagedIntune_Apply.json` | apply | Managed Intune |
| `Workplace-Foundation_ManagedIntune_Plan.json` | plan | Managed Intune, read-only |
| `Workplace-Foundation_ManagedEntra_Apply.json` | apply | Managed Entra |
| `Workplace-Foundation_ManagedEntra_Plan.json` | plan | Managed Entra, read-only |
| `Workplace-Foundation_FullFeatureSet_Apply.json` | apply | everything, incl. `Exchange.ManageAsApp` (Office 365 Exchange Online) |
| `Workplace-Foundation_FullFeatureSet_Plan.json` | plan | everything, read-only |
| `Workplace-Foundation_ManagedEntra_Apply_DirectoryRoles.json` | apply | directory roles for Managed Entra |
| `Workplace-Foundation_FullFeatureSet_Apply_DirectoryRoles.json` | apply | all directory roles of the apply app |
| `Workplace-Foundation_FullFeatureSet_Plan_DirectoryRoles.json` | plan | all directory roles of the plan app |

Managed Intune needs no directory role.

`GrantAppPermToAppReg.ps1` **replaces** the permission list of the app registration. To combine templates, for a tenant with both services, run the second one with `-merge`, which adds to the existing list:

```powershell
. .\GrantAppPermToAppReg.ps1 -appRegObjectId "<apply app object id>" -permissionsTemplate .\Workplace-Foundation\Workplace-Foundation_ManagedIntune_Apply.json
. .\GrantAppPermToAppReg.ps1 -appRegObjectId "<apply app object id>" -permissionsTemplate .\Workplace-Foundation\Workplace-Foundation_ManagedEntra_Apply.json -merge
. .\AssignAzureADRoleToEntApp.ps1 -objectId "<apply enterprise app object id>" -rolesTemplate .\Workplace-Foundation\Workplace-Foundation_ManagedEntra_Apply_DirectoryRoles.json
```

Repeat with the `_Plan` templates for the plan app. Use `-merge` also when you add a template to an app that already has other permissions you want to keep.

The older templates `Workplace-Foundation_FullFeatureSet.json`, `Workplace-Foundation_ReadOnly.json` and `Workplace-Foundation_Intune.json` are deprecated and stay unchanged for one Workplace Foundation release. Use `FullFeatureSet_Apply`, `FullFeatureSet_Plan` and `ManagedIntune_Apply` instead.

## Generic Examples

### Assign MS Graph permissions to an App Registration

Get the AzureAD object id of the AppRegistration (e.g. `a489c529-c750-4100-91e4-c4cbeee96143`)

Prepare a JSON file `graphpermissions.json` containing the AppRole Names you want to assign. See [RealmJoin vNext Runbook permissions](RealmJoinVnext/RJvNextPermissions.json) as an example.

```powershell
. .\GrantAppPermToAppReg.ps1 -appRegObjectId "a489c529-c750-4100-91e4-c4cbeee96143" -permissionsTemplate .\graphpermissions.json
``` 

This will open a browser to let a GA (or similiar admin) sign in.

This script will automatically also grant the permissions on the corresponding Enterprise App by calling `GrantAppPermToEntApp.ps1`.

### Assign MS Graph permissions to a Service Principal (like a Managed Identity)

Get the AzureAD object id of the Mgd. Identity / Service Principal (e.g. `a489c529-c750-4100-91e4-c4cbeee96143`)

Prepare a JSON file `graphpermissions.json` containing the AppRole Names you want to assign. See [RealmJoin vNext Runbook permissions](RealmJoinVnext/RJvNextPermissions.json) as an example.

```powershell
. .\GrantAppPermToEntApp.ps1 -enterpriseAppObjId "a489c529-c750-4100-91e4-c4cbeee96143" -permissionsTemplate .\graphpermissions.json
``` 

This will open a browser to let a GA (or similiar admin) sign in.

### Assign AzureAD admin roles to a Service Principal (like a Managed Identity)

Get the object id of the object you want to give roles to. (e.g. `a489c529-c750-4100-91e4-c4cbeee96143`)

Prepare a JSON file `roles.json` containing the AzureAD Role Names you want to assign. See [RealmJoin vNext Runbook Roles](RealmJoinVnext/RJvNextRoles.json) as an example.

```powershell
. .\AssignAzureADRoleToEntApp.ps1 -objectId "a489c529-c750-4100-91e4-c4cbeee96143" -rolesTemplate .\roles.json
``` 
