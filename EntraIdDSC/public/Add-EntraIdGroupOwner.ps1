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

            # Add all provided owners directly
            foreach ($ownerEntry in $Owners) {
                if ($ownerEntry -like '*@*') {
                    $ownerUserParams = @{
                        UserPrincipalName = $ownerEntry
                    }
                    $ownerUserObj = Get-EntraIdUser @ownerUserParams
                    if ($ownerUserObj) {
                        $ownerUserId = $ownerUserObj.Id
                        $addOwnerParams = @{
                            GroupId = $GroupId
                            DirectoryObjectId = $ownerUserId
                        }
                        try {
                            New-MgGroupOwner @addOwnerParams
                            Write-Output "Added owner $ownerEntry to group $GroupDisplayName ($GroupId)."
                        } catch {
                            if ($_.Exception.Message -match "already an owner") {
                                Write-Warning "Owner $ownerEntry is already an owner of the group. Skipping."
                            } else {
                                throw
                            }
                        }
                    } else {
                        Write-Warning "User not found: $ownerEntry"
                    }
                }
                else {
                    # Group
                    $memberGroupParams = @{
                        DisplayName = $ownerEntry
                    }
                    $memberGroupObj = Get-EntraIdGroup @memberGroupParams
                    if ($null -ne $memberGroupObj) {
                        $memberGroupId = $memberGroupObj.Id
                        $addOwnerParams = @{
                            GroupId = $GroupId
                            DirectoryObjectId = $memberGroupId
                        }
                        try {
                            New-MgGroupOwner @addOwnerParams
                            Write-Output "Added group $ownerEntry as owner of group $GroupDisplayName ($GroupId)."
                        } catch {
                            if ($_.Exception.Message -match "already an owner") {
                                Write-Warning "Owner $ownerEntry is already an owner of the group. Skipping."
                            } else {
                                throw
                            }
                        }
                    }
                    else {
                        # Try as service principal
                        $memberSpnParams = @{
                            DisplayName = $ownerEntry
                        }
                        $memberSpnObj = Get-EntraIdServicePrincipal @memberSpnParams
                        if ($null -ne $memberSpnObj) {
                            $memberSpnId = $memberSpnObj.Id
                            $addOwnerParams = @{
                                GroupId = $GroupId
                                DirectoryObjectId = $memberSpnId
                            }
                            try {
                                New-MgGroupOwner @addOwnerParams
                                Write-Output "Added service principal $ownerEntry as owner of group $GroupDisplayName ($GroupId)."
                            } catch {
                                if ($_.Exception.Message -match "already an owner") {
                                    Write-Warning "Owner $ownerEntry is already an owner of the group. Skipping."
                                } else {
                                    throw
                                }
                            }
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
