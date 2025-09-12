<#!
.SYNOPSIS
    Retrieves an Entra ID (Azure AD) user by their Id or User Principal Name (UPN).

.DESCRIPTION
    This function retrieves an Entra ID user object by their Id or UPN using the Microsoft Graph PowerShell SDK (Get-MgUser). It supports searching by either Id or UPN using parameter sets.

.PARAMETER Id
    The object Id (GUID) of the Entra ID user to retrieve.

.PARAMETER UserPrincipalName
    The User Principal Name (UPN) of the Entra ID user to retrieve.

.EXAMPLE
    Get-EntraIdUser -Id "00000000-0000-0000-0000-000000000001"
    Retrieves the user with the specified Id.

.EXAMPLE
    Get-EntraIdUser -UserPrincipalName "user@contoso.com"
    Retrieves the user with the specified UPN.

.NOTES
    This function requires Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Get-EntraIdUser {
    [CmdletBinding(DefaultParameterSetName='ById')]
    param(
        [Parameter(Mandatory, ParameterSetName='ById', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,
        [Parameter(Mandatory, ParameterSetName='ByUPN', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$UserPrincipalName
    )

    process {
        Test-GraphAuth

        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                # Query Microsoft Graph for the user by Id
                $getUserParams = @{
                    UserId = $Id
                    Property = 'EmployeeId,GivenName,Surname,MobilePhone,UsageLocation,StreetAddress,City,State,PostalCode,Country,AccountEnabled,DisplayName,MailNickname,UserPrincipalName,JobTitle,Department,OfficeLocation'
                    ErrorAction = 'SilentlyContinue'
                }
                $user = Get-MgUser @getUserParams
                if (-not $user) {
                    Write-Verbose "No user found with Id '$Id'."
                    return $null
                }
                return $user
            }
            'ByUPN' {
                # Query Microsoft Graph for the user by UPN
                $getUserParams = @{
                    UserId = $UserPrincipalName
                    Property = 'EmployeeId,GivenName,Surname,MobilePhone,UsageLocation,StreetAddress,City,State,PostalCode,Country,AccountEnabled,DisplayName,MailNickname,UserPrincipalName,JobTitle,Department,OfficeLocation'
                    ErrorAction = 'SilentlyContinue'
                }
                $user = Get-MgUser @getUserParams
                if (-not $user) {
                    Write-Verbose "No user found with UPN '$UserPrincipalName'."
                    return $null
                }
                return $user
            }
        }
    }
}
