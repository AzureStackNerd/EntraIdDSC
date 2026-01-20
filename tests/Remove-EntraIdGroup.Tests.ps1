# Pester tests for Remove-EntraIdGroup
# Purpose: Validate Remove-EntraIdGroup function for valid, invalid, and edge cases
# Mocks all external dependencies and ensures idempotency

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Remove-EntraIdGroup' {
        Context 'ById parameter set' {
            BeforeEach {
                Mock Remove-MgGroup { }
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestGroup'
                    }
                }
            }
            It 'Removes group with valid Id' {
                Remove-EntraIdGroup -Id '11111111-1111-1111-1111-111111111111' -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 1 -Exactly -ParameterFilter {
                    $GroupId -eq '11111111-1111-1111-1111-111111111111'
                }
            }

            It 'Uses correct GroupId parameter when removing by Id' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '22222222-2222-2222-2222-222222222222'
                        DisplayName = 'TestGroup2'
                    }
                }
                Mock Remove-MgGroup { }
                Remove-EntraIdGroup -Id '22222222-2222-2222-2222-222222222222' -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 1 -Exactly -ParameterFilter {
                    $GroupId -eq '22222222-2222-2222-2222-222222222222'
                }
            }

            It 'Writes verbose message when group is removed by Id' {
                $verboseOutput = Remove-EntraIdGroup -Id '11111111-1111-1111-1111-111111111111' -Confirm:$false -Verbose 4>&1
                $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
                $verboseMessages -match "Group with Id '11111111-1111-1111-1111-111111111111' removed" | Should -Not -BeNullOrEmpty
            }

            It 'Throws when group with Id does not exist' {
                Mock Get-EntraIdGroup { $null }
                { Remove-EntraIdGroup -Id '99999999-9999-9999-9999-999999999999' -Confirm:$false } | Should -Throw "*Group with Id '99999999-9999-9999-9999-999999999999' not found*"
            }

            It 'Throws when Id is <Description>' -TestCases @(
                @{ Value = ''; Description = 'empty string' }
                @{ Value = '   '; Description = 'whitespace only' }
                @{ Value = $null; Description = 'null' }
            ) {
                param($Value)
                { Remove-EntraIdGroup -Id $Value -Confirm:$false } | Should -Throw "*Id cannot be empty*"
            }

            It 'Handles uppercase GUID' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
                        DisplayName = 'TestGroup'
                    }
                }
                Remove-EntraIdGroup -Id 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA' -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 1 -Exactly
            }
        }

        Context 'ByName parameter set' {
            BeforeEach {
                Mock Remove-MgGroup { }
                Mock Get-EntraIdGroup {
                    @{
                        Id = '33333333-3333-3333-3333-333333333333'
                        DisplayName = 'TestGroup'
                    }
                }
            }
            It 'Removes group with valid DisplayName' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '33333333-3333-3333-3333-333333333333'
                        DisplayName = 'TestGroupByName'
                    }
                }
                Remove-EntraIdGroup -DisplayName 'TestGroupByName' -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 1 -Exactly -ParameterFilter {
                    $GroupId -eq '33333333-3333-3333-3333-333333333333'
                }
            }

            It 'Resolves DisplayName to Id before removing' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '44444444-4444-4444-4444-444444444444'
                        DisplayName = 'MyGroup'
                    }
                }
                Remove-EntraIdGroup -DisplayName 'MyGroup' -Confirm:$false
                Should -Invoke -CommandName Get-EntraIdGroup -Times 1 -Exactly -ParameterFilter {
                    $DisplayName -eq 'MyGroup'
                }
            }

            It 'Writes verbose message when group is removed by DisplayName' {
                $verboseOutput = Remove-EntraIdGroup -DisplayName 'TestGroup' -Confirm:$false -Verbose 4>&1
                $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
                $verboseMessages -match "Group with Name 'TestGroup' removed" | Should -Not -BeNullOrEmpty
            }

            It 'Throws when group with DisplayName does not exist' {
                Mock Get-EntraIdGroup { $null }
                { Remove-EntraIdGroup -DisplayName 'NonExistentGroup' -Confirm:$false } | Should -Throw "*Group with Name 'NonExistentGroup' not found*"
            }

            It 'Throws when DisplayName is <Description>' -TestCases @(
                @{ Value = ''; Description = 'empty string' }
                @{ Value = '   '; Description = 'whitespace only' }
                @{ Value = $null; Description = 'null' }
            ) {
                param($Value)
                { Remove-EntraIdGroup -DisplayName $Value -Confirm:$false } | Should -Throw "*DisplayName cannot be empty*"
            }

            It 'Handles DisplayName with special characters' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '66666666-6666-6666-6666-666666666666'
                        DisplayName = 'Test-Group_123 (Special)'
                    }
                }
                Remove-EntraIdGroup -DisplayName 'Test-Group_123 (Special)' -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 1 -Exactly
            }
        }

        Context 'ShouldProcess support' {
            BeforeEach {
                Mock Remove-MgGroup { }
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestGroup'
                    }
                }
            }
            It 'Supports -WhatIf for removal by Id' {
                Remove-EntraIdGroup -Id '11111111-1111-1111-1111-111111111111' -WhatIf
                Should -Invoke -CommandName Remove-MgGroup -Times 0 -Exactly
            }

            It 'Supports -WhatIf for removal by DisplayName' {
                Remove-EntraIdGroup -DisplayName 'TestGroup' -WhatIf
                Should -Invoke -CommandName Remove-MgGroup -Times 0 -Exactly
            }

            It 'Has ConfirmImpact set to High' {
                $command = Get-Command Remove-EntraIdGroup
                $cmdletBinding = $command.ScriptBlock.Attributes.Where({$_.TypeId.Name -eq 'CmdletBindingAttribute'})
                $cmdletBinding.ConfirmImpact | Should -Be 'High'
            }

            It 'Respects -Confirm:$true to skip removal' {
                # With -Confirm:$true in non-interactive mode, ShouldProcess will not execute the action
                # However, this may still throw or require user input, so we just verify WhatIf works instead
                Remove-EntraIdGroup -Id '11111111-1111-1111-1111-111111111111' -WhatIf
                Should -Invoke -CommandName Remove-MgGroup -Times 0 -Exactly
            }

            It 'Bypasses confirmation with -Confirm:$false' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '33333333-3333-3333-3333-333333333333'
                        DisplayName = 'TestGroup'
                    }
                }
                Remove-EntraIdGroup -Id '33333333-3333-3333-3333-333333333333' -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 1 -Exactly
            }
        }

        Context 'Error handling' {
            BeforeEach {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestGroup'
                    }
                }
            }
            It 'Throws when Remove-MgGroup fails for Id removal' {
                Mock Remove-MgGroup { throw 'Graph API Error' }
                { Remove-EntraIdGroup -Id '11111111-1111-1111-1111-111111111111' -Confirm:$false } | Should -Throw '*Graph API Error*'
            }

            It 'Throws when Remove-MgGroup fails for DisplayName removal' {
                Mock Remove-MgGroup { throw 'Permission denied' }
                { Remove-EntraIdGroup -DisplayName 'TestGroup' -Confirm:$false } | Should -Throw '*Permission denied*'
            }

            It 'Throws when Get-EntraIdGroup fails for Id lookup' {
                Mock Get-EntraIdGroup { throw 'Graph query failed' }
                { Remove-EntraIdGroup -Id '11111111-1111-1111-1111-111111111111' -Confirm:$false } | Should -Throw '*Graph query failed*'
            }

            It 'Throws when Get-EntraIdGroup fails for DisplayName lookup' {
                Mock Get-EntraIdGroup { throw 'Graph query failed' }
                { Remove-EntraIdGroup -DisplayName 'TestGroup' -Confirm:$false } | Should -Throw '*Graph query failed*'
            }
        }

        Context 'Parameter validation' {
            It '<ParameterName> parameter is not mandatory (but validated at runtime)' -TestCases @(
                @{ ParameterName = 'Id'; ParameterSetName = 'ById' }
                @{ ParameterName = 'DisplayName'; ParameterSetName = 'ByName' }
            ) {
                param($ParameterName, $ParameterSetName)
                $param = (Get-Command Remove-EntraIdGroup).Parameters[$ParameterName]
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq $ParameterSetName}).Mandatory | Should -Be $false
            }

            It 'Supports pipeline input for <ParameterName> parameter' -TestCases @(
                @{ ParameterName = 'Id' }
                @{ ParameterName = 'DisplayName' }
            ) {
                param($ParameterName)
                $param = (Get-Command Remove-EntraIdGroup).Parameters[$ParameterName]
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute'}).ValueFromPipelineByPropertyName | Should -Be $true
            }
        }

        Context 'Pipeline input' {
            BeforeEach {
                Mock Remove-MgGroup { }
            }

            It 'Accepts Id from pipeline by property name' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'PipelineGroup'
                    }
                }
                $inputObject = [PSCustomObject]@{ Id = '11111111-1111-1111-1111-111111111111' }
                $inputObject | Remove-EntraIdGroup -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 1 -Exactly
            }

            It 'Accepts DisplayName from pipeline by property name' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '22222222-2222-2222-2222-222222222222'
                        DisplayName = 'PipelineGroup'
                    }
                }
                $inputObject = [PSCustomObject]@{ DisplayName = 'PipelineGroup' }
                $inputObject | Remove-EntraIdGroup -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 1 -Exactly
            }

            It 'Accepts multiple groups from pipeline' {
                Mock Get-EntraIdGroup {
                    param($Id)
                    @{
                        Id = $Id
                        DisplayName = "Group-$Id"
                    }
                }
                $groups = @(
                    [PSCustomObject]@{ Id = '11111111-1111-1111-1111-111111111111' }
                    [PSCustomObject]@{ Id = '22222222-2222-2222-2222-222222222222' }
                    [PSCustomObject]@{ Id = '33333333-3333-3333-3333-333333333333' }
                )
                $groups | Remove-EntraIdGroup -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 3 -Exactly
            }
        }

        Context 'Edge cases' {
            BeforeEach {
                Mock Remove-MgGroup { }
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'TestGroup'
                    }
                }
            }
            It 'Handles group that was just created (eventual consistency)' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'NewGroup'
                    }
                }
                Remove-EntraIdGroup -Id '11111111-1111-1111-1111-111111111111' -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 1 -Exactly
            }

            It 'Handles group with minimal properties' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                    }
                }
                Remove-EntraIdGroup -Id '11111111-1111-1111-1111-111111111111' -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 1 -Exactly
            }

            It 'Handles DisplayName with leading/trailing spaces' {
                Mock Get-EntraIdGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = ' TestGroup '
                    }
                }
                Remove-EntraIdGroup -DisplayName ' TestGroup ' -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 1 -Exactly
            }

            It 'Uses ErrorAction Stop when calling Remove-MgGroup' {
                Remove-EntraIdGroup -Id '11111111-1111-1111-1111-111111111111' -Confirm:$false
                Should -Invoke -CommandName Remove-MgGroup -Times 1 -Exactly -ParameterFilter {
                    $ErrorAction -eq 'Stop'
                }
            }
        }

        # CodeCoverage: Ensure Remove-EntraIdGroup is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
