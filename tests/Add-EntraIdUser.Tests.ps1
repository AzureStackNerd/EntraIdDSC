# Pester tests for Add-EntraIdUser
# Purpose: Validate Add-EntraIdUser logic, input handling, and edge cases

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Add-EntraIdUser' {
        BeforeAll {
            # Mock external dependencies
            Mock -CommandName Test-GraphAuth -MockWith { $true }
            Mock -CommandName New-MgUser -MockWith { return @{ Id = '11111111-1111-1111-1111-111111111111'; UserPrincipalName = 'user@test.com' } }
        }

        Context 'Valid input scenarios' {
            It 'Creates a user with valid parameters' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                    AdditionalProperties = @{ GivenName = 'Test'; Surname = 'User' }
                }
                $result = Add-EntraIdUser @params
                $result | Should -Not -BeNullOrEmpty
                $result.UserPrincipalName | Should -Be 'user@test.com'
            }
        }

        Context 'Invalid input scenarios' {
            It 'Throws when UserPrincipalName is missing' {
                $params = @{
                    DisplayName = 'Test User'
                    AdditionalProperties = @{ GivenName = 'Test'; Surname = 'User' }
                }
                { Add-EntraIdUser @params } | Should -Throw
            }

            It 'Throws when DisplayName is missing' {
                $params = @{
                    UserPrincipalName = 'user@test.com'
                    AdditionalProperties = @{ GivenName = 'Test'; Surname = 'User' }
                }
                { Add-EntraIdUser @params } | Should -Throw
            }

            It 'Throws when UserPrincipalName is invalid format' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'notavalidemail'
                    AdditionalProperties = @{ GivenName = 'Test'; Surname = 'User' }
                }
                { Add-EntraIdUser @params } | Should -Throw "*not in a valid format*"
            }

            It 'Throws when DisplayName is whitespace only' {
                $params = @{
                    DisplayName = '   '
                    UserPrincipalName = 'user@test.com'
                }
                { Add-EntraIdUser @params } | Should -Throw "*DisplayName is required*"
            }

            It 'Throws when UserPrincipalName is whitespace only' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = '   '
                }
                { Add-EntraIdUser @params } | Should -Throw "*UserPrincipalName is required*"
            }

            It 'Throws when UserPrincipalName has no domain' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@'
                }
                { Add-EntraIdUser @params } | Should -Throw "*not in a valid format*"
            }

            It 'Throws when UserPrincipalName has no @' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'usertest.com'
                }
                { Add-EntraIdUser @params } | Should -Throw "*not in a valid format*"
            }
        }

        Context 'Edge cases' {
            It 'Handles empty AdditionalProperties' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                    AdditionalProperties = @{}
                }
                $result = Add-EntraIdUser @params
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Handles minimal valid input' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                }
                $result = Add-EntraIdUser @params
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Handles null AdditionalProperties' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                    AdditionalProperties = $null
                }
                { Add-EntraIdUser @params } | Should -Not -Throw
            }

            It 'Creates user with AccountEnabled set to false by default' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                }
                Add-EntraIdUser @params
                Should -Invoke -CommandName New-MgUser -Times 1 -Exactly -ParameterFilter {
                    $BodyParameter.AccountEnabled -eq $false
                }
            }

            It 'Creates user with ForceChangePasswordNextSignIn set to true' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                }
                Add-EntraIdUser @params
                Should -Invoke -CommandName New-MgUser -Times 1 -Exactly -ParameterFilter {
                    $BodyParameter.PasswordProfile.ForceChangePasswordNextSignIn -eq $true
                }
            }

            It 'Generates a GUID password for the user' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                }
                Add-EntraIdUser @params
                Should -Invoke -CommandName New-MgUser -Times 1 -Exactly -ParameterFilter {
                    $BodyParameter.PasswordProfile.Password -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                }
            }

            It 'Merges AdditionalProperties with base user object' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                    AdditionalProperties = @{
                        JobTitle = 'Manager'
                        Department = 'IT'
                        OfficeLocation = 'Building 5'
                    }
                }
                Add-EntraIdUser @params
                Should -Invoke -CommandName New-MgUser -Times 1 -Exactly -ParameterFilter {
                    $BodyParameter.JobTitle -eq 'Manager' -and
                    $BodyParameter.Department -eq 'IT' -and
                    $BodyParameter.OfficeLocation -eq 'Building 5'
                }
            }

            It 'Handles UPN with special characters' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user.name+tag@sub.domain.com'
                }
                { Add-EntraIdUser @params } | Should -Not -Throw
            }

            It 'Handles DisplayName with special characters' {
                $params = @{
                    DisplayName = "O'Brien, Test (Manager)"
                    UserPrincipalName = 'user@test.com'
                }
                { Add-EntraIdUser @params } | Should -Not -Throw
            }
        }

        Context 'Error handling' {
            It 'Throws when Test-GraphAuth fails' {
                Mock -CommandName Test-GraphAuth -MockWith { throw "Not authenticated" }

                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                }
                { Add-EntraIdUser @params } | Should -Throw "*Not authenticated*"
            }

            It 'Throws when New-MgUser fails' {
                Mock -CommandName New-MgUser -MockWith { throw "Graph API Error: User already exists" }

                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                }
                { Add-EntraIdUser @params } | Should -Throw "*User already exists*"
            }

            It 'Does not create user when Graph API throws permission error' {
                Mock -CommandName New-MgUser -MockWith { throw "Insufficient privileges" }

                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                }
                { Add-EntraIdUser @params } | Should -Throw "*Insufficient privileges*"
            }
        }

        Context 'ShouldProcess support' {
            It 'Supports -WhatIf' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                    WhatIf = $true
                }
                { Add-EntraIdUser @params } | Should -Not -Throw
                Should -Invoke -CommandName New-MgUser -Times 0 -Exactly
            }

            It 'Creates user when -Confirm:$false is specified' {
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                    Confirm = $false
                }
                { Add-EntraIdUser @params } | Should -Not -Throw
                Should -Invoke -CommandName New-MgUser -Times 1 -Exactly
            }
        }

        Context 'Output validation' {
            It 'Writes success message with DisplayName and UPN' {
                $params = @{
                    DisplayName = 'John Doe'
                    UserPrincipalName = 'john.doe@test.com'
                }
                $output = Add-EntraIdUser @params
                $output -join ' ' | Should -Match "User 'John Doe' with UPN 'john.doe@test.com' created successfully"
            }

            It 'Returns user object from New-MgUser' {
                Mock -CommandName New-MgUser -MockWith {
                    return @{
                        Id = '12345678-1234-1234-1234-123456789012'
                        UserPrincipalName = 'user@test.com'
                        DisplayName = 'Test User'
                    }
                }

                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                }
                $result = Add-EntraIdUser @params
                $result.Id | Should -Be '12345678-1234-1234-1234-123456789012'
            }
        }

        # CodeCoverage: Ensure Add-EntraIdUser is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
