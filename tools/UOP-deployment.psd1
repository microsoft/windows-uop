#
# Copyright (c) Microsoft Corporation.  All rights reserved.
#
# Version: 1.0.0.0
# Revision: 2025.10.08
#
# Module manifest for module 'UOP-deployment'
#

@{
    RootModule = 'UOP-deployment.psm1'
    ModuleVersion = '1.0.0.0'
    GUID = 'EAF9DC68-A6A3-42B2-B837-535D4C815FF4'
    Author = 'Update Orchestration Platform'
    CompanyName = 'Microsoft Corporation'
    Copyright = '(c) Microsoft Corporation. All rights reserved.'
    Description = 'Windows Update Orchestrator Module for Provider Registration and Management Operations'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        # Provider registration and management functions
        'Register-WindowsSoftwareUpdateProvider',
        'Test-WindowsSoftwareUpdateProvider',
        'Unregister-WindowsSoftwareUpdateProvider',
        'Get-WindowsSoftwareUpdateProvider',
        'Get-WindowsSoftwareUpdateProviderIds',
        'Start-WindowsUpdateScan'
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
            Tags = @('WindowsUpdate', 'Provider', 'Registration', 'Management')
            ProjectUri = ''
            LicenseUri = ''
            ReleaseNotes = 'Streamlined module focused on provider registration, validation, and management operations'
        }
    }
}
