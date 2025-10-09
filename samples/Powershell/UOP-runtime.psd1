#
# Copyright (c) Microsoft Corporation.  All rights reserved.
#
# Version: 1.0.0.0
# Revision: 2025.10.08
#
# Module manifest for module 'UOP-runtime'
#

@{
    RootModule = 'UOP-runtime.psm1'
    ModuleVersion = '1.0.0.0'
    GUID = '7AFFFD77-74D9-499F-8086-779DA27DB121'
    Author = 'Update Orchestration Platform'
    CompanyName = 'Microsoft Corporation'
    Copyright = '(c) Microsoft Corporation. All rights reserved.'
    Description = 'Windows Update Orchestrator Module for Sample Provider Operations - Scan and Action Support'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        # Utility functions
        'Write-OutputMessage',
        'Write-ErrorMessage',
        'Write-VerboseMessage',
        'New-UpdateId',
        'Get-FileSizeFromUrl',
        'New-VersionObject',
        'New-OptionalActionsInfo',

        # Update object creation functions
        'Show-WindowsSoftwareUpdate',
        'New-DeployUpdate',
        'New-DownloadInstallUpdate',
        'New-AppPackageUpdate',

        # Provider status helper functions
        'Set-ScanResult',
        'Set-ActionProgress',
        'Set-ActionResult',

        # Logging functions
        'Enable-ProviderLogging'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    RequiredAssemblies = @(
        'System.Runtime.WindowsRuntime',
        'System.Runtime.InteropServices.WindowsRuntime'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('WindowsUpdate', 'SampleProvider', 'Scan', 'Action', 'UpdateCreation')
            ProjectUri = ''
            LicenseUri = ''
            ReleaseNotes = 'Streamlined module focused on sample provider scan and action operations with essential WinRT update creation and provider status functions'
        }
    }
}
