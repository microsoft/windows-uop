#
# Copyright (c) Microsoft Corporation.  All rights reserved.
#
# Version: 1.0.0.0
# Revision: 2025.10.08
#

# Load Windows Runtime assemblies and import namespace
Add-Type -AssemblyName System.Runtime.WindowsRuntime

# Load Windows Runtime types - Core provider and manager types
[void][Windows.Management.Update.WindowsSoftwareUpdateProvider,Windows.Management.Update,ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsUpdateManager,Windows.Management.Update, ContentType=WindowsRuntime]
[void][Windows.Management.Update.WindowsUpdateManagerScanOptions,Windows.Management.Update, ContentType=WindowsRuntime]

# Result types returned by WinRT API calls
[void][Windows.Management.Update.WindowsSoftwareUpdateResult, Windows.Management.Update, ContentType=WindowsRuntime]

#region Provider Registration Functions

function Register-WindowsSoftwareUpdateProvider {
    <#
    .SYNOPSIS
    Registers a Windows Update provider.

    .DESCRIPTION
    Creates and registers a Windows Update provider with the specified path.

    .PARAMETER ProviderPath
    The path to the provider to register.

    .EXAMPLE
    Register-WindowsSoftwareUpdateProvider -ProviderPath "C:\MyProvider"

    .OUTPUTS
    Windows.Management.Update.WindowsSoftwareUpdateProvider
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProviderPath
    )

    try {
        Write-Host "Registering Provider..." -ForegroundColor Green
        $provider = New-Object Windows.Management.Update.WindowsSoftwareUpdateProvider($ProviderPath)

        Write-Host "Result of provider Registration..." -ForegroundColor Green
        $result = $provider.Register()

        if ($result.Succeeded -eq $false) {
            Write-Error "Provider registration failed: $($result.ResultCode)"
            return $result
        }
        else {
            Write-Host "Provider registration succeeded!" -ForegroundColor Green
            return $provider
        }
    }
    catch {
        Write-Error "Failed to register provider: $_"
        throw
    }
}

function Test-WindowsSoftwareUpdateProvider {
    <#
    .SYNOPSIS
    Validate a Windows Update provider.

    .DESCRIPTION
    Creates and validates a Windows Update provider.json with the specified path.

    .PARAMETER ProviderPath
    The path to the provider to validate.

    .EXAMPLE
    Test-WindowsSoftwareUpdateProvider -ProviderPath "C:\MyProvider"

    .OUTPUTS
    Windows.Management.Update.WindowsSoftwareUpdateResult
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProviderPath
    )

    try {
        Write-Host "Creating Provider for validation..." -ForegroundColor Green
        $provider = New-Object Windows.Management.Update.WindowsSoftwareUpdateProvider($ProviderPath)

        Write-Host "Validating Provider registration metadata..." -ForegroundColor Green
        $result = $provider.Validate()

        Write-Host "Provider validation completed!" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Error "Failed to validate provider registration: $_"
        throw
    }
}

function Get-WindowsSoftwareUpdateProvider {
    <#
    .SYNOPSIS
    Gets information about registered Windows Update providers.

    .DESCRIPTION
    Retrieves the list of registered Windows Update providers.

    .PARAMETER ClientName
    The client name required for the Windows Update Manager instance.

    .PARAMETER ProviderId
    The ID of the provider to retrieve.

    .EXAMPLE
    Get-WindowsSoftwareUpdateProvider -ClientName "UOP-deployment" -ProviderId "MyProvider"

    .OUTPUTS
    Windows.Management.Update.WindowsSoftwareUpdateProvider
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ClientName = "UOP-deployment",
        [Parameter(Mandatory = $true)]
        [string]$ProviderId
    )

    try {
        Write-Host "Getting Windows Update Manager..." -ForegroundColor Green
        $manager = New-Object Windows.Management.Update.WindowsUpdateManager($ClientName)

        Write-Host "Getting $ProviderId object..." -ForegroundColor Green
        $provider = $manager.GetProvider($ProviderId)

        return $provider
    }
    catch {
        Write-Error "Failed to get provider: $_"
        throw
    }
}

function Get-WindowsSoftwareUpdateProviderIds {
    <#
    .SYNOPSIS
    Gets information about registered Windows Update providers.

    .DESCRIPTION
    Retrieves the list of registered provider IDs from the Windows Update Manager.

    .PARAMETER ClientName
    The client name required for the Windows Update Manager instance.

    .EXAMPLE
    Get-WindowsSoftwareUpdateProviderIds -ClientName "UOP-deployment"

    .OUTPUTS
    System.Collections.Generic.IReadOnlyList[System.String]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ClientName = "UOP-deployment"
    )

    try {
        Write-Host "Getting Windows Update Manager..." -ForegroundColor Green
        $manager = New-Object Windows.Management.Update.WindowsUpdateManager($ClientName)

        Write-Host "Getting list of Provider IDs..." -ForegroundColor Green
        $providerIds = $manager.ProviderIds

        Write-Host "Registered Provider IDs:" -ForegroundColor Green
        return $providerIds
    }
    catch {
        Write-Error "Failed to get provider information: $_"
        throw
    }
}

function Start-WindowsUpdateScan {
    <#
    .SYNOPSIS
    Starts a Windows Update scan.

    .DESCRIPTION
    Initiates a scan for available Windows Updates.

    .PARAMETER ClientName
    The client name required for the Windows Update Manager instance.

    .PARAMETER IsUserInitiated
    Indicates if the scan is initiated by the user. Default is false.

    .PARAMETER PerformUpdateActions
    Indicates if update actions (Download, Install, Deploy) should be performed after scan completion. Default is true.

    .PARAMETER AllowBypassThrottling
    Indicates if the scan can bypass throttling policies. Default is false.

    .PARAMETER ProviderFilter
    An optional list of provider IDs to filter the scan to specific providers. Default is $null (all providers).

    .EXAMPLE
    Start-WindowsUpdateScan -ClientName "UOP-deployment" -IsUserInitiated $true -PerformUpdateActions $true -AllowBypassThrottling $false

    .OUTPUTS
    Windows.Management.Update.WindowsUpdateScanResult
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ClientName = "UOP-deployment",

        [Parameter(Mandatory = $false)]
        [Boolean]$IsUserInitiated = $false,

        [Parameter(Mandatory = $false)]
        [Boolean]$PerformUpdateActions = $true,

        [Parameter(Mandatory = $false)]
        [Boolean]$AllowBypassThrottling = $false
    )

    try {
        Write-Host "Creating Windows Update Scan Options..." -ForegroundColor Green
        $scanOptions = New-Object Windows.Management.Update.WindowsUpdateManagerScanOptions
        $scanOptions.IsUserInitiated = $IsUserInitiated
        $scanOptions.PerformUpdateActions = $PerformUpdateActions
        $scanOptions.AllowBypassThrottling = $AllowBypassThrottling

        Write-Host "Getting Windows Update Manager..." -ForegroundColor Green
        $manager = New-Object Windows.Management.Update.WindowsUpdateManager($ClientName)

        Write-Host "Starting Windows Update scan..." -ForegroundColor Green
        $result = $manager.PerformScan($scanOptions)

        if ($result.Succeeded -eq $false) {
            Write-Error "Windows Update scan failed: $($result.ResultCode)"
            return $result
        }
        else {
            Write-Host "Windows Update scan completed successfully!" -ForegroundColor Green
            return $result.Updates
        }
    }
    catch {
        Write-Error "Failed to start Windows Update scan: $_"
        throw
    }
}

function Unregister-WindowsSoftwareUpdateProvider {
    <#
    .SYNOPSIS
    Unregisters a Windows Update provider.

    .DESCRIPTION
    Unregisters a Windows Update provider using the specified provider ID.

    .PARAMETER ClientName
    The name of the Windows Update Manager instance.

    .PARAMETER ProviderId
    The ID of the provider to unregister.

    .EXAMPLE
    Unregister-WindowsSoftwareUpdateProvider -ClientName "UOP-deployment" -ProviderId "MyProvider"

    .OUTPUTS
    Windows.Management.Update.WindowsSoftwareUpdateResult
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ClientName = "UOP-deployment",
        [Parameter(Mandatory = $true)]
        [string]$ProviderId
    )

    try {
        Write-Host "Getting Windows Update Manager..." -ForegroundColor Green
        $manager = New-Object Windows.Management.Update.WindowsUpdateManager($ClientName)

        Write-Host "Finding Provider with ID: $ProviderId..." -ForegroundColor Green
        $provider = $manager.GetProvider($ProviderId)

        Write-Host "Unregistering Provider..." -ForegroundColor Green
        $result = $provider.Unregister()

        if ($result.Succeeded -eq $false) {
            Write-Error "Provider unregistration failed: $($result.ResultCode)"
        }
        else
        {
            Write-Host "Provider unregistered successfully!" -ForegroundColor Green
        }
        return $result
    }
    catch {
        Write-Error "Failed to unregister provider: $_"
        throw
    }
}

#endregion

#region Module Exports

# Export provider registration functions
Export-ModuleMember -Function Register-WindowsSoftwareUpdateProvider
Export-ModuleMember -Function Test-WindowsSoftwareUpdateProvider
Export-ModuleMember -Function Get-WindowsSoftwareUpdateProvider
Export-ModuleMember -Function Get-WindowsSoftwareUpdateProviderIds
Export-ModuleMember -Function Start-WindowsUpdateScan
Export-ModuleMember -Function Unregister-WindowsSoftwareUpdateProvider

#endregion
