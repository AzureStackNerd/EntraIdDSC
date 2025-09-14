<#
.SYNOPSIS
    Tests if there is an authenticated Microsoft Graph connection in the current session.

.DESCRIPTION
    This function checks for an active Microsoft Graph authentication context. If no authenticated connection is found, it writes an error message and returns.
#>
function Test-GraphAuth {
    # Attempt to get the current Microsoft Graph context
    try {
        $mgContext = Get-MgContext -ErrorAction Stop
        # Check if the Account property is present (indicating authentication)
        if (-not $mgContext) {
            try {
                Connect-MgGraph -NoWelcome -ErrorAction Stop
            } catch {
                throw "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-Error "Microsoft Graph authentication required. Please connect using Connect-MgGraph."
        throw
    }
}