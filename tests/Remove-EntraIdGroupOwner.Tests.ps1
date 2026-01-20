# Pester tests for Remove-EntraIdGroupOwner
# Purpose: Validate Remove-EntraIdGroupOwner function for valid, invalid, and edge cases
# Mocks all external dependencies and ensures idempotency

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Remove-EntraIdGroupOwner' {
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
            Mock -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -MockWith { }
        }

        Context 'ById parameter set - Removing user owners' {
            It 'Removes a single user owner by GroupId' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestGroup'
                    }
                }
                Mock Get-EntraIdUser {
                    @{
                        Id = '22222222-2222-2222-2222-222222222222'
                        UserPrincipalName = 'owner@test.com'
                    }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                $output = Remove-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111' -Owners @('owner@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 1 -Exactly -ParameterFilter {
                    $GroupId -eq '11111111-1111-1111-1111-111111111111' -and
                    $DirectoryObjectId -eq '22222222-2222-2222-2222-222222222222'
                }
                $output | Should -Match "Removed Owner \(user\) owner@test.com"
            }

            It 'Removes multiple user owners by GroupId' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestGroup'
                    }
                }
                Mock Get-EntraIdUser {
                    param($UserPrincipalName)
                    if ($UserPrincipalName -eq 'owner1@test.com') {
                        @{ Id = 'owner-1111-1111-1111-111111111111'; UserPrincipalName = 'owner1@test.com' }
                    } else {
                        @{ Id = 'owner-2222-2222-2222-222222222222'; UserPrincipalName = 'owner2@test.com' }
                    }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                Remove-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111' -Owners @('owner1@test.com', 'owner2@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 2 -Exactly
            }

            It 'Uses GroupId parameter correctly' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner@test.com' }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                Remove-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111' -Owners @('owner@test.com') -Confirm:$false

                Should -Invoke -CommandName Get-EntraIdGroup -Times 1 -Exactly -ParameterFilter {
                    $Id -eq '11111111-1111-1111-1111-111111111111'
                }
            }

            It 'Warns when user owner does not exist' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser { $null }
                Mock Write-Warning { }

                Remove-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111' -Owners @('nonexistent@test.com') -Confirm:$false

                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -match 'User not found: nonexistent@test.com'
                }
            }
        }

        Context 'ByDisplayName parameter set - Removing user owners' {
            It 'Removes user owner by GroupDisplayName' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestGroup'
                    }
                }
                Mock Get-EntraIdUser {
                    @{
                        Id = '22222222-2222-2222-2222-222222222222'
                        UserPrincipalName = 'owner@test.com'
                    }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                $output = Remove-EntraIdGroupOwner -GroupDisplayName 'TestGroup' -Owners @('owner@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 1 -Exactly
                $output | Should -Match "Removed Owner \(user\) owner@test.com"
            }

            It 'Resolves GroupDisplayName to GroupId' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'MyTestGroup'
                    }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner@test.com' }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                Remove-EntraIdGroupOwner -GroupDisplayName 'MyTestGroup' -Owners @('owner@test.com') -Confirm:$false

                Should -Invoke -CommandName Get-EntraIdGroup -Times 1 -Exactly -ParameterFilter {
                    $DisplayName -eq 'MyTestGroup'
                }
            }

            It 'Warns when group with DisplayName does not exist' {
                Mock Get-EntraIdGroup { $null }
                Mock Write-Warning { }

                Remove-EntraIdGroupOwner -GroupDisplayName 'NonExistentGroup' -Owners @('owner@test.com') -Confirm:$false

                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -match "No group found with display name 'NonExistentGroup'"
                }
                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 0 -Exactly
            }
        }

        Context 'Removing group owners' {
            It 'Removes a group owner' {
                Mock Get-EntraIdGroup {
                    param($Id, $DisplayName)
                    if ($DisplayName -eq 'ParentGroup') {
                        @{ Id = 'parent-1111-1111-1111-111111111111'; DisplayName = 'ParentGroup' }
                    } else {
                        @{ Id = 'ownergroup-2222-2222-2222-222222222222'; DisplayName = 'OwnerGroup' }
                    }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                $output = Remove-EntraIdGroupOwner -GroupDisplayName 'ParentGroup' -Owners @('OwnerGroup') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 1 -Exactly -ParameterFilter {
                    $GroupId -eq 'parent-1111-1111-1111-111111111111' -and
                    $DirectoryObjectId -eq 'ownergroup-2222-2222-2222-222222222222'
                }
                $output | Should -Match "Removed Owner \(group\) OwnerGroup"
            }

            It 'Identifies owners without @ as groups' {
                Mock Get-EntraIdGroup {
                    param($Id, $DisplayName)
                    if ($DisplayName -eq 'TargetGroup') {
                        @{ Id = 'target-1111-1111-1111-111111111111'; DisplayName = 'TargetGroup' }
                    } else {
                        @{ Id = 'ownergroup-2222-2222-2222-222222222222'; DisplayName = 'OwnerGroupName' }
                    }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                Remove-EntraIdGroupOwner -GroupDisplayName 'TargetGroup' -Owners @('OwnerGroupName') -Confirm:$false

                Should -Invoke -CommandName Get-EntraIdGroup -Times 2 -Exactly
            }
        }

        Context 'Removing service principal owners' {
            It 'Removes service principal owner when group lookup fails' {
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
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                $output = Remove-EntraIdGroupOwner -GroupDisplayName 'TestGroup' -Owners @('MyServicePrincipal') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 1 -Exactly -ParameterFilter {
                    $DirectoryObjectId -eq 'spn-3333-3333-3333-333333333333'
                }
                $output | Should -Match "Removed Owner \(service principal\) MyServicePrincipal"
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
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                Remove-EntraIdGroupOwner -GroupDisplayName 'TestGroup' -Owners @('TestSP') -Confirm:$false

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

                Remove-EntraIdGroupOwner -GroupDisplayName 'TestGroup' -Owners @('NonExistent') -Confirm:$false

                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -match 'Group or ServicePrincipal not found: NonExistent'
                }
            }
        }

        Context 'Mixed owner types' {
            It 'Removes mixed owners (users, groups, service principals)' {
                Mock Get-EntraIdGroup {
                    param($Id, $DisplayName)
                    if ($DisplayName -eq 'TargetGroup') {
                        @{ Id = 'target-1111'; DisplayName = 'TargetGroup' }
                    } elseif ($DisplayName -eq 'OwnerGroup') {
                        @{ Id = 'ownergroup-2222'; DisplayName = 'OwnerGroup' }
                    } else {
                        $null
                    }
                }
                Mock Get-EntraIdUser {
                    @{ Id = 'user-3333'; UserPrincipalName = 'owner@test.com' }
                }
                Mock Get-EntraIdServicePrincipal {
                    @{ Id = 'spn-4444'; DisplayName = 'TestSP' }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                Remove-EntraIdGroupOwner -GroupDisplayName 'TargetGroup' -Owners @('owner@test.com', 'OwnerGroup', 'TestSP') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 3 -Exactly
            }
        }

        Context 'Error handling' {
            It 'Warns when Remove-MgGroupOwnerDirectoryObjectByRef fails for user' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner@test.com' }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { throw 'Graph API Error' }
                Mock Write-Warning { }

                Remove-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111' -Owners @('owner@test.com') -Confirm:$false

                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -match 'Failed to remove Owner \(user\) owner@test.com.*Graph API Error'
                }
            }

            It 'Warns when Remove-MgGroupOwnerDirectoryObjectByRef fails for group' {
                Mock Get-EntraIdGroup {
                    param($Id, $DisplayName)
                    if ($DisplayName -eq 'TargetGroup') {
                        @{ Id = 'target-1111'; DisplayName = 'TargetGroup' }
                    } else {
                        @{ Id = 'ownergroup-2222'; DisplayName = 'OwnerGroup' }
                    }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { throw 'Permission denied' }
                Mock Write-Warning { }

                Remove-EntraIdGroupOwner -GroupDisplayName 'TargetGroup' -Owners @('OwnerGroup') -Confirm:$false

                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -match 'Failed to remove Owner \(group\) OwnerGroup.*Permission denied'
                }
            }

            It 'Warns when Remove-MgGroupOwnerDirectoryObjectByRef fails for service principal' {
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
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { throw 'Not authorized' }
                Mock Write-Warning { }

                Remove-EntraIdGroupOwner -GroupDisplayName 'TestGroup' -Owners @('TestSP') -Confirm:$false

                Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -match 'Failed to remove Owner \(service principal\) TestSP.*Not authorized'
                }
            }

            It 'Throws when Test-GraphAuth fails' {
                Mock Test-GraphAuth { throw 'Not authenticated' }

                { Remove-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111' -Owners @('owner@test.com') -Confirm:$false } | Should -Throw '*Not authenticated*'
            }

            It 'Continues processing other owners when one fails' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser {
                    param($UserPrincipalName)
                    if ($UserPrincipalName -eq 'owner1@test.com') {
                        @{ Id = 'owner-1111'; UserPrincipalName = 'owner1@test.com' }
                    } else {
                        @{ Id = 'owner-2222'; UserPrincipalName = 'owner2@test.com' }
                    }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef {
                    param($GroupId, $DirectoryObjectId)
                    if ($DirectoryObjectId -eq 'owner-1111') {
                        throw 'Error removing owner1'
                    }
                }
                Mock Write-Warning { }

                Remove-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111' -Owners @('owner1@test.com', 'owner2@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 2 -Exactly
            }
        }

        Context 'ShouldProcess support' {
            It 'Supports -WhatIf' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner@test.com' }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                Remove-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111' -Owners @('owner@test.com') -WhatIf

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 0 -Exactly
            }

            It 'Bypasses confirmation with -Confirm:$false' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner@test.com' }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                Remove-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111' -Owners @('owner@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 1 -Exactly
            }
        }

        Context 'Parameter validation' {
            It 'GroupId parameter is mandatory in ById parameter set' {
                $param = (Get-Command Remove-EntraIdGroupOwner).Parameters['GroupId']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ById'}).Mandatory | Should -Be $true
            }

            It 'GroupDisplayName parameter is mandatory in ByDisplayName parameter set' {
                $param = (Get-Command Remove-EntraIdGroupOwner).Parameters['GroupDisplayName']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByDisplayName'}).Mandatory | Should -Be $true
            }

            It 'Owners parameter is mandatory' {
                $param = (Get-Command Remove-EntraIdGroupOwner).Parameters['Owners']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute'}).Mandatory | Should -Be $true
            }

            It 'Supports pipeline input for GroupId' {
                $param = (Get-Command Remove-EntraIdGroupOwner).Parameters['GroupId']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute'}).ValueFromPipeline | Should -Be $true
            }

            It 'Supports pipeline input for GroupDisplayName' {
                $param = (Get-Command Remove-EntraIdGroupOwner).Parameters['GroupDisplayName']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute'}).ValueFromPipeline | Should -Be $true
            }
        }

        Context 'Pipeline input' {
            It 'Accepts GroupId from pipeline' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'PipelineGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner@test.com' }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                '11111111-1111-1111-1111-111111111111' | Remove-EntraIdGroupOwner -GroupId { $_ } -Owners @('owner@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 1 -Exactly
            }

            It 'Accepts GroupDisplayName from pipeline' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'PipelineGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner@test.com' }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                'PipelineGroup' | Remove-EntraIdGroupOwner -GroupDisplayName { $_ } -Owners @('owner@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 1 -Exactly
            }
        }

        Context 'Edge cases' {
            It 'Throws when Owners array is empty' {
                # PowerShell parameter validation prevents binding empty collections
                { Remove-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111' -Owners @() -Confirm:$false } | Should -Throw '*empty collection*'
            }

            It 'Handles UPN with special characters' {
                Mock Get-EntraIdGroup {
                    @{ Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' }
                }
                Mock Get-EntraIdUser {
                    @{ Id = '22222222-2222-2222-2222-222222222222'; UserPrincipalName = 'owner.name+tag@test.com' }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                Remove-EntraIdGroupOwner -GroupId '11111111-1111-1111-1111-111111111111' -Owners @('owner.name+tag@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 1 -Exactly
            }

            It 'Handles group DisplayName with special characters' {
                Mock Get-EntraIdGroup {
                    param($Id, $DisplayName)
                    if ($DisplayName -eq 'Target-Group_123') {
                        @{ Id = 'target-id'; DisplayName = 'Target-Group_123' }
                    } else {
                        @{ Id = 'owner-id'; DisplayName = 'Owner-Group_456' }
                    }
                }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                Remove-EntraIdGroupOwner -GroupDisplayName 'Target-Group_123' -Owners @('Owner-Group_456') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 1 -Exactly
            }

            It 'Returns early when group lookup fails by Id' {
                Mock Get-EntraIdGroup { $null }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                Remove-EntraIdGroupOwner -GroupId '99999999-9999-9999-9999-999999999999' -Owners @('owner@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 0 -Exactly
            }

            It 'Returns early when group lookup fails by DisplayName' {
                Mock Get-EntraIdGroup { $null }
                Mock Remove-MgGroupOwnerDirectoryObjectByRef { }

                Remove-EntraIdGroupOwner -GroupDisplayName 'NonExistentGroup' -Owners @('owner@test.com') -Confirm:$false

                Should -Invoke -CommandName Remove-MgGroupOwnerDirectoryObjectByRef -Times 0 -Exactly
            }
        }

        # CodeCoverage: Ensure Remove-EntraIdGroupOwner is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
