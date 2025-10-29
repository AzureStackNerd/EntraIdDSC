<#!
.SYNOPSIS
    Retrieves the members of an Entra ID (Azure AD) group by group Id or display name.

.DESCRIPTION
    This function retrieves all user members of an Entra ID group using Microsoft Graph. It supports searching for the group by Id or display name. For each member, it resolves the UPN by user Id. Returns a list of UPNs (when using GroupDisplayName) or Ids (when using GroupId).

.PARAMETER GroupId
    The object Id (GUID) of the Entra ID group to retrieve members from.

.PARAMETER GroupDisplayName
    The display name of the Entra ID group to retrieve members from.

.EXAMPLE
    Get-EntraIdGroupMember -GroupId "00000000-0000-0000-0000-000000000001"
    Returns the Ids of all user members in the group with the specified Id.

.EXAMPLE
    Get-EntraIdGroupMember -GroupDisplayName "My Security Group"
    Returns the UPNs of all user members in the group with the specified display name.

.NOTES
    This function requires Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Get-EntraIdGroupMember {
    [CmdletBinding(DefaultParameterSetName='ById')]
    param(
        [Parameter(Mandatory, ParameterSetName='ById', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupId,
        [Parameter(Mandatory, ParameterSetName='ByDisplayName', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$GroupDisplayName
    )

    process {
        # Resolve group Id if searching by GroupDisplayName
        if ($PSCmdlet.ParameterSetName -eq 'ByDisplayName') {
            Write-Verbose "Get-EntraIdGroupMember: Searching for group with display name '$GroupDisplayName'"
            $groupParams = @{
                DisplayName = "$GroupDisplayName"
            }
            $group = Get-EntraIdGroup @groupParams
            if (!$group) {
                Write-Warning "No group found with display name '$GroupDisplayName'."
                return $null
            }
            $GroupId = $group.Id
        }

        # Get group members
        $membersParams = @{
            GroupId = $GroupId
            All = $true
            ConsistencyLevel = "eventual"
            CountVariable = "Members"
        }
        $members = Get-MgGroupMember @membersParams
        if (!$members) {
            Write-Warning "No members found for group Id '$GroupId'."
            return $null
        }

        $results = @()
        foreach ($member in $members) {
            # Process user and group objects
            $odataType = $member.AdditionalProperties['@odata.type']
            if ($odataType -eq '#microsoft.graph.user') {
                if ($PSCmdlet.ParameterSetName -eq 'ByDisplayName') {
                    $userParams = @{
                        Id = $member.Id
                    }
                    $user = Get-EntraIdUser @userParams
                    if ($user -and $user.UserPrincipalName) {
                        $results += $user.UserPrincipalName
                    }
                } else {
                    $results += $member.Id
                }
            } elseif ($odataType -eq '#microsoft.graph.group') {
                # For groups, return the group Id or display name as appropriate
                if ($PSCmdlet.ParameterSetName -eq 'ByDisplayName') {
                    $groupObjParams = @{
                        Id = "$($member.Id)"
                    }
                    $groupObj = Get-EntraIdGroup @groupObjParams
                    if ($groupObj -and $groupObj.DisplayName) {
                        $results += $groupObj.DisplayName
                    }
                } else {
                    $results += $member.Id
                }
            } elseif ($odataType -eq '#microsoft.graph.servicePrincipal') {
                # Handle other directory object types (e.g., service principals)
                if ($PSCmdlet.ParameterSetName -eq 'ByDisplayName') {
                    $spnObjParams = @{
                        ServicePrincipalId = $member.Id
                    }
                    $spnObj = Get-EntraIdServicePrincipal @spnObjParams
                    if ($spnObj -and $spnObj.DisplayName) {
                        $results += $spnObj.DisplayName
                    }
                } else {
                    $results += $member.Id
                }
            }
        }
        return $results
    }
}
