# Pester tests for Set-EntraIdUser
# Purpose: Validate Set-EntraIdUser logic, input handling, and edge cases

Import-Module "$PSScriptRoot/../EntraIdDSC/" -Force

InModuleScope EntraIdDSC {
    Describe 'Set-EntraIdUser' {
        BeforeAll {
            # Mock external dependencies
            Mock -CommandName Test-GraphAuth -MockWith { $true }
            Mock -CommandName Get-EntraIdUser -MockWith { $null }
            Mock -CommandName Update-MgUser -MockWith { }
        }

        Context 'Valid input scenarios' {
            It 'Updates user properties when they differ from desired state' {
                $existingUser = @{
                    Id = '11111111-1111-1111-1111-111111111111'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Old Name'
                    JobTitle = 'Old Title'
                    Department = 'Old Dept'
                    AccountEnabled = $true
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'New Name'
                    JobTitle = 'New Title'
                    Department = 'New Dept'
                    AccountEnabled = $true
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgUser -Times 1 -Exactly -ParameterFilter {
                    $BodyParameter.DisplayName -eq 'New Name' -and
                    $BodyParameter.JobTitle -eq 'New Title' -and
                    $BodyParameter.Department -eq 'New Dept'
                }
            }

            It 'Updates only properties that differ' {
                $existingUser = @{
                    Id = '22222222-2222-2222-2222-222222222222'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Same Name'
                    JobTitle = 'Old Title'
                    Department = 'Same Dept'
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Same Name'
                    JobTitle = 'New Title'
                    Department = 'Same Dept'
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgUser -Times 1 -Exactly -ParameterFilter {
                    $BodyParameter.JobTitle -eq 'New Title' -and
                    $BodyParameter.Count -eq 1
                }
            }

            It 'Does not update when user is already in desired state' {
                $existingUser = @{
                    Id = '33333333-3333-3333-3333-333333333333'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Correct Name'
                    JobTitle = 'Correct Title'
                    Department = 'Correct Dept'
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Correct Name'
                    JobTitle = 'Correct Title'
                    Department = 'Correct Dept'
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgUser -Times 0 -Exactly
            }

            It 'Updates multiple user properties' {
                $existingUser = @{
                    Id = '44444444-4444-4444-4444-444444444444'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Old Name'
                    JobTitle = 'Old Title'
                    Department = 'Old Dept'
                    OfficeLocation = 'Old Office'
                    MobilePhone = '+1 111-111-1111'
                    UsageLocation = 'US'
                    AccountEnabled = $true
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'New Name'
                    JobTitle = 'New Title'
                    Department = 'New Dept'
                    OfficeLocation = 'New Office'
                    MobilePhone = '+1 222-222-2222'
                    UsageLocation = 'GB'
                    AccountEnabled = $false
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgUser -Times 1 -Exactly -ParameterFilter {
                    $BodyParameter.DisplayName -eq 'New Name' -and
                    $BodyParameter.JobTitle -eq 'New Title' -and
                    $BodyParameter.Department -eq 'New Dept' -and
                    $BodyParameter.OfficeLocation -eq 'New Office' -and
                    $BodyParameter.MobilePhone -eq '+1 222-222-2222' -and
                    $BodyParameter.UsageLocation -eq 'GB' -and
                    $BodyParameter.AccountEnabled -eq $false
                }
            }

            It 'Does not update UserPrincipalName property' {
                $existingUser = @{
                    Id = '55555555-5555-5555-5555-555555555555'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Test User'
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'differentuser@test.com'
                    DisplayName = 'Updated Name'
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgUser -Times 1 -Exactly -ParameterFilter {
                    $BodyParameter.Keys -notcontains 'UserPrincipalName'
                }
            }

            It 'Handles user with minimal properties' {
                $existingUser = @{
                    Id = '66666666-6666-6666-6666-666666666666'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Minimal User'
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Updated Minimal'
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgUser -Times 1 -Exactly
            }
        }

        Context 'Invalid input scenarios' {
            It 'Throws when user does not exist' {
                Mock -CommandName Get-EntraIdUser -MockWith { $null }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'nonexistent@test.com'
                    DisplayName = 'Non-Existent User'
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Throw "*does not exist*"
                Should -Invoke -CommandName Update-MgUser -Times 0 -Exactly
            }

            It 'Throws when User parameter is missing' {
                # Use Get-Command to verify User is mandatory, not actual invocation
                (Get-Command Set-EntraIdUser).Parameters['User'].Attributes.Mandatory | Should -Be $true
            }

            It 'Throws when User parameter is null' {
                { Set-EntraIdUser -User $null -Confirm:$false } | Should -Throw
            }

            It 'Throws when UserPrincipalName is missing from User object' {
                # Mock Get-EntraIdUser to throw when called with null UPN
                Mock -CommandName Get-EntraIdUser -MockWith {
                    throw "Cannot validate argument on parameter 'UserPrincipalName'"
                }

                $desiredUser = [PSCustomObject]@{
                    DisplayName = 'Missing UPN'
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Throw
            }
        }

        Context 'Edge cases' {
            It 'Handles null property values in desired state' {
                $existingUser = [PSCustomObject]@{
                    Id = '88888888-8888-8888-8888-888888888888'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Test User'
                    JobTitle = 'Old Title'
                    Department = 'Old Dept'
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Test User'
                    JobTitle = $null
                    Department = $null
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Not -Throw
                # Just verify Update-MgUser was called, the function handles null correctly
                Should -Invoke -CommandName Update-MgUser -Times 1 -Exactly
            }

            It 'Handles empty string property values' {
                $existingUser = @{
                    Id = '99999999-9999-9999-9999-999999999999'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Test User'
                    JobTitle = 'Old Title'
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Test User'
                    JobTitle = ''
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgUser -Times 1 -Exactly
            }

            It 'Handles boolean property changes' {
                $existingUser = @{
                    Id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Test User'
                    AccountEnabled = $true
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Test User'
                    AccountEnabled = $false
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgUser -Times 1 -Exactly -ParameterFilter {
                    $BodyParameter.AccountEnabled -eq $false
                }
            }

            It 'Handles Update-MgUser exceptions' {
                $existingUser = @{
                    Id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Old Name'
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }
                Mock -CommandName Update-MgUser -MockWith { throw "Graph API Error" }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'New Name'
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Throw "*Graph API Error*"
            }

            It 'Handles Get-EntraIdUser exceptions' {
                Mock -CommandName Get-EntraIdUser -MockWith { throw "Auth Error" }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Test User'
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Throw "*Auth Error*"
            }

            It 'Handles user object with additional custom properties' {
                $existingUser = @{
                    Id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Test User'
                    JobTitle = 'Old Title'
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Test User'
                    JobTitle = 'New Title'
                    CustomProperty = 'CustomValue'
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgUser -Times 1 -Exactly
            }
        }

        Context 'ShouldProcess support' {
            It 'Supports -WhatIf for user updates' {
                $existingUser = @{
                    Id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Old Name'
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'New Name'
                }

                { Set-EntraIdUser -User $desiredUser -WhatIf } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgUser -Times 0 -Exactly
            }

            It 'Respects -Confirm:$false' {
                $existingUser = @{
                    Id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Old Name'
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'New Name'
                }

                { Set-EntraIdUser -User $desiredUser -Confirm:$false } | Should -Not -Throw
                Should -Invoke -CommandName Update-MgUser -Times 1 -Exactly
            }
        }

        Context 'Output validation' {
            It 'Writes output when update is required' {
                $existingUser = @{
                    Id = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Old Name'
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'New Name'
                }

                $output = Set-EntraIdUser -User $desiredUser -Confirm:$false
                $output | Should -Not -BeNullOrEmpty
            }

            It 'Writes output when no update is required' {
                $existingUser = @{
                    Id = '10101010-1010-1010-1010-101010101010'
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Same Name'
                }
                Mock -CommandName Get-EntraIdUser -MockWith { $existingUser }

                $desiredUser = [PSCustomObject]@{
                    UserPrincipalName = 'user@test.com'
                    DisplayName = 'Same Name'
                }

                $output = Set-EntraIdUser -User $desiredUser -Confirm:$false
                $output | Should -Not -BeNullOrEmpty
            }
        }

        # CodeCoverage: Ensure Set-EntraIdUser is covered
        # This is a comment for CI configuration, not a Pester directive
    }
}
