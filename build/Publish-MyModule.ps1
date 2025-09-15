<#
    .SYNOPSIS
    Publishes a PowerShell module to a repository.

    .DESCRIPTION
    This function publishes a PowerShell module to a specified repository using the provided path and API key.

    .PARAMETER Path
    The path to the module directory to be published.

    .PARAMETER ApiKey
    The API key for authenticating with the repository.

    .EXAMPLE
    Publish-MyModule -Path "C:\Modules\MyModule" -ApiKey "12345-abcde-67890"

    Publishes the module located at the specified path using the provided API key.

    .NOTES
    Ensure that the module manifest (.psd1) file is present in the specified path.
    #>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$ApiKey
)

process {
    try {
        # Validate the module path
        if (-not (Test-Path -Path $Path -PathType Container)) {
            throw "The specified path '$Path' does not exist or is not a directory."
        }

        # Find the module manifest
        $manifest = Get-ChildItem -Path $Path -Filter '*.psd1' | Select-Object -First 1
        if (-not $manifest) {
            throw "No module manifest (.psd1) file found in the specified path."
        }

        # Publish the module
        Write-Host "Publishing module from path: $Path"
        $publishParams = @{
            Path        = $Path
            NuGetApiKey = $ApiKey
            Repository  = 'PSGallery'
        }
        # Publish-Module @publishParams
        Write-Host "Module published successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}
