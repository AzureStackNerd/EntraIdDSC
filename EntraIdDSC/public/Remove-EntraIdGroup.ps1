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
                if ([string]::IsNullOrWhiteSpace($Id)) {
                    Throw "Id cannot be empty."
                }
                $groupParams = @{
                    Id = "$Id"
                }
                $group = Get-EntraIdGroup @groupParams
                if ($group) {
                    if ($PSCmdlet.ShouldProcess($Id, "Remove Entra ID group by Id")) {
                        $removeGroupParams = @{
                            GroupId     = $Id
                            ErrorAction = 'Stop'
                        }
                        Remove-MgGroup @removeGroupParams
                        Write-Verbose "Group with Id '$Id' removed."
                    }
                }
                else {
                    Throw "Group with Id '$Id' not found."
                }
            }
            'ByName' {
                if ([string]::IsNullOrWhiteSpace($DisplayName)) {
                    Throw "DisplayName cannot be empty."
                }
                $groupParams = @{
                    DisplayName = "$DisplayName"
                }
                $group = Get-EntraIdGroup @groupParams
                if ($group) {
                    if ($PSCmdlet.ShouldProcess($DisplayName, "Remove Entra ID group by Name")) {
                        $removeGroupParams = @{
                            GroupId     = $group.Id
                            ErrorAction = 'Stop'
                        }
                        Remove-MgGroup @removeGroupParams
                        Write-Verbose "Group with Name '$DisplayName' removed."
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
