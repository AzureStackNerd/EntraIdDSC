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
        $user = Get-MgUser -Filter "userPrincipalName eq '$Name'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($user) {
            return 'User'
        }
    } else {
        # try to get it as sp
        $sp = Get-MgServicePrincipal -Filter "displayName eq '$Name'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($sp) {
            return 'ServicePrincipal'
        }
        $group = Get-MgGroup -Filter "displayName eq '$Name'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($group) {
            return 'Group'
        }
    }
    return $null
}
