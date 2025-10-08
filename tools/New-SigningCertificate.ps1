#
# Copyright (c) Microsoft Corporation.  All rights reserved.
#
# Version: 1.0.0.0
# Revision: 2025.10.08
#

<#
.SYNOPSIS
    Creates a self-signed code signing certificate for UOP Provider development.

.DESCRIPTION
    This script simplifies the process of creating a self-signed code signing certificate
    for development and testing of UOP (Universal Orchestrator Provider) components.

    The script will:
    1. Create a new self-signed code signing certificate
    2. Export it as a PFX file (with private key) for signing
    3. Export it as a CER file (public key only) for trust installation

    Note: The password is not stored anywhere for maximum security. You must remember it.

    By default, certificates are created in the current directory, but you can specify
    a different output directory.

.PARAMETER ProviderName
    The name of the UOP Provider. Used to generate the certificate subject and file names.
    Example: "SampleProvider" creates subject "CN=SampleProvider Signing Cert"

.PARAMETER OutputPath
    The directory where certificate files will be created. Default is current directory.

.PARAMETER Password
    The password for the PFX file. This parameter is required for security.

.PARAMETER Force
    Overwrite existing certificate files without prompting.

.PARAMETER Verbose
    Show detailed output during certificate creation.

.EXAMPLE
    .\New-SigningCertificate.ps1 -ProviderName "SampleProvider" -Password (Read-Host -AsSecureString -Prompt "Enter PFX password")
    Creates a certificate for SampleProvider, prompting the user to enter a secure password.

.EXAMPLE
    .\New-SigningCertificate.ps1 -ProviderName "MyCustomProvider" -OutputPath "C:\Certificates" -Password (Read-Host -AsSecureString -Prompt "Password")
    Creates a certificate for MyCustomProvider in the specified directory with user-provided password.

.EXAMPLE
    $password = Read-Host -AsSecureString -Prompt "Enter secure password for certificate"
    .\New-SigningCertificate.ps1 -ProviderName "TestProvider" -Password $password -Verbose
    Creates a certificate with detailed output, using a password stored in a variable.

.NOTES
    This script creates self-signed certificates suitable for development and testing only.
    For production use, obtain certificates from a trusted Certificate Authority.

    The generated certificate will be valid for 1 year from creation date.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ProviderName,

    [string]$OutputPath = (Get-Location).Path,
    [Parameter(Mandatory=$true)]
    [SecureString]$Password,
    [switch]$Force
)

# Function to check if file exists and handle overwrite
function Test-FileOverwrite {
    param([string]$FilePath, [switch]$Force)

    if (Test-Path $FilePath) {
        if ($Force) {
            Write-Verbose "Overwriting existing file: $FilePath"
            return $true
        } else {
            $response = Read-Host "File '$FilePath' already exists. Overwrite? (y/n)"
            return ($response -eq 'y' -or $response -eq 'Y')
        }
    }
    return $true
}

try {
    Write-Host "=== UOP Provider Code Signing Certificate Creator ===" -ForegroundColor Green
    Write-Host ""

    # Validate and create output directory
    if (-not (Test-Path $OutputPath)) {
        Write-Host "Creating output directory: $OutputPath" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Resolve full path
    $OutputPath = Resolve-Path $OutputPath

    # Generate certificate subject and file names from ProviderName
    $Subject = "CN=$ProviderName Signing Cert"
    $CertName = $ProviderName

    # Define file paths
    $pfxPath = Join-Path $OutputPath "$CertName.pfx"
    $cerPath = Join-Path $OutputPath "$CertName.cer"

    # Check for existing files
    $filesToCreate = @($pfxPath, $cerPath)
    foreach ($file in $filesToCreate) {
        if (-not (Test-FileOverwrite -FilePath $file -Force:$Force)) {
            Write-Host "Operation cancelled by user." -ForegroundColor Red
            return
        }
    }

    # Password is provided by user as SecureString - never stored in plaintext

    Write-Host "Creating self-signed code signing certificate..." -ForegroundColor Cyan
    Write-Host "Subject: $Subject" -ForegroundColor Gray
    Write-Host "Output Directory: $OutputPath" -ForegroundColor Gray
    Write-Host ""

    # Step 1: Create the certificate
    Write-Host "Step 1: Creating certificate in certificate store..." -ForegroundColor Yellow
    $cert = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject $Subject `
        -KeyUsage DigitalSignature `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddYears(1)

    Write-Host "[SUCCESS] Certificate created successfully" -ForegroundColor Green
    Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
    Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Gray
    Write-Host "  Valid Until: $($cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host ""

    # Step 2: Export PFX file (with private key)
    Write-Host "Step 2: Exporting PFX file (with private key)..." -ForegroundColor Yellow
    Export-PfxCertificate `
        -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" `
        -FilePath $pfxPath `
        -Password $Password | Out-Null

    Write-Host "[SUCCESS] PFX file exported: $pfxPath" -ForegroundColor Green
    Write-Host "  Size: $((Get-Item $pfxPath).Length) bytes" -ForegroundColor Gray
    Write-Host ""

    # Step 3: Export CER file (public key only)
    Write-Host "Step 3: Exporting CER file (public key only)..." -ForegroundColor Yellow
    Export-Certificate `
        -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" `
        -FilePath $cerPath | Out-Null

    Write-Host "[SUCCESS] CER file exported: $cerPath" -ForegroundColor Green
    Write-Host "  Size: $((Get-Item $cerPath).Length) bytes" -ForegroundColor Gray
    Write-Host ""



    # Summary
    Write-Host "=== Certificate Creation Complete ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Files created:" -ForegroundColor Cyan
    Write-Host "  PFX (Private Key): $pfxPath" -ForegroundColor White
    Write-Host "  CER (Public Key):  $cerPath" -ForegroundColor White
    Write-Host ""
    Write-Host "Certificate Details:" -ForegroundColor Cyan
    Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor White
    Write-Host "  Subject:    $($cert.Subject)" -ForegroundColor White
    Write-Host "  Valid From: $($cert.NotBefore.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
    Write-Host "  Valid To:   $($cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
    Write-Host ""

    Write-Host "Security Notes:" -ForegroundColor Cyan
    Write-Host "  - Password is not stored anywhere - you must remember it" -ForegroundColor White
    Write-Host "  - You will need to provide the password each time you sign files" -ForegroundColor White
    Write-Host "  - This approach provides maximum security with no password exposure risk" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage Instructions:" -ForegroundColor Cyan
    Write-Host "1. Remember your password - it's not stored anywhere" -ForegroundColor White
    Write-Host "2. Use Update-Provider.ps1 -SignCatalog and provide password when prompted" -ForegroundColor White
    Write-Host "3. Install the CER file to Trusted Root Certification Authorities to trust the signature" -ForegroundColor White
    Write-Host ""

}
catch {
    Write-Error "Failed to create certificate: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Common issues and solutions:" -ForegroundColor Yellow
    Write-Host "- Insufficient permissions: Run PowerShell as Administrator" -ForegroundColor Gray
    Write-Host "- Certificate store access: Ensure you have access to CurrentUser certificate store" -ForegroundColor Gray
    Write-Host "- File access: Check that output directory is writable" -ForegroundColor Gray
    exit 1
}

Write-Host "Certificate creation completed successfully!" -ForegroundColor Green