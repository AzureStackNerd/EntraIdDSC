<#
    .SYNOPSIS
    Bumps the version in the PowerShell module manifest (.psd1).

    .DESCRIPTION
    This function increments the version number in the module manifest (.psd1) file according to semantic versioning.

    .PARAMETER Path
    The path to the module directory containing the manifest.

    .PARAMETER IncrementVersion
    Which part of the version to increment: Major, Minor, or Patch.

    .EXAMPLE
    Set-Version -Path "C:\Modules\MyModule" -IncrementVersion Minor

    Increments the minor version in the manifest file.

    .NOTES
    Ensure that the module manifest (.psd1) file is present in the specified path.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Major', 'Minor', 'Patch')]
    [string]$IncrementVersion = 'Minor',

    [Parameter(Mandatory = $false)]
    [string]$Repo = 'AzureStackNerd/EntraIdDSC'
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

        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
        $latestVersion = $latestRelease.tag_name
        $version = $latestVersion.TrimStart('v')
        Write-Host "Latest release version: $latestVersion"


        # Increment version based on IncrementVersion parameter (semver: major.minor.patch)
        $versionParts = $version -split '\.'
        if ($versionParts.Count -lt 2) {
            throw "ModuleVersion format is invalid: $version"
        }
        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]
        $patch = if ($versionParts.Count -gt 2) { [int]$versionParts[2] } else { 0 }

        switch ($IncrementVersion) {
            'Major' {
                $major++
                $minor = 0
                $patch = 0
            }
            'Minor' {
                $minor++
                $patch = 0
            }
            'Patch' {
                $patch++
            }
        }
        $newVersion = "$major.$minor.$patch"

        $manifestObject = Import-PowerShellDataFile -Path $manifest.FullName
        $manifestObject.ModuleVersion = $newVersion

        # Write the updated manifest back to the file
        $manifestContent = Get-Content -Path $manifest.FullName -Raw
        $manifestContent = $manifestContent -replace "ModuleVersion\s*=\s*'[^']+'", "ModuleVersion = '$newVersion'"
        Set-Content -Path $manifest.FullName -Value $manifestContent
        Write-Host "Version updated to $newVersion"
        Add-Content -Path $env:GITHUB_ENV -Value "MODULE_VERSION=$newVersion"
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}
