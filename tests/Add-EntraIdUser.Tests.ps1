# Pester tests for Add-EntraIdUser
# Purpose: Validate Add-EntraIdUser logic, input handling, and edge cases

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Add-EntraIdUser' {
        Context 'Valid input scenarios' {
            BeforeEach {
                Mock Test-GraphAuth { $true }
                Mock New-MgUser { return @{ Id = '11111111-1111-1111-1111-111111111111'; UserPrincipalName = 'user@test.com' } }
            }
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
            BeforeEach {
                Mock Test-GraphAuth { $true }
                Mock New-MgUser { return @{ Id = '11111111-1111-1111-1111-111111111111'; UserPrincipalName = 'user@test.com' } }
            }

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

            It 'Throws when <Parameter> is whitespace only' -TestCases @(
                @{ Parameter = 'DisplayName'; DisplayName = '   '; UserPrincipalName = 'user@test.com'; ErrorMessage = '*DisplayName is required*' }
                @{ Parameter = 'UserPrincipalName'; DisplayName = 'Test User'; UserPrincipalName = '   '; ErrorMessage = '*UserPrincipalName is required*' }
            ) {
                param($DisplayName, $UserPrincipalName, $ErrorMessage)
                $params = @{
                    DisplayName = $DisplayName
                    UserPrincipalName = $UserPrincipalName
                }
                { Add-EntraIdUser @params } | Should -Throw $ErrorMessage
            }

            It 'Throws when UserPrincipalName is <Description>' -TestCases @(
                @{ UserPrincipalName = 'notavalidemail'; Description = 'invalid format' }
                @{ UserPrincipalName = 'user@'; Description = 'has no domain' }
                @{ UserPrincipalName = 'usertest.com'; Description = 'has no @' }
            ) {
                param($UserPrincipalName)
                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = $UserPrincipalName
                }
                { Add-EntraIdUser @params } | Should -Throw "*not in a valid format*"
            }
        }

        Context 'Edge cases' {
            BeforeEach {
                Mock Test-GraphAuth { $true }
                Mock New-MgUser { return @{ Id = '11111111-1111-1111-1111-111111111111'; UserPrincipalName = 'user@test.com' } }
            }
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
            It 'Throws when <Scenario>' -TestCases @(
                @{ Scenario = 'Test-GraphAuth fails'; MockCommand = 'Test-GraphAuth'; ErrorThrown = 'Not authenticated'; ErrorExpected = '*Not authenticated*' }
                @{ Scenario = 'New-MgUser fails'; MockCommand = 'New-MgUser'; ErrorThrown = 'Graph API Error: User already exists'; ErrorExpected = '*User already exists*' }
                @{ Scenario = 'Graph API throws permission error'; MockCommand = 'New-MgUser'; ErrorThrown = 'Insufficient privileges'; ErrorExpected = '*Insufficient privileges*' }
            ) {
                param($MockCommand, $ErrorThrown, $ErrorExpected)

                if ($MockCommand -eq 'Test-GraphAuth') {
                    Mock Test-GraphAuth { throw $ErrorThrown }
                } else {
                    Mock Test-GraphAuth { $true }
                    Mock New-MgUser { throw $ErrorThrown }
                }

                $params = @{
                    DisplayName = 'Test User'
                    UserPrincipalName = 'user@test.com'
                }
                { Add-EntraIdUser @params } | Should -Throw $ErrorExpected
            }
        }

        Context 'ShouldProcess support' {
            BeforeEach {
                Mock Test-GraphAuth { $true }
                Mock New-MgUser { return @{ Id = '11111111-1111-1111-1111-111111111111'; UserPrincipalName = 'user@test.com' } }
            }
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
            BeforeEach {
                Mock Test-GraphAuth { $true }
            }

            It 'Writes success message with DisplayName and UPN' {
                Mock New-MgUser { return @{ Id = '11111111-1111-1111-1111-111111111111'; UserPrincipalName = 'john.doe@test.com' } }
                $params = @{
                    DisplayName = 'John Doe'
                    UserPrincipalName = 'john.doe@test.com'
                }
                $output = Add-EntraIdUser @params
                $output -join ' ' | Should -Match "User 'John Doe' with UPN 'john.doe@test.com' created successfully"
            }

            It 'Returns user object from New-MgUser' {
                Mock New-MgUser {
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
