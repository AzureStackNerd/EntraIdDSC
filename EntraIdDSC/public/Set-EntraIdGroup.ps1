<#
.SYNOPSIS
    Ensures an Entra ID (Azure AD) group exists with the specified name, description, and members (UPNs).

.DESCRIPTION
    This function checks if a group with the given name exists. If not, it creates the group with the specified name and description. It then ensures the group description is correct and synchronizes the group membership to match the provided list of UPNs (adding missing members and removing extra ones). Owners can also be specified and synchronized.

.PARAMETER GroupName
    The display name of the Entra ID group to ensure exists and is configured.

.PARAMETER Description
    The description to set on the group.

.PARAMETER Members
    An array of user principal names (UPNs) to be members of the group.

.PARAMETER Owners
    An array of user principal names (UPNs) to be owners of the group.

.PARAMETER GroupMembershipType
    Specifies the type of group membership. Valid values are "Direct" or "Dynamic". Defaults to "Direct".

.PARAMETER IsAssignableToRole
    Indicates whether the group can be assigned to a role. Defaults to $false.

.EXAMPLE
    Set-EntraIdGroup -DisplayName "Platform Admins" -Description "Admins for the platform" -Members @("alice@contoso.com", "bob@contoso.com") -Owners @("carol@contoso.com")
    Ensures the group "Platform Admins" exists with the specified description, members, and owners.

.EXAMPLE
    Set-EntraIdGroup -DisplayName "Dynamic Group" -Description "Dynamic membership group" -GroupMembershipType "Dynamic" -Members @("(user.department -eq 'IT')")
    Creates or updates a dynamic group with the specified membership rule.

.NOTES
    Author: Remco Vermeer
    Date: 10 September 2025
#>
function Set-EntraIdGroup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Direct", "Dynamic")]
        [string]$GroupMembershipType = "Direct",
        [Parameter(Mandatory)]
        [string]$Description,
        [Parameter(Mandatory = $false)]
        [array]$Members,
        [Parameter(Mandatory)]
        [array]$Owners,
        [Parameter(Mandatory = $false)]
        [bool]$IsAssignableToRole = $false,
        [Parameter(Mandatory = $false)]
        [string]$AdministrativeUnit = $null
    )

    process {
        Test-GraphAuth

        Write-Output "Processing Group: '$DisplayName'"
        $newGroup = $false
        $updateRequired = $false
        # Check if group exists
        $groupParams = @{
            Filter = "displayName eq '$DisplayName'"
        }
        $group = Get-MgGroup @groupParams | Select-Object -First 1
        if (!$group) {
            # Common group parameters
            $newGroupParams = @{
                DisplayName        = $DisplayName
                Description        = $Description
                MailEnabled        = $false
                MailNickname       = $DisplayName.Replace(' ', '').ToLower()
                SecurityEnabled    = $true
                IsAssignableToRole = $IsAssignableToRole
            }
            switch ($GroupMembershipType) {
                "Direct" {
                    # No extra params needed
                }
                "Dynamic" {
                    Write-Output "Creating dynamic group with rule: $Members[0]"
                    $newGroupParams.GroupTypes = @("DynamicMembership")
                    $newGroupParams.MembershipRule = $Members[0] # Assuming Members contains the rule as a string
                    $newGroupParams.MembershipRuleProcessingState = "On"
                }
                default {
                    throw "Unsupported GroupMembershipType: $GroupMembershipType"
                }
            }
            $newGroup = $true


            if ([string]::IsNullOrWhiteSpace($AdministrativeUnit)) {
                if ($PSCmdlet.ShouldProcess("Group '$DisplayName'", "Create group with parameters $($newGroupParams | ConvertTo-Json)")) {
                    $group = New-MgGroup @newGroupParams
                }
            }
            else {
                $adminUnitParams = @{
                    Filter = "DisplayName eq '$AdministrativeUnit'"
                }
                $adminUnitObj = Get-MgDirectoryAdministrativeUnit @adminUnitParams | Select-Object -First 1
                if (!$adminUnitObj) {
                    throw "Administrative Unit '$AdministrativeUnit' not found. Cannot create group in a non-existent Administrative Unit."
                }
                # $bodyParams = @{
                #     "@odata.id" = "https://graph.microsoft.com/v1.0/groups/$($group.Id)"
                # }
                # New-MgDirectoryAdministrativeUnitMemberByRef -AdministrativeUnitId $($adminUnitObj.id) -BodyParameter $bodyParams
                $bodyParams = @{}
                $newGroupParams.Keys | ForEach-Object { $bodyParams[$_] = $newGroupParams[$_] }
                $bodyParams['@odata.type'] = '#microsoft.graph.group'
                if ($PSCmdlet.ShouldProcess("Group '$DisplayName'", "Create group in Administrative Unit '$AdministrativeUnit' with parameters $($bodyParams | ConvertTo-Json)")) {
                    $addMemberParams = @{
                        AdministrativeUnitId = $adminUnitObj.Id
                        BodyParameter        = $bodyParams
                    }
                    New-MgDirectoryAdministrativeUnitMember @addMemberParams
                }
            }
            Write-Output "Created group '$DisplayName' ($GroupMembershipType membership)"

        }
        else {
            $updateRequired = $false
            # Update description if needed
            if ($group.Description -ne $Description) {
                $updateParams = @{
                    GroupId     = $group.Id
                    Description = $Description
                }
                $updateRequired = $true
                if ($PSCmdlet.ShouldProcess("Group '$DisplayName'", "Update group description to '$Description'")) {
                    Update-MgGroup @updateParams
                    Write-Output "Updated description for group '$DisplayName'"
                }
            }
            if (![string]::IsNullOrWhiteSpace($AdministrativeUnit)) {
                $adminUnitParams = @{
                    Filter = "DisplayName eq '$AdministrativeUnit'"
                }
                $adminUnitObj = Get-MgDirectoryAdministrativeUnit @adminUnitParams | Select-Object -First 1
                if ($null -eq $adminUnitObj) {
                    Throw "Administrative Unit '$AdministrativeUnit' not found."
                }
                $adminUnitId = $adminUnitObj.Id
                $administrativeUnitMember = Get-MgDirectoryAdministrativeUnitMember -AdministrativeUnitId $adminUnitId | Where-Object { $_.Id -eq $group.Id }
                if ([string]::IsNullOrWhiteSpace($administrativeUnitMember)) {
                    # $updateRequired = $true
                    # $bodyParams = @{
                    #     "@odata.id" = "https://graph.microsoft.com/v1.0/groups/$($group.Id)"
                    # }
                    # New-MgDirectoryAdministrativeUnitMemberByRef -AdministrativeUnitId $($adminUnitObj.id) -BodyParameter $bodyParams
                    # Write-Output "Adding group '$DisplayName' to Administrative Unit '$AdministrativeUnit'"
                    Write-Warning "Changing Administrative Unit membership for existing groups is not (yet) implemented."
                    # Permission issues with the current Graph SDK prevent implementation. It needs AdministrativeUnit.ReadWrite.All
                    # This is a to broad scope if the intention is only to manage group membership in a specific Administrative Unit.
                    # There is not a particular role available on the administrative unit level to delegate this.
                }


            }
            if ($group.IsAssignableToRole -and $group.IsAssignableToRole -ne $IsAssignableToRole) {
                Write-Warning "IsAssignableToRole cannot be changed after group creation. Please delete and recreate the group if needed."
            }
        }

        # Synchronize members only for Direct groups
        if ($GroupMembershipType -eq "Direct") {
            if (!$newGroup) {
                $currentMembers = Get-EntraIdGroupMember -GroupDisplayName $DisplayName
                Write-Verbose "Fetched group: $DisplayName current members. $($currentMembers | ConvertTo-Json -Depth 3)"

            }
            else {
                $currentMembers = @()
                Write-Verbose "New group created, no current members."
            }

            # Add missing members
            if ($Members) {
                $toAdd = $Members | Where-Object { $_ -notin $currentMembers }
            }


            # Remove extra members
            if ($Members) {
                $toRemove = $currentMembers | Where-Object { $_ -notin $Members }
            }
            else {
                $toRemove = $currentMembers
            }

            if ($toAdd.Count -gt 0) {
                $updateRequired = $true
                if ($PSCmdlet.ShouldProcess("Group '$DisplayName'", "Add Members $($toAdd | ConvertTo-Json)")) {
                    Add-EntraIdGroupMember -GroupDisplayName $DisplayName -Members $toAdd
                }
            }
            if ($toRemove.Count -gt 0) {
                $updateRequired = $true
                if ($PSCmdlet.ShouldProcess("Group '$DisplayName'", "Remove Members $($toRemove | ConvertTo-Json)")) {
                    Remove-EntraIdGroupMember -GroupDisplayName $DisplayName -Members $toRemove
                }
            }


        }
        # Get current owners (UPNs)
        $currentOwners = Get-EntraIdGroupOwner -GroupDisplayName $DisplayName
        $toAddOwners = $Owners | Where-Object { $_ -notin $currentOwners }
        $toRemoveOwners = $currentOwners | Where-Object { $_ -notin $Owners }

        if ($toAddOwners.Count -gt 0) {
            $updateRequired = $true
            if ($PSCmdlet.ShouldProcess("Group '$DisplayName'", "Add Owners $($toAddOwners | ConvertTo-Json)")) {
                Add-EntraIdGroupOwner -GroupDisplayName $DisplayName -Owners $toAddOwners
            }
        }
        if ($toRemoveOwners.Count -gt 0) {
            $updateRequired = $true
            if ($PSCmdlet.ShouldProcess("Group '$DisplayName'", "Remove Owners $($toRemoveOwners | ConvertTo-Json)")) {
                Remove-EntraIdGroupOwner -GroupDisplayName $DisplayName -Owners $toRemoveOwners
            }
        }

        if (!$updateRequired) {
            Write-Output "Group '$DisplayName' is already in the desired state."
        }
        Write-Output ""
    }
}
