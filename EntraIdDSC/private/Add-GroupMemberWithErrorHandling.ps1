function Add-GroupMemberWithErrorHandling {
    <#
    .SYNOPSIS
        Helper function to add a member to a group with standardized error handling.

    .DESCRIPTION
        This private function encapsulates the logic for adding a member to an Entra ID group
        and handles the common error scenario where a member is already part of the group.

    .PARAMETER MemberType
        The type of member being added (e.g., 'user', 'group', 'service principal').

    .PARAMETER MemberIdentifier
        The display identifier for the member (UPN, DisplayName, etc.).

    .PARAMETER MemberId
        The object Id of the member to add.

    .PARAMETER TargetGroupId
        The object Id of the group to add the member to.

    .PARAMETER TargetGroupDisplayName
        The display name of the group to add the member to.

    .NOTES
        This is a private helper function and should not be called directly.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MemberType,

        [Parameter(Mandatory)]
        [string]$MemberIdentifier,

        [Parameter(Mandatory)]
        [string]$MemberId,

        [Parameter(Mandatory)]
        [string]$TargetGroupId,

        [Parameter(Mandatory)]
        [string]$TargetGroupDisplayName
    )

    $addMemberParams = @{
        GroupId           = $TargetGroupId
        DirectoryObjectId = $MemberId
    }

    try {
        New-MgGroupMember @addMemberParams
        Write-Output "Added Member ($MemberType) $MemberIdentifier to group $TargetGroupDisplayName ($TargetGroupId)."
    }
    catch {
        if ($_.Exception.Message -match "already a member") {
            Write-Warning "Member $MemberIdentifier is already in the group. Skipping."
        }
        else {
            throw
        }
    }
}
