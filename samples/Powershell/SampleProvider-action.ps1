#
# Copyright (c) Microsoft Corporation.  All rights reserved.
#
# Version: 1.0.0.0
# Revision: 2025.10.08
#

<#
.SYNOPSIS
    Windows Update Sample Provider - Action Operations

.DESCRIPTION
    This script handles action operations for the Windows Update Sample Provider.
    It performs download, install, deploy, and restart actions for updates.

    This script is referenced by SampleProvider-scan.ps1 as the executable file path
    for performing update actions.

.PARAMETER Action
    The action to perform: download, install, deploy, restart

.PARAMETER ProviderId
    The provider ID to use (defaults to 'SampleProvider')

.PARAMETER UpdateId
    The update ID for the action (required for most actions)

.PARAMETER LogFile
    Enable logging to the specified log file in State subfolder

.PARAMETER ForceClose
    Force close applications during install/deploy actions

.EXAMPLE
    .\SampleProvider-action.ps1 download -ProviderId "MyProvider" -UpdateId "SampleApp.Deploy_1.2.3.4" -LogFile "MyProvider-action.log" -Verbose
    .\SampleProvider-action.ps1 install -UpdateId "SampleApp.Deploy_1.2.3.4" -ForceClose -LogFile "action.log"
#>

[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet("download", "install", "deploy", "restart")]
    [string]$Action,

    [string]$ProviderId = "SampleProvider",
    [string]$UpdateId = "",
    [string]$LogFile = "",
    [switch]$ForceClose
    # -Verbose is automatically available via [CmdletBinding()]
)

#region Action Implementation

function Invoke-ProviderAction {
    <#
    .SYNOPSIS
    Performs the specified action operation for this sample provider.

    .DESCRIPTION
    Implements the actual sample/fake update operations (download, install, deploy, restart)
    with progress reporting and result status updates via the UOP-runtime module helpers.

    .PARAMETER ProviderId
    The provider ID to use for the action.

    .PARAMETER ActionName
    The name of the action to perform.

    .PARAMETER UpdateId
    The update ID for the action.

    .PARAMETER ForceClose
    Whether to force close applications during the action.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProviderId,
        [Parameter(Mandatory=$true)]
        [string]$ActionName,
        [string]$UpdateId = "",
        [bool]$ForceClose = $false
    )

    Write-OutputMessage "=== Starting Provider Action Implementation ==="
    Write-OutputMessage "Provider ID: $ProviderId"
    Write-OutputMessage "Action: $ActionName"
    Write-OutputMessage "Action Script: $($MyInvocation.ScriptName)"

    if ($UpdateId) {
        Write-OutputMessage "Update ID: $UpdateId"
        Write-VerboseMessage "Working on Update ID: $UpdateId"
    } else {
        Write-OutputMessage "Update ID: (not specified)"
    }
    if ($ForceClose) {
        Write-OutputMessage "Force Close: Enabled"
    }

    try {
        # Validate that this is a supported action
        $supportedActions = @("download", "install", "deploy", "restart")
        if ($ActionName -notin $supportedActions) {
            throw "Unsupported action: $ActionName. Supported actions: $($supportedActions -join ', ')"
        }

        Write-VerboseMessage "Implementing sample $ActionName operation..."

        # Implement the actual sample update operation based on action type
        switch ($ActionName.ToLower()) {
            "download" {
                Invoke-SampleDownload -ProviderId $ProviderId -UpdateId $UpdateId
            }
            "install" {
                Invoke-SampleInstall -ProviderId $ProviderId -UpdateId $UpdateId -ForceClose $ForceClose
            }
            "deploy" {
                Invoke-SampleDeploy -ProviderId $ProviderId -UpdateId $UpdateId -ForceClose $ForceClose
            }
            "restart" {
                Invoke-SampleRestart -ProviderId $ProviderId -UpdateId $UpdateId
            }
            default {
                throw "Action implementation not found for: $ActionName"
            }
        }

        Write-OutputMessage "=== Provider Action Implementation Completed Successfully ==="
    }
    catch {
        Write-OutputMessage "Provider action implementation failed: $($_.Exception.Message)"

        # Report failure result using module helper
        try {
            $Reason = [Windows.Management.Update.WindowsSoftwareUpdateRestartReason]::None
            $Result = [Windows.Management.Update.WindowsSoftwareUpdateActionResult]::Failed
            # HResult is Int32; HRESULTs >= 0x80000000 are negative. Reinterpret bits as UInt32 for the WinRT API.
            $HResult = if ($_.Exception.HResult) { $_.Exception.HResult } else { -2147418113 } # 0x8000FFFF
            $ErrorCode = [uint32]([int64]$HResult -band 0xFFFFFFFFL)
            Set-ActionResult -ProviderId $ProviderId -Result $Result -Reason $Reason -ResultCode $ErrorCode
        }
        catch {
            Write-VerboseMessage "Failed to send action result: $($_.Exception.Message)"
        }

        throw
    }
}

#region Sample Action Implementations

function Invoke-SampleDownload {
    param([string]$ProviderId, [string]$UpdateId)

    Write-OutputMessage "Starting sample download operation..."
    Write-VerboseMessage "Download operation for UpdateId: $UpdateId"
    Write-VerboseMessage "Simulating download of 500MB file..."

    $totalSizeMB = 500
    $downloadedMB = 0
    $chunkSizeMB = 10  # Download 10MB chunks

    # Simulate downloading in chunks with variable timing
    while ($downloadedMB -lt $totalSizeMB) {
        $downloadedMB = [Math]::Min($downloadedMB + $chunkSizeMB, $totalSizeMB)
        $progressPercentage = [Math]::Round(($downloadedMB / $totalSizeMB) * 100)

        Write-VerboseMessage "Downloaded: ${downloadedMB}MB / ${totalSizeMB}MB (${progressPercentage}%)"
        Set-ActionProgress -ProviderId $ProviderId -CurrentProgress $downloadedMB -TotalProgress $totalSizeMB

        if ($downloadedMB -lt $totalSizeMB) {
            # Simulate variable download speeds (faster at start, slower in middle, faster at end)
            if ($progressPercentage -lt 30 -or $progressPercentage -gt 80) {
                Start-Sleep -Milliseconds 50   # Fast download (demo speed)
            } else {
                Start-Sleep -Milliseconds 100  # Slower download in middle (demo speed)
            }
        }
    }

    $Reason = [Windows.Management.Update.WindowsSoftwareUpdateRestartReason]::None
    $Result = [Windows.Management.Update.WindowsSoftwareUpdateActionResult]::Succeeded
    Set-ActionResult -ProviderId $ProviderId -Result $Result -Reason $Reason
    Write-OutputMessage "Sample download operation completed successfully (500MB simulated)"
}

function Invoke-SampleInstall {
    param([string]$ProviderId, [string]$UpdateId, [bool]$ForceClose)

    Write-OutputMessage "Starting sample install operation..."
    Write-VerboseMessage "Install operation for UpdateId: $UpdateId, ForceClose: $ForceClose"

    # Simulate install with simple progress updates
    for ($progress = 0; $progress -le 100; $progress += 20) {
        Set-ActionProgress -ProviderId $ProviderId -CurrentProgress $progress -TotalProgress 100
        if ($progress -lt 100) { Start-Sleep -Seconds 1 }
    }

    $Reason = [Windows.Management.Update.WindowsSoftwareUpdateRestartReason]::None
    $Result = [Windows.Management.Update.WindowsSoftwareUpdateActionResult]::Succeeded
    Set-ActionResult -ProviderId $ProviderId -Result $Result -Reason $Reason
    Write-OutputMessage "Sample install operation completed successfully"
}

function Invoke-SampleDeploy {
    param([string]$ProviderId, [string]$UpdateId, [bool]$ForceClose)

    Write-OutputMessage "Starting sample deploy operation..."
    Write-VerboseMessage "Deploy operation for UpdateId: $UpdateId, ForceClose: $ForceClose"

    # Simulate deploy with simple progress updates
    for ($progress = 0; $progress -le 100; $progress += 15) {
        Set-ActionProgress -ProviderId $ProviderId -CurrentProgress $progress -TotalProgress 100
        if ($progress -lt 100) { Start-Sleep -Seconds 1 }
    }

    $Reason = [Windows.Management.Update.WindowsSoftwareUpdateRestartReason]::None
    $Result = [Windows.Management.Update.WindowsSoftwareUpdateActionResult]::Succeeded
    Set-ActionResult -ProviderId $ProviderId -Result $Result -Reason $Reason
    Write-OutputMessage "Sample deploy operation completed successfully"
}

function Invoke-SampleRestart {
    param([string]$ProviderId, [string]$UpdateId)

    Write-OutputMessage "Starting sample restart operation..."
    Write-VerboseMessage "Restart operation for UpdateId: $UpdateId"

    # Simulate restart preparation with simple progress updates
    for ($progress = 0; $progress -le 100; $progress += 25) {
        Set-ActionProgress -ProviderId $ProviderId -CurrentProgress $progress -TotalProgress 100
        if ($progress -lt 100) { Start-Sleep -Seconds 1 }
    }

    $Reason = [Windows.Management.Update.WindowsSoftwareUpdateRestartReason]::None
    $Result = [Windows.Management.Update.WindowsSoftwareUpdateActionResult]::Succeeded
    Set-ActionResult -ProviderId $ProviderId -Result $Result -Reason $Reason
    Write-OutputMessage "Sample restart operation completed successfully"
    Write-OutputMessage "Note: This is a sample - no actual system restart will occur"
}

#endregion

#endregion

#region Usage Information

function Show-ActionUsage {
    Write-Host "Usage: [] denotes optional argument, <> denotes required argument"
    Write-Host "    download [-ProviderId <ProviderID>] [-UpdateId <UpdateID>] [-LogFile <LogFile>] [-Verbose] - perform download action"
    Write-Host "    install [-ProviderId <ProviderID>] [-UpdateId <UpdateID>] [-LogFile <LogFile>] [-ForceClose] [-Verbose] - perform install action"
    Write-Host "    deploy [-ProviderId <ProviderID>] [-UpdateId <UpdateID>] [-LogFile <LogFile>] [-ForceClose] [-Verbose] - perform deploy action"
    Write-Host "    restart [-ProviderId <ProviderID>] [-UpdateId <UpdateID>] [-LogFile <LogFile>] [-Verbose] - restart application after update"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "    -ProviderId <ProviderID> - Specify the provider ID (defaults to 'SampleProvider')"
    Write-Host "    -UpdateId <UpdateID> - Specify the update ID for the action"
    Write-Host "    -LogFile <LogFile> - Redirect console output to specified log file in State subfolder"
    Write-Host "    -ForceClose - Force close applications during install/deploy actions"
    Write-Host "    -Verbose - Display detailed action information"
    Write-Host ""
    Write-Host "Note: This script is typically called by the Windows Update system or by SampleProvider-scan.ps1"
}

#endregion

# Main execution logic
try {
    # Import the UOP-runtime module first
    $scriptDir = Split-Path -Parent $PSCommandPath
    $modulePath = Join-Path $scriptDir "UOP-runtime.psm1"

    if (-not (Test-Path $modulePath)) {
        Write-OutputMessage "UOP-runtime module not found at: $modulePath"
        Write-OutputMessage "Please ensure the module is available in the same directory as this script."
        exit 1
    }

    Import-Module $modulePath -Force

    # Process command line arguments and set up logging
    if (-not [string]::IsNullOrEmpty($LogFile)) {
        if (-not (Enable-ProviderLogging -LogFileName $LogFile -MaxLogSizeMB 5)) {
            Write-OutputMessage "Failed to set up logging, continuing with console output"
        } else {
            Write-OutputMessage "Logging enabled with 5MB rotation to: $LogFile"
        }
    }

    # Enable verbose output if requested (either via -Verbose or when logging is enabled)
    if ($VerbosePreference -eq 'Continue' -or (-not [string]::IsNullOrEmpty($LogFile))) {
        $VerbosePreference = "Continue"
    }

    Write-OutputMessage "SampleProvider Action Script Starting..."
    Write-OutputMessage "Using provider ID: $ProviderId"

    if ($UpdateId -ne "") {
        Write-OutputMessage "Using update ID: $UpdateId"
    }
    if ($ForceClose) {
        Write-OutputMessage "Force close applications: Enabled"
    }
    if ($VerbosePreference -ne 'SilentlyContinue') {
        Write-OutputMessage "Verbose mode: Enabled"
    }

    # Validate required parameters
    if ($Action -in @("download", "install", "deploy") -and [string]::IsNullOrEmpty($UpdateId)) {
        Write-Warning "UpdateId is typically required for $Action actions"
    }

    # Perform the action operation
    Invoke-ProviderAction -ProviderId $ProviderId -ActionName $Action.ToLower() -UpdateId $UpdateId -ForceClose $ForceClose
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
