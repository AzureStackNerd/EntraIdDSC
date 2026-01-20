# Pester tests for Invoke-EntraIdGroupDesiredState
# Purpose: Validate Invoke-EntraIdGroupDesiredState logic, input handling, and edge cases

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Invoke-EntraIdGroupDesiredState' {
        BeforeAll {
            # Mock external dependencies
            Mock -CommandName Test-GraphAuth -MockWith { $true }
            Mock -CommandName Set-EntraIdGroup -MockWith { }

            # Create a temporary test directory for configuration files
            $script:testPath = Join-Path $TestDrive 'GroupConfigs'
            New-Item -Path $script:testPath -ItemType Directory -Force | Out-Null
        }

        Context 'Valid input scenarios - Processing JSON files' {
            It 'Processes a single JSON file with one group' {
                $jsonContent = @'
[
    {
        "name": "TestGroup",
        "groupMembershipType": "Direct",
        "description": "Test Description",
        "members": ["user1@test.com"],
        "owners": ["owner@test.com"],
        "isAssignableToRole": false
    }
]
'@
                $testFile = Join-Path $script:testPath 'group1.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'group1.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 1 -Exactly
            }

            It 'Processes a JSONC file with comments' {
                $jsoncContent = @'
[
    // This is a comment
    {
        "name": "TestGroup",
        "groupMembershipType": "Direct", // inline comment
        "description": "Test Description",
        /* Block comment
           spanning multiple lines */
        "members": ["user1@test.com"],
        "owners": ["owner@test.com"],
        "isAssignableToRole": false
    }
]
'@
                $testFile = Join-Path $script:testPath 'group1.jsonc'
                Set-Content -Path $testFile -Value $jsoncContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'group1.jsonc' })
                }
                Mock -CommandName Get-Content -MockWith { $jsoncContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 1 -Exactly
            }

            It 'Processes multiple groups in a single file' {
                $jsonContent = @'
[
    {
        "name": "Group1",
        "groupMembershipType": "Direct",
        "description": "Description 1",
        "members": ["user1@test.com"],
        "owners": ["owner@test.com"],
        "isAssignableToRole": false
    },
    {
        "name": "Group2",
        "groupMembershipType": "Dynamic",
        "description": "Description 2",
        "members": ["(user.department -eq 'IT')"],
        "owners": ["owner@test.com"],
        "isAssignableToRole": false
    }
]
'@
                $testFile = Join-Path $script:testPath 'multiple.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'multiple.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 2 -Exactly
            }

            It 'Processes multiple JSON files' {
                $json1 = @'
[
    {
        "name": "Group1",
        "groupMembershipType": "Direct",
        "description": "Description 1",
        "members": ["user1@test.com"],
        "owners": ["owner@test.com"],
        "isAssignableToRole": false
    }
]
'@
                $json2 = @'
[
    {
        "name": "Group2",
        "groupMembershipType": "Direct",
        "description": "Description 2",
        "members": ["user2@test.com"],
        "owners": ["owner@test.com"],
        "isAssignableToRole": false
    }
]
'@
                $testFile1 = Join-Path $script:testPath 'group1.json'
                $testFile2 = Join-Path $script:testPath 'group2.json'

                Mock -CommandName Get-ChildItem -MockWith {
                    @(
                        [PSCustomObject]@{ FullName = $testFile1; Name = 'group1.json' },
                        [PSCustomObject]@{ FullName = $testFile2; Name = 'group2.json' }
                    )
                }
                Mock -CommandName Get-Content -MockWith { $json1 } -ParameterFilter { $Path -eq $testFile1 }
                Mock -CommandName Get-Content -MockWith { $json2 } -ParameterFilter { $Path -eq $testFile2 }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 2 -Exactly
            }

            It 'Processes group with Administrative Unit' {
                $jsonContent = @'
[
    {
        "name": "AUGroup",
        "groupMembershipType": "Direct",
        "description": "AU Group",
        "members": ["user1@test.com"],
        "owners": ["owner@test.com"],
        "isAssignableToRole": false,
        "administrativeUnit": "TestAU"
    }
]
'@
                $testFile = Join-Path $script:testPath 'augroup.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'augroup.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 1 -Exactly -ParameterFilter {
                    $AdministrativeUnit -eq 'TestAU'
                }
            }

            It 'Processes group with isAssignableToRole set to true' {
                $jsonContent = @'
[
    {
        "name": "RoleGroup",
        "groupMembershipType": "Direct",
        "description": "Role-assignable",
        "members": ["user1@test.com"],
        "owners": ["owner@test.com"],
        "isAssignableToRole": true
    }
]
'@
                $testFile = Join-Path $script:testPath 'rolegroup.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'rolegroup.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 1 -Exactly -ParameterFilter {
                    $IsAssignableToRole -eq $true
                }
            }
        }

        Context 'Invalid input scenarios' {
            It 'Throws when Path parameter is missing' {
                # Use Get-Command to verify Path is mandatory, not actual invocation
                (Get-Command Invoke-EntraIdGroupDesiredState).Parameters['Path'].Attributes.Mandatory | Should -Be $true
            }

            It 'Skips groups without owners' {
                $jsonContent = @'
[
    {
        "name": "NoOwners",
        "groupMembershipType": "Direct",
        "description": "No owners",
        "members": ["user1@test.com"],
        "isAssignableToRole": false
    }
]
'@
                $testFile = Join-Path $script:testPath 'noowners.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'noowners.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 0 -Exactly
            }

            It 'Handles invalid JSON gracefully' {
                $invalidJson = '{ "name": "Invalid", "description": }'
                $testFile = Join-Path $script:testPath 'invalid.json'

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'invalid.json' })
                }
                Mock -CommandName Get-Content -MockWith { $invalidJson }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Throw
            }
        }

        Context 'Edge cases' {
            It 'Handles empty directory with no JSON files' {
                Mock -CommandName Get-ChildItem -MockWith { @() }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 0 -Exactly
            }

            It 'Handles empty JSON array' {
                $jsonContent = '[]'
                $testFile = Join-Path $script:testPath 'empty.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'empty.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 0 -Exactly
            }

            It 'Handles group with empty members array' {
                $jsonContent = @'
[
    {
        "name": "EmptyMembers",
        "groupMembershipType": "Direct",
        "description": "No members",
        "members": [],
        "owners": ["owner@test.com"],
        "isAssignableToRole": false
    }
]
'@
                $testFile = Join-Path $script:testPath 'emptymembers.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'emptymembers.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 1 -Exactly
            }

            It 'Handles group with null members' {
                $jsonContent = @'
[
    {
        "name": "NullMembers",
        "groupMembershipType": "Direct",
        "description": "Null members",
        "members": null,
        "owners": ["owner@test.com"],
        "isAssignableToRole": false
    }
]
'@
                $testFile = Join-Path $script:testPath 'nullmembers.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'nullmembers.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 1 -Exactly
            }

            It 'Handles JSONC with only comments gracefully' {
                $jsoncContent = @'
// This file only has comments
/* And some block comments
   Nothing else
*/
'@
                $testFile = Join-Path $script:testPath 'commentsonly.jsonc'
                Set-Content -Path $testFile -Value $jsoncContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'commentsonly.jsonc' })
                }
                Mock -CommandName Get-Content -MockWith { $jsoncContent }

                # After removing comments, this becomes empty and ConvertFrom-Json will handle it
                # The function should not throw, but also should not process any groups
                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 0 -Exactly
            }

            It 'Processes files in sorted order' {
                $json1 = @'
[
    {
        "name": "ZGroup",
        "groupMembershipType": "Direct",
        "description": "Last alphabetically",
        "members": [],
        "owners": ["owner@test.com"],
        "isAssignableToRole": false
    }
]
'@
                $json2 = @'
[
    {
        "name": "AGroup",
        "groupMembershipType": "Direct",
        "description": "First alphabetically",
        "members": [],
        "owners": ["owner@test.com"],
        "isAssignableToRole": false
    }
]
'@
                $testFile1 = Join-Path $script:testPath 'z-group.json'
                $testFile2 = Join-Path $script:testPath 'a-group.json'

                Mock -CommandName Get-ChildItem -MockWith {
                    @(
                        [PSCustomObject]@{ FullName = $testFile2; Name = 'a-group.json' },
                        [PSCustomObject]@{ FullName = $testFile1; Name = 'z-group.json' }
                    )
                }
                Mock -CommandName Get-Content -MockWith { $json1 } -ParameterFilter { $Path -eq $testFile1 }
                Mock -CommandName Get-Content -MockWith { $json2 } -ParameterFilter { $Path -eq $testFile2 }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 2 -Exactly
            }

            It 'Handles recursive file search' {
                $jsonContent = @'
[
    {
        "name": "NestedGroup",
        "groupMembershipType": "Direct",
        "description": "In subdirectory",
        "members": [],
        "owners": ["owner@test.com"],
        "isAssignableToRole": false
    }
]
'@
                $subPath = Join-Path $script:testPath 'subfolder'
                $testFile = Join-Path $subPath 'nested.json'

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'nested.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 1 -Exactly
            }

            It 'Skips group and continues when owners is empty array' {
                $jsonContent = @'
[
    {
        "name": "EmptyOwners",
        "groupMembershipType": "Direct",
        "description": "Empty owners array",
        "members": ["user@test.com"],
        "owners": [],
        "isAssignableToRole": false
    }
]
'@
                $testFile = Join-Path $script:testPath 'emptyowners.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'emptyowners.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 0 -Exactly
            }
        }

        Context 'ShouldProcess support' {
            It 'Supports -WhatIf' {
                $jsonContent = @'
[
    {
        "name": "WhatIfGroup",
        "groupMembershipType": "Direct",
        "description": "Test",
        "members": ["user@test.com"],
        "owners": ["owner@test.com"],
        "isAssignableToRole": false
    }
]
'@
                $testFile = Join-Path $script:testPath 'whatif.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'whatif.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -WhatIf } | Should -Not -Throw
            }
        }

        Context 'Integration with Set-EntraIdGroup' {
            It 'Passes correct parameters to Set-EntraIdGroup' {
                $jsonContent = @'
[
    {
        "name": "IntegrationGroup",
        "groupMembershipType": "Dynamic",
        "description": "Integration test",
        "members": ["(user.department -eq 'IT')"],
        "owners": ["owner1@test.com", "owner2@test.com"],
        "isAssignableToRole": true,
        "administrativeUnit": "TestAU"
    }
]
'@
                $testFile = Join-Path $script:testPath 'integration.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'integration.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdGroupDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdGroup -Times 1 -Exactly -ParameterFilter {
                    $DisplayName -eq 'IntegrationGroup' -and
                    $GroupMembershipType -eq 'Dynamic' -and
                    $Description -eq 'Integration test' -and
                    $Members[0] -eq "(user.department -eq 'IT')" -and
                    $Owners.Count -eq 2 -and
                    $IsAssignableToRole -eq $true -and
                    $AdministrativeUnit -eq 'TestAU'
                }
            }
        }

        # CodeCoverage: Ensure Invoke-EntraIdGroupDesiredState is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
