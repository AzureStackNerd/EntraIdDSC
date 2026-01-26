# Pester tests for Get-EntraIdGroupOwner
# Follows Pester best practices: structure, assertions, mocks
Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Get-EntraIdGroupOwner' {
        BeforeAll {
            # Mock external dependencies with generic fallbacks
            Mock -CommandName Get-ObjectType -MockWith { return 'User' }
            Mock -CommandName Test-GraphAuth -MockWith { return $true }
            Mock -CommandName Get-MgGroup -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' } }
            Mock -CommandName Get-EntraIdGroup -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' } }
            Mock -CommandName Get-EntraIdUser -MockWith { return @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner@test.com' } }
            Mock -CommandName Get-MgGroupOwner -MockWith { return @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner@test.com'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } } }
            Mock -CommandName Get-EntraIdServicePrincipal -MockWith { return @{ Id = '33333333-3333-3333-3333-333333333333'; DisplayName = 'TestServicePrincipal' } }
            Mock -CommandName Write-Warning -MockWith { }
        }

        Context 'Valid input scenarios - ById parameter set' {
            It 'Returns group owners for valid group Id' {
                $result = Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Returns owner Ids when using GroupId parameter' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = '22222222-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                $result = Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Be '22222222-2222-2222-2222-222222222222'
            }

            It 'Uses correct parameters for Get-MgGroupOwner' {
                Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111'
                Should -Invoke -CommandName Get-MgGroupOwner -Times 1 -Exactly -ParameterFilter {
                    $GroupId -eq '11111111-1111-1111-1111-111111111111' -and
                    $All -eq $true -and
                    $ConsistencyLevel -eq 'eventual'
                }
            }
        }

        Context 'Valid input scenarios - ByDisplayName parameter set' {
            It 'Returns group owners for valid group DisplayName' {
                $result = Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -Be 'owner@test.com'
            }

            It 'Resolves group Id from DisplayName before getting owners' {
                Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup'
                Should -Invoke -CommandName Get-EntraIdGroup -Times 1 -Exactly -ParameterFilter {
                    $DisplayName -eq 'TestGroup'
                }
            }

            It 'Returns UPNs when using GroupDisplayName parameter' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = '22222222-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                Mock -CommandName Get-EntraIdUser -MockWith {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner@test.com' }
                }
                $result = Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup'
                $result | Should -Be 'owner@test.com'
            }

            It 'Writes verbose message when searching for group by DisplayName' {
                $verboseOutput = Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup' -Verbose 4>&1
                $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | Should -Match "Searching for group with display name 'TestGroup'"
            }
        }

        Context 'Owner type handling - User owners' {
            It 'Returns user Ids when using GroupId parameter' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } },
                        @{ Id = 'user-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                $result = Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111'
                $result.Count | Should -Be 2
                $result[0] | Should -Be 'user-1111-1111-1111-111111111111'
                $result[1] | Should -Be 'user-2222-2222-2222-222222222222'
            }

            It 'Returns user UPNs when using GroupDisplayName parameter' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } },
                        @{ Id = 'user-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                Mock -CommandName Get-EntraIdUser -MockWith {
                    param($Id)
                    if ($Id -eq 'user-1111-1111-1111-111111111111') {
                        return @{ Id = $Id; UserPrincipalName = 'owner1@test.com' }
                    } else {
                        return @{ Id = $Id; UserPrincipalName = 'owner2@test.com' }
                    }
                }
                $result = Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup'
                $result.Count | Should -Be 2
                $result[0] | Should -Be 'owner1@test.com'
                $result[1] | Should -Be 'owner2@test.com'
            }
        }

        Context 'Owner type handling - Group owners' {
            It 'Returns group Ids when group has group owners (ById)' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'group-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.group' } }
                    )
                }
                $result = Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Be 'group-1111-1111-1111-111111111111'
            }

            It 'Returns group DisplayNames when group has group owners (ByDisplayName)' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'group-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.group' } }
                    )
                }
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    param($Id, $DisplayName)
                    if ($Id) {
                        return @{ Id = $Id; DisplayName = 'OwnerGroup' }
                    } else {
                        return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = $DisplayName }
                    }
                }
                $result = Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup'
                $result | Should -Be 'OwnerGroup'
            }
        }

        Context 'Owner type handling - Service Principal owners' {
            It 'Returns service principal Ids when group has SP owners (ById)' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'sp-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.servicePrincipal' } }
                    )
                }
                $result = Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Be 'sp-1111-1111-1111-111111111111'
            }

            It 'Returns service principal DisplayNames when group has SP owners (ByDisplayName)' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'sp-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.servicePrincipal' } }
                    )
                }
                Mock -CommandName Get-EntraIdServicePrincipal -MockWith {
                    @{ Id = 'sp-1111-1111-1111-111111111111'; DisplayName = 'MyServicePrincipal' }
                }
                $result = Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup'
                $result | Should -Be 'MyServicePrincipal'
            }
        }

        Context 'Owner type handling - Mixed owner types' {
            It 'Returns mixed owner Ids when using GroupId' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } },
                        @{ Id = 'group-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.group' } },
                        @{ Id = 'sp-3333-3333-3333-333333333333'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.servicePrincipal' } }
                    )
                }
                $result = Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111'
                $result.Count | Should -Be 3
                $result[0] | Should -Be 'user-1111-1111-1111-111111111111'
                $result[1] | Should -Be 'group-2222-2222-2222-222222222222'
                $result[2] | Should -Be 'sp-3333-3333-3333-333333333333'
            }

            It 'Returns mixed owner names when using GroupDisplayName' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } },
                        @{ Id = 'group-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.group' } },
                        @{ Id = 'sp-3333-3333-3333-333333333333'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.servicePrincipal' } }
                    )
                }
                Mock -CommandName Get-EntraIdUser -MockWith {
                    @{ UserPrincipalName = 'owner@test.com' }
                }
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    param($Id, $DisplayName)
                    if ($Id) {
                        return @{ DisplayName = 'OwnerGroup' }
                    } else {
                        return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = $DisplayName }
                    }
                }
                Mock -CommandName Get-EntraIdServicePrincipal -MockWith {
                    @{ DisplayName = 'MyServicePrincipal' }
                }
                $result = Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup'
                $result.Count | Should -Be 3
                $result[0] | Should -Be 'owner@test.com'
                $result[1] | Should -Be 'OwnerGroup'
                $result[2] | Should -Be 'MyServicePrincipal'
            }
        }

        Context 'Invalid input scenarios' {
            It 'Returns null when group does not exist (ByDisplayName)' {
                Mock -CommandName Get-EntraIdGroup -MockWith { $null }
                $result = Get-EntraIdGroupOwner -GroupDisplayName 'NonExistentGroup'
                $result | Should -Be $null
            }

            It 'Writes warning when group does not exist (ByDisplayName)' {
                Mock -CommandName Get-EntraIdGroup -MockWith { $null }
                Get-EntraIdGroupOwner -GroupDisplayName 'NonExistentGroup'
                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -like "*No group found with display name 'NonExistentGroup'*"
                }
            }

            It 'Returns null when group has no owners' {
                Mock -CommandName Get-MgGroupOwner -MockWith { $null }
                $result = Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Be $null
            }

            It 'Writes warning when group has no owners' {
                Mock -CommandName Get-MgGroupOwner -MockWith { $null }
                Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111'
                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -like "*No owners found for group Id '11111111-1111-1111-1111-111111111111'*"
                }
            }

            It 'Throws on invalid GroupId (empty string)' {
                Mock -CommandName Get-EntraIdGroup -MockWith { return $null }
                { Get-EntraIdGroupOwner -GroupId '' } | Should -Throw
            }
        }

        Context 'Edge cases' {
            It 'Handles empty owner list' {
                Mock -CommandName Get-MgGroupOwner -MockWith { @() }
                $result = Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Be $null
            }

            It 'Skips users without UPN when using GroupDisplayName' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                Mock -CommandName Get-EntraIdUser -MockWith {
                    @{ Id = 'user-1111-1111-1111-111111111111' }  # No UserPrincipalName
                }
                $result = Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup'
                $result | Should -BeNullOrEmpty
            }

            It 'Skips users that cannot be resolved when using GroupDisplayName' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $null }
                $result = Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup'
                $result | Should -BeNullOrEmpty
            }

            It 'Skips groups without DisplayName when using GroupDisplayName' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'group-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.group' } }
                    )
                }
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    param($Id, $DisplayName)
                    if ($Id) {
                        return @{ Id = $Id }  # No DisplayName
                    } else {
                        return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = $DisplayName }
                    }
                }
                $result = Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup'
                $result | Should -BeNullOrEmpty
            }

            It 'Skips service principals without DisplayName when using GroupDisplayName' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'sp-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.servicePrincipal' } }
                    )
                }
                Mock -CommandName Get-EntraIdServicePrincipal -MockWith {
                    @{ Id = 'sp-1111-1111-1111-111111111111' }  # No DisplayName
                }
                $result = Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup'
                $result | Should -BeNullOrEmpty
            }

            It 'Handles owners with unknown odata.type' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'unknown-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.unknownType' } }
                    )
                }
                $result = Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -BeNullOrEmpty
            }
        }

        Context 'Error handling' {
            It 'Throws when Get-EntraIdGroup fails' {
                Mock -CommandName Get-EntraIdGroup -MockWith { throw "Graph API Error" }
                { Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup' } | Should -Throw "*Graph API Error*"
            }

            It 'Throws when Get-MgGroupOwner fails' {
                Mock -CommandName Get-MgGroupOwner -MockWith { throw "Permission denied" }
                { Get-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111' } | Should -Throw "*Permission denied*"
            }

            It 'Throws when Get-EntraIdUser fails' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                Mock -CommandName Get-EntraIdUser -MockWith { throw "User lookup failed" }
                { Get-EntraIdGroupOwner -GroupDisplayName 'TestGroup' } | Should -Throw "*User lookup failed*"
            }
        }

        Context 'Parameter validation' {
            It 'GroupId is mandatory in ById parameter set' {
                $param = (Get-Command Get-EntraIdGroupOwner).Parameters['GroupId']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ById'}).Mandatory | Should -Be $true
            }

            It 'GroupDisplayName is mandatory in ByDisplayName parameter set' {
                $param = (Get-Command Get-EntraIdGroupOwner).Parameters['GroupDisplayName']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByDisplayName'}).Mandatory | Should -Be $true
            }
        }

        Context 'Pipeline input' {
            It 'Accepts GroupId from pipeline' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = '22222222-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                $result = '11111111-1111-1111-1111-111111111111' | Get-EntraIdGroupOwner
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Accepts GroupDisplayName from pipeline' {
                $result = 'TestGroup' | Get-EntraIdGroupOwner
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Accepts object with GroupId property from pipeline' {
                Mock -CommandName Get-MgGroupOwner -MockWith {
                    @(
                        @{ Id = '22222222-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                $inputObject = [PSCustomObject]@{ GroupId = '11111111-1111-1111-1111-111111111111' }
                $result = $inputObject | Get-EntraIdGroupOwner
                $result | Should -Not -BeNullOrEmpty
            }
        }

        # CodeCoverage: Ensure Get-EntraIdGroupOwner is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
