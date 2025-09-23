# Pester tests for Remove-EntraIdGroup
# Purpose: Validate Remove-EntraIdGroup function for valid, invalid, and edge cases
# Mocks all external dependencies and ensures idempotency

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

Describe 'Remove-EntraIdGroup' {
    InModuleScope EntraIdDSC {
        Context 'Valid input' {
            It 'Removes group with valid Id' {
                Mock -CommandName Remove-MgGroup -MockWith { $true } -ParameterFilter { $Id -eq '11111111-1111-1111-1111-111111111111' }
                $result = Remove-EntraIdGroup -Id '11111111-1111-1111-1111-111111111111' -Confirm:$false
                $result | Should -Be $true
            }
            It 'Removes group with valid DisplayName' {
                Mock -CommandName Get-MgGroup -MockWith { @{ Id = '44444444-4444-4444-4444-444444444444' } } -ParameterFilter { $Filter -eq "displayName eq 'TestGroup'" }
                Mock -CommandName Remove-MgGroup -MockWith { $true } -ParameterFilter { $GroupId -eq '44444444-4444-4444-4444-444444444444' }
                $result = Remove-EntraIdGroup -DisplayName 'TestGroup' -Confirm:$false
                $result | Should -Be $true
            }
        }

        Context 'Invalid input' {
            It 'Throws error for missing Id' {
                { Remove-EntraIdGroup -Id $null -Confirm:$false } | Should -Throw
            }
            It 'Throws error for missing DisplayName' {
                { Remove-EntraIdGroup -DisplayName $null -Confirm:$false } | Should -Throw
            }
        }

        Context 'Edge cases' {
            It 'Handles non-existent group Id gracefully' {
                Mock -CommandName Remove-MgGroup -MockWith { $null } -ParameterFilter { $Id -eq '22222222-2222-2222-2222-222222222222' }
                $result = Remove-EntraIdGroup -Id '22222222-2222-2222-2222-222222222222' -Confirm:$false
                $result | Should -BeNullOrEmpty
            }
            It 'Handles already deleted group Id' {
                Mock -CommandName Remove-MgGroup -MockWith { $null } -ParameterFilter { $Id -eq '33333333-3333-3333-3333-333333333333' }
                $result = Remove-EntraIdGroup -Id '33333333-3333-3333-3333-333333333333' -Confirm:$false
                $result | Should -BeNullOrEmpty
            }
            It 'Throws error for non-existent DisplayName' {
                Mock -CommandName Get-MgGroup -MockWith { $null } -ParameterFilter { $Filter -eq "displayName eq 'MissingGroup'" }
                { Remove-EntraIdGroup -DisplayName 'MissingGroup' -Confirm:$true} | Should -Throw
            }
        }

        # CodeCoverage: Ensure Remove-EntraIdGroup is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
