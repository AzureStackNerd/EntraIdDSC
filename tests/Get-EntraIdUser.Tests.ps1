# Pester tests for Get-EntraIdUser
# Purpose: Validate Get-EntraIdUser logic, input handling, and edge cases

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    BeforeAll {
        Mock Test-GraphAuth { }
    }
    Describe 'Get-EntraIdUser' {
        BeforeAll {
            # Mock external dependencies with generic fallbacks
            Mock -CommandName Get-MgUser -MockWith {
                return @{
                    Id = '11111111-1111-1111-1111-111111111111'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Test User'
                }
            }
        }

        Context 'ByUPN parameter set' {
            It 'Returns user when UserPrincipalName exists' {
                Mock Get-MgUser {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        UserPrincipalName = 'testuser@test.com'
                        DisplayName = 'Test User'
                    }
                }
                $result = Get-EntraIdUser -UserPrincipalName 'testuser@test.com'
                $result.UserPrincipalName | Should -Be 'testuser@test.com'
            }

            It 'Returns null when UserPrincipalName does not exist' {
                Mock Get-MgUser { $null }
                $result = Get-EntraIdUser -UserPrincipalName 'notfound@test.com'
                $result | Should -Be $null
            }

            It 'Uses correct UserId parameter with UserPrincipalName' {
                Mock Get-MgUser {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        UserPrincipalName = 'testuser@test.com'
                    }
                }
                Get-EntraIdUser -UserPrincipalName 'testuser@test.com'
                Should -Invoke -CommandName Get-MgUser -Times 1 -Exactly -ParameterFilter {
                    $UserId -eq 'testuser@test.com'
                }
            }

            It 'Writes warning when user not found by UPN' {
                Mock Get-MgUser { $null }
                $result = Get-EntraIdUser -UserPrincipalName 'notfound@test.com' -WarningVariable warn
                $warn | Should -Match "No user found with UPN 'notfound@test.com'"
            }

            It 'Handles UPN with special characters' {
                Mock Get-MgUser {
                    @{ UserPrincipalName = 'user.name+tag@test.com' }
                }
                $result = Get-EntraIdUser -UserPrincipalName 'user.name+tag@test.com'
                $result.UserPrincipalName | Should -Be 'user.name+tag@test.com'
            }

            It 'Handles uppercase UPN' {
                Mock Get-MgUser {
                    @{ UserPrincipalName = 'USER@TEST.COM' }
                }
                $result = Get-EntraIdUser -UserPrincipalName 'USER@TEST.COM'
                $result.UserPrincipalName | Should -Be 'USER@TEST.COM'
            }

            It 'Throws when UserPrincipalName is empty string' {
                { Get-EntraIdUser -UserPrincipalName '' } | Should -Throw "*UserPrincipalName*required*"
            }

            It 'Throws when UserPrincipalName is whitespace only' {
                { Get-EntraIdUser -UserPrincipalName '   ' } | Should -Throw "*UserPrincipalName*required*"
            }
        }

        Context 'ById parameter set' {
            It 'Returns user when Id exists' {
                Mock Get-MgUser {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        UserPrincipalName = 'user@test.com'
                        DisplayName = 'Test User By Id'
                    }
                }
                $result = Get-EntraIdUser -Id '11111111-1111-1111-1111-111111111111'
                $result.Id | Should -Be '11111111-1111-1111-1111-111111111111'
            }

            It 'Returns user with correct UserPrincipalName when called by Id' {
                Mock Get-MgUser {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        UserPrincipalName = 'userbyid@test.com'
                    }
                }
                $result = Get-EntraIdUser -Id '11111111-1111-1111-1111-111111111111'
                $result.UserPrincipalName | Should -Be 'userbyid@test.com'
            }

            It 'Returns null when Id does not exist' {
                Mock Get-MgUser { $null }
                $result = Get-EntraIdUser -Id '22222222-2222-2222-2222-222222222222'
                $result | Should -Be $null
            }

            It 'Uses correct UserId parameter with Id' {
                Mock Get-MgUser {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        UserPrincipalName = 'user@test.com'
                    }
                }
                Get-EntraIdUser -Id '11111111-1111-1111-1111-111111111111'
                Should -Invoke -CommandName Get-MgUser -Times 1 -Exactly -ParameterFilter {
                    $UserId -eq '11111111-1111-1111-1111-111111111111'
                }
            }

            It 'Writes warning when user not found by Id' {
                Mock Get-MgUser { $null }
                $result = Get-EntraIdUser -Id '22222222-2222-2222-2222-222222222222' -WarningVariable warn
                $warn | Should -Match "No user found with Id '22222222-2222-2222-2222-222222222222'"
            }

            It 'Handles uppercase GUID' {
                Mock Get-MgUser {
                    @{
                        Id = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
                        UserPrincipalName = 'user@test.com'
                    }
                }
                $result = Get-EntraIdUser -Id 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
                $result.Id | Should -Be 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
            }

            It 'Throws when Id is empty string' {
                { Get-EntraIdUser -Id '' } | Should -Throw "*Id*required*"
            }

            It 'Throws when Id is whitespace only' {
                { Get-EntraIdUser -Id '   ' } | Should -Throw "*Id*required*"
            }
        }

        Context 'Error handling' {
            It 'Throws when Test-GraphAuth fails' {
                Mock Test-GraphAuth { throw 'Not authenticated' }
                { Get-EntraIdUser -UserPrincipalName 'user@test.com' } | Should -Throw '*Not authenticated*'
            }

            It 'Throws when Get-MgUser fails for UPN search' {
                Mock Get-MgUser { throw 'Graph API Error' }
                { Get-EntraIdUser -UserPrincipalName 'user@test.com' } | Should -Throw '*Graph API Error*'
            }

            It 'Throws when Get-MgUser fails for Id search' {
                Mock Get-MgUser { throw 'User not found' }
                { Get-EntraIdUser -Id '11111111-1111-1111-1111-111111111111' } | Should -Throw '*User not found*'
            }

            It 'Handles empty result array from Get-MgUser' {
                Mock Get-MgUser { @() }
                $result = Get-EntraIdUser -UserPrincipalName 'empty@test.com' -WarningVariable warn
                $result | Should -Be $null
                $warn | Should -Match "No user found"
            }
        }

        Context 'Parameter validation' {
            It 'Id parameter is not mandatory (but validated at runtime)' {
                $param = (Get-Command Get-EntraIdUser).Parameters['Id']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ById'}).Mandatory | Should -Be $false
            }

            It 'UserPrincipalName parameter is not mandatory (but validated at runtime)' {
                $param = (Get-Command Get-EntraIdUser).Parameters['UserPrincipalName']
                $param.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByUPN'}).Mandatory | Should -Be $false
            }

            It 'Throws when neither Id nor UserPrincipalName is provided' {
                { Get-EntraIdUser } | Should -Throw "*required*"
            }
        }

        Context 'Pipeline input' {
            It 'Accepts UserPrincipalName from pipeline' {
                Mock Get-MgUser {
                    @{ UserPrincipalName = 'pipeline@test.com' }
                }
                $result = 'pipeline@test.com' | Get-EntraIdUser -UserPrincipalName { $_ }
                $result.UserPrincipalName | Should -Be 'pipeline@test.com'
            }

            It 'Accepts Id from pipeline' {
                Mock Get-MgUser {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        UserPrincipalName = 'pipeline@test.com'
                    }
                }
                $result = '11111111-1111-1111-1111-111111111111' | Get-EntraIdUser -Id { $_ }
                $result.Id | Should -Be '11111111-1111-1111-1111-111111111111'
            }

            It 'Accepts object with UserPrincipalName property from pipeline' {
                Mock Get-MgUser {
                    @{ UserPrincipalName = 'object@test.com' }
                }
                $inputObject = [PSCustomObject]@{ UserPrincipalName = 'object@test.com' }
                $result = $inputObject | Get-EntraIdUser -UserPrincipalName { $_.UserPrincipalName }
                $result.UserPrincipalName | Should -Be 'object@test.com'
            }
        }

        Context 'Edge cases' {
            It 'Returns complete user object with all properties' {
                Mock Get-MgUser {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        UserPrincipalName = 'complete@test.com'
                        DisplayName = 'Complete User'
                        Mail = 'complete@test.com'
                        JobTitle = 'Engineer'
                        Department = 'IT'
                        AccountEnabled = $true
                    }
                }
                $result = Get-EntraIdUser -UserPrincipalName 'complete@test.com'
                $result.Id | Should -Be '11111111-1111-1111-1111-111111111111'
                $result.DisplayName | Should -Be 'Complete User'
                $result.JobTitle | Should -Be 'Engineer'
                $result.Department | Should -Be 'IT'
                $result.AccountEnabled | Should -Be $true
            }

            It 'Handles user with null or missing properties gracefully' {
                Mock Get-MgUser {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        UserPrincipalName = 'minimal@test.com'
                    }
                }
                $result = Get-EntraIdUser -UserPrincipalName 'minimal@test.com'
                $result.Id | Should -Be '11111111-1111-1111-1111-111111111111'
                $result.UserPrincipalName | Should -Be 'minimal@test.com'
            }

            It 'Requests all user properties from Graph API' {
                Mock Get-MgUser {
                    @{ UserPrincipalName = 'user@test.com' }
                }
                Get-EntraIdUser -UserPrincipalName 'user@test.com'
                Should -Invoke -CommandName Get-MgUser -Times 1 -Exactly -ParameterFilter {
                    $Property -contains 'UserPrincipalName' -and
                    $Property -contains 'DisplayName' -and
                    $Property -contains 'Mail' -and
                    $Property.Count -gt 100
                }
            }

            It 'Handles disabled user accounts' {
                Mock Get-MgUser {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        UserPrincipalName = 'disabled@test.com'
                        AccountEnabled = $false
                    }
                }
                $result = Get-EntraIdUser -UserPrincipalName 'disabled@test.com'
                $result.AccountEnabled | Should -Be $false
            }

            It 'Handles guest users (external users)' {
                Mock Get-MgUser {
                    @{
                        Id = '11111111-1111-1111-1111-111111111111'
                        UserPrincipalName = 'guest_external.com#EXT#@tenant.onmicrosoft.com'
                        UserType = 'Guest'
                    }
                }
                $result = Get-EntraIdUser -UserPrincipalName 'guest_external.com#EXT#@tenant.onmicrosoft.com'
                $result.UserType | Should -Be 'Guest'
            }
        }

        # CodeCoverage: Ensure Get-EntraIdUser is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
