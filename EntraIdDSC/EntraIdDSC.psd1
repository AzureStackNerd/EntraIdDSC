@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'EntraIdDSC.psm1'

    # Version number of this module.

    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'c6cb6bdb-fb65-425b-9579-3d49128a4ebd'

    # Required modules for this module to work
    # The following modules are required for EntraIdDSC to function correctly.
    # Please install them manually before using this module, as dependencies are not automatically enforced.
    # Required dependencies (minimum versions):
    #   - Microsoft.Graph.Authentication (>=1.26.0): Provides authentication capabilities for Microsoft Graph.
    #   - Microsoft.Graph.Groups (>=1.26.0): Enables management of Microsoft 365 groups via Microsoft Graph.
    #   - Microsoft.Graph.Users (>=1.26.0): Enables management of users via Microsoft Graph.
    # You can install these modules using:
    #   Install-Module Microsoft.Graph.Authentication -MinimumVersion 1.26.0
    #   Install-Module Microsoft.Graph.Groups -MinimumVersion 1.26.0
    #   Install-Module Microsoft.Graph.Users -MinimumVersion 1.26.0

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
    Description = 'This module contains functions to maintain EntraId Groups and Users in Desired State.'

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




































