# Windows Update Orchestration Platform (UOP)

#### Table of Contents
- [Overview](#overview)
- [Key Terms](#key-terms)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Onboarding A SampleProvider](#onboarding-a-sampleprovider)
- [Testing and Validation](#testing-and-validation)
- [Troubleshooting](#troubleshooting)
- [API Reference](#api-reference)
- [Support](#support)
- [Contributing](#contributing)
- [License](#license)

## Overview
The Update Orchestration Platform (UOP) enables third-party software update providers to integrate seamlessly into the Windows Update ecosystem. This creates a single point of orchestration for both system and app updates.

### Key Orchestration Capabilities
#### Intelligent Scheduling
* System and onboarded app updates are orchestrated uniformly, ensuring consistent scheduling of update providers.
* Schedules update work dynamically based on device state, considering factors such as network, battery and user activity.
* Performs update work during sustainable periods to minimize resource contention and optimize system efficiency.

#### Unified Update Flow
* Provides a unified reboot experience for both system and app updates, reducing user disruption.
* Allows onboarded apps to leverage existing Windows update policies for compliance and scheduling.

#### Enhanced User Experience
* Onboarded app updates use native Windows interfaces for consistent messaging and notifications.
* Integrates seamlessly with the Windows Settings Apps page.
* Automatically benefits from future enhancements and orchestration efficiencies.

###  Key Terms
| Term | Description |
|-------------|---------|
| **Orchestrator** | The built-in Windows component that schedules and manages update operations. |
| **Software Update** | A package containing files and metadata required to install new features or fixes on the system. |
| **Software Update Provider** | A package containing files and metadata required to discover, download and install software updates. |
| **Scan** | An operation that discovers software updates available to the device. |
| **Action** | An operation required to complete a software update. |


## Prerequisites

### System Requirements

| Requirement | Details |
|-------------|---------|
| **Operating System** | 26100.9168+ |
| **SKU Support** | Windows 11 Pro,  Enterprise and Home  SKUs only |
| **Privileges** | Administrator privileges required for all operations |
| **Provider Support** | Powershell-based or Executable-based providers |

> _**Note**_: This feature and API support are gradually being rolled out, so you might not see them on your device immediately upon installing the .9168+ update.
<br>Instructions to opt into getting the latest updates can be found here - [Get the latest updates as soon as they're available](https://support.microsoft.com/en-US/Windows/Deployment/Updates-Lifecycle/get-windows-updates-as-soon-as-they-re-available-for-your-device).

## Getting Started

###  Setup
1. Install the latest cumulative update [KB5121003 (OS Builds 26200.9168 and 26100.9168](https://support.microsoft.com/en-US/servicing/os/windows-11/2026/08/kb5121003-windows-11-24h2-25h2-security-update) through Windows Update.

2. Reboot your device once the latest cumulative update has installed.

### Development Environment Setup

**Prerequisites:**

- **Repository**: Clone this repository on your development machine
```bash
# Cloning the repo
git clone https://github.com/microsoft/windows-uop.git
cd windows-uop

# Copy content to a local folder
xcopy /E /I C:/path/where/windows-uop/was/cloned C:\Test\SampleProvider

# Navigate to the local folder
cd C:/Test/SampleProvider
```

> _**Important: Ensure you have CRLF line endings set in your editor when working with the provider files.**_

- **Windows SDK**: Install [Windows SDK for Windows 11 (10.0.26100.9169)](https://go.microsoft.com/fwlink/?linkid=2376216) or later. Content under the tools directory makes use of the tools present in the SDK.

- **Powershell**: Version 5.1
```powershell
# Check Powershell version
$PSVersionTable.PSVersion
```

- **Development Tools**: Text editor or IDE for Powershell script development.
_**Ensure you have CRLF line endings set in your editor when working with provider related content.**_

## Onboarding A SampleProvider

The following steps outline the process of onboarding the sampleprovider.

### Step 1: Certificate Setup (One-Time)

Code signing is mandatory for provider registration. Create a certificate.

**For Development (Self-Signed Certificate):**
```powershell
# Set the ExecutionPolicy
 Set-ExecutionPolicy Unrestricted

# Navigate to the tools directory
cd tools

# Run the certificate creation script
# Create certificate in dedicated certificates folder
.\New-SigningCertificate.ps1 -ProviderName "SampleProvider" -OutputPath "C:\Certificates" -Password (Read-Host -AsSecureString -Prompt "Certificate password")

# Enter a password when prompted
```

> **For Production: Use your organization's code signing certificate issued by a trusted Certificate Authority.**

### Step 2: Provider Content Preparation

The SampleProvider requires the following files:

**Required Files:**
- `provider.json` - Provider metadata and configuration
- `SampleProvider-scan.ps1` - Update scanning logic (ScanFile)
- `SampleProvider-action.ps1` - Update installation logic (ActionFile)
- `SampleProvider.cat` - Catalog file for integrity verification
- `UOP-deployment.psm1` - Provider registration and management modules
- `UOP-deployment.psd1` - Module manifest defining exported functions and metadata
- `README.md` - Documentation file containing provider-specific information, usage instructions, and troubleshooting guide

```powershell
# Update names/hashes in the provider.json, generate catalog, and sign
.\Update-Provider.ps1 -ProviderPath "C:\Test\SampleProvider\samples\Powershell" -SignCatalog -PfxFile "C:\Certificates\SampleProvider.pfx" -Force
```

**Preparation Process:**
When onboarding your custom provider, ensure the following:
1. **Create Provider Scripts**: Implement your scan and action Powershell scripts
2. **Update Metadata**: Configure [`provider.json`](samples/Powershell/provider.json) with your provider details. **Note that all property names are case-sensitive and must use Pascal casing.**
3. **Generate File Hashes**: Calculate SHA-256 hashes for all payload files and update them in the provider.json
4. **Create a Catalog File**: Generate a catalog file vouching for file integrity. Ensure to update the provider.json.
5. **Code Sign**: Sign all files with your certificate

**Detailed Guide**: [Content Preparation and Signing](tools/README.md#management-scripts)

### Step 3: Install Certificate for Trust (On Target Machines)
```powershell
# Install the public key certificate to trust the signature
certutil.exe -f -addStore root "C:\Certificates\SampleProvider.cer"
```

### Step 4: Register SampleProvider Uninstall Identity
UOP requires each provider and update identity (`ProductCode` or `PackageFamilyName`) to match an installed product. This file registers the sample `ProductCode` identities.

```powershell
# From an elevated PowerShell prompt:
reg import ".\tools\sample-products.reg"
```

### Step 5: Provider Registration
Import the UOP-deployment manifest file and register the SampleProvider:

```powershell
# Import the Windows Update Orchestrator module
Import-Module -Name ".\UOP-deployment.psd1" -Force

# Register your provider (performs validation automatically)
Register-WindowsSoftwareUpdateProvider -ProviderPath "C:\Test\SampleProvider\samples\Powershell"
```

**Registration Process**
The following checks take place as part of the registration process:
1. The contents of the `provider.json` are validated. This includes ensuring that the all required fields are present, and the JSON is not malformed.
2. Validation of file hashes against the files present in the folderPath specified during provider construction.
3. Validation of the catalog file integrity
4. Code signing certificates verification

If all these checks pass, then the respective provider will be registered with teh Windows Update Orchestrator service, otherwise an error code specifying the reason for the registration failure will be outputted. Please refer to [UOPReturnCodes.md](docs/UOPReturnCodes.md) for a comprehensive list of error codes.

## Testing and Validation

### Pre-Registration Validation (Recommended)

Test your provider configuration before registration:

```powershell
# Validate provider without registering
Test-WindowsSoftwareUpdateProvider -ProviderPath "C:\Test\SampleProvider\samples\Powershell"
```

This command checks:
- JSON syntax and structure
- File existence and hash verification
- Catalog file validity
- Code signing verification

### Post-Registration Testing

After successful registration, test the update flow:

```powershell
# Import the module
Import-Module -Name ".\UOP-deployment.psd1" -Force

# Scan for updates from your provider only.
Start-WindowsUpdateScan -Mode UserInitiated
```


## Troubleshooting

### Logging and Diagnostics
For debugging and monitoring, utilize the logging utilities in [`UOP-deployment.psm1`](tools/UOP-deployment.psm1). All log files and diagnostic content should be written to the **State folder**, which is automatically created within your provider's registration directory upon successful registration.

**Important**: Files generated by the provider should be written to the State folder. Files written directly to the respective provider registration folder will result in validation failures.

### Error Code Reference
For comprehensive error code documentation, see: [UOP Error Codes](docs/UOPReturnCodes.md).

## API Reference
For comprehensive API documentation including parameters, examples, and advanced scenarios, see: [API Usage Guide](docs/UOPApiUsageGuide.md)

## Support

For questions, issues, or feedback regarding the Windows Update Orchestration Platform, please use one of the following channels:

- **Teams**: Post in the Windows Update Orchestration Platform Private Preview Teams channel
- **Email**: [unifiedorchestrator@service.microsoft.com](mailto:unifiedorchestrator@service.microsoft.com)

### Reporting Issues

When reporting issues, please include the following information to help us diagnose and resolve problems:

1. **Windows Update Orchestration logs** - Collect logs using the [Windows Update log collection tool](https://aka.ms/wucopylogs)
2. **Provider-specific logs** - Logs from your provider's State folder.
3. **Error codes and messages** - Any error codes or messages returned during registration or provider execution.
4. **Provider configuration** - Your `provider.json` file (with sensitive information redacted)
5. **Environment details** - Windows version, OS build number, and SKU (Pro/Enterprise)
6. **Steps to reproduce** - Detailed reproduction steps, including expected behaviour versus actual behaviour.

## Contributing
This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## License
Copyright (c) Microsoft Corporation. All rights reserved.

Licensed under the [MIT](LICENSE) license.