
Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe "Get-EntraIdGroup" {
        BeforeAll {
            Mock Test-GraphAuth { }
        }
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
            It "Uses correct filter parameter with displayName eq operator" {
                Mock Get-MgGroup { @{DisplayName = 'TestGroup' } }
                Get-EntraIdGroup -DisplayName "TestGroup"
                Should -Invoke -CommandName Get-MgGroup -Times 1 -Exactly -ParameterFilter {
                    $Filter -eq "displayName eq 'TestGroup'"
                }
            }
            It "Returns multiple groups when Get-MgGroup returns array" {
                Mock Get-MgGroup {
                    @(
                        @{Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' },
                        @{Id = '22222222-2222-2222-2222-222222222222'; DisplayName = 'TestGroup' }
                    )
                }
                $result = Get-EntraIdGroup -DisplayName "TestGroup"
                $result.Count | Should -Be 2
            }
            It "Handles display names with special characters" {
                Mock Get-MgGroup { @{DisplayName = "Test-Group_123 (Special)" } }
                $result = Get-EntraIdGroup -DisplayName "Test-Group_123 (Special)"
                $result.DisplayName | Should -Be "Test-Group_123 (Special)"
            }
            It "Handles display names with single quotes" {
                Mock Get-MgGroup { @{DisplayName = "Test'Group" } }
                $result = Get-EntraIdGroup -DisplayName "Test'Group"
                $result.DisplayName | Should -Be "Test'Group"
            }
            It "Writes verbose message when group not found" {
                Mock Get-MgGroup { $null }
                $verboseOutput = Get-EntraIdGroup -DisplayName "NonExistent" -Verbose 4>&1
                $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | Should -Match "No group found with display name 'NonExistent'"
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
            It "Uses correct GroupId parameter" {
                Mock Get-MgGroup { @{Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' } }
                Get-EntraIdGroup -Id "11111111-1111-1111-1111-111111111111"
                Should -Invoke -CommandName Get-MgGroup -Times 1 -Exactly -ParameterFilter {
                    $GroupId -eq '11111111-1111-1111-1111-111111111111'
                }
            }
            It "Writes verbose message when searching by Id" {
                Mock Get-MgGroup { @{Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'TestGroup' } }
                $verboseOutput = Get-EntraIdGroup -Id "11111111-1111-1111-1111-111111111111" -Verbose 4>&1
                $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | Should -Match "Searching for group with Id '11111111-1111-1111-1111-111111111111'"
            }
            It "Writes verbose message when group not found by Id" {
                Mock Get-MgGroup { $null }
                $verboseOutput = Get-EntraIdGroup -Id "22222222-2222-2222-2222-222222222222" -Verbose 4>&1
                $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | Select-Object -Last 1 | Should -Match "No group found with Id '22222222-2222-2222-2222-222222222222'"
            }
            It "Handles uppercase GUID" {
                Mock Get-MgGroup { @{Id = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'; DisplayName = 'TestGroup' } }
                $result = Get-EntraIdGroup -Id "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
                $result.Id | Should -Be 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
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
            It "Uses -All parameter to retrieve all groups" {
                Mock Get-MgGroup -ParameterFilter { $All -eq $true } {
                    @(@{DisplayName = 'UG-PIM-Alpha' })
                }
                Get-EntraIdGroup -DisplayNamePattern "UG-PIM-*"
                Should -Invoke -CommandName Get-MgGroup -Times 1 -Exactly -ParameterFilter {
                    $All -eq $true
                }
            }
            It "Handles pattern with question mark wildcard" {
                Mock Get-MgGroup -ParameterFilter { $true } {
                    @(
                        @{DisplayName = 'Test1' },
                        @{DisplayName = 'Test2' },
                        @{DisplayName = 'Testing' }
                    )
                }
                $result = Get-EntraIdGroup -DisplayNamePattern "Test?"
                $result.Count | Should -Be 2
            }
            It "Handles pattern with middle wildcard" {
                Mock Get-MgGroup -ParameterFilter { $true } {
                    @(
                        @{DisplayName = 'Prefix-Alpha-Suffix' },
                        @{DisplayName = 'Prefix-Beta-Suffix' },
                        @{DisplayName = 'OtherGroup' }
                    )
                }
                $result = Get-EntraIdGroup -DisplayNamePattern "Prefix-*-Suffix"
                $result.Count | Should -Be 2
            }
            It "Handles exact match pattern without wildcards" {
                Mock Get-MgGroup -ParameterFilter { $true } {
                    @(
                        @{DisplayName = 'ExactMatch' },
                        @{DisplayName = 'ExactMatchPlus' }
                    )
                }
                $result = Get-EntraIdGroup -DisplayNamePattern "ExactMatch"
                $result.Count | Should -Be 1
                $result.DisplayName | Should -Be 'ExactMatch'
            }
            It "Is case-insensitive in pattern matching" {
                Mock Get-MgGroup -ParameterFilter { $true } {
                    @(@{DisplayName = 'TestGroup' })
                }
                $result = Get-EntraIdGroup -DisplayNamePattern "testgroup"
                $result | Should -Not -BeNullOrEmpty
                $result.DisplayName | Should -Be 'TestGroup'
            }
            It "Writes verbose message when no groups match pattern" {
                Mock Get-MgGroup -ParameterFilter { $true } { @() }
                $verboseOutput = Get-EntraIdGroup -DisplayNamePattern "NoMatch-*" -Verbose 4>&1
                $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | Should -Match "No groups found matching pattern 'NoMatch-\*'"
            }
            It "Returns empty array when Get-MgGroup returns empty array" {
                Mock Get-MgGroup -ParameterFilter { $true } { @() }
                $result = Get-EntraIdGroup -DisplayNamePattern "Empty-*"
                $result | Should -Be $null
            }
        }

        Context "Error handling" {
            It "Throws when Test-GraphAuth fails" {
                Mock Test-GraphAuth { throw "Not authenticated" }
                { Get-EntraIdGroup -DisplayName "TestGroup" } | Should -Throw "*Not authenticated*"
            }
            It "Throws when Get-MgGroup fails for DisplayName search" {
                Mock Get-MgGroup { throw "Graph API Error" }
                { Get-EntraIdGroup -DisplayName "TestGroup" } | Should -Throw "*Graph API Error*"
            }
            It "Throws when Get-MgGroup fails for Id search" {
                Mock Get-MgGroup { throw "Group not found" }
                { Get-EntraIdGroup -Id "11111111-1111-1111-1111-111111111111" } | Should -Throw "*Group not found*"
            }
            It "Throws when Get-MgGroup fails for pattern search" {
                Mock Get-MgGroup -ParameterFilter { $true } { throw "Permission denied" }
                { Get-EntraIdGroup -DisplayNamePattern "Test-*" } | Should -Throw "*Permission denied*"
            }
        }

        Context "Parameter validation" {
            It "<ParameterName> is <MandatoryStatus> in <ParameterSetName> parameter set" -TestCases @(
                @{ ParameterName = 'DisplayName'; ParameterSetName = 'ByDisplayName'; IsMandatory = $true; MandatoryStatus = 'mandatory' }
                @{ ParameterName = 'Id'; ParameterSetName = 'ById'; IsMandatory = $true; MandatoryStatus = 'mandatory' }
                @{ ParameterName = 'DisplayNamePattern'; ParameterSetName = 'ByDisplayNamePattern'; IsMandatory = $false; MandatoryStatus = 'not mandatory' }
            ) {
                param($ParameterName, $ParameterSetName, $IsMandatory)
                $param = (Get-Command Get-EntraIdGroup).Parameters[$ParameterName]
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq $ParameterSetName}).Mandatory | Should -Be $IsMandatory
            }
        }

        Context "Pipeline input" {
            It "Accepts DisplayName from pipeline" {
                Mock Get-MgGroup { @{DisplayName = 'PipelineGroup' } }
                $result = "PipelineGroup" | Get-EntraIdGroup
                $result.DisplayName | Should -Be 'PipelineGroup'
            }
            It "Accepts Id from pipeline" {
                Mock Get-MgGroup { @{Id = '11111111-1111-1111-1111-111111111111'; DisplayName = 'PipelineGroup' } }
                $result = "11111111-1111-1111-1111-111111111111" | Get-EntraIdGroup -Id { $_ }
                $result.DisplayName | Should -Be 'PipelineGroup'
            }
            It "Accepts object with DisplayName property from pipeline" {
                Mock Get-MgGroup { @{DisplayName = 'ObjectGroup' } }
                $inputObject = [PSCustomObject]@{ DisplayName = 'ObjectGroup' }
                $result = $inputObject | Get-EntraIdGroup
                $result.DisplayName | Should -Be 'ObjectGroup'
            }
        }

        Context "Edge cases" {
            It "Handles empty string DisplayName" {
                # Empty strings are not allowed by PowerShell parameter validation
                { Get-EntraIdGroup -DisplayName "" } | Should -Throw "*Cannot bind argument to parameter 'DisplayName'*"
            }
            It "Handles whitespace-only DisplayName" {
                Mock Get-MgGroup { $null }
                Get-EntraIdGroup -DisplayName "   "
                Should -Invoke -CommandName Get-MgGroup -Times 1 -Exactly -ParameterFilter {
                    $Filter -eq "displayName eq '   '"
                }
            }
            It "Handles DisplayName with leading/trailing spaces" {
                Mock Get-MgGroup { @{DisplayName = ' TestGroup ' } }
                $result = Get-EntraIdGroup -DisplayName " TestGroup "
                $result.DisplayName | Should -Be ' TestGroup '
            }
            It "Returns complete group object with all properties" {
                Mock Get-MgGroup {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        DisplayName = 'CompleteGroup'
                        Description = 'Test Description'
                        MailEnabled = $false
                        SecurityEnabled = $true
                        GroupTypes = @()
                    }
                }
                $result = Get-EntraIdGroup -DisplayName "CompleteGroup"
                $result.Id | Should -Be '11111111-1111-1111-1111-111111111111'
                $result.Description | Should -Be 'Test Description'
                $result.MailEnabled | Should -Be $false
                $result.SecurityEnabled | Should -Be $true
            }
        }

        # CodeCoverage: Ensure Get-EntraIdGroup is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
