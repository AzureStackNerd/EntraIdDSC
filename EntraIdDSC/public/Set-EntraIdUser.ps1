<#
.SYNOPSIS
Ensures that a user in Entra ID (Azure AD) is in the desired state.

.DESCRIPTION
This function checks if a user exists in Entra ID (Azure AD) and updates their properties to match the desired state defined in the provided user object. If the user does not exist, it writes an error.

.PARAMETER User
The user object containing the desired state properties, such as DisplayName, UserPrincipalName, and other attributes.

.EXAMPLE
$user = [PSCustomObject]@{
    DisplayName = "John Doe"
    UserPrincipalName = "johndoe@contoso.com"
    AccountEnabled = $true
    JobTitle = "Software Engineer"
    Department = "IT"
    OfficeLocation = "Building A"
    MobilePhone = "+1 555-555-5555"
    UsageLocation = "US"
}
Set-EntraIdUser -User $user

.NOTES
Author: AzureStackNerd
Date: 11 September 2025
#>
function Set-EntraIdUser {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The user object containing desired state properties
        [Parameter(Mandatory)]
        [PSCustomObject]$User
    )


    try {
        # Ensure Graph authentication is valid
        Test-GraphAuth

        # Check if the user already exists
        $getUserParams = @{
            UserPrincipalName = $User.UserPrincipalName
        }
        $existingUser = Get-EntraIdUser @getUserParams

        if ($existingUser) {

            Write-Output "User '$($User.DisplayName)' exists. Checking for updates."

            # Compare and update properties if necessary
            $updateRequired = $false
            $updateParams = @{}

            foreach ($key in $User.PSObject.Properties.Name) {
                if ($key -ne "UserPrincipalName" -and $existingUser.$key -ne $User.$key) {
                    $updateRequired = $true
                    $updateParams[$key] = $User.$key
                    # Write-Output "Property '$key' differs. Current: '$($existingUser.$key)', Desired: '$($User.$key)'. Marking for update."
                }
            }

            if ($updateRequired) {
                Write-Output "Updating user '$($User.DisplayName)' to match desired state."
                if ($PSCmdlet.ShouldProcess("User '$($User.UserPrincipalName)'", "Update user properties $($updateParams | ConvertTo-Json)")) {
                    $updateUserParams = @{
                        UserId = $existingUser.UserPrincipalName
                        BodyParameter = $updateParams
                    }
                    Update-MgUser @updateUserParams
                }
            } else {
                Write-Output "User '$($User.DisplayName)' is already in the desired state."
            }
            Write-Output ""

        } else {
            Write-Error -Message "User '$($User.DisplayName)' does not exist. Unable to set desired state." -ErrorAction Stop
        }
    } catch {
        Write-Error -Message $_.Exception.Message -ErrorAction Stop
    }
}
