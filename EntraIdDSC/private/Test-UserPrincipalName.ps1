<#
.SYNOPSIS
Tests the formatting of a UserPrincipalName (UPN).

.DESCRIPTION
This function validates the format of a UserPrincipalName (UPN) to ensure it adheres to the standard format (e.g., user@domain.com).

.PARAMETER UserPrincipalName
The UserPrincipalName to validate.

.EXAMPLE
Test-UserPrincipalName -UserPrincipalName "johndoe@contoso.com"

.EXAMPLE
Test-UserPrincipalName -UserPrincipalName "invalid-upn"

.NOTES
Author: AzureStackNerd
Date: 11 September 2025
#>

function Test-UserPrincipalName {
    [CmdletBinding()]
    param (
        # The UserPrincipalName to validate
        [Parameter(Mandatory)]
        [string]$UserPrincipalName
    )

    process {
        try {
            # Define a regex pattern for a valid UPN
            $upnPattern = '^[^@\s]+@[^@\s]+\.[^@\s]+$'

            if ($UserPrincipalName -match $upnPattern) {
                Write-Verbose "The UserPrincipalName '$UserPrincipalName' is valid."
                return $true
            } else {
                Write-Verbose "The UserPrincipalName '$UserPrincipalName' is invalid."
                return $false
            }
        } catch {
            Write-Error -Message "An error occurred while validating the UserPrincipalName: $_.Exception.Message" -ErrorAction Stop
        }
    }
}
