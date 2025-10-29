<#
.SYNOPSIS
Invokes the desired state configuration for Entra ID groups based on JSON configuration files.

.DESCRIPTION
This function processes JSON configuration files to ensure that Entra ID groups are created or updated to match the desired state. It validates group properties such as membership type, description, members, owners, and whether the group is assignable to roles.

.PARAMETER Path
The path to the directory containing JSON configuration files for groups.

.EXAMPLE
Invoke-EntraIdGroupDesiredState -Path "C:\Configs\Groups"

.NOTES
Author: AzureStackNerd
Date: 11 September 2025
#>

function Invoke-EntraIdGroupDesiredState {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    process {
        Test-GraphAuth
        # Get all JSON configuration files in the specified path
        $filesParams = @{
            Path = $Path
            Include = "*.json", "*.jsonc"
            File = $true
            Recurse = $true
        }
        $files = Get-ChildItem @filesParams | Sort-Object Name

        foreach ($file in $files) {
            Write-Verbose "Processing file: $($file.FullName)"
            # Read the group object from the JSON/JSONC file, removing comment lines
            $contentParams = @{
                Path = $file.FullName
                Raw = $true
            }
            $rawContent = Get-Content @contentParams
            # Remove single-line comments (// ...)
            $rawContent = $rawContent -replace '(?m)^\s*//.*$', ''
            # Remove block comments (/* ... */)
            $rawContent = $rawContent -replace '(?s)/\*.*?\*/', ''
            $json = $rawContent | ConvertFrom-Json
            foreach ($group in $json) {
                $groupName = $group.name
                $groupMembershipType = $group.groupMembershipType
                $description = $group.description
                $members = $group.members
                $owners = $group.owners
                $isAssignableToRole = $group.isAssignableToRole
                $administrativeUnit = $group.administrativeUnit

                $params = @{
                    DisplayName         = $groupName
                    GroupMembershipType = $groupMembershipType
                    Description         = $description
                    Owners              = $owners
                    IsAssignableToRole  = $isAssignableToRole
                    Members             = $members
                    AdministrativeUnit  = $administrativeUnit
                }

                if (!$owners) {
                    Write-Output "Skipping group '$groupName' as it has no owners defined."
                    continue
                }
                Set-EntraIdGroup @params
            }
        }
    }
}
