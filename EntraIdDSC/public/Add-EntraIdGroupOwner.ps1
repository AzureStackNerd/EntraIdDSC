<#
.SYNOPSIS
    Adds an owner to an Entra ID (Azure AD) group by group Id or display name.

.DESCRIPTION
    This function adds specified owners to an Entra ID group using Microsoft Graph. It supports searching for the group by Id or display name. Owners can be users, identified by their UPN.

.PARAMETER GroupId
    The object Id (GUID) of the Entra ID group to add owners to.

.PARAMETER GroupDisplayName
    The display name of the Entra ID group to add owners to.

.PARAMETER Owners
    An array of user principal names (UPNs) to add as owners.

.EXAMPLE
    Add-EntraIdGroupOwner -GroupId "00000000-0000-0000-0000-000000000001" -Owners @("user1@contoso.com", "user2@contoso.com")
    Adds the specified users as owners to the group with the specified Id.

.EXAMPLE
    Add-EntraIdGroupOwner -GroupDisplayName "My Security Group" -Owners @("user1@contoso.com", "user2@contoso.com")
    Adds the specified users as owners to the group with the specified display name.

.NOTES
    This function requires Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Add-EntraIdGroupOwner {
    [CmdletBinding(DefaultParameterSetName='ById', SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory, ParameterSetName='ById', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupId,
        [Parameter(Mandatory, ParameterSetName='ByDisplayName', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupDisplayName,
        [Parameter(Mandatory)]
        [array]$Owners
    )

    process {
        if ($PSCmdlet.ShouldProcess("Group: $GroupDisplayName ($GroupId)", "Add specified owners")) {
            Test-GraphAuth

            # Resolve group Id or group display name based on parameter set
            switch ($PSCmdlet.ParameterSetName) {
                'ByDisplayName' {
                    $group = Get-MgGroup -Filter "displayName eq '$GroupDisplayName'" | Select-Object -First 1
                    if (-not $group) {
                        Write-Warning "No group found with display name '$GroupDisplayName'."
                        return
                    }
                    $GroupId = $group.Id
                }
                'ById' {
                    $group = Get-MgGroup -GroupId $GroupId
                    if (-not $group) {
                        Write-Warning "No group found with Id '$GroupId'."
                        return
                    }
                    $GroupDisplayName = $group.DisplayName
                }
            }

            # Get current owners (UPNs)
            $currentOwners = Get-EntraIdGroupOwner -GroupDisplayName $GroupDisplayName

            # Add missing owners
            $toAdd = $Owners | Where-Object { $_ -notin $currentOwners }
            foreach ($ownerEntry in $toAdd) {
                $userObj = Get-EntraIdUser -UserPrincipalName $ownerEntry
                if ($userObj) {
                    $userId = $userObj.Id
                    New-MgGroupOwner -GroupId "$GroupId" -DirectoryObjectId "$userId"
                    Write-Output "Added owner $ownerEntry to group $GroupDisplayName ($GroupId)."
                } else {
                    Write-Warning "User not found: $ownerEntry"
                }
            }
        }
    }
}
