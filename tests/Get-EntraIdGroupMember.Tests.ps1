# Pester tests for Get-EntraIdGroupMember
# Follows Pester best practices: structure, assertions, mocks
Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Get-EntraIdGroupMember' {
        BeforeAll {
            # Mock external dependencies with generic fallbacks
            Mock -CommandName Get-ObjectType -MockWith { return 'User' }
            Mock -CommandName Test-GraphAuth -MockWith { return $true }
            Mock -CommandName Get-MgGroup -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' } }
            Mock -CommandName Get-EntraIdGroup -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' } }
            Mock -CommandName Get-EntraIdUser -MockWith { return @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user@test.com' } }
            Mock -CommandName Get-MgGroupMember -MockWith { return @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user@test.com'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } } }
            Mock -CommandName Get-EntraIdServicePrincipal -MockWith { return @{ Id = '33333333-3333-3333-3333-333333333333'; DisplayName = 'TestServicePrincipal' } }
            Mock -CommandName Write-Warning -MockWith { }
        }

        Context 'Valid input scenarios - ById parameter set' {
            It 'Returns group members for valid group Id' {
                $result = Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Returns member Ids when using GroupId parameter' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = '22222222-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                $result = Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Be '22222222-2222-2222-2222-222222222222'
            }

            It 'Uses correct parameters for Get-MgGroupMember' {
                Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111'
                Should -Invoke -CommandName Get-MgGroupMember -Times 1 -Exactly -ParameterFilter {
                    $GroupId -eq '11111111-1111-1111-1111-111111111111' -and
                    $All -eq $true -and
                    $ConsistencyLevel -eq 'eventual'
                }
            }
        }

        Context 'Valid input scenarios - ByDisplayName parameter set' {
            It 'Returns group members for valid group DisplayName' {
                $result = Get-EntraIdGroupMember -GroupDisplayName 'TestGroup'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -Be 'user@test.com'
            }

            It 'Resolves group Id from DisplayName before getting members' {
                Get-EntraIdGroupMember -GroupDisplayName 'TestGroup'
                Should -Invoke -CommandName Get-EntraIdGroup -Times 1 -Exactly -ParameterFilter {
                    $DisplayName -eq 'TestGroup'
                }
            }

            It 'Returns UPNs when using GroupDisplayName parameter' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = '22222222-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                Mock -CommandName Get-EntraIdUser -MockWith {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user@test.com' }
                }
                $result = Get-EntraIdGroupMember -GroupDisplayName 'TestGroup'
                $result | Should -Be 'user@test.com'
            }

            It 'Writes verbose message when getting group by DisplayName' {
                $verboseOutput = Get-EntraIdGroupMember -GroupDisplayName 'TestGroup' -Verbose 4>&1
                $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | Should -Match "Getting group with display name 'TestGroup'"
            }
        }

        Context 'Member type handling - User members' {
            It 'Returns user Ids when using GroupId parameter' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } },
                        @{ Id = 'user-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                $result = Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111'
                $result.Count | Should -Be 2
                $result[0] | Should -Be 'user-1111-1111-1111-111111111111'
                $result[1] | Should -Be 'user-2222-2222-2222-222222222222'
            }

            It 'Returns user UPNs when using GroupDisplayName parameter' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } },
                        @{ Id = 'user-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                Mock -CommandName Get-EntraIdUser -MockWith {
                    param($Id)
                    if ($Id -eq 'user-1111-1111-1111-111111111111') {
                        return @{ Id = $Id; UserPrincipalName = 'user1@test.com' }
                    } else {
                        return @{ Id = $Id; UserPrincipalName = 'user2@test.com' }
                    }
                }
                $result = Get-EntraIdGroupMember -GroupDisplayName 'TestGroup'
                $result.Count | Should -Be 2
                $result[0] | Should -Be 'user1@test.com'
                $result[1] | Should -Be 'user2@test.com'
            }
        }

        Context 'Member type handling - Group members' {
            It 'Returns group Ids when group contains nested groups (ById)' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'group-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.group' } }
                    )
                }
                $result = Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Be 'group-1111-1111-1111-111111111111'
            }

            It 'Returns group DisplayNames when group contains nested groups (ByDisplayName)' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'group-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.group' } }
                    )
                }
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    param($Id, $DisplayName)
                    if ($Id) {
                        return @{ Id = $Id; DisplayName = 'NestedGroup' }
                    } else {
                        return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = $DisplayName }
                    }
                }
                $result = Get-EntraIdGroupMember -GroupDisplayName 'TestGroup'
                $result | Should -Be 'NestedGroup'
            }
        }

        Context 'Member type handling - Service Principal members' {
            It 'Returns service principal Ids when group contains service principals (ById)' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'sp-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.servicePrincipal' } }
                    )
                }
                $result = Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Be 'sp-1111-1111-1111-111111111111'
            }

            It 'Returns service principal DisplayNames when group contains service principals (ByDisplayName)' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'sp-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.servicePrincipal' } }
                    )
                }
                Mock -CommandName Get-EntraIdServicePrincipal -MockWith {
                    @{ Id = 'sp-1111-1111-1111-111111111111'; DisplayName = 'MyServicePrincipal' }
                }
                $result = Get-EntraIdGroupMember -GroupDisplayName 'TestGroup'
                $result | Should -Be 'MyServicePrincipal'
            }
        }

        Context 'Member type handling - Mixed member types' {
            It 'Returns mixed member Ids when using GroupId' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } },
                        @{ Id = 'group-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.group' } },
                        @{ Id = 'sp-3333-3333-3333-333333333333'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.servicePrincipal' } }
                    )
                }
                $result = Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111'
                $result.Count | Should -Be 3
                $result[0] | Should -Be 'user-1111-1111-1111-111111111111'
                $result[1] | Should -Be 'group-2222-2222-2222-222222222222'
                $result[2] | Should -Be 'sp-3333-3333-3333-333333333333'
            }

            It 'Returns mixed member names when using GroupDisplayName' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } },
                        @{ Id = 'group-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.group' } },
                        @{ Id = 'sp-3333-3333-3333-333333333333'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.servicePrincipal' } }
                    )
                }
                Mock -CommandName Get-EntraIdUser -MockWith {
                    @{ UserPrincipalName = 'user@test.com' }
                }
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    param($Id, $DisplayName)
                    if ($Id) {
                        return @{ DisplayName = 'NestedGroup' }
                    } else {
                        return @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = $DisplayName }
                    }
                }
                Mock -CommandName Get-EntraIdServicePrincipal -MockWith {
                    @{ DisplayName = 'MyServicePrincipal' }
                }
                $result = Get-EntraIdGroupMember -GroupDisplayName 'TestGroup'
                $result.Count | Should -Be 3
                $result[0] | Should -Be 'user@test.com'
                $result[1] | Should -Be 'NestedGroup'
                $result[2] | Should -Be 'MyServicePrincipal'
            }
        }

        Context 'Invalid input scenarios' {
            It 'Returns null when group does not exist (ByDisplayName)' {
                Mock -CommandName Get-EntraIdGroup -MockWith { $null }
                $result = Get-EntraIdGroupMember -GroupDisplayName 'NonExistentGroup'
                $result | Should -Be $null
            }

            It 'Writes warning when group does not exist (ByDisplayName)' {
                Mock -CommandName Get-EntraIdGroup -MockWith { $null }
                Get-EntraIdGroupMember -GroupDisplayName 'NonExistentGroup'
                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -like "*No group found with display name 'NonExistentGroup'*"
                }
            }

            It 'Returns null when group has no members' {
                Mock -CommandName Get-MgGroupMember -MockWith { $null }
                $result = Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Be $null
            }

            It 'Writes warning when group has no members' {
                Mock -CommandName Get-MgGroupMember -MockWith { $null }
                Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111'
                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -like "*No members found for group Id '11111111-1111-1111-1111-111111111111'*"
                }
            }
        }

        Context 'Edge cases' {
            It 'Handles empty member list' {
                Mock -CommandName Get-MgGroupMember -MockWith { @() }
                $result = Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -Be $null
            }

            It 'Skips users without UPN when using GroupDisplayName' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                Mock -CommandName Get-EntraIdUser -MockWith {
                    @{ Id = 'user-1111-1111-1111-111111111111' }  # No UserPrincipalName
                }
                $result = Get-EntraIdGroupMember -GroupDisplayName 'TestGroup'
                $result | Should -BeNullOrEmpty
            }

            It 'Skips users that cannot be resolved when using GroupDisplayName' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $null }
                $result = Get-EntraIdGroupMember -GroupDisplayName 'TestGroup'
                $result | Should -BeNullOrEmpty
            }

            It 'Skips groups without DisplayName when using GroupDisplayName' {
                Mock -CommandName Get-MgGroupMember -MockWith {
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
                $result = Get-EntraIdGroupMember -GroupDisplayName 'TestGroup'
                $result | Should -BeNullOrEmpty
            }

            It 'Skips service principals without DisplayName when using GroupDisplayName' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'sp-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.servicePrincipal' } }
                    )
                }
                Mock -CommandName Get-EntraIdServicePrincipal -MockWith {
                    @{ Id = 'sp-1111-1111-1111-111111111111' }  # No DisplayName
                }
                $result = Get-EntraIdGroupMember -GroupDisplayName 'TestGroup'
                $result | Should -BeNullOrEmpty
            }

            It 'Handles members with unknown odata.type' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'unknown-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.unknownType' } }
                    )
                }
                $result = Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111'
                $result | Should -BeNullOrEmpty
            }
        }

        Context 'Error handling' {
            It 'Throws when Get-EntraIdGroup fails' {
                Mock -CommandName Get-EntraIdGroup -MockWith { throw "Graph API Error" }
                { Get-EntraIdGroupMember -GroupDisplayName 'TestGroup' } | Should -Throw "*Graph API Error*"
            }

            It 'Throws when Get-MgGroupMember fails' {
                Mock -CommandName Get-MgGroupMember -MockWith { throw "Permission denied" }
                { Get-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111' } | Should -Throw "*Permission denied*"
            }

            It 'Throws when Get-EntraIdUser fails' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = 'user-1111-1111-1111-111111111111'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                Mock -CommandName Get-EntraIdUser -MockWith { throw "User lookup failed" }
                { Get-EntraIdGroupMember -GroupDisplayName 'TestGroup' } | Should -Throw "*User lookup failed*"
            }
        }

        Context 'Parameter validation' {
            It 'GroupId is mandatory in ById parameter set' {
                $param = (Get-Command Get-EntraIdGroupMember).Parameters['GroupId']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ById'}).Mandatory | Should -Be $true
            }

            It 'GroupDisplayName is mandatory in ByDisplayName parameter set' {
                $param = (Get-Command Get-EntraIdGroupMember).Parameters['GroupDisplayName']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByDisplayName'}).Mandatory | Should -Be $true
            }
        }

        Context 'Pipeline input' {
            It 'Accepts GroupId from pipeline' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = '22222222-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                $result = '11111111-1111-1111-1111-111111111111' | Get-EntraIdGroupMember
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Accepts GroupDisplayName from pipeline' {
                $result = 'TestGroup' | Get-EntraIdGroupMember -GroupDisplayName { $_ }
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Accepts object with GroupId property from pipeline' {
                Mock -CommandName Get-MgGroupMember -MockWith {
                    @(
                        @{ Id = '22222222-2222-2222-2222-222222222222'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.user' } }
                    )
                }
                $inputObject = [PSCustomObject]@{ GroupId = '11111111-1111-1111-1111-111111111111' }
                $result = $inputObject | Get-EntraIdGroupMember
                $result | Should -Not -BeNullOrEmpty
            }
        }

        # CodeCoverage: Ensure Get-EntraIdGroupMember is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}

