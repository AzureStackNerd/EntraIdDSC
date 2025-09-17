<#!
.SYNOPSIS
    Retrieves an Entra ID (Azure AD) user by their Id or User Principal Name (UPN).

.DESCRIPTION
    This function retrieves an Entra ID user object by their Id or UPN using the Microsoft Graph PowerShell SDK (Get-MgUser). It supports searching by either Id or UPN using parameter sets.

.PARAMETER Id
    The object Id (GUID) of the Entra ID user to retrieve.

.PARAMETER UserPrincipalName
    The User Principal Name (UPN) of the Entra ID user to retrieve.

.EXAMPLE
    Get-EntraIdUser -Id "00000000-0000-0000-0000-000000000001"
    Retrieves the user with the specified Id.

.EXAMPLE
    Get-EntraIdUser -UserPrincipalName "user@contoso.com"
    Retrieves the user with the specified UPN.

.NOTES
    This function requires Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Get-EntraIdUser {
    [CmdletBinding(DefaultParameterSetName='ById')]
    param(
        [Parameter(Mandatory, ParameterSetName='ById', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,
        [Parameter(Mandatory, ParameterSetName='ByUPN', Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$UserPrincipalName
    )

    process {
        Test-GraphAuth
        $properties = @(
            'AboutMe'
            'AccountEnabled'
            'Activities'
            'AgeGroup'
            'AgreementAcceptances'
            'AppRoleAssignments'
            'AssignedLicenses'
            'AssignedPlans'
            'Authentication'
            'AuthorizationInfo'
            'Birthday'
            'BusinessPhones'
            'Calendar'
            'CalendarGroups'
            'CalendarView'
            'Calendars'
            'Chats'
            'City'
            'CloudClipboard'
            'CompanyName'
            'ConsentProvidedForMinor'
            'ContactFolders'
            'Contacts'
            'Country'
            'CreatedDateTime'
            'CreatedObjects'
            'CreationType'
            'CustomSecurityAttributes'
            'DataSecurityAndGovernance'
            'DeletedDateTime'
            'Department'
            'DeviceManagementTroubleshootingEvents'
            'DirectReports'
            'DisplayName'
            'Drive'
            'Drives'
            'EmployeeExperience'
            'EmployeeHireDate'
            'EmployeeId'
            'EmployeeLeaveDateTime'
            'EmployeeOrgData'
            'EmployeeType'
            'Events'
            'Extensions'
            'ExternalUserState'
            'ExternalUserStateChangeDateTime'
            'FaxNumber'
            'FollowedSites'
            'GivenName'
            'HireDate'
            'Id'
            'Identities'
            'ImAddresses'
            'InferenceClassification'
            'Insights'
            'Interests'
            'IsManagementRestricted'
            'IsResourceAccount'
            'JobTitle'
            'JoinedTeams'
            'LastPasswordChangeDateTime'
            'LegalAgeGroupClassification'
            'LicenseAssignmentStates'
            'LicenseDetails'
            'Mail'
            'MailFolders'
            'MailNickname'
            'ManagedAppRegistrations'
            'ManagedDevices'
            'Manager'
            'MemberOf'
            'Messages'
            'MobilePhone'
            'MySite'
            'Oauth2PermissionGrants'
            'OfficeLocation'
            'OnPremisesDistinguishedName'
            'OnPremisesDomainName'
            'OnPremisesExtensionAttributes'
            'OnPremisesImmutableId'
            'OnPremisesLastSyncDateTime'
            'OnPremisesProvisioningErrors'
            'OnPremisesSamAccountName'
            'OnPremisesSecurityIdentifier'
            'OnPremisesSyncEnabled'
            'OnPremisesUserPrincipalName'
            'Onenote'
            'OnlineMeetings'
            'OtherMails'
            'Outlook'
            'OwnedDevices'
            'OwnedObjects'
            'PasswordPolicies'
            'PasswordProfile'
            'PastProjects'
            'People'
            'PermissionGrants'
            'Photo'
            'Photos'
            'Planner'
            'PostalCode'
            'PreferredDataLocation'
            'PreferredLanguage'
            'PreferredName'
            'Presence'
            'ProvisionedPlans'
            'ProxyAddresses'
            'RegisteredDevices'
            'Responsibilities'
            'Schools'
            'ScopedRoleMemberOf'
            'SecurityIdentifier'
            'ServiceProvisioningErrors'
            'Settings'
            'ShowInAddressList'
            'SignInSessionsValidFromDateTime'
            'Skills'
            'Solutions'
            'Sponsors'
            'State'
            'StreetAddress'
            'Surname'
            'Teamwork'
            'Todo'
            'TransitiveMemberOf'
            'UsageLocation'
            'UserPrincipalName'
            'UserType'
        )

        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                # Query Microsoft Graph for the user by Id
                $getUserParams = @{
                    UserId = $Id
                    Property = $properties
                    ErrorAction = 'SilentlyContinue'
                }
                $user = Get-MgUser @getUserParams
                if (-not $user) {
                    Write-Verbose "No user found with Id '$Id'."
                    return $null
                }
                return $user
            }
            'ByUPN' {
                # Query Microsoft Graph for the user by UPN
                $getUserParams = @{
                    UserId = $UserPrincipalName
                    Property = $properties
                    ErrorAction = 'SilentlyContinue'
                }
                $user = Get-MgUser @getUserParams
                if (-not $user) {
                    Write-Verbose "No user found with UPN '$UserPrincipalName'."
                    return $null
                }
                return $user
            }
        }
    }
}
