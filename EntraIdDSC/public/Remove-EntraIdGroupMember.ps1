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

            # Get current members (UPNs)
            $currentMembers = Get-EntraIdGroupMember -GroupDisplayName $GroupDisplayName

            # Remove specified members if present
            $toRemove = $Members | Where-Object { $_ -in $currentMembers }
            foreach ($memberEntry in $toRemove) {
                if ($memberEntry -like '*@*') {
                    # User
                    $userObj = Get-EntraIdUser -UserPrincipalName $memberEntry
                    if ($userObj) {
                        try {
                            Remove-MgGroupMemberDirectoryObjectByRef -GroupId $GroupId -DirectoryObjectId $userObj.Id
                            Write-Output "Removed user $memberEntry from group $GroupDisplayName ($GroupId)."
                        } catch {
                            Write-Warning "Failed to remove $memberEntry as member: $($_.Exception.Message)"
                        }
                    } else {
                        Write-Warning "User not found: $memberEntry"
                    }
                } else {
                    # Group
                    $groupMemberObj = Get-EntraIdGroup -DisplayName $memberEntry
                    if ($groupMemberObj) {
                        try {
                            Remove-MgGroupMemberDirectoryObjectByRef -GroupId $GroupId -DirectoryObjectId $groupMemberObj.Id
                            Write-Output "Removed group $memberEntry from group $GroupDisplayName ($GroupId)."
                        } catch {
                            Write-Warning "Failed to remove group $memberEntry as member: $($_.Exception.Message)"
                        }
                    } else {
                        Write-Warning "Group not found: $memberEntry"
                    }
                }
            }
        }
    }
}
