# Pester tests for Get-EntraIdServicePrincipal
# Follows Pester best practices: structure, assertions, mocks
Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    BeforeAll {
        Mock Test-GraphAuth { }
    }
    Describe 'Get-EntraIdServicePrincipal' {
        BeforeAll {
            # Mock external dependencies with generic fallbacks
            Mock -CommandName Get-MgServicePrincipal -MockWith {
                return @{
                    Id = '11111111-1111-1111-1111-111111111111'
                    DisplayName = 'TestSP'
                    AppId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                }
            }
        }

        Context 'ByDisplayName parameter set' {
            It 'Returns service principal when display name exists' {
                Mock Get-MgServicePrincipal {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestServicePrincipal'
                        AppId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                    }
                }
                $result = Get-EntraIdServicePrincipal -DisplayName 'TestServicePrincipal'
                $result.DisplayName | Should -Be 'TestServicePrincipal'
            }

            It 'Returns null when display name does not exist' {
                Mock Get-MgServicePrincipal { $null }
                $result = Get-EntraIdServicePrincipal -DisplayName 'NonExistentSP'
                $result | Should -Be $null
            }

            It 'Uses correct filter parameter with displayName eq operator' {
                Mock Get-MgServicePrincipal {
                    @{ DisplayName = 'TestServicePrincipal' }
                }
                Get-EntraIdServicePrincipal -DisplayName 'TestServicePrincipal'
                Should -Invoke -CommandName Get-MgServicePrincipal -Times 1 -Exactly -ParameterFilter {
                    $Filter -eq "displayName eq 'TestServicePrincipal'"
                }
            }

            It 'Returns first service principal when Get-MgServicePrincipal returns array' {
                Mock Get-MgServicePrincipal {
                    @(
                        @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestSP' },
                        @{ Id = '22222222-2222-2222-2222-222222222222'; DisplayName = 'TestSP' }
                    )
                }
                $result = Get-EntraIdServicePrincipal -DisplayName 'TestSP'
                $result.Id | Should -Be '11111111-1111-1111-1111-111111111111'
            }

            It 'Handles display names with special characters' {
                Mock Get-MgServicePrincipal {
                    @{ DisplayName = 'Test-SP_123 (Special)' }
                }
                $result = Get-EntraIdServicePrincipal -DisplayName 'Test-SP_123 (Special)'
                $result.DisplayName | Should -Be 'Test-SP_123 (Special)'
            }

            It 'Handles display names with single quotes' {
                Mock Get-MgServicePrincipal {
                    @{ DisplayName = "Test'SP" }
                }
                $result = Get-EntraIdServicePrincipal -DisplayName "Test'SP"
                $result.DisplayName | Should -Be "Test'SP"
            }

            It 'Writes verbose message when service principal not found' {
                Mock Get-MgServicePrincipal { $null }
                $verboseOutput = Get-EntraIdServicePrincipal -DisplayName 'NonExistent' -Verbose 4>&1
                $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | Should -Match "No Service Principal found with display name 'NonExistent'"
            }
        }

        Context 'ByServicePrincipalId parameter set' {
            It 'Returns service principal when ServicePrincipalId exists' {
                Mock Get-MgServicePrincipal {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestSPById'
                        AppId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                    }
                }
                $result = Get-EntraIdServicePrincipal -ServicePrincipalId '11111111-1111-1111-1111-111111111111'
                $result.Id | Should -Be '11111111-1111-1111-1111-111111111111'
            }

            It 'Returns service principal with correct DisplayName when called by ServicePrincipalId' {
                Mock Get-MgServicePrincipal {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestSPById'
                    }
                }
                $result = Get-EntraIdServicePrincipal -ServicePrincipalId '11111111-1111-1111-1111-111111111111'
                $result.DisplayName | Should -Be 'TestSPById'
            }

            It 'Returns null when ServicePrincipalId does not exist' {
                Mock Get-MgServicePrincipal { $null }
                $result = Get-EntraIdServicePrincipal -ServicePrincipalId '22222222-2222-2222-2222-222222222222'
                $result | Should -Be $null
            }

            It 'Uses correct ServicePrincipalId parameter' {
                Mock Get-MgServicePrincipal {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestSP'
                    }
                }
                Get-EntraIdServicePrincipal -ServicePrincipalId '11111111-1111-1111-1111-111111111111'
                Should -Invoke -CommandName Get-MgServicePrincipal -Times 1 -Exactly -ParameterFilter {
                    $ServicePrincipalId -eq '11111111-1111-1111-1111-111111111111'
                }
            }

            It 'Writes verbose message when service principal not found by ServicePrincipalId' {
                Mock Get-MgServicePrincipal { $null }
                $verboseOutput = Get-EntraIdServicePrincipal -ServicePrincipalId '22222222-2222-2222-2222-222222222222' -Verbose 4>&1
                $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | Select-Object -Last 1 | Should -Match "No Service Principal found with ServicePrincipalId '22222222-2222-2222-2222-222222222222'"
            }

            It 'Handles uppercase GUID' {
                Mock Get-MgServicePrincipal {
                    @{
                        Id = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
                        DisplayName = 'TestSP'
                    }
                }
                $result = Get-EntraIdServicePrincipal -ServicePrincipalId 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
                $result.Id | Should -Be 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
            }
        }

        Context 'Error handling' {
            It 'Throws when Test-GraphAuth fails' {
                Mock Test-GraphAuth { throw 'Not authenticated' }
                { Get-EntraIdServicePrincipal -DisplayName 'TestSP' } | Should -Throw '*Not authenticated*'
            }

            It 'Throws when Get-MgServicePrincipal fails for DisplayName search' {
                Mock Get-MgServicePrincipal { throw 'Graph API Error' }
                { Get-EntraIdServicePrincipal -DisplayName 'TestSP' } | Should -Throw '*Graph API Error*'
            }

            It 'Throws when Get-MgServicePrincipal fails for ServicePrincipalId search' {
                Mock Get-MgServicePrincipal { throw 'Service principal not found' }
                { Get-EntraIdServicePrincipal -ServicePrincipalId '11111111-1111-1111-1111-111111111111' } | Should -Throw '*Service principal not found*'
            }
        }

        Context 'Parameter validation' {
            It 'DisplayName parameter is mandatory in its parameter set' {
                $param = (Get-Command Get-EntraIdServicePrincipal).Parameters['DisplayName']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByDisplayName'}).Mandatory | Should -Be $true
            }

            It 'ServicePrincipalId parameter is mandatory in its parameter set' {
                $param = (Get-Command Get-EntraIdServicePrincipal).Parameters['ServicePrincipalId']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByServicePrincipalId'}).Mandatory | Should -Be $true
            }
        }

        Context 'Pipeline input' {
            It 'Accepts DisplayName from pipeline' {
                Mock Get-MgServicePrincipal {
                    @{ DisplayName = 'PipelineSP' }
                }
                $result = 'PipelineSP' | Get-EntraIdServicePrincipal
                $result.DisplayName | Should -Be 'PipelineSP'
            }

            It 'Accepts ServicePrincipalId from pipeline' {
                Mock Get-MgServicePrincipal {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'PipelineSP'
                    }
                }
                $result = '11111111-1111-1111-1111-111111111111' | Get-EntraIdServicePrincipal -ServicePrincipalId { $_ }
                $result.DisplayName | Should -Be 'PipelineSP'
            }

            It 'Accepts object with DisplayName property from pipeline' {
                Mock Get-MgServicePrincipal {
                    @{ DisplayName = 'ObjectSP' }
                }
                $inputObject = [PSCustomObject]@{ DisplayName = 'ObjectSP' }
                $result = $inputObject | Get-EntraIdServicePrincipal
                $result.DisplayName | Should -Be 'ObjectSP'
            }
        }

        Context 'Edge cases' {
            It 'Handles empty string DisplayName' {
                # Empty strings are not allowed by PowerShell parameter validation
                { Get-EntraIdServicePrincipal -DisplayName '' } | Should -Throw '*Cannot bind argument to parameter*'
            }

            It 'Handles whitespace-only DisplayName' {
                Mock Get-MgServicePrincipal { $null }
                Get-EntraIdServicePrincipal -DisplayName '   '
                Should -Invoke -CommandName Get-MgServicePrincipal -Times 1 -Exactly -ParameterFilter {
                    $Filter -eq "displayName eq '   '"
                }
            }

            It 'Handles DisplayName with leading/trailing spaces' {
                Mock Get-MgServicePrincipal {
                    @{ DisplayName = ' TestSP ' }
                }
                $result = Get-EntraIdServicePrincipal -DisplayName ' TestSP '
                $result.DisplayName | Should -Be ' TestSP '
            }

            It 'Returns complete service principal object with all properties' {
                Mock Get-MgServicePrincipal {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'CompleteSP'
                        AppId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                        ServicePrincipalType = 'Application'
                        AccountEnabled = $true
                    }
                }
                $result = Get-EntraIdServicePrincipal -DisplayName 'CompleteSP'
                $result.Id | Should -Be '11111111-1111-1111-1111-111111111111'
                $result.AppId | Should -Be 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                $result.ServicePrincipalType | Should -Be 'Application'
                $result.AccountEnabled | Should -Be $true
            }

            It 'Handles service principal with null or missing properties gracefully' {
                Mock Get-MgServicePrincipal {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'MinimalSP'
                    }
                }
                $result = Get-EntraIdServicePrincipal -DisplayName 'MinimalSP'
                $result.Id | Should -Be '11111111-1111-1111-1111-111111111111'
                $result.DisplayName | Should -Be 'MinimalSP'
            }
        }
    }
}
