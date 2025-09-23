# Pester tests for Get-EntraIdGroupOwner
# Follows Pester best practices: structure, assertions, mocks
Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Get-EntraIdGroupOwner' {
        BeforeAll {
            # Mock external dependencies
            Mock -CommandName Get-ObjectType -MockWith { return 'User' }
            Mock -CommandName Test-GraphAuth -MockWith { return $true }
            Mock -CommandName Get-MgGroup -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' } } -ParameterFilter { $Filter -eq "displayName eq 'TestGroup'" }
            Mock -CommandName Get-EntraIdGroup -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' } }
            Mock -CommandName Get-EntraIdUser -MockWith { return @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner@test.com' } }
            Mock -CommandName Get-MgGroupOwner -MockWith { return @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner@test.com'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } } } -ParameterFilter { $GroupId -eq '11111111-1111-1111-1111-111111111111' -and $All }
        }

        Context 'Valid input scenarios' {
            It 'Returns group owners for valid group Id' {
                $result = Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Not -BeNullOrEmpty
            }
            It 'Returns group owners for valid group object' {
                $result = Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -Be 'owner@test.com'
            }
        }

        Context 'Invalid input scenarios' {
            It 'Throws on invalid GroupId' {
                Mock -CommandName Get-EntraIdGroup -MockWith { return $null }
                { Get-EntraIdGroupOwner -GroupId '' } | Should -Throw
            }
        }


    }
}
