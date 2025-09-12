# EntraIdDSC: Desired State Configuration for Microsoft Entra ID

## Overview

The `EntraIdDSC` module provides a Desired State Configuration (DSC) solution for managing Microsoft Entra ID resources. **Current support is focused on Groups and Users (with specific fields only).** It simplifies the automation of identity and access management tasks, ensuring consistency and compliance across your environment.

## Features

- **Automated Entra ID Group and User Management**: Define and manage Entra ID Groups and Users (selected fields) using DSC configurations.
- **Configuration as Code**: Manage Entra ID settings declaratively.
- **Non-destructive sync**: Users and Groups removed from the configuration are NOT removed from EntraId; only additions and updates are applied.
- **Protected users exclusion**: Users listed in the `protectedUsers.jsonc` file are excluded from desired state operations, providing an extra safeguard if an important account is accidentally included in a desired state configuration file.
- **Extensibility**: Easily extend the module to support additional Entra ID resources in the future.

## Folder Structure

- `EntraIdDSC/public/` — Exported PowerShell functions for managing Entra ID resources:
  - Add-EntraIdGroupMember
  - Add-EntraIdGroupOwner
  - Add-EntraIdUser
  - Get-EntraIdGroup
  - Get-EntraIdGroupMember
  - Get-EntraIdGroupOwner
  - Get-EntraIdServicePrincipal
  - Get-EntraIdUser
  - Invoke-EntraIdGroupDesiredState
  - Invoke-EntraIdUserDesiredState
  - Remove-EntraIdGroupMember
  - Remove-EntraIdGroupOwner
  - Set-EntraIdGroup
  - Set-EntraIdUser
- `EntraIdDSC/private/` — Internal helper functions (e.g., Get-ObjectType, Test-GraphAuth, Test-UserPrincipalName).
- `EntraIdDSC/EntraIdDSC.psd1` — Module manifest.
- `EntraIdDSC/EntraIdDSC.psm1` — Main module file.
- `docs/examples/groups/` — Example group configuration files (e.g., licenses.jsonc, pim-entraroles.jsonc).
- `docs/examples/users/` — Example user configuration files (e.g., example.jsonc, it-dept.jsonc, protectedusers.jsonc).
- `tests/` — (Currently empty) Intended for Pester tests.

## Getting Started

1. Clone this repository to your local machine:

   ```powershell
   git clone https://github.com/AzureStackNerd/EntraIdDSC.git
   ```

2. Navigate to the module directory:

   ```powershell
   cd EntraIdDSC
   ```

3. Import the module:

    ```powershell
    Import-Module ./EntraIdDSC.psd1
    ```

4. Add one or more user configuration file(s): e.g. (`users/it-dept.json`):

   ```json
   [
     {
       "GivenName": "Emma",
       "Surname": "Jones",
       "DisplayName": "Emma Jones",
       "UserPrincipalName": "emma.jones@contoso.com",
       "AccountEnabled": true,
       "MailNickname": "emma.jones",
       "JobTitle": "Cloud Architect",
       "Department": "IT",
       "OfficeLocation": "Building 1",
       "MobilePhone": "+1 425-555-0101",
       "UsageLocation": "US",
       "StreetAddress": "1 Microsoft Way",
       "City": "Redmond",
       "State": "WA",
       "PostalCode": "98052",
       "Country": "United States"
     },
     {
       "GivenName": "Liam",
       "Surname": "Smith",
       "DisplayName": "Liam Smith",
       "UserPrincipalName": "liam.smith@contoso.com",
       "AccountEnabled": true,
       "MailNickname": "liam.smith",
       "JobTitle": "Security Analyst",
       "Department": "Security",
       "OfficeLocation": "Building 2",
       "MobilePhone": "+1 425-555-0102",
       "UsageLocation": "US",
       "StreetAddress": "1 Microsoft Way",
       "City": "Redmond",
       "State": "WA",
       "PostalCode": "98052",
       "Country": "United States"
     },
     {
       "GivenName": "Isabella",
       "Surname": "Garcia",
       "DisplayName": "Isabella Garcia",
       "UserPrincipalName": "isabella.garcia@contoso.com",
       "AccountEnabled": true,
       "MailNickname": "isabella.garcia",
       "JobTitle": "Project Manager",
       "Department": "Operations",
       "OfficeLocation": "Building 3",
       "MobilePhone": "+1 425-555-0103",
       "UsageLocation": "US",
       "StreetAddress": "1 Microsoft Way",
       "City": "Redmond",
       "State": "WA",
       "PostalCode": "98052",
       "Country": "United States"
     }
   ]
   ```

5. Invoke desired state configuration for all users-files in the `users/` folder:

   ```powershell
   Invoke-EntraIdUserDesiredState -Path ./users/
   ```

6. Add one or more group configuration file(s): e.g. (`groups/licenses.json`):

   ```json
   [
     {
       "Name": "UG-LIC-DynamicsBusinessCentralPremium",
       "GroupMembershipType": "Direct",
       "owners": ["alex.wilson@contoso.com"],
       "description": "License User Group for Microsoft Dynamics Business Central Premium",
       "members": [
         "alex.wilson@contoso.com",
         "emma.jones@contoso.com",
         "liam.smith@contoso.com"
       ],
       "IsAssignableToRole": false
     }
   ]
   ```

7. Invoke desired state configuration for all groups-files in the `groups/` folder:

   ```powershell
   Invoke-EntraIdGroupDesiredState -Path ./groups/
   ```

## Installation

1. Ensure you have PowerShell 7.0 or later installed.
2. Install the required dependencies, such as the `Microsoft.Graph` module.
3. Import the `EntraIdDSC` module into your PowerShell session.

## Usage Examples of Exported Functions

- Configure an Entra ID group:

  ```powershell
  Set-EntraIdGroup -DisplayName "ExampleGroup" -Description "Example Description"
  ```

- Add a member to an Entra ID group:

  ```powershell
  Add-EntraIdGroupMember -GroupId "<GroupId>" -Members @("emma.jones@contoso.com", "liam.smith@contoso.com")
  ```

- Add a member to an Entra ID group by DisplayName:

  ```powershell
  Add-EntraIdGroupMember -GroupDisplayName "ExampleGroup" -Members @("isabella.garcia@contoso.com")
  ```

- Add an owner to an Entra ID group:

  ```powershell
    Add-EntraIdGroupOwner -GroupId "<GroupId>" -Owners @("alex.wilson@contoso.com")
  ```

- Retrieve the current state of an Entra ID group:

  ```powershell
  Get-EntraIdGroup -GroupName "ExampleGroup"
  ```

- Configure a user:

  ```powershell
  Set-EntraIdUser -UserPrincipalName "emma.jones@contoso.com" -Department "IT"
  ```

- Add a user:

  ```powershell
  Add-EntraIdUser -GivenName "Liam" -Surname "Smith" -UserPrincipalName "liam.smith@contoso.com"
  ```

## Contribution Guidelines

We welcome contributions! To contribute:

1. Fork the repository.
2. Create a new branch for your feature or bugfix.
3. Submit a pull request with a detailed description of your changes.

## Purpose

This module is intended for IT administrators and engineers looking to:

- Automate Entra ID resource management
- Implement configuration-as-code for identity and access
- Ensure consistency and compliance in Entra ID configurations

## Disclaimer

This module is provided as-is and is not officially supported by Gridly. Use it at your own risk and adapt it to your environment and security requirements.

---

For more information, see the documentation in the `docs/` folder and the example configuration files in `docs/examples/`.
