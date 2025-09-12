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

.NOTES
    This function requires Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Get-EntraIdGroup {
    [CmdletBinding(DefaultParameterSetName='ByDisplayName', SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory, ParameterSetName='ById', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,
        [Parameter(Mandatory, ParameterSetName='ByDisplayName', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$DisplayName
    )

    process {
        if ($PSCmdlet.ShouldProcess("Retrieving group")) {
            Test-GraphAuth

            switch ($PSCmdlet.ParameterSetName) {
                'ByDisplayName' {
                    # Query Microsoft Graph for the group by display name
                    $group = Get-MgGroup -Filter "displayName eq '$DisplayName'"
                    if (-not $group) {
                        Write-Verbose "No group found with display name '$DisplayName'."
                        return $null
                    }
                    return $group
                }
                'ById' {
                    $group = Get-MgGroup -GroupId $Id
                    if (-not $group) {
                        Write-Verbose "No group found with Id '$Id'."
                        return $null
                    }
                    return $group
                }
            }
        }
    }
}
