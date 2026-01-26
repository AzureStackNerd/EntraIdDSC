# Pester tests for Remove-EntraIdGroupMember
# Purpose: Validate Remove-EntraIdGroupMember function for valid, invalid, and edge cases
# Mocks all external dependencies and ensures idempotency

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Remove-EntraIdGroupMember' {
        BeforeAll {
            # Mock external dependencies with generic fallbacks
            Mock -CommandName Test-GraphAuth -MockWith { }
            Mock -CommandName Get-EntraIdGroup -MockWith {
                @{
                    Id = '11111111-1111-1111-1111-111111111111'
                    DisplayName = 'TestGroup'
                }
            }
            Mock -CommandName Get-EntraIdUser -MockWith {
                @{
                    Id = '22222222-2222-2222-2222-222222222222'
                    UserPrincipalName = 'user@test.com'
                }
            }
            Mock -CommandName Get-EntraIdServicePrincipal -MockWith {
                @{
                    Id = '33333333-3333-3333-3333-333333333333'
                    DisplayName = 'TestSP'
                }
            }
            Mock -CommandName Remove-MgGroupMemberDirectoryObjectByRef -MockWith { }
        }

        Context 'ById parameter set - Removing user members' {
            It 'Removes a single user member by GroupId' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestGroup'
                    }
                }
                Mock Get-EntraIdUser {
                    @{
                        Id = '22222222-2222-2222-2222-222222222222'
                        UserPrincipalName = 'user@test.com'
                    }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                $output = Remove-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111' -Members @('user@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 1 -Exactly -ParameterFilter {
                    $GroupId -eq '11111111-1111-1111-1111-111111111111' -and
                    $DirectoryObjectId -eq '22222222-2222-2222-2222-222222222222'
                }
                $output | Should -Match "Removed Member \(user\) user@test.com"
            }

            It 'Removes multiple user members by GroupId' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestGroup'
                    }
                }
                Mock Get-EntraIdUser {
                    param($UserPrincipalName)
                    if ($UserPrincipalName -eq 'user1@test.com') {
                        @{ Id = 'user-1111-1111-1111-111111111111'; UserPrincipalName = 'user1@test.com' }
                    } else {
                        @{ Id = 'user-2222-2222-2222-222222222222'; UserPrincipalName = 'user2@test.com' }
                    }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                Remove-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111' -Members @('user1@test.com', 'user2@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 2 -Exactly
            }

            It 'Uses GroupId parameter correctly' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user@test.com' }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                Remove-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111' -Members @('user@test.com') -Confirm:$false

                Should -Invoke -CommandName Get-EntraIdGroup -Times 1 -Exactly -ParameterFilter {
                    $Id -eq '11111111-1111-1111-1111-111111111111'
                }
            }

            It 'Warns when user member does not exist' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser { $null }
                Mock Write-Warning { }

                Remove-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111' -Members @('nonexistent@test.com') -Confirm:$false

                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -match 'User not found: nonexistent@test.com'
                }
            }
        }

        Context 'ByDisplayName parameter set - Removing user members' {
            It 'Removes user member by GroupDisplayName' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestGroup'
                    }
                }
                Mock Get-EntraIdUser {
                    @{
                        Id = '22222222-2222-2222-2222-222222222222'
                        UserPrincipalName = 'user@test.com'
                    }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                $output = Remove-EntraIdGroupMember -GroupDisplayName 'TestGroup' -Members @('user@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 1 -Exactly
                $output | Should -Match "Removed Member \(user\) user@test.com"
            }

            It 'Resolves GroupDisplayName to GroupId' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'MyTestGroup'
                    }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user@test.com' }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                Remove-EntraIdGroupMember -GroupDisplayName 'MyTestGroup' -Members @('user@test.com') -Confirm:$false

                Should -Invoke -CommandName Get-EntraIdGroup -Times 1 -Exactly -ParameterFilter {
                    $DisplayName -eq 'MyTestGroup'
                }
            }

            It 'Warns when group with DisplayName does not exist' {
                Mock Get-EntraIdGroup { $null }
                Mock Write-Warning { }

                Remove-EntraIdGroupMember -GroupDisplayName 'NonExistentGroup' -Members @('user@test.com') -Confirm:$false

                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -match "No group found with display name 'NonExistentGroup'"
                }
                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 0 -Exactly
            }
        }

        Context 'Removing group members' {
            It 'Removes a group member (nested group)' {
                Mock Get-EntraIdGroup {
                    param($Id, $DisplayName)
                    if ($DisplayName -eq 'ParentGroup') {
                        @{ Id = 'parent-1111-1111-1111-111111111111'; DisplayName = 'ParentGroup' }
                    } else {
                        @{ Id = 'child-2222-2222-2222-222222222222'; DisplayName = 'ChildGroup' }
                    }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                $output = Remove-EntraIdGroupMember -GroupDisplayName 'ParentGroup' -Members @('ChildGroup') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 1 -Exactly -ParameterFilter {
                    $GroupId -eq 'parent-1111-1111-1111-111111111111' -and
                    $DirectoryObjectId -eq 'child-2222-2222-2222-222222222222'
                }
                $output | Should -Match "Removed Member \(group\) ChildGroup"
            }

            It 'Identifies members without @ as groups' {
                Mock Get-EntraIdGroup {
                    param($Id, $DisplayName)
                    if ($DisplayName -eq 'ParentGroup') {
                        @{ Id = 'parent-1111-1111-1111-111111111111'; DisplayName = 'ParentGroup' }
                    } else {
                        @{ Id = 'nested-2222-2222-2222-222222222222'; DisplayName = 'NestedGroup' }
                    }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                Remove-EntraIdGroupMember -GroupDisplayName 'ParentGroup' -Members @('NestedGroup') -Confirm:$false

                Should -Invoke -CommandName Get-EntraIdGroup -Times 2 -Exactly
            }
        }

        Context 'Removing service principal members' {
            It 'Removes service principal member when group lookup fails' {
                Mock Get-EntraIdGroup {
                    param($Id, $DisplayName)
                    if ($DisplayName -eq 'TestGroup') {
                        @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                    } else {
                        $null
                    }
                }
                Mock Get-EntraIdServicePrincipal {
                    @{
                        Id = 'spn-3333-3333-3333-333333333333'
                        DisplayName = 'MyServicePrincipal'
                    }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                $output = Remove-EntraIdGroupMember -GroupDisplayName 'TestGroup' -Members @('MyServicePrincipal') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 1 -Exactly -ParameterFilter {
                    $DirectoryObjectId -eq 'spn-3333-3333-3333-333333333333'
                }
                $output | Should -Match "Removed Member \(service principal\) MyServicePrincipal"
            }

            It 'Tries service principal after group lookup fails' {
                Mock Get-EntraIdGroup {
                    param($DisplayName)
                    if ($DisplayName -eq 'TestGroup') {
                        @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                    } else {
                        $null
                    }
                }
                Mock Get-EntraIdServicePrincipal {
                    @{ Id = 'spn-id'; DisplayName = 'TestSP' }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                Remove-EntraIdGroupMember -GroupDisplayName 'TestGroup' -Members @('TestSP') -Confirm:$false

                Should -Invoke -CommandName Get-EntraIdServicePrincipal -Times 1 -Exactly
            }

            It 'Warns when neither group nor service principal is found' {
                Mock Get-EntraIdGroup {
                    param($DisplayName)
                    if ($DisplayName -eq 'TestGroup') {
                        @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                    } else {
                        $null
                    }
                }
                Mock Get-EntraIdServicePrincipal { $null }
                Mock Write-Warning { }

                Remove-EntraIdGroupMember -GroupDisplayName 'TestGroup' -Members @('NonExistent') -Confirm:$false

                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -match 'Group or ServicePrincipal not found: NonExistent'
                }
            }
        }

        Context 'Mixed member types' {
            It 'Removes mixed members (users, groups, service principals)' {
                Mock Get-EntraIdGroup {
                    param($Id, $DisplayName)
                    if ($DisplayName -eq 'ParentGroup') {
                        @{ Id = 'parent-1111'; DisplayName = 'ParentGroup' }
                    } elseif ($DisplayName -eq 'ChildGroup') {
                        @{ Id = 'child-2222'; DisplayName = 'ChildGroup' }
                    } else {
                        $null
                    }
                }
                Mock Get-EntraIdUser {
                    @{ Id = 'user-3333'; UserPrincipalName = 'user@test.com' }
                }
                Mock Get-EntraIdServicePrincipal {
                    @{ Id = 'spn-4444'; DisplayName = 'TestSP' }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                Remove-EntraIdGroupMember -GroupDisplayName 'ParentGroup' -Members @('user@test.com', 'ChildGroup', 'TestSP') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 3 -Exactly
            }
        }

        Context 'Error handling' {
            It 'Warns when Remove-MgGroupMemberDirectoryObjectByRef fails for user' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user@test.com' }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { throw 'Graph API Error' }
                Mock Write-Warning { }

                Remove-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111' -Members @('user@test.com') -Confirm:$false

                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -match 'Failed to remove Member \(user\) user@test.com.*Graph API Error'
                }
            }

            It 'Warns when Remove-MgGroupMemberDirectoryObjectByRef fails for group' {
                Mock Get-EntraIdGroup {
                    param($Id, $DisplayName)
                    if ($DisplayName -eq 'ParentGroup') {
                        @{ Id = 'parent-1111'; DisplayName = 'ParentGroup' }
                    } else {
                        @{ Id = 'child-2222'; DisplayName = 'ChildGroup' }
                    }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { throw 'Permission denied' }
                Mock Write-Warning { }

                Remove-EntraIdGroupMember -GroupDisplayName 'ParentGroup' -Members @('ChildGroup') -Confirm:$false

                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -match 'Failed to remove Member \(group\) ChildGroup.*Permission denied'
                }
            }

            It 'Warns when Remove-MgGroupMemberDirectoryObjectByRef fails for service principal' {
                Mock Get-EntraIdGroup {
                    param($DisplayName)
                    if ($DisplayName -eq 'TestGroup') {
                        @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                    } else {
                        $null
                    }
                }
                Mock Get-EntraIdServicePrincipal {
                    @{ Id = 'spn-id'; DisplayName = 'TestSP' }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { throw 'Not authorized' }
                Mock Write-Warning { }

                Remove-EntraIdGroupMember -GroupDisplayName 'TestGroup' -Members @('TestSP') -Confirm:$false

                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -match 'Failed to remove Member \(service principal\) TestSP.*Not authorized'
                }
            }

            It 'Throws when Test-GraphAuth fails' {
                Mock Test-GraphAuth { throw 'Not authenticated' }

                { Remove-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111' -Members @('user@test.com') -Confirm:$false } | Should -Throw '*Not authenticated*'
            }

            It 'Continues processing other members when one fails' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser {
                    param($UserPrincipalName)
                    if ($UserPrincipalName -eq 'user1@test.com') {
                        @{ Id = 'user-1111'; UserPrincipalName = 'user1@test.com' }
                    } else {
                        @{ Id = 'user-2222'; UserPrincipalName = 'user2@test.com' }
                    }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef {
                    param($GroupId, $DirectoryObjectId)
                    if ($DirectoryObjectId -eq 'user-1111') {
                        throw 'Error removing user1'
                    }
                }
                Mock Write-Warning { }

                Remove-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111' -Members @('user1@test.com', 'user2@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 2 -Exactly
            }
        }

        Context 'ShouldProcess support' {
            It 'Supports -WhatIf' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user@test.com' }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                Remove-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111' -Members @('user@test.com') -WhatIf

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 0 -Exactly
            }

            It 'Bypasses confirmation with -Confirm:$false' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user@test.com' }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                Remove-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111' -Members @('user@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 1 -Exactly
            }
        }

        Context 'Parameter validation' {
            It 'GroupId parameter is mandatory in ById parameter set' {
                $param = (Get-Command Remove-EntraIdGroupMember).Parameters['GroupId']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ById'}).Mandatory | Should -Be $true
            }

            It 'GroupDisplayName parameter is mandatory in ByDisplayName parameter set' {
                $param = (Get-Command Remove-EntraIdGroupMember).Parameters['GroupDisplayName']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByDisplayName'}).Mandatory | Should -Be $true
            }

            It 'Members parameter is mandatory' {
                $param = (Get-Command Remove-EntraIdGroupMember).Parameters['Members']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute'}).Mandatory | Should -Be $true
            }

            It 'Supports pipeline input for GroupId' {
                $param = (Get-Command Remove-EntraIdGroupMember).Parameters['GroupId']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute'}).ValueFromPipeline | Should -Be $true
            }

            It 'Supports pipeline input for GroupDisplayName' {
                $param = (Get-Command Remove-EntraIdGroupMember).Parameters['GroupDisplayName']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute'}).ValueFromPipeline | Should -Be $true
            }
        }

        Context 'Pipeline input' {
            It 'Accepts GroupId from pipeline' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'PipelineGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user@test.com' }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                '11111111-1111-1111-1111-111111111111' | Remove-EntraIdGroupMember -GroupId { $_ } -Members @('user@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 1 -Exactly
            }

            It 'Accepts GroupDisplayName from pipeline' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'PipelineGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user@test.com' }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                'PipelineGroup' | Remove-EntraIdGroupMember -Members @('user@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 1 -Exactly
            }
        }

        Context 'Edge cases' {
            It 'Throws when Members array is empty' {
                # PowerShell parameter validation prevents binding empty collections
                { Remove-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111' -Members @() -Confirm:$false } | Should -Throw '*empty collection*'
            }

            It 'Handles UPN with special characters' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'user.name+tag@test.com' }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                Remove-EntraIdGroupMember -GroupId '11111111-1111-1111-1111-111111111111' -Members @('user.name+tag@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 1 -Exactly
            }

            It 'Handles group DisplayName with special characters' {
                Mock Get-EntraIdGroup {
                    param($Id, $DisplayName)
                    if ($DisplayName -eq 'Parent-Group_123') {
                        @{ Id = 'parent-id'; DisplayName = 'Parent-Group_123' }
                    } else {
                        @{ Id = 'child-id'; DisplayName = 'Child-Group_456' }
                    }
                }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                Remove-EntraIdGroupMember -GroupDisplayName 'Parent-Group_123' -Members @('Child-Group_456') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 1 -Exactly
            }

            It 'Returns early when group lookup fails by Id' {
                Mock Get-EntraIdGroup { $null }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                Remove-EntraIdGroupMember -GroupId '99999999-9999-9999-9999-999999999999' -Members @('user@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 0 -Exactly
            }

            It 'Returns early when group lookup fails by DisplayName' {
                Mock Get-EntraIdGroup { $null }
                Mock Remove-MgGroupMemberDirectoryObjectByRef { }

                Remove-EntraIdGroupMember -GroupDisplayName 'NonExistentGroup' -Members @('user@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupMemberDirectoryObjectByRef -Times 0 -Exactly
            }
        }

        # CodeCoverage: Ensure Remove-EntraIdGroupMember is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
