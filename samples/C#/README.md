# Windows Update Sample Provider (C#)

This sample demonstrates how to create a Windows Update Provider using C# and WinRT.

> **See also**: [Main Samples README](../README.md) for an overview of all available sample implementations (C#, C++, PowerShell).

## Prerequisites

- **Windows 11 SDK** (Version TBD)
- **.NET 8.0 SDK** or later
- **Visual Studio 2022** (recommended) or Visual Studio Code

## Building the Sample

### Using Visual Studio 2022

1. **Open the solution**:
   ```powershell
   start SampleProvider.sln
   ```

2. **Build the solution**:
   - Select your target configuration (Debug/Release) and platform (x64/ARM64)
   - Build the solution (Ctrl+Shift+B)

3. **Publish as single-file executable** (recommended for deployment):
   - Right-click the project → Publish
   - Select target runtime (win-x64 or win-arm64)
   - Click Publish

### Using Command Line

1. **Restore packages**:
   ```powershell
   dotnet restore
   ```

2. **Build (creates separate DLL files)**:
   ```powershell
   dotnet build -c Release
   ```

3. **Publish as single-file executable** (recommended for deployment):
   ```powershell
   # For x64
   dotnet publish -c Release -r win-x64

   # For ARM64
   dotnet publish -c Release -r win-arm64
   ```

   **Output locations:**
   - Build output: `bin\x64\Release\net8.0-windows10.0.26100.0\`
   - Published single-file: `bin\x64\Release\net8.0-windows10.0.26100.0\win-x64\publish\`
     - `SampleProvider.exe` (~27 MB - includes embedded .NET runtime)
     - `provider.json` (provider metadata)
     - `SampleProvider.pdb` (debug symbols - optional)

**Note**: The `dotnet publish` command creates a self-contained single-file executable with all dependencies embedded, as configured by `PublishSingleFile` in the project file. This is the recommended approach for distribution. Both `SampleProvider.exe` and `provider.json` are required for deployment.

## Running the Sample

The sample provider supports the following commands:

### Scan for Updates
```powershell
.\SampleProvider.exe scan --providerId SampleProvider --log --verbose
```

### Download an Update
```powershell
.\SampleProvider.exe download --providerId SampleProvider --updateId <UpdateID> --log
```

### Install an Update
```powershell
.\SampleProvider.exe install --providerId SampleProvider --updateId <UpdateID> --log --forceClose
```

### Deploy an Update
```powershell
.\SampleProvider.exe deploy --providerId SampleProvider --updateId <UpdateID> --log --forceClose
```

### Restart After Update
```powershell
.\SampleProvider.exe restart --providerId SampleProvider --updateId <UpdateID> --log
```

## Command-Line Options

- `--providerId <ProviderID>` - Specify the provider ID (defaults to 'SampleProvider')
- `--updateId <UpdateID>` - Specify the update ID for the action (format: PackageId_Version)
- `--log` - Redirect console output to `State\SampleProvider.log`
- `--forceClose` - Force close applications during install/deploy actions
- `--verbose` - Display detailed update information for each update object created

## Project Configuration

The project is configured to:
- Target **.NET 8.0** with Windows 10.0.26100.0 SDK
- Support **x64** and **ARM64** platforms
- Reference WinRT APIs from Windows SDK
- Use C# 12 features with nullable reference types enabled

## Key Files

- `Program.cs` - Main application entry point and command-line handling
- `UpdateHelper.cs` - Helper methods for creating and managing updates
- `SampleProvider.csproj` - Project configuration
- `NuGet.config` - NuGet package source configuration (ensures public nuget.org is used)
- `provider.json` - Provider metadata (copied to output directory)

## Sample Updates

The provider creates three types of sample updates to demonstrate different action flows:

| Update Type | Package ID | Version | Installation Type | Actions | Optional Actions |
|-------------|------------|---------|-------------------|---------|------------------|
| **Deploy Update** | `SampleApp.Deploy` | 1.2.3.4 | Executable | Deploy, Reboot | CloseAndDeploy, CloseAndRestart |
| **Download/Install Update** | `SampleApp.DownloadInstall` | 5.6.7.8 | Executable | Download, Install, Reboot | CloseAndInstall, CloseAndRestart |
| **App Package Update** | `Microsoft.OutlookForWindows_8wekyb3d8bbwe` | 2.3.4.5 | AppPackage (x64) | System-managed | N/A |

> **Note**: Optional actions are defined in `WindowsSoftwareUpdateOptionalActionInfo` and provide alternate execution paths with application closure. They use the same underlying action types (`Deploy`, `Install`, `AppRestart`) with the approval info indicating app closure is approved.

## Logging

When the `--log` flag is used:
- A `State` folder is created in the same directory as the executable
- Console output is redirected to `State\SampleProvider.log`
- Timestamps are added to each log session

## How It Works

1. **Scan Operation**: Creates sample update objects and reports them via `WindowsSoftwareUpdateProviderStatus.SetScanResult()`

2. **Action Operations** (download/install/deploy): Simulates progress by:
   - Reporting progress from 0-100% using `SetActionProgress()`
   - Sleeping 500ms between progress ticks for demonstration
   - Reporting final result using `SetActionResult()`

3. **Update IDs**: Generated by hashing the package identifier (PackageId_Version format) for consistent IDs across runs

## Provider Configuration

The `provider.json` file defines provider metadata:
- Provider ID and version
- Catalog file for code signing
- Scan command and arguments
- Payload files with SHA-256 hashes

**Note**: The file hashes in `provider.json` must be updated after building. Use the [`Update-Provider.ps1`](../../tools/README.md#update-providerps1) script to automatically update hashes and generate catalog files.

See the [samples README](../README.md) for complete `provider.json` schema documentation.

## Code Signing and Catalog Files

For production deployment, providers must be code-signed:

1. **Generate Catalog File**: Use `Update-Provider.ps1` to create the `.cat` file
2. **Sign the Catalog**: Use a code signing certificate
3. **Update Hashes**: Ensure all file hashes in `provider.json` are current

See the [tools README](../../tools/README.md) for detailed instructions on certificate creation and provider signing workflow.

## Comparison with C++ Sample

This C# sample is functionally equivalent to the C++ version, with the following differences:

- Uses C# and .NET 8.0 instead of C++/WinRT
- Uses .NET's built-in `SHA256` for hash generation instead of custom implementation
- Uses .NET's `StreamWriter` for logging instead of redirecting `std::wcout`
- Leverages C# language features like LINQ, nullable reference types, and string interpolation

## Troubleshooting

### Build Errors

**If you encounter errors about missing NuGet packages:**
1. Ensure `NuGet.config` is present in the sample directory
2. Run `dotnet restore` before building
3. Verify you have internet access to reach nuget.org

**If you encounter errors about missing Windows SDK:**
1. Install Windows SDK 10.0.26100.0 or later via Visual Studio Installer
2. Update the `TargetFramework` in `SampleProvider.csproj` to match your installed SDK version

**If you encounter CsWinRT errors:**
1. Ensure NuGet package `Microsoft.Windows.CsWinRT` is restored correctly
2. Clean and rebuild the solution
3. Check that the SDK version matches the `CsWinRTWindowsMetadata` setting

### Runtime Errors

**If you encounter errors about missing WinRT APIs:**
1. Ensure you're running on Windows 10/11 with the required SDK version
2. Verify that Windows.Management.Update APIs are available on your system
3. Check that the Windows Update Orchestrator service is available

**If logging doesn't work:**
1. Ensure the application has write permissions to create the `State` folder
2. Check that the `--log` flag is specified on the command line

## Additional Resources

- [Windows.Management.Update Namespace Documentation](https://learn.microsoft.com/uwp/api/windows.management.update)
- [.NET WinRT Projection Documentation](https://learn.microsoft.com/windows/apps/develop/platform/csharp-winrt/)
- [C#/WinRT Documentation](https://github.com/microsoft/CsWinRT)
- [Provider Configuration Schema](../README.md)
- [Provider Tools and Scripts](../../tools/README.md)