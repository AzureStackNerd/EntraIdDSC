# Pester tests for Invoke-EntraIdUserDesiredState
# Purpose: Validate Invoke-EntraIdUserDesiredState logic, input handling, and edge cases

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Invoke-EntraIdUserDesiredState' {
        BeforeAll {
            # Mock external dependencies
            Mock -CommandName Test-GraphAuth -MockWith { $true }
            Mock -CommandName Get-EntraIdUser -MockWith { $null }
            Mock -CommandName Add-EntraIdUser -MockWith { }
            Mock -CommandName Set-EntraIdUser -MockWith { }

            # Create a temporary test directory for configuration files
            $script:testPath = Join-Path $TestDrive 'UserConfigs'
            New-Item -Path $script:testPath -ItemType Directory -Force | Out-Null
        }

        Context 'Valid input scenarios - Processing JSON files without protected users' {
            It 'Processes a single JSON file with one user' {
                $jsonContent = @'
[
    {
        "DisplayName": "Test User",
        "UserPrincipalName": "testuser@test.com",
        "GivenName": "Test",
        "Surname": "User",
        "MailNickname": "testuser",
        "JobTitle": "Engineer",
        "Department": "IT",
        "UsageLocation": "US"
    }
]
'@
                $testFile = Join-Path $script:testPath 'users.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'users.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }
                Mock -CommandName Get-EntraIdUser -MockWith { $null }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 1 -Exactly
            }

            It 'Updates existing user when user already exists' {
                $jsonContent = @'
[
    {
        "DisplayName": "Existing User",
        "UserPrincipalName": "existing@test.com",
        "GivenName": "Existing",
        "Surname": "User",
        "MailNickname": "existing",
        "JobTitle": "Manager",
        "Department": "HR"
    }
]
'@
                $testFile = Join-Path $script:testPath 'existing.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'existing.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }
                Mock -CommandName Get-EntraIdUser -MockWith {
                    @{
                        UserPrincipalName = 'existing@test.com'
                        DisplayName = 'Existing User'
                    }
                }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdUser -Times 1 -Exactly
                Should -Invoke -CommandName Add-EntraIdUser -Times 0 -Exactly
            }

            It 'Processes multiple users in a single file' {
                $jsonContent = @'
[
    {
        "DisplayName": "User 1",
        "UserPrincipalName": "user1@test.com",
        "GivenName": "User",
        "Surname": "One",
        "MailNickname": "user1"
    },
    {
        "DisplayName": "User 2",
        "UserPrincipalName": "user2@test.com",
        "GivenName": "User",
        "Surname": "Two",
        "MailNickname": "user2"
    }
]
'@
                $testFile = Join-Path $script:testPath 'multipleusers.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'multipleusers.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 2 -Exactly
            }

            It 'Processes JSONC file with comments' {
                $jsoncContent = @'
[
    // This is a test user
    {
        "DisplayName": "Comment User",
        "UserPrincipalName": "comment@test.com", // UPN
        "GivenName": "Comment",
        /* Multi-line
           comment here */
        "Surname": "User",
        "MailNickname": "comment"
    }
]
'@
                $testFile = Join-Path $script:testPath 'comments.jsonc'
                Set-Content -Path $testFile -Value $jsoncContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'comments.jsonc' })
                }
                Mock -CommandName Get-Content -MockWith { $jsoncContent }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 1 -Exactly
            }

            It 'Processes user with all supported properties' {
                $jsonContent = @'
[
    {
        "DisplayName": "Full User",
        "UserPrincipalName": "full@test.com",
        "GivenName": "Full",
        "Surname": "User",
        "MailNickname": "full",
        "JobTitle": "Senior Engineer",
        "Department": "Engineering",
        "OfficeLocation": "Building A",
        "MobilePhone": "+1 555-555-5555",
        "UsageLocation": "US",
        "StreetAddress": "123 Main St",
        "City": "Seattle",
        "State": "WA",
        "PostalCode": "98101",
        "Country": "US"
    }
]
'@
                $testFile = Join-Path $script:testPath 'fulluser.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'fulluser.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 1 -Exactly -ParameterFilter {
                    $AdditionalProperties.GivenName -eq 'Full' -and
                    $AdditionalProperties.JobTitle -eq 'Senior Engineer' -and
                    $AdditionalProperties.Department -eq 'Engineering' -and
                    $AdditionalProperties.UsageLocation -eq 'US'
                }
            }
        }

        Context 'Valid input scenarios - Protected users' {
            It 'Skips protected users defined in ProtectedUsers.json' {
                $protectedContent = @'
[
    {
        "UserPrincipalName": "protected@test.com"
    }
]
'@
                $userContent = @'
[
    {
        "DisplayName": "Protected User",
        "UserPrincipalName": "protected@test.com",
        "GivenName": "Protected",
        "Surname": "User",
        "MailNickname": "protected"
    },
    {
        "DisplayName": "Normal User",
        "UserPrincipalName": "normal@test.com",
        "GivenName": "Normal",
        "Surname": "User",
        "MailNickname": "normal"
    }
]
'@
                $protectedFile = Join-Path $script:testPath 'ProtectedUsers.json'
                $userFile = Join-Path $script:testPath 'users.json'
                Set-Content -Path $protectedFile -Value $protectedContent
                Set-Content -Path $userFile -Value $userContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @(
                        [PSCustomObject]@{ FullName = $protectedFile; Name = 'ProtectedUsers.json' },
                        [PSCustomObject]@{ FullName = $userFile; Name = 'users.json' }
                    )
                }
                Mock -CommandName Get-Content -MockWith { $protectedContent } -ParameterFilter { $Path -eq $protectedFile }
                Mock -CommandName Get-Content -MockWith { $userContent } -ParameterFilter { $Path -eq $userFile }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 1 -Exactly
            }

            It 'Skips protected users defined in ProtectedUsers.jsonc' {
                $protectedContent = @'
[
    // Protected admin account
    {
        "UserPrincipalName": "admin@test.com"
    }
]
'@
                $userContent = @'
[
    {
        "DisplayName": "Admin User",
        "UserPrincipalName": "admin@test.com",
        "GivenName": "Admin",
        "Surname": "User",
        "MailNickname": "admin"
    }
]
'@
                $protectedFile = Join-Path $script:testPath 'ProtectedUsers.jsonc'
                $userFile = Join-Path $script:testPath 'users.json'
                Set-Content -Path $protectedFile -Value $protectedContent
                Set-Content -Path $userFile -Value $userContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @(
                        [PSCustomObject]@{ FullName = $protectedFile; Name = 'ProtectedUsers.jsonc' },
                        [PSCustomObject]@{ FullName = $userFile; Name = 'users.json' }
                    )
                }
                Mock -CommandName Get-Content -MockWith { $protectedContent } -ParameterFilter { $Path -eq $protectedFile }
                Mock -CommandName Get-Content -MockWith { $userContent } -ParameterFilter { $Path -eq $userFile }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 0 -Exactly
            }

            It 'Writes error when multiple ProtectedUsers files exist' {
                $protectedFile1 = Join-Path $script:testPath 'ProtectedUsers.json'
                $protectedFile2 = Join-Path $script:testPath 'ProtectedUsers.jsonc'

                Mock -CommandName Get-ChildItem -MockWith {
                    @(
                        [PSCustomObject]@{ FullName = $protectedFile1; Name = 'ProtectedUsers.json' },
                        [PSCustomObject]@{ FullName = $protectedFile2; Name = 'ProtectedUsers.jsonc' }
                    )
                }
                Mock -CommandName Write-Error -MockWith { }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false -ErrorAction SilentlyContinue } | Should -Not -Throw
                Should -Invoke -CommandName Write-Error -Times 1 -Exactly -ParameterFilter {
                    $Message -like "*Multiple ProtectedUsers*"
                }
                Should -Invoke -CommandName Add-EntraIdUser -Times 0 -Exactly
            }

            It 'Processes normally when no ProtectedUsers file exists' {
                $userContent = @'
[
    {
        "DisplayName": "Normal User",
        "UserPrincipalName": "normal@test.com",
        "GivenName": "Normal",
        "Surname": "User",
        "MailNickname": "normal"
    }
]
'@
                $userFile = Join-Path $script:testPath 'users.json'
                Set-Content -Path $userFile -Value $userContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $userFile; Name = 'users.json' })
                }
                Mock -CommandName Get-Content -MockWith { $userContent }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 1 -Exactly
            }
        }

        Context 'Invalid input scenarios' {
            It 'Throws when Path parameter is missing' {
                # Use Get-Command to verify Path is mandatory, not actual invocation
                (Get-Command Invoke-EntraIdUserDesiredState).Parameters['Path'].Attributes.Mandatory | Should -Be $true
            }

            It 'Handles invalid JSON gracefully' {
                $invalidJson = '{ "DisplayName": "Invalid", "UserPrincipalName": }'
                $testFile = Join-Path $script:testPath 'invalid.json'

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'invalid.json' })
                }
                Mock -CommandName Get-Content -MockWith { $invalidJson }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Throw
            }
        }

        Context 'Edge cases' {
            It 'Handles empty directory with no JSON files' {
                Mock -CommandName Get-ChildItem -MockWith { @() }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 0 -Exactly
            }

            It 'Handles empty JSON array' {
                $jsonContent = '[]'
                $testFile = Join-Path $script:testPath 'empty.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'empty.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 0 -Exactly
            }

            It 'Handles user with minimal properties' {
                $jsonContent = @'
[
    {
        "DisplayName": "Minimal User",
        "UserPrincipalName": "minimal@test.com"
    }
]
'@
                $testFile = Join-Path $script:testPath 'minimal.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'minimal.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 1 -Exactly
            }

            It 'Handles null property values' {
                $jsonContent = @'
[
    {
        "DisplayName": "Null Props User",
        "UserPrincipalName": "nullprops@test.com",
        "GivenName": null,
        "Surname": null,
        "JobTitle": null
    }
]
'@
                $testFile = Join-Path $script:testPath 'nullprops.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'nullprops.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 1 -Exactly
            }

            It 'Processes files in sorted order' {
                $json1 = @'
[
    {
        "DisplayName": "User Z",
        "UserPrincipalName": "z@test.com",
        "GivenName": "User",
        "Surname": "Z"
    }
]
'@
                $json2 = @'
[
    {
        "DisplayName": "User A",
        "UserPrincipalName": "a@test.com",
        "GivenName": "User",
        "Surname": "A"
    }
]
'@
                $testFile1 = Join-Path $script:testPath 'z-user.json'
                $testFile2 = Join-Path $script:testPath 'a-user.json'

                Mock -CommandName Get-ChildItem -MockWith {
                    @(
                        [PSCustomObject]@{ FullName = $testFile2; Name = 'a-user.json' },
                        [PSCustomObject]@{ FullName = $testFile1; Name = 'z-user.json' }
                    )
                }
                Mock -CommandName Get-Content -MockWith { $json1 } -ParameterFilter { $Path -eq $testFile1 }
                Mock -CommandName Get-Content -MockWith { $json2 } -ParameterFilter { $Path -eq $testFile2 }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 2 -Exactly
            }

            It 'Handles recursive file search' {
                $jsonContent = @'
[
    {
        "DisplayName": "Nested User",
        "UserPrincipalName": "nested@test.com",
        "GivenName": "Nested",
        "Surname": "User"
    }
]
'@
                $subPath = Join-Path $script:testPath 'subfolder'
                $testFile = Join-Path $subPath 'nested.json'

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'nested.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 1 -Exactly
            }

            It 'Processes mix of new and existing users' {
                $jsonContent = @'
[
    {
        "DisplayName": "New User",
        "UserPrincipalName": "new@test.com",
        "GivenName": "New",
        "Surname": "User"
    },
    {
        "DisplayName": "Existing User",
        "UserPrincipalName": "existing@test.com",
        "GivenName": "Existing",
        "Surname": "User"
    }
]
'@
                $testFile = Join-Path $script:testPath 'mixed.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'mixed.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }
                Mock -CommandName Get-EntraIdUser -MockWith { $null } -ParameterFilter { $UserPrincipalName -eq 'new@test.com' }
                Mock -CommandName Get-EntraIdUser -MockWith {
                    @{ UserPrincipalName = 'existing@test.com' }
                } -ParameterFilter { $UserPrincipalName -eq 'existing@test.com' }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 1 -Exactly
                Should -Invoke -CommandName Set-EntraIdUser -Times 1 -Exactly
            }

            It 'Handles empty ProtectedUsers array' {
                $protectedContent = '[]'
                $userContent = @'
[
    {
        "DisplayName": "Normal User",
        "UserPrincipalName": "normal@test.com",
        "GivenName": "Normal",
        "Surname": "User"
    }
]
'@
                $protectedFile = Join-Path $script:testPath 'ProtectedUsers.json'
                $userFile = Join-Path $script:testPath 'users.json'
                Set-Content -Path $protectedFile -Value $protectedContent
                Set-Content -Path $userFile -Value $userContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @(
                        [PSCustomObject]@{ FullName = $protectedFile; Name = 'ProtectedUsers.json' },
                        [PSCustomObject]@{ FullName = $userFile; Name = 'users.json' }
                    )
                }
                Mock -CommandName Get-Content -MockWith { $protectedContent } -ParameterFilter { $Path -eq $protectedFile }
                Mock -CommandName Get-Content -MockWith { $userContent } -ParameterFilter { $Path -eq $userFile }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 1 -Exactly
            }
        }

        Context 'ShouldProcess support' {
            It 'Supports -WhatIf' {
                $jsonContent = @'
[
    {
        "DisplayName": "WhatIf User",
        "UserPrincipalName": "whatif@test.com",
        "GivenName": "WhatIf",
        "Surname": "User"
    }
]
'@
                $testFile = Join-Path $script:testPath 'whatif.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'whatif.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -WhatIf } | Should -Not -Throw
            }
        }

        Context 'Integration with Add-EntraIdUser and Set-EntraIdUser' {
            It 'Passes correct parameters to Add-EntraIdUser' {
                $jsonContent = @'
[
    {
        "DisplayName": "Integration User",
        "UserPrincipalName": "integration@test.com",
        "GivenName": "Integration",
        "Surname": "User",
        "MailNickname": "integration",
        "JobTitle": "Tester",
        "Department": "QA",
        "UsageLocation": "US"
    }
]
'@
                $testFile = Join-Path $script:testPath 'integration.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'integration.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdUser -Times 1 -Exactly -ParameterFilter {
                    $DisplayName -eq 'Integration User' -and
                    $UserPrincipalName -eq 'integration@test.com' -and
                    $AdditionalProperties.GivenName -eq 'Integration' -and
                    $AdditionalProperties.Surname -eq 'User' -and
                    $AdditionalProperties.JobTitle -eq 'Tester'
                }
            }

            It 'Passes correct user object to Set-EntraIdUser' {
                $jsonContent = @'
[
    {
        "DisplayName": "Update User",
        "UserPrincipalName": "update@test.com",
        "GivenName": "Update",
        "Surname": "User",
        "JobTitle": "Updated Title"
    }
]
'@
                $testFile = Join-Path $script:testPath 'update.json'
                Set-Content -Path $testFile -Value $jsonContent

                Mock -CommandName Get-ChildItem -MockWith {
                    @([PSCustomObject]@{ FullName = $testFile; Name = 'update.json' })
                }
                Mock -CommandName Get-Content -MockWith { $jsonContent }
                Mock -CommandName Get-EntraIdUser -MockWith {
                    @{ UserPrincipalName = 'update@test.com' }
                }

                { Invoke-EntraIdUserDesiredState -Path $script:testPath -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Set-EntraIdUser -Times 1 -Exactly -ParameterFilter {
                    $User.UserPrincipalName -eq 'update@test.com' -and
                    $User.DisplayName -eq 'Update User'
                }
            }
        }

        # CodeCoverage: Ensure Invoke-EntraIdUserDesiredState is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
