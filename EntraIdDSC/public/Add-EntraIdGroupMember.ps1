<#
.SYNOPSIS
    Adds members to an Entra ID (Azure AD) group by group Id or display name.

.DESCRIPTION
    This function adds specified members to an Entra ID group using Microsoft Graph. It supports searching for the group by Id or display name. Members can be users or other groups, identified by their UPN or display name.

.PARAMETER GroupId
    The object Id (GUID) of the Entra ID group to add members to.

.PARAMETER GroupDisplayName
    The display name of the Entra ID group to add members to.

.PARAMETER Members
    An array of user principal names (UPNs) or group display names to add as members.

.EXAMPLE
    Add-EntraIdGroupMember -GroupId "00000000-0000-0000-0000-000000000001" -Members @("user1@contoso.com", "user2@contoso.com")
    Adds the specified users to the group with the specified Id.

.EXAMPLE
    Add-EntraIdGroupMember -GroupDisplayName "My Security Group" -Members @("user1@contoso.com", "user2@contoso.com")
    Adds the specified users to the group with the specified display name.

.NOTES
    This function requires Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Add-EntraIdGroupMember {
    [CmdletBinding(DefaultParameterSetName = 'ById', SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupId,
        [Parameter(Mandatory, ParameterSetName = 'ByDisplayName', Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupDisplayName,
        [Parameter(Mandatory)]
        [array]$Members
    )

    process {
        if ($PSCmdlet.ShouldProcess("Group: $GroupDisplayName ($GroupId)", "Add specified members")) {
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
            $groupMemberParams = @{
                GroupDisplayName = $GroupDisplayName
            }
            $currentMembers = Get-EntraIdGroupMember @groupMemberParams

            # Add missing members
            $toAdd = $Members | Where-Object { $_ -notin $currentMembers }
            foreach ($memberEntry in $toAdd) {
                if ($memberEntry -like '*@*') {
                    # User
                    $memberUserParams = @{
                        UserPrincipalName = $memberEntry
                    }
                    $memberUserObj = Get-EntraIdUser @memberUserParams
                    if ($null -ne $memberUserObj) {
                        $memberUserId = $memberUserObj.Id
                        $addMemberParams = @{
                            GroupId = $GroupId
                            DirectoryObjectId = $memberUserId
                        }
                        New-MgGroupMember @addMemberParams
                        Write-Output "Added Member (user) $memberEntry to group $GroupDisplayName ($GroupId)."
                    }
                    else {
                        Write-Warning "User not found: $memberEntry"
                    }
                }
                else {
                    # Group
                    $memberGroupParams = @{
                        DisplayName = $memberEntry
                    }
                    $memberGroupObj = Get-EntraIdGroup @memberGroupParams
                    if ($null -ne $memberGroupObj) {
                        $memberGroupId = $memberGroupObj.Id
                        $addMemberParams = @{
                            GroupId = $GroupId
                            DirectoryObjectId = $memberGroupId
                        }
                        New-MgGroupMember @addMemberParams
                        Write-Output "Added Member (group) $memberEntry to group $GroupDisplayName ($GroupId)."
                    }
                    else {
                        # Try as service principal
                        $memberSpnParams = @{
                            DisplayName = $memberEntry
                        }
                        $memberSpnObj = Get-EntraIdServicePrincipal @memberSpnParams
                        if ($null -ne $memberSpnObj) {
                            $memberSpnId = $memberSpnObj.Id
                            $addMemberParams = @{
                                GroupId = $GroupId
                                DirectoryObjectId = $memberSpnId
                            }
                            New-MgGroupMember @addMemberParams
                            Write-Output "Added Member (service principal) $memberEntry to group $GroupDisplayName ($GroupId)."
                        }
                        else {
                            Write-Warning "Group or ServicePrincipal not found: $memberEntry"
                        }
                    }
                }
            }
        }
    }
}
