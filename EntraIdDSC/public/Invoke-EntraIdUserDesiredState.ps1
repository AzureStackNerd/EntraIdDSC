<#
.SYNOPSIS
Invokes the desired state configuration for Entra ID users based on JSON configuration files.

.DESCRIPTION
This function processes JSON configuration files to ensure that Entra ID users are created or updated to match the desired state. It validates user properties such as display name, user principal name, and additional attributes.

.PARAMETER Path
The path to the directory containing JSON configuration files for users.

.EXAMPLE
Invoke-EntraIdUserDesiredState -Path "C:\Configs\Users"

.NOTES
Author: AzureStackNerd
Date: 11 September 2025
#>

function Invoke-EntraIdUserDesiredState {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    Test-GraphAuth
    # Get all JSON configuration files in the specified path
    $files = Get-ChildItem -Path $Path -Include *.json, *.jsonc -File -Recurse | Sort-Object Name
    $protectedUserFile = $files | Where-Object { $_.Name -eq 'ProtectedUsers.jsonc' -or $_.Name -eq 'ProtectedUsers.json' }
    if ($protectedUserFile.Count -gt 1) {
        Write-Error "Multiple ProtectedUsers files found. Please ensure only one exists."
        return
    }
    if ($protectedUserFile) {
        Write-Verbose "Loading protected users from file: $($protectedUserFile.FullName)"
        $protectedRaw = Get-Content -Path $protectedUserFile.FullName -Raw
        # Remove single-line comments (// ...)
        $protectedRaw = $protectedRaw -replace '(?m)^\s*//.*$', ''
        # Remove block comments (/* ... */)
        $protectedRaw = $protectedRaw -replace '/\*.*?\*/', ''
        $protectedUsers = $protectedRaw | ConvertFrom-Json
        $files = $files | Where-Object { $_.FullName -ne $protectedUserFile.FullName }
    }
    else {
        Write-Verbose "No ProtectedUsers file found. Proceeding without protected users."
    }

    foreach ($file in $files) {
        Write-Verbose "Processing file: $($file.FullName)"

        # Read the user object from the JSON/JSONC file, removing comment lines
        $rawContent = Get-Content -Path $file.FullName -Raw
        # Remove single-line comments (// ...)
        $rawContent = $rawContent -replace '(?m)^\s*//.*$', ''
        # Remove block comments (/* ... */)
        $rawContent = $rawContent -replace '/\*.*?\*/', ''
        $json = $rawContent | ConvertFrom-Json

        foreach ($user in $json) {
            $skipUser = $false
            foreach ($protectedUser in $protectedUsers) {
                if ($user.UserPrincipalName -eq $protectedUser.UserPrincipalName) {
                    $skipUser = $true
                }
            }
            if ($skipUser) {
                Write-Host "User '$($user.UserPrincipalName)' is protected. Skipping."
                Write-Host ""
                continue
            }
            $upn = $user.UserPrincipalName
            # Prepare additional properties
            $additionalProperties = @{
                GivenName      = $user.GivenName
                Surname        = $user.Surname
                MailNickname   = $user.MailNickname
                JobTitle       = $user.JobTitle
                Department     = $user.Department
                OfficeLocation = $user.OfficeLocation
                MobilePhone    = $user.MobilePhone
                UsageLocation  = $user.UsageLocation
                StreetAddress  = $user.StreetAddress
                City           = $user.City
                State          = $user.State
                PostalCode     = $user.PostalCode
                Country        = $user.Country
            }

            # Check if the user already exists
            $getUserParams = @{
                UserPrincipalName = $upn
            }
            $existingUser = Get-EntraIdUser @getUserParams
            if (-not $existingUser) {
                Write-Output "Creating user '$($user.DisplayName)' with UPN '$upn'."
                # Create the user
                $addUserParams = @{
                    DisplayName          = $user.DisplayName
                    UserPrincipalName    = $upn
                    AdditionalProperties = $additionalProperties
                }
                Add-EntraIdUser @addUserParams
            }
            else {
                # Ensure the user is in the desired state
                $setUserParams = @{
                    User = $user
                }
                Set-EntraIdUser @setUserParams
            }

        }
    }
}
