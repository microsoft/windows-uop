#
# Copyright (c) Microsoft Corporation.  All rights reserved.
#
# Version: 1.0.0.0
# Revision: 2025.10.08
#

# Provider Management Script
# This script updates file hashes and generates a catalog for a provider folder

<#
.SYNOPSIS
    Updates provider file hashes, generates catalog files, and optionally signs catalogs.

.DESCRIPTION
    This script performs a complete provider management workflow:
    1. Updates file names in provider.json to match actual files
    2. Updates file hashes in provider.json
    3. Generates a catalog (.cat) file from the provider files
    4. Optionally signs the catalog with a code signing certificate

.EXAMPLES
    # Basic usage - update hashes and generate catalog
    .\Update-Provider.ps1 -ProviderPath "C:\MyProvider"

    # Update hashes, generate catalog, and sign it (requires certificate outside provider folder)
    .\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -SignCatalog -PfxFile "C:\Certificates\MyCert.pfx"

    # Only update file hashes (skip catalog generation)
    .\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -SkipCatalogGeneration

    # Only generate and sign catalog (skip hash updates)
    .\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -SkipHashUpdate -SignCatalog -PfxFile "C:\Certificates\MyCert.pfx"

    # Use custom certificate with custom timestamp server
    .\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -SignCatalog -PfxFile "C:\Certificates\MyCert.pfx" -TimestampServer "http://timestamp.sectigo.com"

    # Force overwrite existing catalog file
    .\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -Force

    # Use different base directory for payload files
    .\Update-Provider.ps1 -ProviderPath "C:\MyProvider\config" -BaseDirectory "C:\MyProvider\files"

    # Custom catalog filename with backup
    .\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -CatalogFileName "CustomProvider.cat" -CreateBackup

    # Sign existing catalog without regenerating (useful after manual catalog edits)
    .\Update-Provider.ps1 -ProviderPath "C:\MyProvider" -SignCatalog -SkipHashUpdate -SkipCatalogGeneration -PfxFile "C:\Certificates\MyCert.pfx"
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to the provider folder containing provider.json")]
    [string]$ProviderPath,

    [Parameter(Mandatory = $false, HelpMessage = "Base directory where payload files are located (if different from provider folder)")]
    [string]$BaseDirectory,

    [Parameter(Mandatory = $false, HelpMessage = "Custom catalog file name (overrides JSON CatalogFile property)")]
    [string]$CatalogFileName,

    [Parameter(Mandatory = $false, HelpMessage = "Preserve backup of provider.json (temporary backup always created for safety but deleted on success unless this flag is used)")]
    [switch]$CreateBackup,

    [Parameter(Mandatory = $false, HelpMessage = "Force overwrite of existing catalog file")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Skip file name update")]
    [switch]$SkipFileNameUpdate,

    [Parameter(Mandatory = $false, HelpMessage = "Skip hash update and only generate catalog")]
    [switch]$SkipHashUpdate,

    [Parameter(Mandatory = $false, HelpMessage = "Skip catalog generation and only update hashes")]
    [switch]$SkipCatalogGeneration,

    [Parameter(Mandatory = $false, HelpMessage = "Sign the catalog after generation")]
    [switch]$SignCatalog,

    [Parameter(Mandatory = $false, HelpMessage = "Path to the .pfx certificate file for signing (required when using -SignCatalog, should be outside provider folder)")]
    [string]$PfxFile,

    [Parameter(Mandatory = $false, HelpMessage = "Timestamp server URL for signing")]
    [string]$TimestampServer = "http://timestamp.digicert.com"
)

#region Provider JSON Management Functions

function Update-ProviderFileHashes {
    <#
    .SYNOPSIS
    Updates file hashes in a provider JSON configuration file.

    .DESCRIPTION
    Reads a provider JSON file, calculates SHA256 hashes for all files listed in the PayloadFiles array,
    and updates the FileHash properties with Base64-encoded hash values. The function will look for
    files relative to the JSON file's directory by default, or in a specified base directory.

    .PARAMETER JsonFilePath
    The path to the provider JSON file to update.

    .PARAMETER BaseDirectory
    Optional. The base directory where payload files are located. If not specified, uses the directory
    containing the JSON file.

    .PARAMETER Force
    Optional. If specified, will overwrite the JSON file even if backup creation fails.

    .PARAMETER CreateBackup
    Optional. If specified, creates and preserves a backup of the original JSON file. When not specified,
    a temporary backup is still created for restore purposes but is automatically deleted on success.

    .EXAMPLE
    Update-ProviderFileHashes -JsonFilePath "C:\path\to\provider.json"

    .EXAMPLE
    Update-ProviderFileHashes -JsonFilePath "C:\path\to\provider.json" -BaseDirectory "C:\path\to\files"

    .EXAMPLE
    Update-ProviderFileHashes -JsonFilePath "C:\path\to\provider.json" -Force

    .EXAMPLE
    Update-ProviderFileHashes -JsonFilePath "C:\path\to\provider.json" -CreateBackup
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonFilePath,

        [Parameter(Mandatory = $false)]
        [string]$BaseDirectory,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$CreateBackup
    )

    # Validate input file exists
    if (-not (Test-Path $JsonFilePath)) {
        Write-Error "JSON file not found: $JsonFilePath"
        return $false
    }

    # Set base directory if not provided
    if ([string]::IsNullOrEmpty($BaseDirectory)) {
        $BaseDirectory = Split-Path $JsonFilePath -Parent
    }

    # Validate base directory exists
    if (-not (Test-Path $BaseDirectory)) {
        Write-Error "Base directory not found: $BaseDirectory"
        return $false
    }

    try {
        Write-Host "Reading provider JSON file: $JsonFilePath"
        $jsonContent = Get-Content $JsonFilePath -Raw -Encoding UTF8
        $providerConfig = $jsonContent | ConvertFrom-Json

        # Validate JSON structure
        if (-not $providerConfig.PayloadFiles) {
            Write-Error "No PayloadFiles array found in JSON file"
            return $false
        }

        # Create backup of original file for restore purposes (always create, but only keep if requested)
        $backupPath = "$JsonFilePath.backup"
        $keepBackup = $CreateBackup
        try {
            Copy-Item $JsonFilePath $backupPath -Force
            Write-Verbose "Created temporary backup: $backupPath"
        }
        catch {
            if (-not $Force) {
                Write-Error "Failed to create backup file: $($_.Exception.Message)"
                return $false
            }
            Write-Host "Warning: Could not create backup, but continuing due to -Force flag"
            $backupPath = $null
        }

        $updatedCount = 0
        $errorCount = 0

        # Process each payload file
        foreach ($payloadFile in $providerConfig.PayloadFiles) {
            if (-not $payloadFile.FileName) {
                Write-Error "PayloadFile entry missing FileName property"
                $errorCount++
                continue
            }

            $filePath = Join-Path $BaseDirectory $payloadFile.FileName

            if (-not (Test-Path $filePath)) {
                Write-Error "Payload file not found: $filePath"
                $errorCount++
                continue
            }

            try {
                # Calculate SHA256 hash
                Write-Verbose "Calculating hash for: $($payloadFile.FileName)"
                $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
                $hasher = [System.Security.Cryptography.SHA256]::Create()
                $hashBytes = $hasher.ComputeHash($fileBytes)
                $base64Hash = [System.Convert]::ToBase64String($hashBytes)

                # Update the hash in the object
                $oldHash = $payloadFile.FileHash
                $payloadFile.FileHash = $base64Hash

                if ($oldHash -ne $base64Hash) {
                    Write-Host "Updated hash for $($payloadFile.FileName)"
                    Write-Verbose "  Old: $oldHash"
                    Write-Verbose "  New: $base64Hash"
                    $updatedCount++
                } else {
                    Write-Verbose "Hash unchanged for $($payloadFile.FileName)"
                }

                # Clean up hasher
                $hasher.Dispose()
            }
            catch {
                Write-Error "Failed to calculate hash for $($payloadFile.FileName): $($_.Exception.Message)"
                $errorCount++
            }
        }

        # Save updated JSON back to file
        if ($updatedCount -gt 0 -or $errorCount -eq 0) {
            try {
                # Use pretty-printed JSON for better readability
                $updatedJson = $providerConfig | ConvertTo-Json -Depth 10 -Compress:$false
                # Use UTF-8 without BOM to avoid parsing issues
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($JsonFilePath, $updatedJson, $utf8NoBom)

                Write-Host "Successfully updated provider JSON file"
                Write-Host "  Files processed: $($providerConfig.PayloadFiles.Count)"
                Write-Host "  Hashes updated: $updatedCount"
                if ($errorCount -gt 0) {
                    Write-Host "  Errors encountered: $errorCount"
                }

                # Clean up temporary backup unless user requested to keep it
                if ($backupPath -and (Test-Path $backupPath) -and -not $keepBackup) {
                    try {
                        Remove-Item $backupPath -Force
                        Write-Verbose "Cleaned up temporary backup file"
                    }
                    catch {
                        Write-Verbose "Warning: Could not remove temporary backup file: $($_.Exception.Message)"
                    }
                } elseif ($keepBackup -and $backupPath) {
                    Write-Host "Backup preserved: $backupPath"
                }

                return $true
            }
            catch {
                Write-Error "Failed to save updated JSON file: $($_.Exception.Message)"

                # Try to restore backup if save failed and backup exists
                if ($backupPath -and (Test-Path $backupPath)) {
                    try {
                        Copy-Item $backupPath $JsonFilePath -Force
                        Write-Host "Restored original file from backup"
                    }
                    catch {
                        Write-Error "Failed to restore backup: $($_.Exception.Message)"
                    }
                }
                return $false
            }
        } else {
            Write-Host "No changes made due to errors. Original file unchanged."

            # Clean up temporary backup since no changes were made
            if ($backupPath -and (Test-Path $backupPath) -and -not $keepBackup) {
                try {
                    Remove-Item $backupPath -Force
                    Write-Verbose "Cleaned up temporary backup file"
                }
                catch {
                    Write-Verbose "Warning: Could not remove temporary backup file: $($_.Exception.Message)"
                }
            }

            return $false
        }
    }
    catch {
        Write-Error "Failed to process JSON file: $($_.Exception.Message)"

        # Clean up temporary backup on unexpected error unless user requested to keep it
        if ($backupPath -and (Test-Path $backupPath) -and -not $keepBackup) {
            try {
                Remove-Item $backupPath -Force
                Write-Verbose "Cleaned up temporary backup file after error"
            }
            catch {
                Write-Verbose "Warning: Could not remove temporary backup file: $($_.Exception.Message)"
            }
        }

        return $false
    }
}

function Update-ProviderFileNames {
    <#
    .SYNOPSIS
    Updates the FileName values in a provider JSON file to match the actual files in the provider directory.

    .DESCRIPTION
    This function reads a provider JSON file and updates the FileName values in the PayloadFiles array
    to match the actual case-sensitive filenames found in the provider directory.

    .PARAMETER JsonPath
    The path to the provider JSON file to update.

    .PARAMETER ProviderPath
    The path to the directory containing the provider files.

    .EXAMPLE
    Update-ProviderFileNames -JsonPath "C:\Provider\provider.json" -ProviderPath "C:\Provider"

    .OUTPUTS
    System.Boolean - Returns $true if successful, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonPath,

        [Parameter(Mandatory = $true)]
        [string]$ProviderPath
    )

    try {
        Write-Verbose "Reading provider JSON from: $JsonPath"
        $jsonContent = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json

        if (-not $jsonContent.PayloadFiles) {
            Write-Verbose "No PayloadFiles found in JSON"
            return $true
        }

        Write-Verbose "Getting files from provider directory: $ProviderPath"
        $actualFiles = Get-ChildItem -Path $ProviderPath -File | ForEach-Object { $_.Name }

        $updated = $false
        foreach ($payloadFile in $jsonContent.PayloadFiles) {
            $currentFileName = $payloadFile.FileName

            # Find the actual file with case-insensitive comparison
            $actualFileName = $actualFiles | Where-Object { $_ -ieq $currentFileName }

            if ($actualFileName -and $actualFileName -cne $currentFileName) {
                Write-Verbose "Updating FileName from '$currentFileName' to '$actualFileName'"
                $payloadFile.FileName = $actualFileName
                $updated = $true
            }
            elseif (-not $actualFileName) {
                Write-Error "File '$currentFileName' not found in provider directory"
            }
        }

        # Also update ScanFileName if it exists
        if ($jsonContent.ScanFileName) {
            $currentScanFileName = $jsonContent.ScanFileName
            $actualScanFileName = $actualFiles | Where-Object { $_ -ieq $currentScanFileName }

            if ($actualScanFileName -and $actualScanFileName -cne $currentScanFileName) {
                Write-Verbose "Updating ScanFileName from '$currentScanFileName' to '$actualScanFileName'"
                $jsonContent.ScanFileName = $actualScanFileName
                $updated = $true
            }
        }

        # Also update CatalogFile if it exists
        if ($jsonContent.CatalogFile) {
            $currentCatalogFile = $jsonContent.CatalogFile
            $actualCatalogFile = $actualFiles | Where-Object { $_ -ieq $currentCatalogFile }

            if ($actualCatalogFile -and $actualCatalogFile -cne $currentCatalogFile) {
                Write-Verbose "Updating CatalogFile from '$currentCatalogFile' to '$actualCatalogFile'"
                $jsonContent.CatalogFile = $actualCatalogFile
                $updated = $true
            }
        }

        if ($updated) {
            Write-Verbose "Writing updated JSON back to: $JsonPath"
            $jsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonPath
            Write-Host "Provider file names updated successfully"
        }
        else {
            Write-Verbose "No file name updates needed"
        }

        return $true
    }
    catch {
        Write-Error "Failed to update provider file names: $_"
        return $false
    }
}

function New-ProviderCatalog {
    <#
    .SYNOPSIS
    Generates a catalog file for a provider that includes only the provider.json file.

    .DESCRIPTION
    Creates a catalog (.cat) file that includes only the provider.json configuration file.
    PayloadFiles are verified separately during provider validation using their individual hashes.
    This catalog can then be used for code signing and integrity verification.

    .PARAMETER JsonFilePath
    The path to the provider JSON file.

    .PARAMETER BaseDirectory
    Optional. The base directory where payload files are located. If not specified, uses the directory
    containing the JSON file.

    .PARAMETER CatalogFileName
    Optional. The name of the catalog file to create. If not specified, uses the CatalogFile property
    from the JSON. If neither is provided, the function will error out.

    .PARAMETER Force
    Optional. If specified, will overwrite an existing catalog file.

    .EXAMPLE
    New-ProviderCatalog -JsonFilePath "C:\path\to\provider.json"

    .EXAMPLE
    New-ProviderCatalog -JsonFilePath "C:\path\to\provider.json" -BaseDirectory "C:\path\to\files" -CatalogFileName "mycatalog.cat"

    .EXAMPLE
    New-ProviderCatalog -JsonFilePath "C:\path\to\provider.json" -Force
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonFilePath,

        [Parameter(Mandatory = $false)]
        [string]$BaseDirectory,

        [Parameter(Mandatory = $false)]
        [string]$CatalogFileName,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    # Validate input file exists
    if (-not (Test-Path $JsonFilePath)) {
        Write-Error "JSON file not found: $JsonFilePath"
        return $false
    }

    # Set base directory if not provided
    if ([string]::IsNullOrEmpty($BaseDirectory)) {
        $BaseDirectory = Split-Path $JsonFilePath -Parent
    }

    # Validate base directory exists
    if (-not (Test-Path $BaseDirectory)) {
        Write-Error "Base directory not found: $BaseDirectory"
        return $false
    }

    try {
        Write-Host "Reading provider JSON file: $JsonFilePath"
        $jsonContent = Get-Content $JsonFilePath -Raw -Encoding UTF8
        $providerConfig = $jsonContent | ConvertFrom-Json

        # Determine catalog file name
        if ([string]::IsNullOrEmpty($CatalogFileName)) {
            if ($providerConfig.CatalogFile) {
                $CatalogFileName = $providerConfig.CatalogFile
            } else {
                Write-Error "No catalog file name specified. Either provide -CatalogFileName parameter or set CatalogFile property in the JSON."
                return $false
            }
        }

        $catalogPath = Join-Path $BaseDirectory $CatalogFileName

        # Check if catalog already exists
        if ((Test-Path $catalogPath) -and -not $Force) {
            Write-Error "Catalog file already exists: $catalogPath. Use -Force to overwrite."
            return $false
        }

        # Create a temporary catalog definition file (.cdf)
        $cdfFileName = [System.IO.Path]::GetFileNameWithoutExtension($CatalogFileName) + ".cdf"
        $cdfPath = Join-Path $BaseDirectory $cdfFileName

        Write-Host "Creating catalog definition file: $cdfPath"

        # Build CDF content
        $cdfContent = @()
        $cdfContent += "[CatalogHeader]"
        $cdfContent += "Name=$CatalogFileName"
        $cdfContent += "ResultDir=$BaseDirectory"
        $cdfContent += "CatalogVersion=2"
        $cdfContent += "HashAlgorithms=SHA256"
        $cdfContent += "EncodingType=0x00010001"
        $cdfContent += "CATATTR1=0x10010001:OSAttr:2:10"
        $cdfContent += ""
        $cdfContent += "[CatalogFiles]"

        # Add provider.json file (only file included in catalog)
        $providerJsonName = Split-Path $JsonFilePath -Leaf
        $cdfContent += "<HASH>$providerJsonName=$JsonFilePath"

        $fileCount = 1

        # Note: Only provider.json is included in the catalog.
        # PayloadFiles are verified separately during provider validation.

        # Write CDF file
        $cdfContent | Out-File -FilePath $cdfPath -Encoding ASCII

        Write-Host "Catalog definition file created with $fileCount files"

        # Generate the catalog using makecat.exe
        Write-Host "Generating catalog file: $catalogPath"

        # Try to find makecat.exe in common SDK locations
        $makecatPaths = @(
            "${env:ProgramFiles(x86)}\Windows Kits\10\bin\x64\makecat.exe",
            "${env:ProgramFiles}\Windows Kits\10\bin\x64\makecat.exe",
            "makecat.exe"  # Try PATH
        )

        $makecatExe = $null
        foreach ($path in $makecatPaths) {
            if (Test-Path $path) {
                $makecatExe = $path
                break
            }
        }

        if (-not $makecatExe) {
            # Try to find it in Windows SDK bin directories
            $sdkDirs = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
            foreach ($sdkDir in $sdkDirs) {
                $testPath = Join-Path $sdkDir.FullName "x64\makecat.exe"
                if (Test-Path $testPath) {
                    $makecatExe = $testPath
                    break
                }
            }
        }

        if (-not $makecatExe) {
            Write-Error "makecat.exe not found. Please install Windows SDK or ensure it's in your PATH."
            Write-Host "You can manually create the catalog using: makecat.exe `"$cdfPath`""
            return $false
        }

        Write-Verbose "Using makecat.exe: $makecatExe"

        # Run makecat.exe (hash algorithm is controlled by CDF file, not command line)
        $process = Start-Process -FilePath $makecatExe -ArgumentList "`"$cdfPath`"" -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-Host "Catalog file created successfully: $catalogPath"

            # Clean up temporary CDF file
            if (Test-Path $cdfPath) {
                Remove-Item $cdfPath -Force
                Write-Verbose "Cleaned up temporary CDF file: $cdfPath"
            }

            # Verify catalog file exists
            if (Test-Path $catalogPath) {
                $catalogInfo = Get-Item $catalogPath
                Write-Host "Catalog file size: $($catalogInfo.Length) bytes"
                Write-Host "Files included in catalog: $fileCount"
                return $true
            } else {
                Write-Error "Catalog file was not created at expected location: $catalogPath"
                return $false
            }
        } else {
            Write-Error "makecat.exe failed with exit code: $($process.ExitCode)"
            Write-Host "You can manually create the catalog using: makecat.exe `"$cdfPath`""
            return $false
        }

    }
    catch {
        Write-Error "Failed to create catalog: $($_.Exception.Message)"

        # Clean up temporary files on error
        if (Test-Path $cdfPath) {
            Remove-Item $cdfPath -Force -ErrorAction SilentlyContinue
        }

        return $false
    }
}

#endregion

# Validate provider path
if (-not (Test-Path $ProviderPath)) {
    Write-Error "Provider path not found: $ProviderPath"
    exit 1
}

# Find provider.json file
$jsonFile = Join-Path $ProviderPath "provider.json"
if (-not (Test-Path $jsonFile)) {
    Write-Error "provider.json not found in: $ProviderPath"
    exit 1
}

# Set base directory if not provided
if ([string]::IsNullOrEmpty($BaseDirectory)) {
    $BaseDirectory = $ProviderPath
}

Write-Host "Provider Management Workflow" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green
Write-Host "Provider Path: $ProviderPath" -ForegroundColor Yellow
Write-Host "JSON File: $jsonFile" -ForegroundColor Yellow
Write-Host "Base Directory: $BaseDirectory" -ForegroundColor Yellow
Write-Host ""

$overallSuccess = $true

# Step 1: Update file names (unless skipped)
if (-not $SkipFileNameUpdate) {
    Write-Host "Step 1: Updating file names..." -ForegroundColor Cyan
    Write-Host "  Updating file names to match actual files in directory..." -ForegroundColor Gray
    $nameResult = Update-ProviderFileNames -JsonPath $jsonFile -ProviderPath $BaseDirectory

    if ($nameResult) {
        Write-Host "  [SUCCESS] File names updated successfully" -ForegroundColor Green
    } else {
        Write-Host "  [FAILED] Failed to update file names" -ForegroundColor Red
        $overallSuccess = $false
    }
    Write-Host ""
} else {
    Write-Host "Step 1: Skipping file name update (as requested)" -ForegroundColor Yellow
    Write-Host ""
}

# Step 2: Update file hashes (unless skipped)
if (-not $SkipHashUpdate) {
    Write-Host "Step 2: Updating file hashes..." -ForegroundColor Cyan
    $hashParams = @{
        JsonFilePath = $jsonFile
        BaseDirectory = $BaseDirectory
    }

    if ($CreateBackup) {
        $hashParams.CreateBackup = $true
    }

    $hashResult = Update-ProviderFileHashes @hashParams

    if ($hashResult) {
        Write-Host "  [SUCCESS] File hashes updated successfully" -ForegroundColor Green
    } else {
        Write-Host "  [FAILED] Failed to update file hashes" -ForegroundColor Red
        $overallSuccess = $false
    }
    Write-Host ""
} else {
    Write-Host "Step 2: Skipping hash update (as requested)" -ForegroundColor Yellow
    Write-Host ""
}

# Step 3: Generate catalog (unless skipped)
if (-not $SkipCatalogGeneration) {
    Write-Host "Step 3: Generating catalog file..." -ForegroundColor Cyan

    $catalogParams = @{
        JsonFilePath = $jsonFile
        BaseDirectory = $BaseDirectory
    }

    if (-not [string]::IsNullOrEmpty($CatalogFileName)) {
        $catalogParams.CatalogFileName = $CatalogFileName
    }

    if ($Force) {
        $catalogParams.Force = $true
    }

    $catalogResult = New-ProviderCatalog @catalogParams

    if ($catalogResult) {
        Write-Host "[SUCCESS] Catalog file generated successfully" -ForegroundColor Green

        # Show catalog file information
        $catalogFile = if (-not [string]::IsNullOrEmpty($CatalogFileName)) {
            Join-Path $BaseDirectory $CatalogFileName
        } else {
            # Try to get catalog name from JSON
            $jsonContent = Get-Content $jsonFile -Raw | ConvertFrom-Json
            if ($jsonContent.CatalogFile) {
                Join-Path $BaseDirectory $jsonContent.CatalogFile
            } else {
                $null
            }
        }

        if ($catalogFile -and (Test-Path $catalogFile)) {
            $catalogInfo = Get-Item $catalogFile
            Write-Host "  Catalog file: $($catalogInfo.Name)" -ForegroundColor White
            Write-Host "  Size: $($catalogInfo.Length) bytes" -ForegroundColor White
        }
    } else {
        Write-Host "[FAILED] Failed to generate catalog file" -ForegroundColor Red
        $overallSuccess = $false
    }
    Write-Host ""
} else {
    Write-Host "Step 3: Skipping catalog generation (as requested)" -ForegroundColor Yellow
    Write-Host ""
}

# Step 4: Sign catalog (if requested)
if ($SignCatalog -and -not $SkipCatalogGeneration) {
    Write-Host "Step 4: Signing catalog file..." -ForegroundColor Cyan

    try {
        # Get catalog file path
        $catalogFile = if (-not [string]::IsNullOrEmpty($CatalogFileName)) {
            Join-Path $BaseDirectory $CatalogFileName
        } else {
            # Try to get catalog name from JSON
            $jsonContent = Get-Content $jsonFile -Raw | ConvertFrom-Json
            if ($jsonContent.CatalogFile) {
                Join-Path $BaseDirectory $jsonContent.CatalogFile
            } else {
                # Look for .cat files
                $catFiles = Get-ChildItem -Path $BaseDirectory -Filter "*.cat"
                if ($catFiles.Count -eq 1) {
                    $catFiles[0].FullName
                } else {
                    throw "Cannot determine catalog file to sign"
                }
            }
        }

        if (-not (Test-Path $catalogFile)) {
            throw "Catalog file not found: $catalogFile"
        }

        # Validate PFX file is specified (no auto-detection to avoid unexpected files in provider folder)
        if ([string]::IsNullOrWhiteSpace($PfxFile)) {
            throw "PfxFile parameter is required when using -SignCatalog. Certificate files should not be stored in the provider folder to avoid validation issues."
        } else {
            # Resolve relative path
            if (-not [System.IO.Path]::IsPathRooted($PfxFile)) {
                $PfxFile = Join-Path $BaseDirectory $PfxFile
            }
            $PfxFile = Resolve-Path $PfxFile -ErrorAction Stop
        }

        # Prompt user for certificate password
        Write-Host "  Certificate password required for signing..." -ForegroundColor Yellow
        $securePassword = Read-Host -AsSecureString -Prompt "  Enter PFX password"
        $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
        Write-Host "  Certificate password: $('*' * $password.Length)" -ForegroundColor Gray

        # Find signtool.exe
        $signtoolPath = ""
        try {
            $signtoolPath = (Get-Command "signtool.exe" -ErrorAction Stop).Source
        } catch {
            # Try common Windows SDK locations
            $possiblePaths = @(
                "${env:ProgramFiles(x86)}\Windows Kits\10\bin\x64\signtool.exe",
                "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe",
                "${env:ProgramFiles}\Windows Kits\10\bin\x64\signtool.exe",
                "${env:ProgramFiles(x86)}\Microsoft SDKs\Windows\v7.1A\Bin\signtool.exe"
            )

            foreach ($path in $possiblePaths) {
                if (Test-Path $path) {
                    $signtoolPath = $path
                    break
                }
            }

            if ([string]::IsNullOrWhiteSpace($signtoolPath)) {
                throw "signtool.exe not found. Please install Windows SDK."
            }
        }

        # Build signtool command
        $signArgs = @(
            "sign"
            "/fd"
            "SHA256"
            "/f"
            "`"$PfxFile`""
            "/p"
            "`"$password`""
            "/t"
            "`"$TimestampServer`""
            "`"$catalogFile`""
        )

        # Note: signtool doesn't have a force overwrite flag - it overwrites by default

        # Execute signtool
        Write-Host "  Signing with timestamp server: $TimestampServer" -ForegroundColor Gray
        $process = Start-Process -FilePath $signtoolPath -ArgumentList $signArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput "signtool_output.tmp" -RedirectStandardError "signtool_error.tmp"

        # Read and display output
        if (Test-Path "signtool_output.tmp") {
            $output = Get-Content "signtool_output.tmp" -Raw
            if (-not [string]::IsNullOrWhiteSpace($output)) {
                Write-Host "  $output" -ForegroundColor White
            }
            Remove-Item "signtool_output.tmp" -Force -ErrorAction SilentlyContinue
        }

        if (Test-Path "signtool_error.tmp") {
            $errorOutput = Get-Content "signtool_error.tmp" -Raw
            if (-not [string]::IsNullOrWhiteSpace($errorOutput)) {
                Write-Host "  $errorOutput" -ForegroundColor Red
            }
            Remove-Item "signtool_error.tmp" -Force -ErrorAction SilentlyContinue
        }

        if ($process.ExitCode -eq 0) {
            Write-Host "  [SUCCESS] Catalog signed successfully!" -ForegroundColor Green
        } else {
            throw "Signing failed with exit code: $($process.ExitCode)"
        }

    } catch {
        Write-Host "  [FAILED] Catalog signing failed: $($_.Exception.Message)" -ForegroundColor Red
        $overallSuccess = $false
    }
    Write-Host ""
} elseif ($SignCatalog -and $SkipCatalogGeneration) {
    Write-Host "Step 4: Cannot sign catalog when catalog generation is skipped" -ForegroundColor Red
    $overallSuccess = $false
    Write-Host ""
}

# Summary
Write-Host "Workflow Summary" -ForegroundColor Green
Write-Host "================" -ForegroundColor Green

if ($overallSuccess) {
    Write-Host "[SUCCESS] All operations completed successfully!" -ForegroundColor Green

    if ($SignCatalog -and -not $SkipCatalogGeneration) {
        Write-Host ""
        Write-Host "Provider is ready for deployment with signed catalog!" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Sign the catalog file using your code signing certificate" -ForegroundColor White
        Write-Host "     Example: .\Update-Provider.ps1 -ProviderPath '$ProviderPath' -SignCatalog -SkipHashUpdate -SkipCatalogGeneration" -ForegroundColor Gray
        Write-Host "  2. Deploy the provider with the signed catalog" -ForegroundColor White
    }
} else {
    Write-Host "[FAILED] Some operations failed. Please check the output above for details." -ForegroundColor Red
    exit 1
}
