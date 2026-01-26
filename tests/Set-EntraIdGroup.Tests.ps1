# Pester tests for Set-EntraIdGroup
# Purpose: Validate Set-EntraIdGroup logic, input handling, and edge cases

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Set-EntraIdGroup' {
        BeforeAll {
            # Mock external dependencies
            Mock -CommandName Test-GraphAuth -MockWith { $true }
            Mock -CommandName Get-EntraIdGroup -MockWith { $null }
            Mock -CommandName New-MgGroup -MockWith {
                return @{
                    Id = '11111111-1111-1111-1111-111111111111'
                    DisplayName = 'TestGroup'
                    Description = 'Test Description'
                }
            }
            Mock -CommandName Update-MgGroup -MockWith { }
            Mock -CommandName Get-EntraIdGroupMember -MockWith { @() }
            Mock -CommandName Get-EntraIdGroupOwner -MockWith { @() }
            Mock -CommandName Add-EntraIdGroupMember -MockWith { }
            Mock -CommandName Remove-EntraIdGroupMember -MockWith { }
            Mock -CommandName Add-EntraIdGroupOwner -MockWith { }
            Mock -CommandName Remove-EntraIdGroupOwner -MockWith { }
            Mock -CommandName Get-MgDirectoryAdministrativeUnit -MockWith { $null }
            Mock -CommandName New-MgDirectoryAdministrativeUnitMember -MockWith { }
            Mock -CommandName Get-MgDirectoryAdministrativeUnitMember -MockWith { @() }
            Mock -CommandName Get-MgGroupMember -MockWith { @() }
            Mock -CommandName Write-Warning -MockWith { }
            Mock -CommandName Start-Sleep -MockWith { }
        }

        Context 'Valid input scenarios - Creating new Direct group' {
            It 'Creates a new Direct group with minimal parameters' {
                $script:callCount = 0
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    $script:callCount++
                    if ($script:callCount -eq 1) {
                        return $null  # First call: group doesn't exist
                    }
                    else {
                        return @{
                            Id = '11111111-1111-1111-1111-111111111111'
                            DisplayName = 'NewGroup'
                            Description = 'New Description'
                        }
                    }
                } -ParameterFilter { $DisplayName -eq 'NewGroup' }

                $params = @{
                    DisplayName = 'NewGroup'
                    Description = 'New Description'
                    Owners = @('owner@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                Set-EntraIdGroup @params
                Should -Invoke -CommandName New-MgGroup -Times 1 -Exactly
            }

            It 'Creates a new Direct group with members and owners' {
                $script:callCount = 0
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    $script:callCount++
                    if ($script:callCount -eq 1) {
                        return $null
                    }
                    else {
                        return @{
                            Id = '22222222-2222-2222-2222-222222222222'
                            DisplayName = 'GroupWithMembers'
                            Description = 'Test'
                        }
                    }
                } -ParameterFilter { $DisplayName -eq 'GroupWithMembers' }

                $params = @{
                    DisplayName = 'GroupWithMembers'
                    Description = 'Test'
                    Members = @('user1@test.com', 'user2@test.com')
                    Owners = @('owner@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                Set-EntraIdGroup @params
                Should -Invoke -CommandName New-MgGroup -Times 1 -Exactly
                Should -Invoke -CommandName Add-EntraIdGroupMember -Times 1 -Exactly
                Should -Invoke -CommandName Add-EntraIdGroupOwner -Times 1 -Exactly
            }

            It 'Creates a group with IsAssignableToRole set to true' {
                $script:callCount = 0
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    $script:callCount++
                    if ($script:callCount -eq 1) {
                        return $null
                    }
                    else {
                        return @{
                            Id = '33333333-3333-3333-3333-333333333333'
                            DisplayName = 'RoleGroup'
                        }
                    }
                } -ParameterFilter { $DisplayName -eq 'RoleGroup' }

                $params = @{
                    DisplayName = 'RoleGroup'
                    Description = 'Role-assignable group'
                    Owners = @('owner@test.com')
                    IsAssignableToRole = $true
                    Confirm = $false
                    WhatIf = $false
                }

                Set-EntraIdGroup @params
                Should -Invoke -CommandName New-MgGroup -Times 1 -Exactly -ParameterFilter {
                    $IsAssignableToRole -eq $true
                }
            }
        }

        Context 'Valid input scenarios - Creating new Dynamic group' {
            It 'Creates a new Dynamic group with membership rule' {
                $script:callCount = 0
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    $script:callCount++
                    if ($script:callCount -eq 1) {
                        return $null
                    }
                    else {
                        return @{
                            Id = '44444444-4444-4444-4444-444444444444'
                            DisplayName = 'DynamicGroup'
                        }
                    }
                } -ParameterFilter { $DisplayName -eq 'DynamicGroup' }

                $params = @{
                    DisplayName = 'DynamicGroup'
                    Description = 'Dynamic membership'
                    GroupMembershipType = 'Dynamic'
                    Members = @("(user.department -eq 'IT')")
                    Owners = @('owner@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                Set-EntraIdGroup @params
                Should -Invoke -CommandName New-MgGroup -Times 1 -Exactly -ParameterFilter {
                    $GroupTypes -contains 'DynamicMembership' -and
                    $MembershipRule -eq "(user.department -eq 'IT')"
                }
            }

            It 'Does not add members to Dynamic groups' {
                Mock -CommandName Get-EntraIdGroup -MockWith { $null } -ParameterFilter { $DisplayName -eq 'DynamicNoMembers' }
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    @{
                        Id = '55555555-5555-5555-5555-555555555555'
                        DisplayName = 'DynamicNoMembers'
                    }
                } -ParameterFilter { $DisplayName -eq 'DynamicNoMembers' }

                $params = @{
                    DisplayName = 'DynamicNoMembers'
                    Description = 'Dynamic'
                    GroupMembershipType = 'Dynamic'
                    Members = @("(user.department -eq 'HR')")
                    Owners = @('owner@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdGroupMember -Times 0 -Exactly
            }
        }

        Context 'Valid input scenarios - Updating existing groups' {
            It 'Updates group description when it differs' {
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    @{
                        Id = '66666666-6666-6666-6666-666666666666'
                        DisplayName = 'ExistingGroup'
                        Description = 'Old Description'
                    }
                }

                $params = @{
                    DisplayName = 'ExistingGroup'
                    Description = 'New Description'
                    Owners = @('owner@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgGroup -Times 1 -Exactly -ParameterFilter {
                    $Description -eq 'New Description'
                }
            }

            It 'Does not update when group is already in desired state' {
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    @{
                        Id = '77777777-7777-7777-7777-777777777777'
                        DisplayName = 'ExistingGroup'
                        Description = 'Correct Description'
                    }
                }
                Mock -CommandName Get-EntraIdGroupMember -MockWith { @('user1@test.com') }
                Mock -CommandName Get-EntraIdGroupOwner -MockWith { @('owner@test.com') }

                $params = @{
                    DisplayName = 'ExistingGroup'
                    Description = 'Correct Description'
                    Members = @('user1@test.com')
                    Owners = @('owner@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgGroup -Times 0 -Exactly
                Should -Invoke -CommandName Add-EntraIdGroupMember -Times 0 -Exactly
                Should -Invoke -CommandName Remove-EntraIdGroupMember -Times 0 -Exactly
                Should -Invoke -CommandName Add-EntraIdGroupOwner -Times 0 -Exactly
                Should -Invoke -CommandName Remove-EntraIdGroupOwner -Times 0 -Exactly
            }

            It 'Adds missing members to existing group' {
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    @{
                        Id = '88888888-8888-8888-8888-888888888888'
                        DisplayName = 'ExistingGroup'
                        Description = 'Test'
                    }
                }
                Mock -CommandName Get-EntraIdGroupMember -MockWith { @('user1@test.com') }
                Mock -CommandName Get-EntraIdGroupOwner -MockWith { @('owner@test.com') }

                $params = @{
                    DisplayName = 'ExistingGroup'
                    Description = 'Test'
                    Members = @('user1@test.com', 'user2@test.com')
                    Owners = @('owner@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdGroupMember -Times 1 -Exactly -ParameterFilter {
                    $Members -contains 'user2@test.com' -and $Members.Count -eq 1
                }
            }

            It 'Removes extra members from existing group' {
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    @{
                        Id = '99999999-9999-9999-9999-999999999999'
                        DisplayName = 'ExistingGroup'
                        Description = 'Test'
                    }
                }
                Mock -CommandName Get-EntraIdGroupMember -MockWith { @('user1@test.com', 'user2@test.com') }
                Mock -CommandName Get-EntraIdGroupOwner -MockWith { @('owner@test.com') }

                $params = @{
                    DisplayName = 'ExistingGroup'
                    Description = 'Test'
                    Members = @('user1@test.com')
                    Owners = @('owner@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
                Should -Invoke -CommandName Remove-EntraIdGroupMember -Times 1 -Exactly -ParameterFilter {
                    $Members -contains 'user2@test.com' -and $Members.Count -eq 1
                }
            }

            It 'Synchronizes both members and owners' {
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    @{
                        Id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                        DisplayName = 'SyncGroup'
                        Description = 'Test'
                    }
                }
                Mock -CommandName Get-EntraIdGroupMember -MockWith { @('user1@test.com') }
                Mock -CommandName Get-EntraIdGroupOwner -MockWith { @('owner1@test.com') }

                $params = @{
                    DisplayName = 'SyncGroup'
                    Description = 'Test'
                    Members = @('user2@test.com')
                    Owners = @('owner2@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
                Should -Invoke -CommandName Add-EntraIdGroupMember -Times 1 -Exactly
                Should -Invoke -CommandName Remove-EntraIdGroupMember -Times 1 -Exactly
                Should -Invoke -CommandName Add-EntraIdGroupOwner -Times 1 -Exactly
                Should -Invoke -CommandName Remove-EntraIdGroupOwner -Times 1 -Exactly
            }
        }

        Context 'Valid input scenarios - Administrative Units' {
            It 'Creates group in Administrative Unit when specified' {
                $script:callCount = 0
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    $script:callCount++
                    if ($script:callCount -eq 1) {
                        return $null
                    }
                    else {
                        return @{
                            Id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
                            DisplayName = 'AUGroup'
                        }
                    }
                } -ParameterFilter { $DisplayName -eq 'AUGroup' }
                Mock -CommandName Get-MgDirectoryAdministrativeUnit -MockWith {
                    @{ Id = 'au-11111111-1111-1111-1111-111111111111'; DisplayName = 'TestAU' }
                }

                $params = @{
                    DisplayName = 'AUGroup'
                    Description = 'Test AU Group'
                    Owners = @('owner@test.com')
                    AdministrativeUnit = 'TestAU'
                    Confirm = $false
                    WhatIf = $false
                }

                Set-EntraIdGroup @params
                Should -Invoke -CommandName New-MgDirectoryAdministrativeUnitMember -Times 1 -Exactly
            }

            It 'Throws when Administrative Unit does not exist' {
                Mock -CommandName Get-EntraIdGroup -MockWith { $null }
                Mock -CommandName Get-MgDirectoryAdministrativeUnit -MockWith { $null }

                $params = @{
                    DisplayName = 'FailGroup'
                    Description = 'Test'
                    Owners = @('owner@test.com')
                    AdministrativeUnit = 'NonExistentAU'
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Throw "*Administrative Unit*not found*"
            }

            It 'Warns when trying to change AU membership for existing group' {
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    @{
                        Id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
                        DisplayName = 'ExistingAUGroup'
                        Description = 'Test'
                    }
                }
                Mock -CommandName Get-MgDirectoryAdministrativeUnit -MockWith {
                    @{ Id = 'au-22222222-2222-2222-2222-222222222222'; DisplayName = 'NewAU' }
                }
                Mock -CommandName Get-MgDirectoryAdministrativeUnitMember -MockWith { @() }

                $params = @{
                    DisplayName = 'ExistingAUGroup'
                    Description = 'Test'
                    Owners = @('owner@test.com')
                    AdministrativeUnit = 'NewAU'
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly
            }
        }

        Context 'Invalid input scenarios' {
            It 'Verifies DisplayName parameter is mandatory' {
                (Get-Command Set-EntraIdGroup).Parameters['DisplayName'].Attributes.Mandatory | Should -Be $true
            }

            It 'Verifies Description parameter is mandatory' {
                (Get-Command Set-EntraIdGroup).Parameters['Description'].Attributes.Mandatory | Should -Be $true
            }

            It 'Verifies Owners parameter is mandatory' {
                (Get-Command Set-EntraIdGroup).Parameters['Owners'].Attributes.Mandatory | Should -Be $true
            }

            It 'Throws when invalid GroupMembershipType is provided' {
                $params = @{
                    DisplayName = 'TestGroup'
                    Description = 'Test'
                    GroupMembershipType = 'Invalid'
                    Owners = @('owner@test.com')
                    Confirm = $false
                }
                { Set-EntraIdGroup @params } | Should -Throw
            }
        }

        Context 'Edge cases' {
            It 'Handles empty Members array' {
                Mock -CommandName Get-EntraIdGroup -MockWith { $null } -ParameterFilter { $DisplayName -eq 'NoMembers' }
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    @{
                        Id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
                        DisplayName = 'NoMembers'
                    }
                } -ParameterFilter { $DisplayName -eq 'NoMembers' }

                $params = @{
                    DisplayName = 'NoMembers'
                    Description = 'Test'
                    Members = @()
                    Owners = @('owner@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
            }

            It 'Removes all members when Members is null and group exists' {
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    @{
                        Id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
                        DisplayName = 'RemoveAllMembers'
                        Description = 'Test'
                    }
                }
                Mock -CommandName Get-EntraIdGroupMember -MockWith { @('user1@test.com', 'user2@test.com') }
                Mock -CommandName Get-EntraIdGroupOwner -MockWith { @('owner@test.com') }

                $params = @{
                    DisplayName = 'RemoveAllMembers'
                    Description = 'Test'
                    Owners = @('owner@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
                Should -Invoke -CommandName Remove-EntraIdGroupMember -Times 1 -Exactly -ParameterFilter {
                    $Members.Count -eq 2
                }
            }

            It 'Warns when IsAssignableToRole cannot be changed' {
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    @{
                        Id = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
                        DisplayName = 'ImmutableRole'
                        Description = 'Test'
                        IsAssignableToRole = $false
                    }
                }

                $params = @{
                    DisplayName = 'ImmutableRole'
                    Description = 'Test'
                    Owners = @('owner@test.com')
                    IsAssignableToRole = $true
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly
            }

            It 'Uses retry mechanism when checking group creation' {
                Mock -CommandName Get-EntraIdGroup -MockWith { $null } -ParameterFilter { $DisplayName -eq 'RetryGroup' }
                # First call returns null, subsequent calls return the group
                $script:callCount = 0
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    $script:callCount++
                    if ($script:callCount -le 2) {
                        return $null
                    }
                    return @{
                        Id = '10101010-1010-1010-1010-101010101010'
                        DisplayName = 'RetryGroup'
                    }
                } -ParameterFilter { $DisplayName -eq 'RetryGroup' }
                Mock -CommandName Start-Sleep -MockWith { }

                $params = @{
                    DisplayName = 'RetryGroup'
                    Description = 'Test'
                    Owners = @('owner@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
                Should -Invoke -CommandName Start-Sleep -Times 2 -Exactly
            }

            It 'Throws when group creation check fails after retries' {
                Mock -CommandName Get-EntraIdGroup -MockWith { $null }
                Mock -CommandName Start-Sleep -MockWith { }

                $params = @{
                    DisplayName = 'FailedRetry'
                    Description = 'Test'
                    Owners = @('owner@test.com')
                    Confirm = $false
                    WhatIf = $false
                }

                { Set-EntraIdGroup @params } | Should -Throw "*creation check failed*"
            }
        }

        Context 'ShouldProcess support' {
            It 'Supports -WhatIf for new group creation' {
                Mock -CommandName Get-EntraIdGroup -MockWith { $null }

                $params = @{
                    DisplayName = 'WhatIfGroup'
                    Description = 'Test'
                    Owners = @('owner@test.com')
                    WhatIf = $true
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
                Should -Invoke -CommandName New-MgGroup -Times 0 -Exactly
            }

            It 'Supports -WhatIf for group updates' {
                Mock -CommandName Get-EntraIdGroup -MockWith {
                    @{
                        Id = '12121212-1212-1212-1212-121212121212'
                        DisplayName = 'WhatIfUpdate'
                        Description = 'Old'
                    }
                }

                $params = @{
                    DisplayName = 'WhatIfUpdate'
                    Description = 'New'
                    Owners = @('owner@test.com')
                    WhatIf = $true
                }

                { Set-EntraIdGroup @params } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgGroup -Times 0 -Exactly
            }
        }

        # CodeCoverage: Ensure Set-EntraIdGroup is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}

