
Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe "Get-EntraIdGroup" {
        Context "ByDisplayName parameter set" {
            It "Returns group when display name exists" {
                Mock Get-MgGroup { @{DisplayName = 'TestGroup' } }
                $result = Get-EntraIdGroup -DisplayName "TestGroup"
                $result.DisplayName | Should -Be "TestGroup"
            }
            It "Returns null when display name does not exist" {
                Mock Get-MgGroup { $null }
                $result = Get-EntraIdGroup -DisplayName "NonExistent"
                $result | Should -Be $null
            }
        }

        Context "ById parameter set" {
            It "Returns group when Id exists" {
                Mock Get-MgGroup { @{Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroupById' } }
                $result = Get-EntraIdGroup -Id "11111111-1111-1111-1111-111111111111"
                $result.Id | Should -eq "11111111-1111-1111-1111-111111111111"
            }
            It "Returns group with correct DisplayName when called by Id" {
                Mock Get-MgGroup { @{Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroupById' } }
                $result = Get-EntraIdGroup -Id "11111111-1111-1111-1111-111111111111"
                $result.DisplayName | Should -eq "TestGroupById"
            }
            It "Returns null when Id does not exist" {
                Mock Get-MgGroup { $null }
                $result = Get-EntraIdGroup -Id "22222222-2222-2222-2222-222222222222"
                $result | Should -Be $null
            }
        }

        Context "ByDisplayNamePattern parameter set" {
            It "Returns groups matching pattern" {
                Mock Get-MgGroup -ParameterFilter { $true } {
                    @(
                        @{DisplayName = 'UG-PIM-Alpha' },
                        @{DisplayName = 'UG-PIM-Beta' },
                        @{DisplayName = 'OtherGroup' }
                    )
                }
                $result = Get-EntraIdGroup -DisplayNamePattern "UG-PIM-*"
                ($result | Where-Object { $_.DisplayName -eq 'UG-PIM-Alpha' }).Count | Should -gt 0
                ($result | Where-Object { $_.DisplayName -eq 'UG-PIM-Beta' }).Count | Should -gt 0
            }
            It "Returns null when no groups match pattern" {
                Mock Get-MgGroup -ParameterFilter { $true } {
                    @(@{DisplayName = 'OtherGroup' })
                }
                $result = Get-EntraIdGroup -DisplayNamePattern "UG-PIM-*"
                $result | Should -Be $null
            }
        }
    }
}
