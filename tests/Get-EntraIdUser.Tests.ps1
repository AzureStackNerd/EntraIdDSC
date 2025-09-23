# Pester tests for Get-EntraIdUser
# Purpose: Validate Get-EntraIdUser logic, input handling, and edge cases

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Get-EntraIdUser' {
        BeforeAll {
            # Mock external dependencies
            Mock -CommandName Test-GraphAuth -MockWith { $true }
            Mock -CommandName Get-MgUser -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; UserPrincipalName = 'user@test.com'; DisplayName = 'Test User' } } -ParameterFilter { $UserPrincipalName -eq 'user@test.com' }
        }

        Context 'Valid input scenarios' {
            It 'Returns user for valid UserPrincipalName' {
                $result = Get-EntraIdUser -UserPrincipalName 'user@test.com'
                $result | Should -Not -BeNullOrEmpty
                $result.UserPrincipalName | Should -Be 'user@test.com'
            }
        }

        Context 'Invalid input scenarios' {
            It 'Throws when UserPrincipalName is missing' {
                { Get-EntraIdUser } | Should -Throw
            }
            It 'Writes a warning when user does not exist' {
                Mock -CommandName Get-MgUser -MockWith { return $null } -ParameterFilter { $UserPrincipalName -eq 'notfound@test.com' }
                $null = Get-EntraIdUser -UserPrincipalName 'notfound@test.com' -WarningVariable warn
                $warn | Should -Match '^No user found'
            }
        }

        Context 'Edge cases' {
            It 'Handles empty result from Get-MgUser' {
                Mock -CommandName Get-MgUser -MockWith { return @() } -ParameterFilter { $UserPrincipalName -eq 'empty@test.com' }
                $result = Get-EntraIdUser -UserPrincipalName 'empty@test.com'
                $result | Should -Be @($true, $null)
            }
        }

        # CodeCoverage: Ensure Get-EntraIdUser is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
