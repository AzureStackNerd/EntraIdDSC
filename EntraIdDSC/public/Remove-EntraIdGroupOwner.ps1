<#!
.SYNOPSIS
    Removes owners from an Entra ID (Azure AD) group by group Id or display name.

.DESCRIPTION
    This function removes specified owners from an Entra ID group using Microsoft Graph. It supports searching for the group by Id or display name. Owners can be users, identified by their UPN.

.PARAMETER GroupId
    The object Id (GUID) of the Entra ID group to remove owners from.

.PARAMETER GroupDisplayName
    The display name of the Entra ID group to remove owners from.

.PARAMETER Owners
    An array of user principal names (UPNs) to remove as owners.

.EXAMPLE
    Remove-EntraIdGroupOwner -GroupId "00000000-0000-0000-0000-000000000001" -Owners @("user1@contoso.com", "user2@contoso.com")
    Removes the specified users as owners from the group with the specified Id.

.EXAMPLE
    Remove-EntraIdGroupOwner -GroupDisplayName "My Security Group" -Owners @("user1@contoso.com", "user2@contoso.com")
    Removes the specified users as owners from the group with the specified display name.

.NOTES
    This function requires Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Remove-EntraIdGroupOwner {
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
        if ($PSCmdlet.ShouldProcess("Group: $GroupDisplayName ($GroupId)", "Remove specified owners")) {
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

            # Remove specified owners if present
            $toRemove = $Owners | Where-Object { $_ -in $currentOwners }
            foreach ($ownerEntry in $toRemove) {
                if ($ownerEntry -like '*@*') {
                    # User
                    $ownerUserObj = Get-EntraIdUser -UserPrincipalName $ownerEntry
                    if ($null -ne $ownerUserObj) {
                        try {
                            $ownerUserId = $ownerUserObj.Id
                            Remove-MgGroupOwnerDirectoryObjectByRef -GroupId $GroupId -DirectoryObjectId $ownerUserId
                            Write-Output "Removed user $ownerEntry from group $GroupDisplayName ($GroupId)."
                        } catch {
                            Write-Warning "Failed to remove $ownerEntry as owner: $($_.Exception.Message)"
                        }
                    } else {
                        Write-Warning "User not found: $ownerEntry"
                    }
                } else {
                    # Group
                    $ownerGroupObj = Get-EntraIdGroup -DisplayName $ownerEntry
                    if ($null -ne $ownerGroupObj) {
                        try {
                            $ownerGroupId = $ownerGroupObj.Id
                            Remove-MgGroupOwnerDirectoryObjectByRef -GroupId $GroupId -DirectoryObjectId $ownerGroupId
                            Write-Output "Removed group $ownerEntry from group $GroupDisplayName ($GroupId)."
                        } catch {
                            Write-Warning "Failed to remove group $ownerEntry as owner: $($_.Exception.Message)"
                        }
                    } else {
                        # Try as service principal
                        $ownerSpnObj = Get-EntraIdServicePrincipal -DisplayName $ownerEntry
                        if ($null -ne $ownerSpnObj) {
                            try {
                                $ownerSpnId = $ownerSpnObj.Id
                                Remove-MgGroupOwnerDirectoryObjectByRef -GroupId $GroupId -DirectoryObjectId $ownerSpnId
                                Write-Output "Removed service principal $ownerEntry from group $GroupDisplayName ($GroupId)."
                            } catch {
                                Write-Warning "Failed to remove service principal $ownerEntry as owner: $($_.Exception.Message)"
                            }
                        } else {
                            Write-Warning "Group or ServicePrincipal not found: $ownerEntry"
                        }
                    }
                }
            }
        }
    }
}
