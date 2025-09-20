# Pester tests for Get-EntraIdServicePrincipal
# Follows Pester best practices: structure, assertions, mocks

InModuleScope EntraIdDSC {
    BeforeAll {
        Import-Module "$PSScriptRoot/../EntraIdDSC/"
    }
    Describe 'Get-EntraIdServicePrincipal' {
        BeforeAll {
            # Mock external dependencies
            Mock -CommandName Get-ObjectType -MockWith { return 'ServicePrincipal' }
            Mock -CommandName Test-GraphAuth -MockWith { return $true }
            Mock -CommandName Get-MgServicePrincipal -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestSP' } } -ParameterFilter { $Filter -eq "displayName eq 'TestSP'" -or $Filter -eq "appId eq '11111111-1111-1111-1111-111111111111'" }
            Mock -CommandName Get-EntraIdServicePrincipal -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestSP' } }
        }

        Context 'Valid input scenarios' {
            It 'Returns service principal for valid ServicePrincipalId' {
                $result = Get-EntraIdServicePrincipal -ServicePrincipalId '11111111-1111-1111-1111-111111111111'
                $result | Should -Not -BeNullOrEmpty
                $result.Id | Should -Be '11111111-1111-1111-1111-111111111111'
            }
            It 'Returns service principal for valid display name' {
                $result = Get-EntraIdServicePrincipal -DisplayName 'TestSP'
                $result | Should -Not -BeNullOrEmpty
                $result.DisplayName | Should -Be 'TestSP'
            }
        }

        Context 'Invalid input scenarios' {
            It 'Throws on invalid ServicePrincipalId' {
                Mock -CommandName Get-MgServicePrincipal -MockWith { return $null } -ParameterFilter { $Filter -eq "appId eq 'invalid-id'" }
                { Get-EntraIdServicePrincipal -ServicePrincipalId '' } | Should -Throw
            }
            It 'Throws on invalid display name' {
                Mock -CommandName Get-MgServicePrincipal -MockWith { return $null } -ParameterFilter { $Filter -eq "displayName eq 'InvalidSP'" }
                { Get-EntraIdServicePrincipal -DisplayName '' } | Should -Throw
            }
        }
    }
}
