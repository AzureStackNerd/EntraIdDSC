<#!
.SYNOPSIS
    Removes an Entra ID group by its Id or Name.
.DESCRIPTION
    This function removes an Entra ID group from Microsoft Entra ID (Azure AD) using either the group's unique Id or its display Name.
.PARAMETER GroupId
    The unique identifier (ObjectId) of the group to remove.
.PARAMETER GroupName
    The display name of the group to remove.
.EXAMPLE
    Remove-EntraIdGroup -GroupId "12345678-90ab-cdef-1234-567890abcdef"
.EXAMPLE
    Remove-EntraIdGroup -GroupName "MyGroup"
.NOTES
    You must be connected to Microsoft Graph with sufficient permissions to remove groups.
.OUTPUTS
    None
#>
function Remove-EntraIdGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupId,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupName
    )
    try {
        if ($GroupId) {
            if ($PSCmdlet.ShouldProcess($GroupId, "Remove Entra ID group by Id")) {
                Remove-MgGroup -GroupId $GroupId -ErrorAction Stop
                Write-Verbose "Group with Id '$GroupId' removed."
            }
        }
        elseif ($GroupName) {
            $group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction Stop
            if ($group) {
                if ($PSCmdlet.ShouldProcess($GroupName, "Remove Entra ID group by Name")) {
                    Remove-MgGroup -GroupId $group.Id -ErrorAction Stop
                    Write-Verbose "Group with Name '$GroupName' removed."
                }
            } else {
                Write-Error "Group with Name '$GroupName' not found."
            }
        }
        else {
            Write-Error "You must specify either GroupId or GroupName."
        }
    } catch {
        Write-Error $_
    }
}
