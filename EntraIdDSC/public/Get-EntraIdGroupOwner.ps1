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
            $group = Get-MgGroup -Filter "displayName eq '$GroupDisplayName'"
            if (-not $group) {
                Write-Warning "No group found with display name '$GroupDisplayName'."
                return $null
            }
            $GroupId = $group.Id
        }

        # Get group owners
        $owners = Get-MgGroupOwner -GroupId $GroupId -All
        if (-not $owners) {
            Write-Warning "No owners found for group Id '$GroupId'."
            return $null
        }

        $upns = @()
        foreach ($owner in $owners) {
            if ($owner.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.user') {
                $user = Get-EntraIdUser -Id $owner.Id
                if ($user -and $user.UserPrincipalName) {
                    $upns += $user.UserPrincipalName
                }
            }
        }
        return $upns
    }
}
