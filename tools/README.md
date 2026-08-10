# Windows Update Orchestrator Tools

This folder contains PowerShell modules and scripts for Windows Update provider development and management.

## Tools Overview

### **UOP-deployment Module**
- **`UOP-deployment.psm1`** - Provider registration and management modules
- **`UOP-deployment.psd1`** - Module manifest defining exported functions and metadata

### **UOP-deployment Module**
**Functions:**
- `Register-WindowsSoftwareUpdateProvider` - Register a provider with Windows Update Orchestrator
- `Test-WindowsSoftwareUpdateProvider` - Validate provider configuration
- `Unregister-WindowsSoftwareUpdateProvider` - Remove a registered provider
- `Get-WindowsSoftwareUpdateProvider` - Get provider information
- `Get-WindowsSoftwareUpdateProviderIds` - List registered provider IDs
- `Start-WindowsUpdateScan` - Initiate Windows Update scan

**Usage:**
```powershell
Import-Module .\UOP-deployment.psd1 -Force

# Register a provider
Register-WindowsSoftwareUpdateProvider -ProviderPath "C:\MyProvider"

# Start a scan, marked as user-initiated
Start-WindowsUpdateScan -Mode UserInitiated

# Start a scan scoped to specific providers only
Start-WindowsUpdateScan -Mode UserInitiated -ProviderFilter @("MyProvider")
```

## Management Scripts
- **`Update-Provider.ps1`** - Updates file hashes, generates catalog files, and optionally signs them for provider deployment
- **`New-SigningCertificate.ps1`** - Creates self-signed code signing certificates for development

### **Update-Provider.ps1**
A comprehensive script that handles the complete provider preparation workflow: file name updates, hash updating, catalog generation, and signing.

```powershell
# Complete workflow: update names/hashes, generate catalog, and sign
.\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -SignCatalog -PfxFile "C:\Certificates\MyProvider.pfx"

# Update file names and hashes, generate catalog only (no signing)
.\Update-Provider.ps1 -ProviderPath "C:\MyProvider"

# Use custom catalog name and force overwrite
.\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -CatalogFileName "mycatalog.cat" -Force

# Skip hash update and only generate/sign catalog
.\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -SkipHashUpdate -SignCatalog -PfxFile "C:\Certificates\MyProvider.pfx"

# Only update hashes (skip catalog and signing)
.\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -SkipCatalogGeneration

# Sign with custom certificate and timestamp server
.\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -SignCatalog -PfxFile "C:\Certificates\custom.pfx" -TimestampServer "http://timestamp.comodoca.com"
```

**Features:**
- **Complete Workflow**: Updates file names, hashes, generates catalog, and signs in one command
- **Auto-Detection**: Automatically finds provider.json and catalog files
- **Flexible Operations**: Skip any step with -SkipFileNameUpdate, -SkipHashUpdate, -SkipCatalogGeneration flags
- **Certificate Management**: Requires explicit certificate file path (must be outside provider folder)
- **Signing Integration**: Built-in signtool.exe integration with timestamp server support
- **Error Handling**: Comprehensive validation and detailed error reporting
- **Backup Safety**: Creates temporary backups during hash updates

### **New-SigningCertificate.ps1**
Creates self-signed code signing certificates for development and testing.

```powershell
# Create certificate with secure password prompt
.\New-SigningCertificate.ps1 -ProviderName "SampleProvider" -Password (Read-Host -AsSecureString -Prompt "Enter PFX password")

# Create certificate in specific directory
.\New-SigningCertificate.ps1 -ProviderName "MyProvider" -OutputPath "C:\Certificates" -Password (Read-Host -AsSecureString -Prompt "Password")

# Overwrite existing certificates
.\New-SigningCertificate.ps1 -ProviderName "TestProvider" -Password (Read-Host -AsSecureString -Prompt "Password") -Force
```

**Features:**
- Generates self-signed code signing certificates valid for 1 year
- Creates two files: `.pfx` (private key), `.cer` (public key)
- **User-Controlled Passwords**: Requires users to provide their own secure passwords
- **No Password Storage**: Passwords are never saved anywhere for maximum security
- Users must remember their passwords and provide them when signing
- Includes comprehensive error handling and colored output

**Output Files:**
- `{ProviderName}.pfx` - Private key file for signing (password protected)
- `{ProviderName}.cer` - Public key file for trust installation

## Complete Development Workflow

### **Step 1: Create Signing Certificate (One-time)**
```powershell
# Create certificate in dedicated certificates folder
.\New-SigningCertificate.ps1 -ProviderName "MyProvider" -OutputPath "C:\Certificates" -Password (Read-Host -AsSecureString -Prompt "Certificate password")

# Enter a password when prompted
```

### **Step 2: Prepare Provider Content**
```powershell
# Update file names, hashes, generate catalog, and sign in one command
.\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -SignCatalog -PfxFile "C:\Certificates\MyProvider.pfx" -Force
```

### **Step 3: Install Certificate for Trust (On Target Machines)**
```powershell
# Install the public key certificate to trust the signature
certutil.exe -f -addStore -f root "C:\Certificates\MyProvider.cer"
```

### **Step 4: Test and Register Provider**
```powershell
# Import deployment module and register provider
Import-Module -Name .\UOP-deployment.psd1 -Force
Register-WindowsSoftwareUpdateProvider -ProviderPath "C:\MyProvider"

# Start a Windows Update scan
Start-WindowsUpdateScan -Mode UserInitiated
```
