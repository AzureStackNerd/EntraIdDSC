<#
.SYNOPSIS
    Adds an owner to an Entra ID (Azure AD) group by group Id or display name.

.DESCRIPTION
    This function adds specified owners to an Entra ID group using Microsoft Graph. It supports searching for the group by Id or display name. Owners can be users, groups, or service principals, identified by their UPN or display name.

.PARAMETER GroupId
    The object Id (GUID) of the Entra ID group to add owners to.

.PARAMETER GroupDisplayName
    The display name of the Entra ID group to add owners to.

.PARAMETER Owners
    An array of user principal names (UPNs), group display names, or service principal display names to add as owners.

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
        [string[]]$Owners
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

        if ($PSCmdlet.ShouldProcess("Group: $GroupDisplayName ($GroupId)", "Add specified owners")) {
            # Base parameters that are common for all owner additions
            $baseOwnerParams = @{
                TargetGroupId          = $GroupId
                TargetGroupDisplayName = $GroupDisplayName
            }

            # Add all provided owners directly
            foreach ($ownerEntry in $Owners) {
                if (Test-UserPrincipalName -UserPrincipalName $ownerEntry) {
                    # User
                    Write-Verbose "Searching for user with UPN: $ownerEntry"
                    $ownerUserParams = @{
                        UserPrincipalName = $ownerEntry
                    }
                    $ownerUserObj = Get-EntraIdUser @ownerUserParams
                    if ($ownerUserObj) {
                        $addOwnerParams = $baseOwnerParams + @{
                            OwnerType       = 'user'
                            OwnerIdentifier = $ownerEntry
                            OwnerId         = $ownerUserObj.Id
                        }
                        Add-GroupOwnerWithErrorHandling @addOwnerParams
                    }
                    else {
                        Write-Warning "User not found: $ownerEntry"
                    }
                }
                else {
                    # Group
                    Write-Verbose "Searching for group with DisplayName: $ownerEntry"
                    $ownerGroupParams = @{
                        DisplayName = $ownerEntry
                    }
                    $ownerGroupObj = Get-EntraIdGroup @ownerGroupParams
                    if ($null -ne $ownerGroupObj) {
                        $addOwnerParams = $baseOwnerParams + @{
                            OwnerType       = 'group'
                            OwnerIdentifier = $ownerEntry
                            OwnerId         = $ownerGroupObj.Id
                        }
                        Add-GroupOwnerWithErrorHandling @addOwnerParams
                    }
                    else {
                        # Try as service principal
                        Write-Verbose "Group not found, searching for service principal with DisplayName: $ownerEntry"
                        $ownerSpnParams = @{
                            DisplayName = $ownerEntry
                        }
                        $ownerSpnObj = Get-EntraIdServicePrincipal @ownerSpnParams
                        if ($null -ne $ownerSpnObj) {
                            $addOwnerParams = $baseOwnerParams + @{
                                OwnerType       = 'service principal'
                                OwnerIdentifier = $ownerEntry
                                OwnerId         = $ownerSpnObj.Id
                            }
                            Add-GroupOwnerWithErrorHandling @addOwnerParams
                        }
                        else {
                            Write-Warning "Group or ServicePrincipal not found: $ownerEntry"
                        }
                    }
                }
            }
        }
    }
}
