<#
.SYNOPSIS
    Retrieves an Entra ID (Azure AD) service principal by its display name or App Id.

.DESCRIPTION
    This function retrieves an Entra ID service principal object by its display name or App Id using the Microsoft Graph PowerShell SDK (Get-MgServicePrincipal). It supports searching by either display name or App Id using parameter sets.

.PARAMETER DisplayName
    The display name of the Entra ID service principal to retrieve.

.PARAMETER AppId
    The App Id of the Entra ID service principal to retrieve.

.EXAMPLE
    Get-EntraIdServicePrincipal -DisplayName "My App"
    Retrieves the service principal with the display name 'My App'.

.EXAMPLE
    Get-EntraIdServicePrincipal -AppId "00000000-0000-0000-0000-000000000001"
    Retrieves the service principal with the specified App Id.

.NOTES
    This function requires Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Get-EntraIdServicePrincipal {
    [CmdletBinding(DefaultParameterSetName='ByDisplayName')]
    param(
        [Parameter(Mandatory, ParameterSetName='ByDisplayName', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$DisplayName,
        [Parameter(Mandatory, ParameterSetName='ByAppId', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$AppId
    )

    process {
        Test-GraphAuth

        switch ($PSCmdlet.ParameterSetName) {
            'ByDisplayName' {
                $sp = Get-MgServicePrincipal -Filter "displayName eq '$DisplayName'" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($sp) { return $sp }
                Write-Verbose "No Service Principal found with display name '$DisplayName'."
            }
            'ByAppId' {
                $sp = Get-MgServicePrincipal -Filter "appId eq '$AppId'" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($sp) { return $sp }
                Write-Verbose "No Service Principal found with AppId '$AppId'."
            }
        }
    }
}
