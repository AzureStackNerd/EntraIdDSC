<#
.SYNOPSIS
    Retrieves an Entra ID (Azure AD) service principal by its display name or Service Principal Id.

.DESCRIPTION
    This function retrieves an Entra ID service principal object by its display name or Service Principal Id using the Microsoft Graph PowerShell SDK (Get-MgServicePrincipal). It supports searching by either display name or Service Principal Id using parameter sets.

.PARAMETER DisplayName
    The display name of the Entra ID service principal to retrieve.

.PARAMETER ServicePrincipalId
    The Service Principal Id of the Entra ID service principal to retrieve.

.EXAMPLE
    Get-EntraIdServicePrincipal -DisplayName "My App"
    Retrieves the service principal with the display name 'My App'.

.EXAMPLE
    Get-EntraIdServicePrincipal -ServicePrincipalId "00000000-0000-0000-0000-000000000001"
    Retrieves the service principal with the specified Service Principal Id.

.NOTES
    This function requires Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Get-EntraIdServicePrincipal {
    [CmdletBinding(DefaultParameterSetName='ByDisplayName')]
    param(
        [Parameter(Mandatory, ParameterSetName='ByDisplayName', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$DisplayName,
    [Parameter(Mandatory, ParameterSetName='ByServicePrincipalId', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$ServicePrincipalId
    )

    process {
        Test-GraphAuth

        switch ($PSCmdlet.ParameterSetName) {
            'ByDisplayName' {
                $sp = Get-MgServicePrincipal -Filter "displayName eq '$DisplayName'" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($sp) { return $sp }
                Write-Verbose "No Service Principal found with display name '$DisplayName'."
            }
            'ByServicePrincipalId' {
                $sp = Get-MgServicePrincipal -ServicePrincipalId "$ServicePrincipalId" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($sp) { return $sp }
                Write-Verbose "No Service Principal found with ServicePrincipalId '$ServicePrincipalId'."
            }
        }
    }


}
