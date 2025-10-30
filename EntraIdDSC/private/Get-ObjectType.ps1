<#
.SYNOPSIS
    Gets the object type (User, Group, or ServicePrincipal) for a given Entra ID object name.
.DESCRIPTION
    Accepts a string representing the name of a User, Group, or ServicePrincipal in Entra ID. Returns the type of the object found.
.PARAMETER Name
    The display name or UPN of the Entra ID object to check.
.EXAMPLE
    Get-ObjectType -Name "alice@contoso.com"
.NOTES
    Returns 'User', 'Group', or 'ServicePrincipal' if found, otherwise $null.
#>

function Get-ObjectType {
    [OutputType([System.String])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    # Check if Name is a UPN (contains '@' and looks like an email)
    if ($Name -match '^[^@]+@[^@]+\.[^@]+$') {
        $userParams = @{
            Filter = "userPrincipalName eq '$Name'"
            ErrorAction = 'SilentlyContinue'
        }
        $user = Get-MgUser @userParams | Select-Object -First 1
        if ($user) {
            return 'User'
        }
    } else {
        # try to get it as sp
        $spParams = @{
            Filter = "displayName eq '$Name'"
            ErrorAction = 'SilentlyContinue'
        }
        $sp = Get-MgServicePrincipal @spParams | Select-Object -First 1
        if ($sp) {
            return 'ServicePrincipal'
        }
        $groupParams = @{
            Filter = "displayName eq '$Name'"
            ErrorAction = 'SilentlyContinue'
        }
        $group = Get-MgGroup @groupParams | Select-Object -First 1
        if ($group) {
            return 'Group'
        }
    }
    return $null
}
