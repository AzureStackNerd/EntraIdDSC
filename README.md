# EntraIdDSC: Desired State Configuration for Microsoft Entra ID

## Overview

The `EntraIdDSC` module provides a Desired State Configuration (DSC) solution for managing Microsoft Entra ID resources. It simplifies the automation of identity and access management tasks, ensuring consistency and compliance across your environment.

## Features

- **Automated Entra ID Resource Management**: Define and manage Entra ID resources using DSC configurations.
- **Configuration as Code**: Manage Entra ID settings declaratively with PowerShell DSC.
- **Extensibility**: Easily extend the module to support additional Entra ID resources.

## Structure

- `public/` — Contains exported functions for managing Entra ID resources.
- `private/` — Contains internal helper functions.
- `tests/` — Contains Pester tests for the module.
- `docs/` — Contains detailed documentation for the module.

## Getting Started

1. Clone this repository to your local machine:

   ```powershell
   git clone https://github.com/your-repo/EntraIdDSC.git
   ```

2. Navigate to the module directory:

   ```powershell
   cd EntraIdDSC
   ```

3. Import the module:

   ```powershell
   Import-Module ./EntraIdDSC.psd1
   ```

## Installation

1. Ensure you have PowerShell 7.0 or later installed.
2. Install the required dependencies, such as the `Microsoft.Graph` module.
3. Import the `EntraIdDSC` module into your PowerShell session.

## Usage

- To configure an Entra ID group, use the `Set-EntraIdGroup` function:

  ```powershell
  Set-EntraIdGroup -DisplayName "ExampleGroup" -Description "Example Description"
  ```

- To add a member to an Entra ID group, use the `Add-EntraIdGroupMember` function:

  ```powershell
  Add-EntraIdGroupMember -GroupId "00000000-0000-0000-0000-000000000001" -Members @("user1@contoso.com", "user2@contoso.com")
  ```

- To add an owner to an Entra ID group, use the `Add-EntraIdGroupOwner` function:

  ```powershell
  Add-EntraIdGroupOwner -GroupId "00000000-0000-0000-0000-000000000001" -Owners @("user1@contoso.com", "user2@contoso.com")
  ```

- To retrieve the current state of an Entra ID group, use the `Get-EntraIdGroup` function:

  ```powershell
  Get-EntraIdGroup -GroupName "ExampleGroup"
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
For more information, see the documentation in the `docs/` folder or contact the repository maintainer.
