<#
.SYNOPSIS
    Retrieves the owners of an Entra ID (Azure AD) group by group Id or display name.

.DESCRIPTION
    This function retrieves all owners of an Entra ID group using Microsoft Graph. It supports searching for the group by Id or display name. Returns a list of UPNs (when using GroupDisplayName) or Ids (when using GroupId).

.PARAMETER GroupId
    The object Id (GUID) of the Entra ID group to retrieve owners from.

.PARAMETER GroupDisplayName
    The display name of the Entra ID group to retrieve owners from.

.EXAMPLE
    Get-EntraIdGroupOwner -GroupId "00000000-0000-0000-0000-000000000001"
    Returns the Ids of all owners in the group with the specified Id.

.EXAMPLE
    Get-EntraIdGroupOwner -GroupDisplayName "My Security Group"
    Returns the UPNs of all owners in the group with the specified display name.

.NOTES
    This function requires Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Get-EntraIdGroupOwner {
    [CmdletBinding(DefaultParameterSetName='ById')]
    param(
        [Parameter(Mandatory, ParameterSetName='ById', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupId,
        [Parameter(Mandatory, ParameterSetName='ByDisplayName', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupDisplayName
    )

    process {
        # Resolve group Id if searching by GroupDisplayName
        if ($PSCmdlet.ParameterSetName -eq 'ByDisplayName') {
            Write-Verbose "Get-EntraIdGroupOwner: Searching for group with display name '$GroupDisplayName'"
            $groupParams = @{
                Filter = "displayName eq '$GroupDisplayName'"
            }
            $group = Get-MgGroup @groupParams
            if (!$group) {
                Write-Warning "No group found with display name '$GroupDisplayName'."
                return $null
            }
            $GroupId = $group.Id
        }

        # Get group Owners
        $ownersParams = @{
            GroupId = $GroupId
            All = $true
            ConsistencyLevel = "eventual"
            CountVariable = "Owners"
        }
        $owners = Get-MgGroupOwner @ownersParams
        if (!$owners) {
            Write-Warning "No owners found for group Id '$GroupId'."
            return $null
        }

        $results = @()
        foreach ($owner in $owners) {
            # Process user and group objects
            $odataType = $owner.AdditionalProperties['@odata.type']
            if ($odataType -eq '#microsoft.graph.user') {
                if ($PSCmdlet.ParameterSetName -eq 'ByDisplayName') {
                    $userParams = @{
                        Id = $owner.Id
                    }
                    $user = Get-EntraIdUser @userParams
                    if ($user -and $user.UserPrincipalName) {
                        $results += $user.UserPrincipalName
                    }
                } else {
                    $results += $owner.Id
                }
            } elseif ($odataType -eq '#microsoft.graph.group') {
                # For groups, return the group Id or display name as appropriate
                if ($PSCmdlet.ParameterSetName -eq 'ByDisplayName') {
                    $groupObjParams = @{
                        Id = "$($owner.Id)"
                    }
                    $groupObj = Get-EntraIdGroup @groupObjParams
                    if ($groupObj -and $groupObj.DisplayName) {
                        $results += $groupObj.DisplayName
                    }
                } else {
                    $results += $owner.Id
                }
            } elseif ($odataType -eq '#microsoft.graph.servicePrincipal') {
                if ($PSCmdlet.ParameterSetName -eq 'ByDisplayName') {
                    $spnObjParams = @{
                        ServicePrincipalId = $owner.Id
                    }
                    $spnObj = Get-EntraIdServicePrincipal @spnObjParams
                    if ($spnObj -and $spnObj.DisplayName) {
                        $results += $spnObj.DisplayName
                    }
                } else {
                    $results += $owner.Id
                }
            }
        }
        return $results
    }
}
