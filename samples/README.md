# Windows Update Orchestrator Provider (UOP) Samples

This directory contains sample implementations of Windows Update Orchestrator Providers in multiple programming languages. These samples demonstrate how to create custom update providers that integrate with the Windows Update system to discover, download, install, and deploy updates.

## Available Samples

| Language | Directory | Description |
|----------|-----------|-------------|
| **C#** | [`C#/`](C#/) | .NET-based provider using C#/WinRT projection (~27 MB single-file executable) |
| **C++** | [`C++/`](C++/) | Native C++ provider using C++/WinRT (~221 KB native executable) |
| **PowerShell** | [`Powershell/`](Powershell/) | Script-based provider for rapid prototyping and testing |

## What is a Windows Update Provider?

A Windows Update Provider is a component that:
- **Discovers** available updates for specific software or components
- **Submits** update metadata to Windows Update Orchestrator
- **Executes** update actions (download, install, deploy, restart) when instructed by the system
- **Reports** progress and completion status back to the orchestrator

## Common Prerequisites

All samples require:
- **Windows 11 SDK** (Version 10.0.26100.0 or later) - Includes Windows.Management.Update Contract 2.0 APIs
  - Download from: https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/
- **Administrator privileges** to register and run providers

## Choosing a Sample

### Use C# if you:
- Prefer managed code and .NET ecosystem
- Want rapid development with strong typing and modern language features
- Need good balance between performance and development speed
- Want to deploy as a single-file executable

### Use C++ if you:
- Need maximum performance and minimal runtime dependencies
- Prefer native code without .NET runtime
- Want the smallest possible executable size
- Are already working in a C++ codebase

### Use PowerShell if you:
- Need to quickly prototype and test provider behavior
- Want to modify and test without recompilation
- Are comfortable with scripting and Windows PowerShell
- Need to integrate with existing PowerShell automation

## Core Provider Concepts

Each sample demonstrates:

1. **Provider Registration**: Identifying your provider to Windows Update
2. **Scan Operation**: Creating and submitting update metadata
3. **Action Handling**: Implementing download, install, deploy, and restart operations
4. **Progress Reporting**: Real-time status updates during actions
5. **Result Submission**: Reporting success/failure and extended error information

## Sample Update Types

All samples create similar update types to demonstrate different action flows:

| Update Type | Actions | Optional Actions (with app closure) | Purpose |
|-------------|---------|--------------------------------------|---------|
| **Deploy Update** | Deploy, Reboot | CloseAndDeploy, CloseAndRestart | Demonstrates deployment without separate download/install |
| **Download/Install Update** | Download, Install, Reboot | CloseAndInstall, CloseAndRestart | Demonstrates traditional two-phase update |
| **App Package Update** | System-managed | N/A | Demonstrates packaged application updates |

> **Note**: Optional actions (`CloseAndDeploy`, `CloseAndInstall`, `CloseAndRestart`) are not separate action types. They represent the same underlying actions (Deploy, Install, AppRestart) with the `--forceClose` flag to request application closure before execution.

## Getting Started

1. **Choose your preferred language** from the table above
2. **Navigate to the corresponding subdirectory**
3. **Follow the README.md** in that directory for specific build and usage instructions
4. **Review the provider.json** configuration file in each sample

## Additional Resources

- [Windows.Management.Update API Documentation](https://learn.microsoft.com/uwp/api/windows.management.update)
- [Provider Tools and Scripts](../tools/README.md)
- **Debugging**: Use Event Viewer (Windows Logs → Application) for provider diagnostics

## Support

For issues or questions about these samples, please refer to the main project documentation or file an issue in the project repository.

## Creating Custom Providers
### **Step 1: Define Provider Configuration**

Create a `provider.json` file that defines your provider configuration. This file specifies the provider metadata, scan and action script files, and file hashes required for integrity verification.

**Example provider.json:**
```json
{
  "Id": "MyProvider",
  "Version": "1.0.0.0",
  "Type": "Powershell",
  "CatalogFile": "MyProvider.cat",
  "ScanFileName": "MyProvider-scan.ps1",
  "ScanFileArguments": "-ProviderId MyProvider -LogFile MyProvider.log -Verbose",
  "PayloadFiles": [
    {
      "FileName": "MyProvider-action.ps1",
      "FileHash": "PLACEHOLDER_SHA256_HASH_TO_BE_UPDATED"
    },
    {
      "FileName": "MyProvider-scan.ps1",
      "FileHash": "PLACEHOLDER_SHA256_HASH_TO_BE_UPDATED"
    },
    {
      "FileName": "UOP-runtime.psd1",
      "FileHash": "PLACEHOLDER_SHA256_HASH_TO_BE_UPDATED"
    },
    {
      "FileName": "UOP-runtime.psm1",
      "FileHash": "PLACEHOLDER_SHA256_HASH_TO_BE_UPDATED"
    }
  ]
}
```

**Provider Metadata Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Id` | `string` | Required | Unique provider identifier |
| `Version` | `string` | Required | Provider version (semantic versioning) |
| `Type` | `string` | Required | `Executable` or `Powershell` based providers |
| `CatalogFile` | `string` | Required | Catalog file name for code signing |
| `ScanFileName` | `string` | Required | Entry point script for scan operations |
| `ScanFileArguments` | `string` | Optional | Default arguments passed to scan script |
| `PayloadFiles` | `array` | Required | Array of all provider files with integrity hashes |
| `PayloadFiles[].FileName` | `string` | Required | Relative path to the payload file |
| `PayloadFiles[].FileHash` | `string` | Required | SHA-256 hash of the file (Base64 encoded) |
| `ScanFrequencyInHours` | `integer` | Optional | Scan frequency in hours (Min: 12 hours, Max: 360 hours (15 days)) |
| `MigrateStateOnUpgrade` | `boolean` | Optional | Whether provider `State` folder contents should be migrated on an OS upgrade |

> **Note:** File hashes will be automatically calculated and updated when using the [`Update-Provider.ps1`](../../../tools/Update-Provider.ps1) script in Step 4.

For a complete example, see [`provider.json`](provider.json) in this samples directory.

### **Step 2: Certificate Setup (One-time)**
```powershell
.\New-SigningCertificate.ps1 -ProviderName "MyProvider"
```

### **Step 3: Copy and Customize Scripts**
1. Copy `SampleProvider-scan.ps1` → `MyProvider-scan.ps1`
2. Copy `SampleProvider-action.ps1` → `MyProvider-action.ps1`
3. Modify scan script to create your specific updates
4. Modify action script to perform your specific operations
5. Ensure scan script references your action script filename

> **Note:** An alternative approach is to use a single script that handles all update operations (download, install, deploy, restart) by branching logic based on the action argument passed by the orchestrator, rather than creating separate scripts for each action type.

### **Step 4: Prepare and Sign Provider**
```powershell
# Complete workflow: update hashes, generate catalog, and sign
.\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -SignCatalog
```

### **Step 5: Test Provider**
```powershell
# Test provider
.\MyProvider-scan.ps1 -ProviderId "MyProvider" -LogFile MyProvider.log -Verbose",
```

### **Step 6: Register Provider**
```powershell
# Import the Windows Update Orchestrator module
Import-Module -Name ".\windows-uop\tools\UOP-deployment.psd1" -Force

# Register your provider (performs validation automatically)
Register-WindowsSoftwareUpdateProvider -ProviderPath "C:\MyProvider"
```

### **Step 7: Perform a Windows Software Update Scan**
```powershell
# Import the module
Import-Module -Name ".\windows-uop\tools\UOP-deployment.psd1" -Force

# Scan for updates from your provider only
Start-WindowsUpdateScan -IsUserInitiated $true
```
