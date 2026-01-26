function Add-GroupOwnerWithErrorHandling {
    <#
    .SYNOPSIS
        Helper function to add an owner to a group with standardized error handling.

    .DESCRIPTION
        This private function encapsulates the logic for adding an owner to an Entra ID group
        and handles the common error scenario where an owner is already assigned to the group.

    .PARAMETER OwnerType
        The type of owner being added (e.g., 'user', 'group', 'service principal').

    .PARAMETER OwnerIdentifier
        The display identifier for the owner (UPN, DisplayName, etc.).

    .PARAMETER OwnerId
        The object Id of the owner to add.

    .PARAMETER TargetGroupId
        The object Id of the group to add the owner to.

    .PARAMETER TargetGroupDisplayName
        The display name of the group to add the owner to.

    .NOTES
        This is a private helper function and should not be called directly.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OwnerType,

        [Parameter(Mandatory)]
        [string]$OwnerIdentifier,

        [Parameter(Mandatory)]
        [string]$OwnerId,

        [Parameter(Mandatory)]
        [string]$TargetGroupId,

        [Parameter(Mandatory)]
        [string]$TargetGroupDisplayName
    )

    $addOwnerParams = @{
        GroupId           = $TargetGroupId
        DirectoryObjectId = $OwnerId
    }

    try {
        New-MgGroupOwner @addOwnerParams
        Write-Output "Added owner ($OwnerType) $OwnerIdentifier to group $TargetGroupDisplayName ($TargetGroupId)."
    }
    catch {
        if ($_.Exception.Message -match "already an owner") {
            Write-Warning "Owner $OwnerIdentifier is already an owner of the group. Skipping."
        }
        else {
            throw
        }
    }
}
