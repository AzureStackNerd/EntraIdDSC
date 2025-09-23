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
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param (
        [Parameter(ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true)]
        [string]$DisplayName
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                if (-not $Id) {
                    Throw "Id cannot be empty."
                }
                if ($PSCmdlet.ShouldProcess($Id, "Remove Entra ID group by Id")) {
                    try {
                        Remove-MgGroup -GroupId $Id -ErrorAction Stop
                        Write-Verbose "Group with Id '$Id' removed."
                    }
                    catch {
                        Write-Error $_
                    }
                }
            }
            'ByName' {
                if (-not $DisplayName) {
                    Throw "DisplayName cannot be empty."
                }
                $group = Get-MgGroup -Filter "displayName eq '$DisplayName'" -ErrorAction Stop
                if ($group) {
                    if ($PSCmdlet.ShouldProcess($DisplayName, "Remove Entra ID group by Name")) {
                        try {
                            Remove-MgGroup -GroupId $group.Id -ErrorAction Stop
                            Write-Verbose "Group with Name '$DisplayName' removed."
                        }
                        catch {
                            Write-Error $_
                        }
                    }
                }
                else {
                    Throw "Group with Name '$DisplayName' not found."
                }
            }
            default {
                Throw "You must specify either Id or DisplayName."
            }
        }

    }
}
