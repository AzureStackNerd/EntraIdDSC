<#
.SYNOPSIS
    Tests if there is an authenticated Microsoft Graph connection in the current session.

.DESCRIPTION
    This function checks for an active Microsoft Graph authentication context. If no authenticated connection is found, it writes an error message and returns.
#>
function Test-GraphAuth {
    # Attempt to get the current Microsoft Graph context
    try {
        $getContextParams = @{
            ErrorAction = 'Stop'
        }
        $mgContext = Get-MgContext @getContextParams
        # Check if the Account property is present (indicating authentication)
        if (!$mgContext) {
            try {
                $connectParams = @{
                    NoWelcome = $true
                    ErrorAction = 'Stop'
                }
                Connect-MgGraph @connectParams
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