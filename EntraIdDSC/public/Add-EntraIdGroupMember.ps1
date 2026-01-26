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
        [string[]]$Members
    )

    process {
        Test-GraphAuth

        # Resolve group Id or group display name based on parameter set
        switch ($PSCmdlet.ParameterSetName) {
            'ByDisplayName' {
                $groupParams = @{
                    DisplayName = $GroupDisplayName
                }
                $group = Get-EntraIdGroup @groupParams
                if (!$group) {
                    Write-Warning "No group found with display name '$GroupDisplayName'."
                    return
                }
                $GroupId = $group.Id
                Write-Verbose "Resolved group '$GroupDisplayName' to Id: $GroupId"
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
                Write-Verbose "Resolved group Id '$GroupId' to DisplayName: $GroupDisplayName"
            }
        }

        if ($PSCmdlet.ShouldProcess("Group: $GroupDisplayName ($GroupId)", "Add specified members")) {
            # Base parameters that are common for all member additions
            $baseMemberParams = @{
                TargetGroupId          = $GroupId
                TargetGroupDisplayName = $GroupDisplayName
            }

            # Add all provided members directly
            foreach ($memberEntry in $Members) {
                if (Test-UserPrincipalName -UserPrincipalName $memberEntry) {
                    # User
                    Write-Verbose "Searching for user with UPN: $memberEntry"
                    $memberUserParams = @{
                        UserPrincipalName = $memberEntry
                    }
                    $memberUserObj = Get-EntraIdUser @memberUserParams
                    if ($null -ne $memberUserObj) {
                        $addMemberParams = $baseMemberParams + @{
                            MemberType       = 'user'
                            MemberIdentifier = $memberEntry
                            MemberId         = $memberUserObj.Id
                        }
                        Add-GroupMemberWithErrorHandling @addMemberParams
                    }
                    else {
                        Write-Warning "User not found: $memberEntry"
                    }
                }
                else {
                    # Group
                    Write-Verbose "Searching for group with DisplayName: $memberEntry"
                    $memberGroupParams = @{
                        DisplayName = $memberEntry
                    }
                    $memberGroupObj = Get-EntraIdGroup @memberGroupParams
                    if ($null -ne $memberGroupObj) {
                        $addMemberParams = $baseMemberParams + @{
                            MemberType       = 'group'
                            MemberIdentifier = $memberEntry
                            MemberId         = $memberGroupObj.Id
                        }
                        Add-GroupMemberWithErrorHandling @addMemberParams
                    }
                    else {
                        # Try as service principal
                        Write-Verbose "Group not found, searching for service principal with DisplayName: $memberEntry"
                        $memberSpnParams = @{
                            DisplayName = $memberEntry
                        }
                        $memberSpnObj = Get-EntraIdServicePrincipal @memberSpnParams
                        if ($null -ne $memberSpnObj) {
                            $addMemberParams = $baseMemberParams + @{
                                MemberType       = 'service principal'
                                MemberIdentifier = $memberEntry
                                MemberId         = $memberSpnObj.Id
                            }
                            Add-GroupMemberWithErrorHandling @addMemberParams
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
