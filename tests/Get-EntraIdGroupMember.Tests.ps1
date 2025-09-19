# Pester tests for Get-EntraIdGroupMember
# Follows Pester best practices: structure, assertions, mocks

Import-Module "$PSScriptRoot/../EntraIdDSC/"

InModuleScope EntraIdDSC {
    Describe 'Get-EntraIdGroupMember' {
        BeforeAll {
            # Mock external dependencies
            Mock -CommandName Get-ObjectType -MockWith { return 'User' }
            Mock -CommandName Test-GraphAuth -MockWith { return $true }
            Mock -CommandName Get-MgGroup -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' } } -ParameterFilter { $Filter -eq "displayName eq 'TestGroup'" }
            Mock -CommandName Get-EntraIdGroup -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' } }
            Mock -CommandName Get-EntraIdUser -MockWith { return @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user@test.com' } }
            Mock -CommandName Get-MgGroupMember -MockWith { return @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user@test.com'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } } } -ParameterFilter { $GroupId -eq '11111111-1111-1111-1111-111111111111' -and $All }
        }

        Context 'Valid input scenarios' {
            It 'Returns group members for valid group Id' {
                $result = Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Not -BeNullOrEmpty
            }
            It 'Returns group members for valid group object' {
                $result = Get-EntraIdGroupMember -GroupDisplayName 'TestGroup'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -Be 'user@test.com'

            }
        }

        Context 'Invalid input scenarios' {
            It 'Throws on invalid GroupId' {
                Mock -CommandName Get-EntraIdGroup -MockWith { return $null }
                { Get-EntraIdGroupMember -GroupId } | Should -Throw
            }
        }

    }
}

