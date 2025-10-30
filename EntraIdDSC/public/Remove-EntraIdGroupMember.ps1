<#
.SYNOPSIS
    Removes members from an Entra ID (Azure AD) group by group Id or display name.

.DESCRIPTION
    This function removes specified members from an Entra ID group using Microsoft Graph. It supports searching for the group by Id or display name. Members can be users or other groups, identified by their UPN or display name.

.PARAMETER GroupId
    The object Id (GUID) of the Entra ID group to remove members from.

.PARAMETER GroupDisplayName
    The display name of the Entra ID group to remove members from.

.PARAMETER Members
    An array of user principal names (UPNs) or group display names to remove as members.

.EXAMPLE
    Remove-EntraIdGroupMember -GroupId "00000000-0000-0000-0000-000000000001" -Members @("user1@contoso.com", "user2@contoso.com")
    Removes the specified users from the group with the specified Id.

.EXAMPLE
    Remove-EntraIdGroupMember -GroupDisplayName "My Security Group" -Members @("user1@contoso.com", "user2@contoso.com")
    Removes the specified users from the group with the specified display name.

.NOTES
    This function requires Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Remove-EntraIdGroupMember {
    [CmdletBinding(DefaultParameterSetName='ById', SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory, ParameterSetName='ById', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupId,
        [Parameter(Mandatory, ParameterSetName='ByDisplayName', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupDisplayName,
        [Parameter(Mandatory)]
        [array]$Members
    )

    process {
        if ($PSCmdlet.ShouldProcess("Group: $GroupDisplayName ($GroupId)", "Remove specified members")) {
            Test-GraphAuth

            # Resolve group Id or group display name based on parameter set
            switch ($PSCmdlet.ParameterSetName) {
                'ByDisplayName' {
                    $groupParams = @{
                        DisplayName = "$GroupDisplayName"
                    }
                    $group = Get-EntraIdGroup @groupParams
                    if (!$group) {
                        Write-Warning "No group found with display name '$GroupDisplayName'."
                        return
                    }
                    $GroupId = $group.Id
                }
                'ById' {
                    $groupParams = @{
                        Id = $GroupId
                    }
                    $group = Get-EntraIdGroup @groupParams
                    if (!$group) {
                        Write-Warning "No group found with Id '$GroupId'."
                        return
                    }
                    $GroupDisplayName = $group.DisplayName
                }
            }

            # Get current members (UPNs)
            $currentMembers = Get-EntraIdGroupMember -GroupDisplayName $GroupDisplayName

            # Remove specified members if present
            $toRemove = $Members | Where-Object { $_ -in $currentMembers }
            foreach ($memberEntry in $toRemove) {
                if ($memberEntry -like '*@*') {
                    # User
                    $memberUserObj = Get-EntraIdUser -UserPrincipalName $memberEntry
                    if ($null -ne $memberUserObj) {
                        try {
                            $memberUserId = $memberUserObj.Id
                            $removeParams = @{
                                GroupId = $GroupId
                                DirectoryObjectId = $memberUserId
                            }
                            Remove-MgGroupMemberDirectoryObjectByRef @removeParams
                            Write-Output "Removed Member (user) $memberEntry from group $GroupDisplayName ($GroupId)."
                        } catch {
                            Write-Warning "Failed to remove Member (user) $memberEntry from group $GroupDisplayName ($GroupId): $($_.Exception.Message)"
                        }
                    } else {
                        Write-Warning "User not found: $memberEntry"
                    }
                } else {
                    # Group
                    $memberGroupObj = Get-EntraIdGroup -DisplayName $memberEntry
                    if ($null -ne $memberGroupObj) {
                        try {
                            $memberGroupId = $memberGroupObj.Id
                            $removeParams = @{
                                GroupId = $GroupId
                                DirectoryObjectId = $memberGroupId
                            }
                            Remove-MgGroupMemberDirectoryObjectByRef @removeParams
                            Write-Output "Removed Member (group) $memberEntry from group $GroupDisplayName ($GroupId)."
                        } catch {
                            Write-Warning "Failed to remove Member (group) $memberEntry from group $GroupDisplayName ($GroupId): $($_.Exception.Message)"
                        }
                    } else {
                        # Try as service principal
                        $memberSpnObj = Get-EntraIdServicePrincipal -DisplayName $memberEntry
                        if ($null -ne $memberSpnObj) {
                            try {
                                $memberSpnId = $memberSpnObj.Id
                                $removeParams = @{
                                    GroupId = $GroupId
                                    DirectoryObjectId = $memberSpnId
                                }
                                Remove-MgGroupMemberDirectoryObjectByRef @removeParams
                                Write-Output "Removed Member (service principal) $memberEntry from group $GroupDisplayName ($GroupId)."
                            } catch {
                                Write-Warning "Failed to remove Member (service principal) $memberEntry from group $GroupDisplayName ($GroupId): $($_.Exception.Message)"
                            }
                        } else {
                            Write-Warning "Group or ServicePrincipal not found: $memberEntry"
                        }
                    }
                }
            }
        }
    }
}
