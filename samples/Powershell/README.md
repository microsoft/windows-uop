# Windows Update Sample Provider (PowerShell)

A PowerShell-based sample provider demonstrating Windows Update Orchestrator (UOP) APIs for creating, scanning, and executing updates.

> **See also**: [Main Samples README](../README.md) for an overview of all available sample implementations (C#, C++, PowerShell).

## Prerequisites
1. **PowerShell 5.1** with Windows Runtime support. This is required to load the WinRT runtimeclasses.
2. Currently only supported for `powershell.exe` (not PowerShell Core/7+)
3. **Administrator privileges** required to execute PowerShell modules
4. **Windows 11 SDK** (Version 10.0.26100.0 or later) - Includes Windows.Management.Update Contract 2.0 APIs

> **Note**: Unlike the C# and C++ samples which use `--flag` syntax, PowerShell scripts use standard PowerShell parameter syntax with `-Parameter` format.

## Directory Structure

| File | Purpose |
|------|---------|
| `SampleProvider-scan.ps1` | Discovers and reports available updates to Windows Update Orchestrator |
| `SampleProvider-action.ps1` | Executes update actions (download, install, deploy, restart) |
| `UOP-runtime.psm1` | Core Powershell module with WinRT APIs and helper functions |
| `UOP-runtime.psd1` | Module manifest defining exported functions and metadata |

## Core Scripts

### SampleProvider-scan.ps1
Creates sample updates and submits them to Windows Update Orchestrator via `WindowsSoftwareUpdateProviderStatus` APIs.

**Usage:**
```powershell
.\SampleProvider-scan.ps1 [-ProviderId <string>] [-LogFile <string>] [-Verbose]
```

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `-ProviderId` | "SampleProvider" | Provider identifier |
| `-LogFile` | "" | Log file in State subfolder |
| `-Verbose` | N/A | Detailed output |

### SampleProvider-action.ps1
Handles action operations with progress reporting and result status updates.

**Usage:**
```powershell
.\SampleProvider-action.ps1 <Action> [-ProviderId <string>] [-UpdateId <string>] [-LogFile <string>] [-ForceClose] [-Verbose]
```

**Parameters:**
| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `Action` | Yes | N/A | download, install, deploy, restart |
| `-ProviderId` | No | "SampleProvider" | Provider identifier |
| `-UpdateId` | No | "" | Update ID for the action |
| `-LogFile` | No | "" | Log file in State subfolder |
| `-ForceClose` | No | N/A | Force close applications |
| `-Verbose` | No | N/A | Detailed output |

## Support Module

### UOP-runtime.psm1
Core module providing:
- **WinRT Type Loading**: Windows.Management.Update APIs
- **Update Creation**: Functions to create deploy, download/install, and app package updates
- **Provider Status**: Progress reporting and result submission
- **Utility Functions**: Logging, versioning, message output

### UOP-runtime.psd1
Module manifest exporting essential functions for sample provider operations.

## Sample Updates

The scan script creates three types of sample updates to demonstrate different action flows:

| Update Type | Package ID | Version | Update ID Format | Actions | Optional Actions |
|-------------|------------|---------|------------------|---------|------------------|
| **Deploy Update** | `SampleApp.Deploy` | 1.2.3.4 | `SampleApp.Deploy_1.2.3.4` | Deploy, Reboot | CloseAndDeploy, CloseAndRestart |
| **Download/Install Update** | `SampleApp.DownloadInstall` | 5.6.7.8 | `SampleApp.DownloadInstall_5.6.7.8` | Download, Install, Reboot | CloseAndInstall, CloseAndRestart |
| **App Package Update** | `Microsoft.OutlookForWindows_8wekyb3d8bbwe` | 2.3.4.5 | Hash-based | System-managed | N/A |

> **Note**: Optional actions (`CloseAndDeploy`, `CloseAndInstall`, `CloseAndRestart`) are defined in `WindowsSoftwareUpdateOptionalActionInfo`, not as separate action types. They represent alternate execution paths where the orchestrator will attempt to close affected applications before executing the corresponding primary action (`Deploy`, `Install`, or `AppRestart`).

## Action Examples

| Action | Command | Purpose |
|--------|---------|---------|
| **Scan** | `.\SampleProvider-scan.ps1` | Discover updates |
| **Download** | `.\SampleProvider-action.ps1 download -UpdateId "ABC123"` | Download update |
| **Install** | `.\SampleProvider-action.ps1 install -UpdateId "ABC123" -ForceClose` | Install with app closure |
| **Deploy** | `.\SampleProvider-action.ps1 deploy -UpdateId "ABC123"` | Deploy update |
| **Restart** | `.\SampleProvider-action.ps1 restart -UpdateId "ABC123"` | Application restart |

## Logging

When `-LogFile` is specified:
- Output redirected to `State/<LogFile>`
- Automatic log rotation (5MB default)
- Timestamped entries with structured information
- Verbose mode automatically enabled

## Integration with Windows Update

1. **Registration**: Provider registers with Windows Update system
2. **Scan Phase**: System calls `SampleProvider-scan.ps1` to discover updates
3. **Action Phase**: System calls `SampleProvider-action.ps1` to execute operations
4. **Progress Reporting**: Actions report progress via UOP-runtime module

## Example Workflows

### Basic Scan
```powershell
.\SampleProvider-scan.ps1
```

### Scan with Logging
```powershell
.\SampleProvider-scan.ps1 -ProviderId "SampleProvider" -LogFile "scan.log"
```

### Execute Actions
```powershell
# Download
.\SampleProvider-action.ps1 download -UpdateId "SampleApp.Deploy_1.2.3.4"

# Install with logging
.\SampleProvider-action.ps1 install -UpdateId "SampleApp.Deploy_1.2.3.4" -LogFile "action.log" -Verbose
```

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
