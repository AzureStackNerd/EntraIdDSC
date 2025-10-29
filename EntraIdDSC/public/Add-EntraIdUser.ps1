<#
.SYNOPSIS
Adds a new user to Entra ID (Azure AD).

.DESCRIPTION
This function creates a new user in Entra ID (Azure AD) with the specified display name and user principal name. A random GUID is used as the password. Additional properties can be provided as a hashtable.

.PARAMETER DisplayName
The display name of the user to add.

.PARAMETER UserPrincipalName
The user principal name (UPN) of the user to add.

.PARAMETER AdditionalProperties
Additional properties for the user as a hashtable.

.EXAMPLE
Add-EntraIdUser -DisplayName "John Doe" -UserPrincipalName "johndoe@contoso.com"

.EXAMPLE
Add-EntraIdUser -DisplayName "Jane Smith" -UserPrincipalName "janesmith@contoso.com" -AdditionalProperties @{ JobTitle = "Manager"; Department = "HR" }

.NOTES
Author: AzureStackNerd
Date: 11 September 2025
#>

function Add-EntraIdUser {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The display name of the user to add
        [Parameter(Position = 0)]
        [string]$DisplayName,

        # The user principal name (UPN) of the user to add
        [Parameter(Position = 1)]
        [string]$UserPrincipalName,

        # Additional properties for the user
        [Parameter()]
        [hashtable]$AdditionalProperties
    )

    process {
        # Validate the DisplayName
        if ([string]::IsNullOrWhiteSpace($DisplayName)) {
            throw "DisplayName is required."
        }
        # Validate the UserPrincipalName
        if ([string]::IsNullOrWhiteSpace($UserPrincipalName)) {
            throw "UserPrincipalName is required."
        }

        $testUPNParams = @{
            UserPrincipalName = $UserPrincipalName
        }
        if (!(Test-UserPrincipalName @testUPNParams)) {
            Write-Error -Message "The UserPrincipalName '$UserPrincipalName' is not in a valid format." -ErrorAction Stop
        }

        if ($PSCmdlet.ShouldProcess("UserPrincipalName: $UserPrincipalName", "Add user to Entra ID")) {
            try {

                # Ensure Graph authentication is valid
                Test-GraphAuth

                # Generate a random GUID as the password
                $randomPassword = [Guid]::NewGuid().ToString()

                # Construct the user object
                $userObject = @{
                    DisplayName       = $DisplayName
                    UserPrincipalName = $UserPrincipalName
                    AccountEnabled    = $false
                    PasswordProfile   = @{ Password = $randomPassword; ForceChangePasswordNextSignIn = $true }
                }

                if ($AdditionalProperties) {
                    $userObject += $AdditionalProperties
                }

                # Call Microsoft Graph to create the user
                $newUserParams = @{
                    BodyParameter = $userObject
                }
                New-MgUser @newUserParams

                Write-Output "User '$DisplayName' with UPN '$UserPrincipalName' created successfully."
            }
            catch {
                Write-Error -Message $_.Exception.Message -ErrorAction Stop
            }
        }
    }
}
