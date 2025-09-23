@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'EntraIdDSC.psm1'

    # Version number of this module.

    ModuleVersion = '0.6.3'

    # ID used to uniquely identify this module
    GUID = 'c6cb6bdb-fb65-425b-9579-3d49128a4ebd'

    # Required modules for this module to work
    RequiredModules = @('Microsoft.Graph.Authentication','Microsoft.Graph.Groups','Microsoft.Graph.Users')

    # Author of this module
    Author = 'Remco Vermeer'

    # Company or vendor of this module
    CompanyName = 'Gridly B.V.'

    # Copyright statement for this module
    Copyright = '(c) 2025 Gridly B.V. All rights reserved.'

    PrivateData = @{
    PSData = @{
        Tags = @('Entra', 'EntraId', 'DSC', 'AzureAD', 'Identity', 'Desired', 'State')
        LicenseUri = 'https://opensource.org/licenses/MIT'
        ProjectUri = 'https://github.com/AzureStackNerd/EntraIdDSC/'
        ReleaseNotes = 'Fix tags in module manifest'
    }
}

    # Description of the functionality provided by this module
    Description = 'This module contains functions to maintain EntraId Groups and Users (limited fields) in Desired State.'

    # Functions to export from this module
    FunctionsToExport = @(
        'Get-EntraIdGroup',
        'Get-EntraIdUser',
        'Get-EntraIdServicePrincipal',
        'Get-EntraIdGroupMember',
        'Set-EntraIdGroup',
        'Get-EntraIdGroupOwner',
        'Add-EntraIdGroupMember',
        'Remove-EntraIdGroupMember',
        'Add-EntraIdGroupOwner',
        'Remove-EntraIdGroupOwner',
        'Add-EntraIdUser',
        'Set-EntraIdUser',
        'Invoke-EntraIdGroupDesiredState',
        'Invoke-EntraIdUserDesiredState',
        'Remove-EntraIdGroup'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

}


































