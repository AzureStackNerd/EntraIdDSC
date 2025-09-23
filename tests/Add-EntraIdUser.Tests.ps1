# Pester tests for Add-EntraIdUser
# Purpose: Validate Add-EntraIdUser logic, input handling, and edge cases

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Add-EntraIdUser' {
        BeforeAll {
            # Mock external dependencies
            Mock -CommandName Test-GraphAuth -MockWith { $true }
            Mock -CommandName New-MgUser -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; UserPrincipalName = 'user@test.com' } }
        }

        Context 'Valid input scenarios' {
            It 'Creates a user with valid parameters' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                    AdditionalProperties = @{ GivenName = 'Test'; Surname = 'User' }
                }
                $result = Add-EntraIdUser @params
                $result | Should -Not -BeNullOrEmpty
                $result.UserPrincipalName | Should -Be 'user@test.com'
            }
        }

        Context 'Invalid input scenarios' {
            It 'Throws when UserPrincipalName is missing' {
                $params = @{
                    DisplayName = 'Test User'
                    AdditionalProperties = @{ GivenName = 'Test'; Surname = 'User' }
                }
                { Add-EntraIdUser @params } | Should -Throw
            }
            It 'Throws when DisplayName is missing' {
                $params = @{
                    UserPrincipalName = 'user@test.com'
                    AdditionalProperties = @{ GivenName = 'Test'; Surname = 'User' }
                }
                { Add-EntraIdUser @params } | Should -Throw
            }
        }

        Context 'Edge cases' {
            It 'Handles empty AdditionalProperties' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                    AdditionalProperties = @{}
                }
                $result = Add-EntraIdUser @params
                $result | Should -Not -BeNullOrEmpty
            }
            It 'Handles minimal valid input' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                }
                $result = Add-EntraIdUser @params
                $result | Should -Not -BeNullOrEmpty
            }
        }

        # CodeCoverage: Ensure Add-EntraIdUser is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
