# Windows Update Sample Provider (C++)

This sample demonstrates how to create a Windows Update Provider using C++ and WinRT.

> **See also**: [Main Samples README](../README.md) for an overview of all available sample implementations (C#, C++, PowerShell).

## Prerequisites

- **Windows 11 SDK**: Version 10.0.26100.0 or later (Build 10.0.26100.6901 released 10/2025)
  - Download from: https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/
  - Includes Windows.Management.Update Contract 2.0 APIs
- **Visual Studio 2022** (v143 toolset)
- **NuGet**: For package restoration

## Required NuGet Packages

The project uses the following NuGet packages (defined in `packages.config`):
- `Microsoft.Windows.CppWinRT` (v2.0.250303.1) - C++/WinRT language projection
- `Microsoft.Windows.ImplementationLibrary` (WIL v1.0.250325.1) - Windows Implementation Library

## Building the Sample

### Using Visual Studio 2022

1. **Open the solution**:
   ```powershell
   start SampleProvider.sln
   ```

2. **Restore NuGet packages**:
   - Right-click the solution in Solution Explorer → Restore NuGet Packages
   - Or use command line: `nuget restore SampleProvider.sln -PackagesDirectory packages`

3. **Build the solution**:
   - Select your target configuration (Debug/Release) and platform (x64/ARM64)
   - Build the solution (Ctrl+Shift+B)

**Output location:** `x64\Release\SampleProvider.exe` (~221 KB native executable)

### Using Command Line (Visual Studio Developer Command Prompt)

**Recommended approach** - Use the Visual Studio Developer Command Prompt for proper MSBuild environment:

1. **Open Developer Command Prompt**:
   ```powershell
   # In PowerShell
   &"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64
   ```

2. **Navigate to project directory**:
   ```powershell
   cd path\to\samples\C++
   ```

3. **Restore NuGet packages**:
   ```powershell
   nuget restore SampleProvider.sln
   ```

4. **Build with MSBuild**:
   ```powershell
   # For x64
   msbuild SampleProvider.sln /p:Configuration=Release /p:Platform=x64

   # For ARM64
   msbuild SampleProvider.sln /p:Configuration=Release /p:Platform=ARM64

   # Rebuild (clean + build)
   msbuild SampleProvider.sln /p:Configuration=Release /p:Platform=x64 /t:Rebuild
   ```

**Output location:** `x64\Release\`
- `SampleProvider.exe` (~226 KB native executable)
- `provider.json` (provider metadata)
- `SampleProvider.pdb` (debug symbols - optional)

**Note**: Both `SampleProvider.exe` and `provider.json` are required for deployment.

### Alternative: Using Command Line (Direct MSBuild)

If you need to use MSBuild directly without the Developer Command Prompt:

1. **Restore NuGet packages**:
   ```powershell
   nuget restore SampleProvider.sln -PackagesDirectory packages
   ```

2. **Build with full MSBuild path**:
   ```powershell
   # For x64
   &"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe" SampleProvider.sln /p:Configuration=Release /p:Platform=x64

   # For ARM64
   &"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe" SampleProvider.sln /p:Configuration=Release /p:Platform=ARM64
   ```

**Output location:** `x64\Release\` (or `ARM64\Release\` for ARM64 builds)
- `SampleProvider.exe` (~226 KB native executable)
- `provider.json` (provider metadata)
- `SampleProvider.pdb` (debug symbols - optional)

## Project Configuration

The project is configured to:
- Target Windows SDK 10.0.26100.0
- Use C++17 standard
- Reference WinRT metadata from the Windows SDK
- Link against `runtimeobject.lib` for WinRT support

## Key Files

- `SampleProvider.cpp` - Main implementation
- `SampleProvider.vcxproj` - Project file
- `packages.config` - NuGet package dependencies
- `NuGet.config` - NuGet package source configuration (ensures public nuget.org is used)
- `provider.json` - Provider metadata (copied to output directory)

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

## Comparison with C# Sample

This C++ sample is functionally equivalent to the C# version, with the following differences:

- Uses C++/WinRT instead of C# with CsWinRT projections
- Uses WIL (Windows Implementation Library) for error handling and RAII patterns
- Uses custom SHA-256 hash implementation instead of .NET's built-in `SHA256` class
- Uses file redirection for logging instead of C#'s `StreamWriter`
- Leverages C++17 standard library features

## Troubleshooting

### Build Errors

**If you encounter errors about missing NuGet packages:**
1. Ensure `NuGet.config` is present in the sample directory
2. Run `nuget restore SampleProvider.sln` before building
3. Verify you have internet access to reach nuget.org

**If you encounter errors about missing Windows SDK:**
1. Install Windows SDK 10.0.26100.0 or later via Visual Studio Installer
2. Update the `WindowsTargetPlatformVersion` in `SampleProvider.vcxproj` to match your installed SDK version

**If you encounter C++/WinRT compilation errors:**
1. Ensure NuGet packages are restored correctly
2. Check that the `packages` folder contains `Microsoft.Windows.CppWinRT`
3. Clean and rebuild the solution

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
- [C++/WinRT Documentation](https://learn.microsoft.com/windows/uwp/cpp-and-winrt-apis/)
- [Windows Implementation Library (WIL)](https://github.com/microsoft/wil)
- [Provider Configuration Schema](../README.md)
- [Provider Tools and Scripts](../../tools/README.md)