# Load Windows Runtime assemblies and import namespace
Add-Type -AssemblyName System.Runtime.WindowsRuntime

# Load Windows Runtime types - Core provider and manager types
[void][Windows.Management.Update.WindowsSoftwareUpdateProvider,Windows.Management.Update,ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdate,Windows.Management.Update, ContentType=WindowsRuntime]

# Core types used directly in PowerShell code
[void][Windows.Management.Update.WindowsSoftwareUpdateProviderStatus, Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdateVersion, Windows.Management.Update, ContentType=WindowsRuntime]

# Info types used in PowerShell functions
[void][Windows.Management.Update.WindowsSoftwareUpdateLocalizationInfo, Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdateOptionalInfo, Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdateActionInfo, Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdateOptionalActionInfo, Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdateExecutionInfo, Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdateAppPackageInfo, Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdateProviderActionResult, Windows.Management.Update, ContentType=WindowsRuntime]

# Enumeration types used in PowerShell
[void][Windows.Management.Update.WindowsSoftwareUpdateInstallationType, Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdateActionType, Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdateArchitecture, Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdateActionResult, Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdateRestartReason, Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsSoftwareUpdateCategory, Windows.Management.Update, ContentType=WindowsRuntime]

# Result types returned by WinRT API calls
[void][Windows.Management.Update.WindowsSoftwareUpdateResult, Windows.Management.Update, ContentType=WindowsRuntime]

#region Utility Functions

# Helper function to write output (either to console or log)
function Write-OutputMessage {
    <#
    .SYNOPSIS
    Writes a message to console or log file.

    .DESCRIPTION
    Helper function to write output messages. Can be used with logging functionality.

    .PARAMETER Message
    The message to write.

    .EXAMPLE
    Write-OutputMessage "Starting operation..."
    #>
    param([string]$Message)

    if ($script:LoggingEnabled -and $script:LogFile) {
        Add-Content -Path $script:LogFile -Value $Message -Encoding UTF8
    } else {
        Write-Host $Message
    }
}

function Write-ErrorMessage {
    <#
    .SYNOPSIS
    Writes an error message to console or log file.

    .DESCRIPTION
    Helper function to write error messages. Can be used with logging functionality.

    .PARAMETER Message
    The error message to write.

    .EXAMPLE
    Write-ErrorMessage "Operation failed"
    #>
    param([string]$Message)

    if ($script:LoggingEnabled -and $script:LogFile) {
        Add-Content -Path $script:LogFile -Value "ERROR: $Message" -Encoding UTF8
    } else {
        Write-Error $Message
    }
}

function Write-VerboseMessage {
    <#
    .SYNOPSIS
    Writes a verbose message to log file when logging is enabled, or to console when logging is disabled.

    .DESCRIPTION
    Helper function to write verbose messages. When logging is enabled, messages go only to the log file.
    When logging is disabled, messages go to the verbose stream (console).

    .PARAMETER Message
    The verbose message to write.

    .EXAMPLE
    Write-VerboseMessage "Processing item 1 of 10"
    #>
    param([string]$Message)

    if ($script:LoggingEnabled -and $script:LogFile) {
        # When logging is enabled, write only to log file (nothing to console)
        Add-Content -Path $script:LogFile -Value "VERBOSE: $Message" -Encoding UTF8
    } else {
        # When logging is disabled, write to verbose stream (console)
        Write-Verbose $Message
    }
}

# Helper function to extract HRESULT from ResultCode property
function Get-HResultFromResultCode {
    <#
    .SYNOPSIS
    Extracts HRESULT from a ResultCode property.

    .DESCRIPTION
    Helper function to extract and format HRESULT values from various result code formats.

    .PARAMETER ResultCode
    The result code to extract HRESULT from.

    .EXAMPLE
    $hresult = Get-HResultFromResultCode $result.ResultCode
    #>
    param($ResultCode)

    if ($null -eq $ResultCode) {
        return 0x00000000
    }

    # If it's wrapped in an exception, extract the HResult
    if ($ResultCode -is [System.Exception]) {
        return [uint32]$ResultCode.HResult
    }

    # If it's already a numeric value, use it directly
    if ($ResultCode -is [int32] -or $ResultCode -is [uint32]) {
        return [uint32]$ResultCode
    }

    # Try to parse as hex string if it's a string
    if ($ResultCode -is [string] -and $ResultCode.StartsWith("0x")) {
        return [Convert]::ToUInt32($ResultCode, 16)
    }

    # Fallback - try to convert to uint32
    try {
        return [uint32]$ResultCode
    }
    catch {
        Write-Warning "Could not convert ResultCode to HRESULT: $ResultCode"
        return 0xFFFFFFFF
    }
}

# Helper function to format HRESULT as hex string
function Format-HResult {
    <#
    .SYNOPSIS
    Formats HRESULT as hex string.

    .DESCRIPTION
    Helper function to format HRESULT values as hex strings for display.

    .PARAMETER HResult
    The HRESULT value to format.

    .EXAMPLE
    $formatted = Format-HResult $hresult
    #>
    param([uint32]$HResult)
    return "0x{0:X8}" -f $HResult
}

# Updated helper function to write result with proper HRESULT formatting
function Write-ResultMessage {
    <#
    .SYNOPSIS
    Writes a formatted result message with HRESULT information.

    .DESCRIPTION
    Helper function to write operation results with proper HRESULT formatting.

    .PARAMETER Operation
    The name of the operation.

    .PARAMETER Result
    The result object containing status information.

    .EXAMPLE
    Write-ResultMessage "SetScanResult()" $result
    #>
    param(
        [string]$Operation,
        $Result
    )

    if ($null -eq $Result) {
        Write-OutputMessage "$Operation -> Warning: Result is null"
        return
    }

    $hresult = Get-HResultFromResultCode $Result.ResultCode
    $hresultFormatted = Format-HResult $hresult

    Write-OutputMessage "$Operation -> Succeeded: $($Result.Succeeded), CancelRequested: $($Result.CancelRequested), ResultCode: $hresultFormatted, ExtendedError: $($Result.ExtendedError)"

    # Also log the raw HRESULT value for debugging
    Write-Verbose "Raw HRESULT value: $hresult (decimal: $([int32]$hresult))"
}

# Base64 encoding function
function ConvertTo-Base64 {
    <#
    .SYNOPSIS
    Converts a string to Base64 encoding.

    .DESCRIPTION
    Helper function to encode strings as Base64.

    .PARAMETER InputString
    The string to encode.

    .EXAMPLE
    $encoded = ConvertTo-Base64 "Hello World"
    #>
    param([string]$InputString)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    return [System.Convert]::ToBase64String($bytes)
}

# Base64 decoding function
function ConvertFrom-Base64 {
    <#
    .SYNOPSIS
    Converts a Base64 string back to plain text.

    .DESCRIPTION
    Helper function to decode Base64 strings.

    .PARAMETER Base64String
    The Base64 string to decode.

    .EXAMPLE
    $decoded = ConvertFrom-Base64 $base64String
    #>
    param([string]$Base64String)

    try {
        $bytes = [System.Convert]::FromBase64String($Base64String)
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    }
    catch {
        return ""
    }
}

# Generate a hash for package title and version (32 character hex string)
function New-UpdateId {
    <#
    .SYNOPSIS
    Generates a unique update ID based on provider ID, title and version.

    .DESCRIPTION
    Creates a SHA256-based hash for generating consistent update IDs.

    .PARAMETER ProviderId
    The provider ID for the update.

    .PARAMETER Title
    The title/name of the update.

    .PARAMETER Version
    The version of the update.

    .EXAMPLE
    $updateId = New-UpdateId -ProviderId "SampleProvider" -Title "SampleApp_1.0.0" -Version "1.0.0"
    #>
    param(
        [string]$ProviderId = "",
        [string]$Title,
        [string]$Version
    )

    $inputString = "$ProviderId|$Title|$Version"
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($inputString))
    $hashHex = [System.BitConverter]::ToString($hashBytes) -replace '-', ''

    # Ensure it's exactly 32 characters
    return $hashHex.Substring(0, 32)
}

# Get current script path
function Get-CurrentModulePath {
    <#
    .SYNOPSIS
    Gets the path of the currently executing PowerShell script or module.

    .DESCRIPTION
    Helper function to retrieve the current script/module path.

    .EXAMPLE
    $scriptPath = Get-CurrentModulePath
    #>
    return $PSCommandPath
}

# Helper function to get file size from URL
function Get-FileSizeFromUrl {
    <#
    .SYNOPSIS
    Gets the file size from a URL using an HTTP HEAD request.

    .DESCRIPTION
    Makes an HTTP HEAD request to determine the file size without downloading the content.
    Useful for getting accurate download/install sizes for updates.

    .PARAMETER Url
    The URL to check for file size.

    .PARAMETER TimeoutMs
    The timeout in milliseconds for the HTTP request. Default is 10000 (10 seconds).

    .EXAMPLE
    $size = Get-FileSizeFromUrl -Url "https://example.com/file.exe"

    .EXAMPLE
    $size = Get-FileSizeFromUrl -Url "https://example.com/file.exe" -TimeoutMs 5000
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [int]$TimeoutMs = 10000
    )

    try {
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Method = "HEAD"
        $request.Timeout = $TimeoutMs

        $response = $request.GetResponse()
        $contentLength = $response.ContentLength
        $response.Close()

        if ($contentLength -gt 0) {
            Write-Verbose "Retrieved file size from ${Url}: $contentLength bytes"
            return [uint64]$contentLength
        }
    }
    catch {
        Write-Verbose "Failed to get file size from $Url`: $($_.Exception.Message)"
    }

    # Return default size if we can't determine the actual size
    return [uint64]1048576  # 1MB default
}

# Helper function to normalize version strings to 4-component format
function ConvertTo-NormalizedVersion {
    <#
    .SYNOPSIS
    Normalizes version strings to 4-component format (Major.Minor.Revision.Build).

    .DESCRIPTION
    Converts version strings with 1-4 components to standardized 4-component format.
    - "1.2" becomes "1.2.0.0"
    - "1.2.3" becomes "1.2.3.0"
    - "1.2.3.4" remains "1.2.3.4"
    - Empty or invalid strings default to "0.0.0.0"

    .PARAMETER VersionString
    The version string to normalize.

    .EXAMPLE
    $normalized = ConvertTo-NormalizedVersion "1.2.3"
    # Returns "1.2.3.0"
    #>
    param(
        [string]$VersionString
    )

    if ([string]::IsNullOrEmpty($VersionString) -or $VersionString -eq "0.0.0.0") {
        return "0.0.0.0"
    }

    $parts = $VersionString.Split('.')
    $major = if ($parts.Length -gt 0 -and [int]::TryParse($parts[0], [ref]$null)) { [int]$parts[0] } else { 0 }
    $minor = if ($parts.Length -gt 1 -and [int]::TryParse($parts[1], [ref]$null)) { [int]$parts[1] } else { 0 }
    $revision = if ($parts.Length -gt 2 -and [int]::TryParse($parts[2], [ref]$null)) { [int]$parts[2] } else { 0 }
    $build = if ($parts.Length -gt 3 -and [int]::TryParse($parts[3], [ref]$null)) { [int]$parts[3] } else { 0 }

    return "$major.$minor.$revision.$build"
}

# Helper function to parse normalized version string into components
function Get-VersionComponents {
    <#
    .SYNOPSIS
    Parses a normalized version string into individual integer components.

    .DESCRIPTION
    Takes a 4-component version string and returns individual integer values for use with WinRT APIs.

    .PARAMETER NormalizedVersion
    The normalized version string (e.g., "1.2.3.4").

    .EXAMPLE
    $components = Get-VersionComponents "1.2.3.4"
    # Returns hashtable with Major=1, Minor=2, RevisionMajor=3, RevisionMinor=4
    #>
    param(
        [string]$NormalizedVersion
    )

    $parts = $NormalizedVersion.Split('.')
    return @{
        Major = [int]$parts[0]
        Minor = [int]$parts[1]
        RevisionMajor = [int]$parts[2]
        RevisionMinor = [int]$parts[3]
    }
}

# Helper function that directly returns a WindowsSoftwareUpdateVersion object
function New-VersionObject {
    <#
    .SYNOPSIS
    Creates a WindowsSoftwareUpdateVersion object from a version string.

    .DESCRIPTION
    Takes any version string format, normalizes it to a 4-component format, and returns a
    WindowsSoftwareUpdateVersion object ready to use with Windows.Management.Update APIs.

    .PARAMETER VersionString
    The version string to convert (e.g., "1.2", "1.2.3", "1.2.3.4", "0.0.0.0").

    .EXAMPLE
    $versionObj = New-VersionObject "1.2.3"
    # Returns a WindowsSoftwareUpdateVersion object with Major=1, Minor=2, RevisionMajor=3, RevisionMinor=0
    #>
    param(
        [string]$VersionString
    )

    $normalized = ConvertTo-NormalizedVersion $VersionString
    $components = Get-VersionComponents $normalized

    return [Windows.Management.Update.WindowsSoftwareUpdateVersion]::new(
        $components.Major,
        $components.Minor,
        $components.RevisionMajor,
        $components.RevisionMinor
    )
}

# Helper function that creates WindowsSoftwareUpdateOptionalActionInfo objects
function New-OptionalActionsInfo {
    <#
    .SYNOPSIS
    Creates a WindowsSoftwareUpdateOptionalActionInfo object for Windows Software Updates.

    .DESCRIPTION
    Creates a WindowsSoftwareUpdateOptionalActionInfo object with optional action commands.
    This helper function centralizes the creation of optional actions used in update creation.
    Each action requires its own specific action filename.

    .PARAMETER CloseAndDeployFileName
    The filename to use for the close and deploy action.

    .PARAMETER CloseAndDeployCommand
    The command string to use for the close and deploy action.

    .PARAMETER CloseAndInstallFileName
    The filename to use for the close and install action.

    .PARAMETER CloseAndInstallCommand
    The command string to use for the close and install action.

    .PARAMETER RestartFileName
    The filename to use for the restart action.

    .PARAMETER RestartCommand
    The command string to use for the restart action.

    .EXAMPLE
    $optionalActionsInfo = New-OptionalActionsInfo -CloseAndDeployFileName "deploy.ps1" -CloseAndDeployCommand "deploy -ForceClose" -RestartFileName "restart.ps1" -RestartCommand "restart"
    #>
    param(
        [string]$CloseAndDeployFileName = "",
        [string]$CloseAndDeployCommand = "",
        [string]$CloseAndInstallFileName = "",
        [string]$CloseAndInstallCommand = "",
        [string]$RestartFileName = "",
        [string]$RestartCommand = ""
    )

    # Create action info objects for optional actions
    # Map legacy CloseAndDeploy -> Deploy (still optional vs primary)
    $closeAndDeployInfo = if ($CloseAndDeployCommand -and $CloseAndDeployFileName) {
        [Windows.Management.Update.WindowsSoftwareUpdateActionInfo]::new(
            $CloseAndDeployFileName,
            $CloseAndDeployCommand,
            [Windows.Management.Update.WindowsSoftwareUpdateActionType]::Deploy
        )
    } else { $null }

    # Map legacy CloseAndInstall -> Install
    $closeAndInstallInfo = if ($CloseAndInstallCommand -and $CloseAndInstallFileName) {
        [Windows.Management.Update.WindowsSoftwareUpdateActionInfo]::new(
            $CloseAndInstallFileName,
            $CloseAndInstallCommand,
            [Windows.Management.Update.WindowsSoftwareUpdateActionType]::Install
        )
    } else { $null }

    # Map legacy CloseAndRestart -> AppRestart
    $closeAndRestartInfo = if ($RestartCommand -and $RestartFileName) {
        [Windows.Management.Update.WindowsSoftwareUpdateActionInfo]::new(
            $RestartFileName,
            $RestartCommand,
            [Windows.Management.Update.WindowsSoftwareUpdateActionType]::AppRestart
        )
    } else { $null }

    # Create and return the optional actions info object
    return [Windows.Management.Update.WindowsSoftwareUpdateOptionalActionInfo]::new(
        $closeAndDeployInfo,
        $closeAndInstallInfo,
        $closeAndRestartInfo
    )
}

#endregion

#region Update Object Creation Functions

# Display WindowsSoftwareUpdate object details (similar to C++ to_wstring function)
function Show-WindowsSoftwareUpdate {
    <#
    .SYNOPSIS
    Displays detailed information about a WindowsSoftwareUpdate object.

    .DESCRIPTION
    Shows comprehensive details about a WindowsSoftwareUpdate object including all properties and nested objects.

    .PARAMETER Update
    The WindowsSoftwareUpdate object to display.

    .EXAMPLE
    Show-WindowsSoftwareUpdate -Update $update
    #>
    param([Windows.Management.Update.WindowsSoftwareUpdate]$Update)

    Write-OutputMessage "======================================"

    Write-OutputMessage "Update Id: $($Update.UpdateId)"
    Write-OutputMessage "Title: $($Update.Title)"
    Write-OutputMessage "Description: $($Update.Description)"
    Write-OutputMessage "More Info URL: $($Update.MoreInfoUrl.RawUri)"
    Write-OutputMessage "Download Size: $($Update.DownloadSizeInBytes) bytes"
    Write-OutputMessage "Install Size: $($Update.InstallSizeInBytes) bytes"
    Write-OutputMessage "Provider Id: $($Update.ProviderId)"
    Write-OutputMessage "Installation Type: $([int]$Update.InstallationType)"

    # IWindowsSoftwareUpdate2 additions
    Write-OutputMessage "Is Seeker: $($Update.IsSeeker)"
    Write-OutputMessage "Is Feature Update: $($Update.IsFeatureUpdate)"
    Write-OutputMessage "Update Category: $($Update.UpdateCategory)"

    if ($Update.UpdateIdentity) {
        Write-OutputMessage "Update Identity Type: $($Update.UpdateIdentity.Type)"
        Write-OutputMessage "Update Identity: $($Update.UpdateIdentity.Identity)"
    } else {
        Write-OutputMessage "Update Identity: [empty]"
    }

    # Update Source Version
    if ($Update.SourceVersion) {
        $sourceVersion = $Update.SourceVersion
        Write-OutputMessage "Source Version: $($sourceVersion.Major).$($sourceVersion.Minor).$($sourceVersion.RevisionMajor).$($sourceVersion.RevisionMinor)"
    } else {
        Write-OutputMessage "Source Version: [empty]"
    }

    # Update Target Version
    if ($Update.TargetVersion) {
        $targetVersion = $Update.TargetVersion
        Write-OutputMessage "Target Version: $($targetVersion.Major).$($targetVersion.Minor).$($targetVersion.RevisionMajor).$($targetVersion.RevisionMinor)"
    } else {
        Write-OutputMessage "Target Version: [empty]"
    }

    # App Package Information
    if ($Update.AppPackageInfo) {
        $appPackageInfo = $Update.AppPackageInfo
        Write-OutputMessage "App Package Information:"
        Write-OutputMessage "  PackageFamilyName: $($appPackageInfo.PackageFamilyName)"
        Write-OutputMessage "  InstallUri: $($appPackageInfo.InstallUri.RawUri)"
        Write-OutputMessage "  Architecture: $([int]$appPackageInfo.PackageArchitecture)"
    } else {
        Write-OutputMessage "App Package Information: [empty]"
    }

    # Optional Information
    if ($Update.OptionalInfo) {
        $optInfo = $Update.OptionalInfo
        Write-OutputMessage "Optional Information:"

        $category = if ($optInfo.Category) { $optInfo.Category.Value } else { "[empty]" }
        Write-OutputMessage "  Category: $category"

        $complianceDeadline = if ($optInfo.ComplianceDeadlineInDays) { $optInfo.ComplianceDeadlineInDays.Value } else { "[empty]" }
        Write-OutputMessage "  ComplianceDeadlineInDays: $complianceDeadline"

        $complianceGrace = if ($optInfo.ComplianceGracePeriodInDays) { $optInfo.ComplianceGracePeriodInDays.Value } else { "[empty]" }
        Write-OutputMessage "  ComplianceGracePeriodInDays: $complianceGrace"

        if ($optInfo.LocalizationInfo -and $optInfo.LocalizationInfo.Count -gt 0) {
            Write-OutputMessage "  LocalizationInfo:"
            foreach ($loc in $optInfo.LocalizationInfo) {
                Write-OutputMessage "    LanguageId: $($loc.LanguageId)"
                Write-OutputMessage "    Title: $($loc.Title)"
                Write-OutputMessage "    Description: $($loc.Description)"
                $moreInfoUrl = if ($loc.MoreInfoUrl) { $loc.MoreInfoUrl.RawUri } else { "[empty]" }
                Write-OutputMessage "    MoreInfoUrl: $moreInfoUrl"
            }
        }
    } else {
        Write-OutputMessage "Optional Information: [empty]"
    }

    # Executable Information
    if ($Update.ExecutionInfo) {
        $execInfo = $Update.ExecutionInfo

        if ($execInfo.DownloadInfo) {
            $downloadActionInfo = $execInfo.DownloadInfo
            Write-OutputMessage "Executable Information (Download):"
            Write-OutputMessage "  FileName: $($downloadActionInfo.FileName)"
            Write-OutputMessage "  FileArguments: $($downloadActionInfo.FileArguments)"
            Write-OutputMessage "  ActionType: $([int]$downloadActionInfo.ActionType)"
        } else {
            Write-OutputMessage "Executable Information (Download): [empty]"
        }

        if ($execInfo.InstallInfo) {
            $installActionInfo = $execInfo.InstallInfo
            Write-OutputMessage "Executable Information (Install):"
            Write-OutputMessage "  FileName: $($installActionInfo.FileName)"
            Write-OutputMessage "  FileArguments: $($installActionInfo.FileArguments)"
            Write-OutputMessage "  ActionType: $([int]$installActionInfo.ActionType)"
        } else {
            Write-OutputMessage "Executable Information (Install): [empty]"
        }

        if ($execInfo.DeployInfo) {
            $deployActionInfo = $execInfo.DeployInfo
            Write-OutputMessage "Executable Information (Deploy):"
            Write-OutputMessage "  FileName: $($deployActionInfo.FileName)"
            Write-OutputMessage "  FileArguments: $($deployActionInfo.FileArguments)"
            Write-OutputMessage "  ActionType: $([int]$deployActionInfo.ActionType)"
        } else {
            Write-OutputMessage "Executable Information (Deploy): [empty]"
        }

        # Optional Action Executable Information
        if ($execInfo.OptionalActionInfo) {
            $optActionInfo = $execInfo.OptionalActionInfo
            Write-OutputMessage "Optional Action Executable Information:"

            if ($optActionInfo.CloseAndDeployInfo) {
                $closeAndDeployInfo = $optActionInfo.CloseAndDeployInfo
                Write-OutputMessage "  CloseAndDeploy:"
                Write-OutputMessage "    FileName: $($closeAndDeployInfo.FileName)"
                Write-OutputMessage "    FileArguments: $($closeAndDeployInfo.FileArguments)"
                Write-OutputMessage "    ActionType: $([int]$closeAndDeployInfo.ActionType)"
            } else {
                Write-OutputMessage "  CloseAndDeploy: [empty]"
            }

            if ($optActionInfo.CloseAndInstallInfo) {
                $closeAndInstallInfo = $optActionInfo.CloseAndInstallInfo
                Write-OutputMessage "  CloseAndInstall:"
                Write-OutputMessage "    FileName: $($closeAndInstallInfo.FileName)"
                Write-OutputMessage "    FileArguments: $($closeAndInstallInfo.FileArguments)"
                Write-OutputMessage "    ActionType: $([int]$closeAndInstallInfo.ActionType)"
            } else {
                Write-OutputMessage "  CloseAndInstall: [empty]"
            }

            if ($optActionInfo.CloseAndRestartInfo) {
                $closeAndRestartInfo = $optActionInfo.CloseAndRestartInfo
                Write-OutputMessage "  CloseAndRestart:"
                Write-OutputMessage "    FileName: $($closeAndRestartInfo.FileName)"
                Write-OutputMessage "    FileArguments: $($closeAndRestartInfo.FileArguments)"
                Write-OutputMessage "    ActionType: $([int]$closeAndRestartInfo.ActionType)"
            } else {
                Write-OutputMessage "  CloseAndRestart: [empty]"
            }
        } else {
            Write-OutputMessage "Optional Action Executable Information: [empty]"
        }
    } else {
        Write-OutputMessage "Executable Information: [empty]"
    }

    Write-OutputMessage "======================================"
}

# Create actual WinRT WindowsSoftwareUpdate object for PowerShell Deploy Update
function New-DeployUpdate {
    <#
    .SYNOPSIS
    Creates a WindowsSoftwareUpdate object for executable deploy updates.

    .DESCRIPTION
    Creates a deploy-type WindowsSoftwareUpdate object with appropriate action commands.

    .PARAMETER ProviderId
    The provider ID to associate with the update.

    .PARAMETER PackageId
    The package ID for the update.

    .PARAMETER PackageVersion
    The package version for the update.

    .PARAMETER Title
    The title of the update.

    .PARAMETER Description
    The description of the update.

    .PARAMETER MoreInfoUrl
    The more info URL for the update.

    .PARAMETER DownloadSize
    The download size in bytes.

    .PARAMETER InstallSize
    The install size in bytes.

    .PARAMETER DeployFileName
    The filename to use for the deploy action.

    .PARAMETER DeployCommand
    The deploy command string to use for the deploy action.

    .PARAMETER CloseAndDeployFileName
    The filename to use for the close and deploy action.

    .PARAMETER CloseAndDeployCommand
    The command string to use for the close and deploy action.

    .PARAMETER RestartFileName
    The filename to use for the restart action.

    .PARAMETER RestartCommand
    The restart command string to use for the restart action.

    .PARAMETER LocalizationInfo
    Optional array of localization info hashtables. Each hashtable should contain LanguageId, Title, Description, and MoreInfoUrl.

    .EXAMPLE
    $update = New-DeployUpdate -ProviderId "SampleProvider" -UpdateId "ABC123DEF456" -Title "Sample Deploy Update" -Description "Sample deploy update description" -MoreInfoUrl "http://contoso.com/updateId=SampleApp.Deploy_1.2.3.4" -DeployFileName "deploy.ps1" -DeployCommand "deploy -ProviderId SampleProvider -UpdateId SampleApp.Deploy_1.2.3.4" -CloseAndDeployFileName "deploy.ps1" -CloseAndDeployCommand "deploy -ProviderId SampleProvider -UpdateId SampleApp.Deploy_1.2.3.4 -ForceClose"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProviderId,
        [Parameter(Mandatory=$true)]
        [string]$UpdateId,
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$Description,
        [Parameter(Mandatory=$true)]
        [string]$MoreInfoUrl,
        [string]$SourceVersion = "0.0.0.0",
        [string]$TargetVersion = "0.0.0.0",
        [int64]$DownloadSize = 0,
        [int64]$InstallSize = 0,
        [Parameter(Mandatory=$true)]
        [Windows.Management.Update.WindowsSoftwareUpdateInstallationType]$InstallationType,
        [Parameter(Mandatory=$true)]
        [string]$DeployFileName,
        [string]$DeployCommand = "",
        [string]$CloseAndDeployFileName = "",
        [string]$CloseAndDeployCommand = "",
    [string]$RestartFileName = "",
    [string]$RestartCommand = "",
        [array]$LocalizationInfo = @(),
        [Nullable[int]]$ComplianceDeadlineInDays = $null,
        [Nullable[int]]$ComplianceGracePeriodInDays = $null,
        # The orchestrator rejects scan results whose ProductCode is not in the live installed-app
        # inventory. This default matches the named uninstall key registered by sample-products.reg;
        # import that .reg file (as Administrator) before running.
        [string]$ProductCode = "SampleApp.Deploy",
        [Windows.Management.Update.WindowsSoftwareUpdateCategory]$Category = [Windows.Management.Update.WindowsSoftwareUpdateCategory]::Application
    )

    # Display update information with Write-Verbose (will only show if -Verbose is used)
    Write-Verbose "Creating Executable Deploy software update..."
    Write-Verbose "Update ID: $UpdateId"
    Write-Verbose "Source Version: $SourceVersion"
    Write-Verbose "Target Version: $TargetVersion"

    # Create version objects directly from version strings
    $sourceVersionObj = New-VersionObject $SourceVersion
    $targetVersionObj = New-VersionObject $TargetVersion

    $moreInfoUrlObj = [System.Uri]::new($MoreInfoUrl)

    # Create localization info
    $localizationList = [System.Collections.Generic.List[Windows.Management.Update.WindowsSoftwareUpdateLocalizationInfo]]::new()

    # Add provided localization info
    foreach ($locInfo in $LocalizationInfo) {
        $locUrl = [System.Uri]::new($locInfo.MoreInfoUrl)
        $localization = [Windows.Management.Update.WindowsSoftwareUpdateLocalizationInfo]::new(
            $locInfo.LanguageId,
            $locInfo.Title,
            $locInfo.Description,
            $locUrl
        )
        $localizationList.Add($localization)
    }

    # Create optional info with localization and compliance values
    $optionalInfo = if ($localizationList.Count -gt 0 -or $ComplianceDeadlineInDays -ne $null -or $ComplianceGracePeriodInDays -ne $null) {
        # Create boxed values for nullable integers
        $deadlineValue = if ($ComplianceDeadlineInDays -ne $null) { [System.Nullable[int]]::new($ComplianceDeadlineInDays) } else { $null }
        $graceValue = if ($ComplianceGracePeriodInDays -ne $null) { [System.Nullable[int]]::new($ComplianceGracePeriodInDays) } else { $null }

        [Windows.Management.Update.WindowsSoftwareUpdateOptionalInfo]::new(
            $Category,
            $localizationList,
            $deadlineValue, # ComplianceDeadlineInDays
            $graceValue    # ComplianceGracePeriodInDays
        )
    } else {
        $null
    }

    # Use provided command strings
    $deployCmd = $DeployCommand

    # Create the primary action info
    $deployActionInfo = [Windows.Management.Update.WindowsSoftwareUpdateActionInfo]::new(
        $DeployFileName,
        $deployCmd,
        [Windows.Management.Update.WindowsSoftwareUpdateActionType]::Deploy
    )

    # Create optional actions info using helper function
    $optionalActionsInfo = New-OptionalActionsInfo `
        -CloseAndDeployFileName $CloseAndDeployFileName `
        -CloseAndDeployCommand $CloseAndDeployCommand `
    -RestartFileName $RestartFileName `
    -RestartCommand $RestartCommand

    # Create execution info
    $executionInfo = [Windows.Management.Update.WindowsSoftwareUpdateExecutionInfo]::new(
        $deployActionInfo,  # DeployInfo
        $optionalActionsInfo
    )

    # Create update identity from product code
    $updateIdentity = [Windows.Management.Update.WindowsSoftwareUpdateIdentity]::new(
        [Windows.Management.Update.WindowsSoftwareUpdateIdentityType]::ProductCode,
        $ProductCode
    )

    # Create the WindowsSoftwareUpdate object
    $update = [Windows.Management.Update.WindowsSoftwareUpdate]::new(
        $ProviderId,
        $InstallationType,
        $UpdateId,
        $Title,
        $Description,
        $moreInfoUrlObj,
        $DownloadSize,
        $InstallSize,
        $updateIdentity,
        $sourceVersionObj,
        $targetVersionObj,
        $null,              # AppPackage info
        $executionInfo,
        $optionalInfo
    )

    # Show detailed update information when -Verbose is used
    if ($VerbosePreference -eq 'Continue') {
        Show-WindowsSoftwareUpdate -Update $update
    }

    return $update
}

# Create actual WinRT WindowsSoftwareUpdate object for PowerShell Download/Install Update
function New-DownloadInstallUpdate {
    <#
    .SYNOPSIS
    Creates a WindowsSoftwareUpdate object for executable download/install updates.

    .DESCRIPTION
    Creates a download/install-type WindowsSoftwareUpdate object with appropriate action commands.

    .PARAMETER ProviderId
    The provider ID to associate with the update.

    .PARAMETER PackageId
    The package ID for the update.

    .PARAMETER PackageVersion
    The package version for the update.

    .PARAMETER Title
    The title of the update.

    .PARAMETER Description
    The description of the update.

    .PARAMETER MoreInfoUrl
    The more info URL for the update.

    .PARAMETER DownloadSize
    The download size in bytes.

    .PARAMETER InstallSize
    The install size in bytes.

    .PARAMETER DownloadFileName
    The filename to use for the download action.

    .PARAMETER DownloadCommand
    The download command string to use for the download action.

    .PARAMETER InstallFileName
    The filename to use for the install action.

    .PARAMETER InstallCommand
    The install command string to use for the install action.

    .PARAMETER CloseAndInstallFileName
    The filename to use for the close and install action.

    .PARAMETER CloseAndInstallCommand
    The command string to use for the close and install action.

    .PARAMETER RestartFileName
    The filename to use for the restart action.

    .PARAMETER RestartCommand
    The restart command string to use for the restart action.

    .PARAMETER LocalizationInfo
    Optional array of localization info hashtables. Each hashtable should contain LanguageId, Title, Description, and MoreInfoUrl.

    .EXAMPLE
    $update = New-DownloadInstallUpdate -ProviderId "SampleProvider" -UpdateId "ABC123DEF456" -Title "Sample Download/Install Update" -Description "Sample download/install update description" -MoreInfoUrl "http://contoso.com/updateId=SampleApp.DownloadInstall_5.6.7.8" -DownloadFileName "download.ps1" -DownloadCommand "download -ProviderId SampleProvider -UpdateId SampleApp.DownloadInstall_5.6.7.8" -InstallFileName "install.ps1" -InstallCommand "install -ProviderId SampleProvider -UpdateId SampleApp.DownloadInstall_5.6.7.8"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProviderId,
        [Parameter(Mandatory=$true)]
        [string]$UpdateId,
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$Description,
        [Parameter(Mandatory=$true)]
        [string]$MoreInfoUrl,
        [string]$SourceVersion = "0.0.0.0",
        [string]$TargetVersion = "0.0.0.0",
        [int64]$DownloadSize = 0,
        [int64]$InstallSize = 0,
        [Parameter(Mandatory=$true)]
        [Windows.Management.Update.WindowsSoftwareUpdateInstallationType]$InstallationType,
        [Parameter(Mandatory=$true)]
        [string]$DownloadFileName,
        [string]$DownloadCommand = "",
        [Parameter(Mandatory=$true)]
        [string]$InstallFileName,
        [string]$InstallCommand = "",
        [string]$CloseAndInstallCommand = "",
        [string]$CloseAndInstallFileName = "",
    [string]$RestartCommand = "",
    [string]$RestartFileName = "",
        [array]$LocalizationInfo = @(),
        [Nullable[int]]$ComplianceDeadlineInDays = $null,
        [Nullable[int]]$ComplianceGracePeriodInDays = $null,
        # The orchestrator rejects scan results whose ProductCode is not in the live installed-app
        # inventory. This default matches the named uninstall key registered by sample-products.reg;
        # import that .reg file (as Administrator) before running.
        [string]$ProductCode = "SampleApp.DownloadInstall",
        [Windows.Management.Update.WindowsSoftwareUpdateCategory]$Category = [Windows.Management.Update.WindowsSoftwareUpdateCategory]::Application
    )

    # Display update information with Write-Verbose (will only show if -Verbose is used)
    Write-Verbose "Creating Executable Download/Install software update..."
    Write-Verbose "Update ID: $UpdateId"
    Write-Verbose "Source Version: $SourceVersion"
    Write-Verbose "Target Version: $TargetVersion"

    # Create version objects directly from version strings
    $sourceVersionObj = New-VersionObject $SourceVersion
    $targetVersionObj = New-VersionObject $TargetVersion

    $moreInfoUrlObj = [System.Uri]::new($MoreInfoUrl)

    # Create localization info
    $localizationList = [System.Collections.Generic.List[Windows.Management.Update.WindowsSoftwareUpdateLocalizationInfo]]::new()

    # Add provided localization info
    foreach ($locInfo in $LocalizationInfo) {
        $locUrl = [System.Uri]::new($locInfo.MoreInfoUrl)
        $localization = [Windows.Management.Update.WindowsSoftwareUpdateLocalizationInfo]::new(
            $locInfo.LanguageId,
            $locInfo.Title,
            $locInfo.Description,
            $locUrl
        )
        $localizationList.Add($localization)
    }

    # Create optional info with localization and compliance values
    $optionalInfo = if ($localizationList.Count -gt 0 -or $ComplianceDeadlineInDays -ne $null -or $ComplianceGracePeriodInDays -ne $null) {
        # Create boxed values for nullable integers
        $deadlineValue = if ($ComplianceDeadlineInDays -ne $null) { [System.Nullable[int]]::new($ComplianceDeadlineInDays) } else { $null }
        $graceValue = if ($ComplianceGracePeriodInDays -ne $null) { [System.Nullable[int]]::new($ComplianceGracePeriodInDays) } else { $null }

        [Windows.Management.Update.WindowsSoftwareUpdateOptionalInfo]::new(
            $Category,
            $localizationList,
            $deadlineValue, # ComplianceDeadlineInDays
            $graceValue    # ComplianceGracePeriodInDays
        )
    } else {
        $null
    }

    # Use provided command strings
    $downloadCmd = $DownloadCommand
    $installCmd = $InstallCommand

    # Create primary action info objects
    $downloadActionInfo = [Windows.Management.Update.WindowsSoftwareUpdateActionInfo]::new(
        $DownloadFileName,
        $downloadCmd,
        [Windows.Management.Update.WindowsSoftwareUpdateActionType]::Download
    )

    $installActionInfo = [Windows.Management.Update.WindowsSoftwareUpdateActionInfo]::new(
        $InstallFileName,
        $installCmd,
        [Windows.Management.Update.WindowsSoftwareUpdateActionType]::Install
    )

    # Create optional actions info using helper function
    $optionalActionsInfo = New-OptionalActionsInfo `
        -CloseAndInstallFileName $CloseAndInstallFileName `
        -CloseAndInstallCommand $CloseAndInstallCommand `
    -RestartFileName $RestartFileName `
    -RestartCommand $RestartCommand

    # Create execution info
    $executionInfo = [Windows.Management.Update.WindowsSoftwareUpdateExecutionInfo]::new(
        $downloadActionInfo, # DownloadInfo
        $installActionInfo,  # InstallInfo
        $optionalActionsInfo
    )

    # Create update identity from product code
    $updateIdentity = [Windows.Management.Update.WindowsSoftwareUpdateIdentity]::new(
        [Windows.Management.Update.WindowsSoftwareUpdateIdentityType]::ProductCode,
        $ProductCode
    )

    # Create the WindowsSoftwareUpdate object
    $update = [Windows.Management.Update.WindowsSoftwareUpdate]::new(
        $ProviderId,
        $InstallationType,
        $UpdateId,
        $Title,
        $Description,
        $moreInfoUrlObj,
        $DownloadSize,
        $InstallSize,
        $updateIdentity,
        $sourceVersionObj,
        $targetVersionObj,
        $null,              # AppPackage info
        $executionInfo,
        $optionalInfo
    )

    # Show detailed update information when -Verbose is used
    if ($VerbosePreference -eq 'Continue') {
        Show-WindowsSoftwareUpdate -Update $update
    }

    return $update
}

# Create actual WinRT WindowsSoftwareUpdate object for AppPackage Update
function New-AppPackageUpdate {
    <#
    .SYNOPSIS
    Creates a WindowsSoftwareUpdate object for AppPackage updates.

    .DESCRIPTION
    Creates an AppPackage-type WindowsSoftwareUpdate object.

    .PARAMETER ProviderId
    The provider ID to associate with the update.

    .PARAMETER UpdateId
    The unique update ID for this update.

    .PARAMETER PackageFamilyName
    The package family name for the app package.

    .PARAMETER Architecture
    The architecture (X64, X86, ARM64, etc.).

    .PARAMETER Title
    The title of the update.

    .PARAMETER Description
    The description of the update.

    .PARAMETER PackageVersion
    The package version for the update.

    .PARAMETER MoreInfoUrl
    The more info URL for the update.

    .PARAMETER InstallUri
    The install URI for the app package.

    .PARAMETER SourceVersion
    The source version of the update.

    .PARAMETER TargetVersion
    The target version of the update.

    .PARAMETER DownloadSize
    The download size in bytes.

    .PARAMETER InstallSize
    The install size in bytes.

    .EXAMPLE
    $update = New-AppPackageUpdate -ProviderId "SampleProvider" -UpdateId "ABC123DEF456" -PackageFamilyName "Microsoft.OutlookForWindows_8wekyb3d8bbwe" -Architecture "X64" -Title "Outlook Package Update" -Description "Outlook package update description" -PackageVersion "2.3.4.5"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProviderId,
        [Parameter(Mandatory=$true)]
        [string]$UpdateId,
        [Parameter(Mandatory=$true)]
        [string]$PackageFamilyName,
        [Parameter(Mandatory=$true)]
        [string]$Architecture,
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$Description,
        [Parameter(Mandatory=$true)]
        [string]$PackageVersion,
        [Parameter(Mandatory=$true)]
        [string]$MoreInfoUrl,
        [Parameter(Mandatory=$true)]
        [string]$InstallUri,
        [string]$SourceVersion = "0.0.0.0",
        [string]$TargetVersion = "0.0.0.0",
        [int64]$DownloadSize = 0,
        [int64]$InstallSize = 0,
        [Nullable[int]]$ComplianceDeadlineInDays = $null,
        [Nullable[int]]$ComplianceGracePeriodInDays = $null,
        [array]$LocalizationInfo = @(),
        [Windows.Management.Update.WindowsSoftwareUpdateCategory]$Category = [Windows.Management.Update.WindowsSoftwareUpdateCategory]::Application
    )

    # Display package information with Write-Verbose (will only show if -Verbose is used)
    Write-Verbose "Creating AppPackage software update..."
    Write-Verbose "Package Family Name: $PackageFamilyName"
    Write-Verbose "Architecture: $Architecture"
    Write-Verbose "UpdateId: $UpdateId"
    Write-Verbose "Source Version: $SourceVersion"
    Write-Verbose "Target Version: $TargetVersion"

    # Create version objects directly from version strings
    $sourceVersionObj = New-VersionObject $SourceVersion
    $targetVersionObj = New-VersionObject $TargetVersion
    $moreInfoUrlObj = [System.Uri]::new($MoreInfoUrl)

    $installUriObj = [System.Uri]::new($InstallUri)

    # Map architecture string to enum
    $architectureEnum = switch ($Architecture.ToUpper()) {
        "X64" { [Windows.Management.Update.WindowsSoftwareUpdateArchitecture]::X64 }
        "X86" { [Windows.Management.Update.WindowsSoftwareUpdateArchitecture]::X86 }
        "ARM64" { [Windows.Management.Update.WindowsSoftwareUpdateArchitecture]::Arm64 }
        "ARM" { [Windows.Management.Update.WindowsSoftwareUpdateArchitecture]::Arm }
        default { [Windows.Management.Update.WindowsSoftwareUpdateArchitecture]::X64 }
    }

    # Create localization info
    $localizationList = [System.Collections.Generic.List[Windows.Management.Update.WindowsSoftwareUpdateLocalizationInfo]]::new()

    # Add provided localization info
    foreach ($locInfo in $LocalizationInfo) {
        $locUrl = [System.Uri]::new($locInfo.MoreInfoUrl)
        $localization = [Windows.Management.Update.WindowsSoftwareUpdateLocalizationInfo]::new(
            $locInfo.LanguageId,
            $locInfo.Title,
            $locInfo.Description,
            $locUrl
        )
        $localizationList.Add($localization)
    }

    # Create AppPackage info
    $appPackageInfo = [Windows.Management.Update.WindowsSoftwareUpdateAppPackageInfo]::new(
        $PackageFamilyName,
        $architectureEnum,
        $installUriObj
    )

    # Create optional info with compliance values if provided
    $optionalInfo = if ($ComplianceDeadlineInDays -ne $null -or $ComplianceGracePeriodInDays -ne $null -or $localizationList.Count -gt 0) {
        # Create boxed values for nullable integers
        $deadlineValue = if ($ComplianceDeadlineInDays -ne $null) { [System.Nullable[int]]::new($ComplianceDeadlineInDays) } else { $null }
        $graceValue = if ($ComplianceGracePeriodInDays -ne $null) { [System.Nullable[int]]::new($ComplianceGracePeriodInDays) } else { $null }

        [Windows.Management.Update.WindowsSoftwareUpdateOptionalInfo]::new(
            $Category,
            $localizationList,
            $deadlineValue,
            $graceValue
        )
    } else {
        $null
    }

    # Create update identity from package family name
    $updateIdentity = [Windows.Management.Update.WindowsSoftwareUpdateIdentity]::new(
        [Windows.Management.Update.WindowsSoftwareUpdateIdentityType]::PackageFamilyName,
        $PackageFamilyName
    )

    # Create the WindowsSoftwareUpdate object
    $update = [Windows.Management.Update.WindowsSoftwareUpdate]::new(
        $ProviderId,
        [Windows.Management.Update.WindowsSoftwareUpdateInstallationType]::AppPackage,
        $UpdateId,
        $Title,
        $Description,
        $moreInfoUrlObj,
        $DownloadSize,
        $InstallSize,
        $updateIdentity,
        $sourceVersionObj,
        $targetVersionObj,
        $appPackageInfo,
        $null,          # Execution info (none for AppPackage in sample)
        $optionalInfo
    )

    # Show detailed update information when -Verbose is used
    if ($VerbosePreference -eq 'Continue') {
        Show-WindowsSoftwareUpdate -Update $update
    }

    return $update
}

#endregion

#region Provider Status Helper Functions

# Helper function to create and submit scan results
function Set-ScanResult {
    <#
    .SYNOPSIS
    Sets scan results in the Windows Update Provider Status API.

    .DESCRIPTION
    Creates a provider status object and sets the provided update collection as scan results.

    .PARAMETER ProviderId
    The provider ID to use for the scan.

    .PARAMETER UpdateCollection
    Collection of WindowsSoftwareUpdate objects to report.

    .PARAMETER Succeeded
    Whether the scan succeeded. Defaults to $true.

    .PARAMETER ResultCode
    HRESULT for the scan result. Defaults to S_OK (0). Pass an unsigned 32-bit value;
    if you have a signed Int32 HRESULT, reinterpret its bits with:
        [uint32]([int64]$hr -band 0xFFFFFFFFL)

    .PARAMETER ExtendedError
    Provider-defined 64-bit extended error code. Defaults to 0.

    .EXAMPLE
    $updates = @($update1, $update2)
    Set-ScanResult -ProviderId "SampleProvider" -UpdateCollection $updates

    .EXAMPLE
    Set-ScanResult -ProviderId "SampleProvider" -UpdateCollection @() `
        -Succeeded $false -ResultCode ([uint32]0x80070005) -ExtendedError 0
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProviderId,
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[Windows.Management.Update.WindowsSoftwareUpdate]]$UpdateCollection,
        [bool]$Succeeded = $true,
        [uint32]$ResultCode = 0,
        [uint64]$ExtendedError = 0
    )

    Write-OutputMessage "Creating provider status..."
    $providerStatus = [Windows.Management.Update.WindowsSoftwareUpdateProviderStatus]::new($ProviderId)

    Write-OutputMessage "Setting scan result..."
    $statusResult = $providerStatus.SetScanResult($Succeeded, $ResultCode, $ExtendedError, $UpdateCollection)

    if ($statusResult) {
        Write-ResultMessage "SetScanResult()" $statusResult
    } else {
        Write-OutputMessage "SetScanResult() -> Warning: Returned null result"
    }
}

# Helper function to send action progress
function Set-ActionProgress {
    <#
    .SYNOPSIS
    Sets action progress in the Windows Update Provider Status API.

    .DESCRIPTION
    Creates a provider status object and sets progress for an action.

    .PARAMETER ProviderId
    The provider ID to use for the action.

    .PARAMETER CurrentProgress
    The current progress value.

    .PARAMETER TotalProgress
    The total progress value.

    .EXAMPLE
    Set-ActionProgress -ProviderId "SampleProvider" -CurrentProgress 50 -TotalProgress 100
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProviderId,
        [Parameter(Mandatory=$true)]
        [uint64]$CurrentProgress,
        [Parameter(Mandatory=$true)]
        [uint64]$TotalProgress
    )

    $providerStatus = [Windows.Management.Update.WindowsSoftwareUpdateProviderStatus]::new($ProviderId)

    try {
        $progressResult = $providerStatus.SetActionProgress($CurrentProgress, $TotalProgress)
        Write-ResultMessage "SetActionProgress()" $progressResult
    }
    catch {
        Write-OutputMessage "SetActionProgress() -> Failed: $($_.Exception.Message)"
    }
}

# Helper function to send action result
function Set-ActionResult {
    <#
    .SYNOPSIS
    Sets action result in the Windows Update Provider Status API.

    .DESCRIPTION
    Creates a provider status object and sets the final result of an action.

    .PARAMETER ProviderId
    The provider ID to use for the action.

    .PARAMETER Result
    The result status to report.

    .PARAMETER Reason
    The restart reason (if applicable).

    .PARAMETER ResultCode
    The result code to report.

    .PARAMETER ExtendedError
    The extended error code to report.

    .EXAMPLE
    Set-ActionResult -ProviderId "SampleProvider" -Result "Succeeded" -ResultCode 0
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProviderId,
        [Parameter(Mandatory=$true)]
        [Windows.Management.Update.WindowsSoftwareUpdateActionResult]$Result,
        [Parameter(Mandatory=$true)]
        [Windows.Management.Update.WindowsSoftwareUpdateRestartReason]$Reason,
        [uint32]$ResultCode = 0,
        [uint64]$ExtendedError = 0
    )

    Write-OutputMessage "Creating provider status..."
    $providerStatus = [Windows.Management.Update.WindowsSoftwareUpdateProviderStatus]::new($ProviderId)

    Write-OutputMessage "Creating provider action result..."
    $actionResult = [Windows.Management.Update.WindowsSoftwareUpdateProviderActionResult]::new($Result, $Reason, $ResultCode, $ExtendedError)

    Write-OutputMessage "Setting action result..."
    try {
        $statusResult = $providerStatus.SetActionResult($actionResult)
        Write-ResultMessage "SetActionResult()" $statusResult
    }
    catch {
        Write-OutputMessage "SetActionResult() -> Failed: $($_.Exception.Message)"
    }
}

#endregion

#region Logging Functions

# Enable logging function
function Enable-ProviderLogging {
    <#
    .SYNOPSIS
    Enables logging for update provider operations.

    .DESCRIPTION
    Sets up logging to a file in the State subfolder relative to the script location.
    Either ProviderId or LogFileName must be provided to enable logging.
    Includes automatic log rotation when files exceed 10MB.

    .PARAMETER ProviderId
    The ID of the provider, used as part of the log file name.

    .PARAMETER LogFileName
    The name of the log file. If not specified but ProviderId is, log file will be "{ProviderId}.log".

    .PARAMETER MaxLogSizeMB
    Maximum log file size in MB before rotation. Default is 10MB.

    .EXAMPLE
    $success = Enable-ProviderLogging -ProviderId "MyCustomProvider"

    .EXAMPLE
    $success = Enable-ProviderLogging -LogFileName "CustomLogFile.log" -MaxLogSizeMB 5
    #>
    param(
        [string]$ProviderId = "",
        [string]$LogFileName = "",
        [int]$MaxLogSizeMB = 10
    )

    # If neither ProviderId nor LogFileName is provided, do not enable logging
    if ([string]::IsNullOrEmpty($ProviderId) -and [string]::IsNullOrEmpty($LogFileName)) {
        Write-Warning "Logging not enabled: Either ProviderId or LogFileName must be provided."
        return $false
    }

    try {
        # Get the directory containing the script
        $ScriptPath = Get-CurrentModulePath

        # Determine the log file name based on ProviderId if LogFileName is not provided
        if ([string]::IsNullOrEmpty($LogFileName) -and -not [string]::IsNullOrEmpty($ProviderId)) {
            $LogFileName = "$ProviderId.log"
        }

        $scriptDir = Split-Path -Parent $ScriptPath
        $stateDir = Join-Path $scriptDir "State"
        $logPath = Join-Path $stateDir $LogFileName

        # Create the State directory if it doesn't exist
        if (-not (Test-Path $stateDir)) {
            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
        }

        # Check if log file exists and needs rotation
        if (Test-Path $logPath) {
            $logFile = Get-Item $logPath
            $logSizeMB = [math]::Round($logFile.Length / 1MB, 2)

            if ($logSizeMB -gt $MaxLogSizeMB) {
                # Rotate the log file
                $oldLogPath = Join-Path $stateDir "$($LogFileName).old"
                if (Test-Path $oldLogPath) {
                    Remove-Item $oldLogPath -Force
                }
                Move-Item $logPath $oldLogPath
                Write-Verbose "Log file rotated: $logSizeMB MB -> $oldLogPath"
            }
        }

        $script:LogFile = $logPath
        $script:LoggingEnabled = $true

        # Write a timestamp to the log
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $logPath -Value "=== Update Provider Log Started at $timestamp ===" -Encoding UTF8

        return $true
    }
    catch {
        Write-Error "Exception setting up logging: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Module Exports

# Export utility functions that create WinRT objects
Export-ModuleMember -Function New-VersionObject
Export-ModuleMember -Function New-OptionalActionsInfo

# Export the main update creation functions
Export-ModuleMember -Function New-DeployUpdate
Export-ModuleMember -Function New-DownloadInstallUpdate
Export-ModuleMember -Function New-AppPackageUpdate

# Export provider status functions
Export-ModuleMember -Function Set-ScanResult
Export-ModuleMember -Function Set-ActionProgress
Export-ModuleMember -Function Set-ActionResult

# Export utility functions
Export-ModuleMember -Function New-UpdateId
Export-ModuleMember -Function Enable-ProviderLogging
Export-ModuleMember -Function Show-WindowsSoftwareUpdate
Export-ModuleMember -Function Write-OutputMessage
Export-ModuleMember -Function Write-ErrorMessage
Export-ModuleMember -Function Write-VerboseMessage
Export-ModuleMember -Function Get-FileSizeFromUrl
#endregion
