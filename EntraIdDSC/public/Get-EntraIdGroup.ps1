<#
.SYNOPSIS
    Retrieves an Entra ID (Azure AD) group by its display name or Id using Microsoft Graph.

.DESCRIPTION
    This function retrieves an Entra ID group object by its display name or Id using the Microsoft Graph PowerShell SDK (Get-MgGroup). It supports searching by either display name or Id using parameter sets.

.PARAMETER DisplayName
    The display name of the Entra ID group to retrieve.

.PARAMETER Id
    The object Id (GUID) of the Entra ID group to retrieve.


.EXAMPLE
    Get-EntraIdGroup -DisplayName "My Security Group"
    Retrieves the group with the display name 'My Security Group'.

.EXAMPLE
    Get-EntraIdGroup -Id "00000000-0000-0000-0000-000000000001"
    Retrieves the group with the specified Id.

.EXAMPLE
    Get-EntraIdGroup -DisplayNamePattern "UG-PIM-*"
    Retrieves all groups whose display names match the pattern 'UG-PIM-*'.

.NOTES
    This function requires Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Get-EntraIdGroup {
    [CmdletBinding(DefaultParameterSetName = 'ByDisplayName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByDisplayName', Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$DisplayName,
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDisplayNamePattern')]
        [string]$DisplayNamePattern
    )

    process {
        Test-GraphAuth

        switch ($PSCmdlet.ParameterSetName) {
            'ByDisplayName' {
                $groupParams = @{
                    Filter = "displayName eq '$DisplayName'"
                }
                $group = Get-MgGroup @groupParams
                if (-not $group) {
                    Write-Verbose "No group found with display name '$DisplayName'."
                    return $null
                }
                return $group
            }
            'ById' {
                Write-Verbose "Get-EntraIdGroup: Searching for group with Id '$Id'"
                $groupParams = @{
                    GroupId = $Id
                }
                $group = Get-MgGroup @groupParams
                if (-not $group) {
                    Write-Verbose "No group found with Id '$Id'."
                    return $null
                }
                return $group
            }
            'ByDisplayNamePattern' {
                # Support wildcard filtering, e.g., UG-PIM-*
                $allGroupsParams = @{
                    All = $true
                }
                $allGroups = Get-MgGroup @allGroupsParams
                $filteredGroups = $allGroups | Where-Object { $_.DisplayName -like $DisplayNamePattern }
                if (-not $filteredGroups) {
                    Write-Verbose "No groups found matching pattern '$DisplayNamePattern'."
                    return $null
                }
                return $filteredGroups
            }
        }

    }
}
