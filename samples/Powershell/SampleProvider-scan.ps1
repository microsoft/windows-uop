#
# Copyright (c) Microsoft Corporation.  All rights reserved.
#
# Version: 1.0.0.0
# Revision: 2025.10.08
#

<#
.SYNOPSIS
    Windows Update Sample Provider - Scan Operations

.DESCRIPTION
    Performs a sample provider scan: constructs sample WindowsSoftwareUpdate objects (Deploy, Download/Install, AppPackage)
    and submits them via provider status APIs. Optional "close and *" and restart actions are included and mapped to
    supported ActionType values (Deploy, Install, AppRestart) per the updated WindowsManagement.Update contract.

    When creating executable/Powershell updates, this script references SampleProvider-action.ps1 as the executable
    script file for performing the actions.

.PARAMETER ProviderId
    The provider ID to use (defaults to 'SampleProvider').

.PARAMETER LogFile
    Enables logging to the specified log file in the State subfolder (rotated by module functions).

.EXAMPLE
    .\SampleProvider-scan.ps1 -ProviderId "MyProvider" -LogFile "MyProvider-scan.log" -Verbose
#>

[CmdletBinding()]
param(
    [string]$ProviderId = "SampleProvider",
    [string]$LogFile = ""
    # -Verbose is automatically available via [CmdletBinding()]
)

#region Scan Implementation

function Invoke-ProviderScan {
    <#
    .SYNOPSIS
    Performs the sample provider scan operation.

    .DESCRIPTION
    Creates sample updates and reports them to Windows Update via the provider status APIs.
    This contains the actual sample content and update definitions.

    .PARAMETER ProviderId
    The provider ID to use for the scan.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProviderId
    )

    Write-VerboseMessage "=== SCAN RESULTS ==="
    Write-VerboseMessage "Provider ID: $ProviderId"
    Write-VerboseMessage ""

    $ActionScriptFileName = "SampleProvider-action.ps1"
    $ActionScriptInstallationType = [Windows.Management.Update.WindowsSoftwareUpdateInstallationType]::Powershell

    # Create individual update examples for demonstration purposes

    Write-VerboseMessage "Creating empty software update collection..."

    # Create the collection directly in the script to avoid module boundary issues
    try {
        $updateCollection = [System.Collections.Generic.List[Windows.Management.Update.WindowsSoftwareUpdate]]::new()
        Write-VerboseMessage "Update collection created successfully. Type: $($updateCollection.GetType().FullName)"
    }
    catch {
        Write-Error "Failed to create update collection: $($_.Exception.Message)"
        return
    }

    Write-OutputMessage "Creating 3 sample updates individually..."

    # Add LogFile parameter if logging is enabled
    $ExtraArgs = ""
    if (-not [string]::IsNullOrEmpty($LogFile)) {
        $ExtraArgs += " -LogFile `"$LogFile`""
    }

    # Add Verbose parameter if verbose mode is enabled
    if ($VerbosePreference -eq 'Continue') {
        $ExtraArgs += " -Verbose"
    }

    #region Create Deploy Update Example
    Write-OutputMessage "Creating Deploy Update example..."

    # Deploy Update properties
    $deployTitle = "Sample Deploy Update (1.2.3.4)"
    $deployVersion = "1.2.3.4"
    $deployUpdateId = New-UpdateId -ProviderId $ProviderId -Title $deployTitle -Version $deployVersion

    # Build command strings
    $deployCommand = "deploy -ProviderId `"$ProviderId`" -UpdateId `"$deployUpdateId`"$ExtraArgs"
    $closeAndDeployCommand = "deploy -ForceClose -ProviderId `"$ProviderId`" -UpdateId `"$deployUpdateId`"$ExtraArgs"
    $deployRestartCommand = "restart -ProviderId `"$ProviderId`" -UpdateId `"$deployUpdateId`"$ExtraArgs"

    # Create the deploy update
    $deployUpdate = New-DeployUpdate `
        -ProviderId $ProviderId `
        -UpdateId $deployUpdateId `
        -Title $deployTitle `
        -Description "This is a sample PowerShell executable deploy update for demonstration purposes." `
        -MoreInfoUrl "http://contoso.com/updateId=SampleApp.Deploy_1.2.3.4" `
        -TargetVersion $deployVersion `
        -DownloadSize ([uint64]1048576) `
        -InstallSize ([uint64]2097152) `
        -InstallationType $ActionScriptInstallationType `
        -DeployFileName $ActionScriptFileName `
        -DeployCommand $deployCommand `
        -CloseAndDeployFileName $ActionScriptFileName `
        -CloseAndDeployCommand $closeAndDeployCommand `
        -RestartFileName $ActionScriptFileName `
        -RestartCommand $deployRestartCommand `
        -LocalizationInfo @(
            @{
                LanguageId = 3082
                Title = "PowerShell Deploy Actualización 1234 Título (es-ES)"
                Description = "PowerShell Deploy Actualización 1234 Descripción (es-ES)"
                MoreInfoUrl = "http://contoso.com/es-ES/updateId=SampleApp.Deploy_1.2.3.4"
            },
            @{
                LanguageId = 1036
                Title = "PowerShell Deploy Mise à jour 1234 Titre (fr-FR)"
                Description = "PowerShell Deploy Mise à jour 1234 Description (fr-FR)"
                MoreInfoUrl = "http://contoso.com/fr-FR/updateId=SampleApp.Deploy_1.2.3.4"
            }
        )

    Write-VerboseMessage "Deploy Update created: $($deployUpdate.UpdateId)"
    Write-VerboseMessage "Title: $($deployUpdate.Title)"
    Write-VerboseMessage "Version: $($deployUpdate.TargetVersion.Major).$($deployUpdate.TargetVersion.Minor).$($deployUpdate.TargetVersion.RevisionMajor).$($deployUpdate.TargetVersion.RevisionMinor)"
    Write-VerboseMessage ""

    $updateCollection.Add($deployUpdate)
    Write-OutputMessage "Added Deploy Update to collection"
    #endregion

    #region Create Download/Install Update Example
    Write-OutputMessage "Creating Download/Install Update example..."

    # Download/Install Update properties
    $downloadInstallTitle = "Sample Download/Install Update (5.6.7.8)"
    $downloadInstallVersion = "5.6.7.8"
    $downloadInstallUpdateId = New-UpdateId -ProviderId $ProviderId -Title $downloadInstallTitle -Version $downloadInstallVersion

    # Build command strings
    $downloadCommand = "download -ProviderId `"$ProviderId`" -UpdateId `"$downloadInstallUpdateId`"$ExtraArgs"
    $installCommand = "install -ProviderId `"$ProviderId`" -UpdateId `"$downloadInstallUpdateId`"$ExtraArgs"
    $closeAndInstallCommand = "install -ForceClose -ProviderId `"$ProviderId`" -UpdateId `"$downloadInstallUpdateId`"$ExtraArgs"
    $downloadInstallRestartCommand = "restart -ProviderId `"$ProviderId`" -UpdateId `"$downloadInstallUpdateId`"$ExtraArgs"

    # Create the download/install update
    $downloadInstallUpdate = New-DownloadInstallUpdate `
        -ProviderId $ProviderId `
        -UpdateId $downloadInstallUpdateId `
        -Title $downloadInstallTitle `
        -Description "This is a sample PowerShell executable download/install update for demonstration purposes." `
        -MoreInfoUrl "http://contoso.com/updateId=SampleApp.DownloadInstall_5.6.7.8" `
        -InstallationType $ActionScriptInstallationType `
        -TargetVersion $downloadInstallVersion `
        -DownloadSize ([uint64]1048576) `
        -InstallSize ([uint64]2097152) `
        -DownloadFileName $ActionScriptFileName `
        -DownloadCommand $downloadCommand `
        -InstallFileName $ActionScriptFileName `
        -InstallCommand $installCommand `
        -CloseAndInstallFileName $ActionScriptFileName `
        -CloseAndInstallCommand $closeAndInstallCommand `
        -RestartFileName $ActionScriptFileName `
        -RestartCommand $downloadInstallRestartCommand `
        -LocalizationInfo @(
            @{
                LanguageId = 3082
                Title = "PowerShell Download/Install Actualización 5678 Título (es-ES)"
                Description = "PowerShell Download/Install Actualización 5678 Descripción (es-ES)"
                MoreInfoUrl = "http://contoso.com/es-ES/updateId=SampleApp.DownloadInstall_5.6.7.8"
            },
            @{
                LanguageId = 1036
                Title = "PowerShell Download/Install Mise à jour 5678 Titre (fr-FR)"
                Description = "PowerShell Download/Install Mise à jour 5678 Description (fr-FR)"
                MoreInfoUrl = "http://contoso.com/fr-FR/updateId=SampleApp.DownloadInstall_5.6.7.8"
            }
        )

    Write-VerboseMessage "Download/Install Update created: $($downloadInstallUpdate.UpdateId)"
    Write-VerboseMessage "Title: $($downloadInstallUpdate.Title)"
    Write-VerboseMessage "Version: $($downloadInstallUpdate.TargetVersion.Major).$($downloadInstallUpdate.TargetVersion.Minor).$($downloadInstallUpdate.TargetVersion.RevisionMajor).$($downloadInstallUpdate.TargetVersion.RevisionMinor)"
    Write-VerboseMessage ""

    $updateCollection.Add($downloadInstallUpdate)
    Write-OutputMessage "Added Download/Install Update to collection"
    #endregion

    #region Create App Package Update Example
    Write-OutputMessage "Creating App Package Update example..."

    # App Package Update properties
    $packageFamilyName = "Microsoft.OutlookForWindows_8wekyb3d8bbwe"
    $architecture = "X64"
    $packageVersion = "2.3.4.5"
    $packageTitle = "Outlook Package Update (2.3.4.5)"
    $packageInfo = "$packageFamilyName" + "_" + "$architecture"
    $packageUpdateId = New-UpdateId -ProviderId $ProviderId -Title $packageInfo -Version $packageVersion

    # Create the app package update
    $appPackageUpdate = New-AppPackageUpdate `
        -ProviderId $ProviderId `
        -UpdateId $packageUpdateId `
        -PackageFamilyName $packageFamilyName `
        -Architecture $architecture `
        -Title $packageTitle `
        -Description "This is a sample AppX package update for demonstration purposes." `
        -PackageVersion $packageVersion `
        -MoreInfoUrl "http://contoso.com/updateId=SampleApp.AppPackage_2.3.4.5" `
        -InstallUri "https://go.microsoft.com/fwlink/?linkid=2195164" `
        -SourceVersion "0.0.0.0" `
        -TargetVersion $packageVersion `
        -DownloadSize ([uint64]104857600) `
        -InstallSize ([uint64]314572800) `
        -LocalizationInfo @(
            @{
                LanguageId = 3082
                Title = "PowerShell AppPackage Actualización 2345 Título (es-ES)"
                Description = "PowerShell AppPackage Actualización 2345 Descripción (es-ES)"
                MoreInfoUrl = "http://contoso.com/es-ES/updateId=SampleApp.AppPackage_2.3.4.5"
            },
            @{
                LanguageId = 1036
                Title = "PowerShell AppPackage Mise à jour 2345 Titre (fr-FR)"
                Description = "PowerShell AppPackage Mise à jour 2345 Description (fr-FR)"
                MoreInfoUrl = "http://contoso.com/fr-FR/updateId=SampleApp.AppPackage_2.3.4.5"
            }
        )

    Write-VerboseMessage "App Package Update created: $($appPackageUpdate.UpdateId)"
    Write-VerboseMessage "Title: $($appPackageUpdate.Title)"
    Write-VerboseMessage "Version: $($appPackageUpdate.TargetVersion.Major).$($appPackageUpdate.TargetVersion.Minor).$($appPackageUpdate.TargetVersion.RevisionMajor).$($appPackageUpdate.TargetVersion.RevisionMinor)"
    Write-VerboseMessage ""

    $updateCollection.Add($appPackageUpdate)
    Write-OutputMessage "Added App Package Update to collection"
    #endregion

    # Debug: Check collection state before submitting
    Write-VerboseMessage "Final collection state: Count=$($updateCollection.Count), Type=$($updateCollection.GetType().FullName)"

    if ($null -eq $updateCollection) {
        Write-Error "Update collection is null before submission"
        return
    }

    # Submit the scan results using the helper function
    Set-ScanResult -ProviderId $ProviderId -UpdateCollection $updateCollection
}

#endregion

# Main execution logic
try {
    # Import the UOP-runtime module first
    $scriptDir = Split-Path -Parent $PSCommandPath
    $modulePath = Join-Path $scriptDir "UOP-runtime.psm1"

    if (-not (Test-Path $modulePath)) {
        Write-Error "UOP-runtime module not found at: $modulePath"
        Write-Error "Please ensure the module is available in the same directory as this script."
        exit 1
    }

    Import-Module $modulePath -Force

    # Process command line arguments and set up logging
    if (-not [string]::IsNullOrEmpty($LogFile)) {
        if (-not (Enable-ProviderLogging -LogFileName $LogFile -MaxLogSizeMB 5)) {
            Write-Error "Failed to set up logging, continuing with console output"
        } else {
            Write-OutputMessage "Logging enabled with 5MB rotation to: $LogFile"

            # Enable verbose output - when logging is enabled, verbose messages
            # will go only to the log file (not to console)
            $VerbosePreference = "Continue"
        }
    }

    Write-OutputMessage "SampleProvider Scan Script Starting..."
    Write-OutputMessage "Using provider ID: $ProviderId"

    if ($VerbosePreference -ne 'SilentlyContinue') {
        Write-OutputMessage "Verbose mode: Enabled"
    }

    # Perform the scan operation
    Invoke-ProviderScan -ProviderId $ProviderId
}
catch [System.Runtime.InteropServices.COMException] {
    # Handle WinRT/COM errors specifically (equivalent to winrt::hresult_error)
    $comException = $_.Exception
    Write-OutputMessage ""
    Write-OutputMessage "WinRT error: hr = $($comException.HResult), message: $($comException.Message)"
    exit 1
}
catch [System.Runtime.InteropServices.ExternalException] {
    # Handle other external/runtime errors (equivalent to std::runtime_error)
    Write-OutputMessage ""
    Write-OutputMessage "Error: $($_.Exception.Message)"
    exit 1
}
catch {
    # Handle all other exceptions (equivalent to catch(...))
    Write-OutputMessage ""
    Write-OutputMessage "Error encountered: $($_.Exception.Message)"
    exit 1
}

exit 0
