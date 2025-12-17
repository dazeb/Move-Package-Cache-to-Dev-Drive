<#
.SYNOPSIS
    Moves package manager caches to a Dev Drive for improved performance.

.DESCRIPTION
    This script detects installed package managers and moves their caches to a Dev Drive.
    It sets the appropriate environment variables and migrates existing cache data.

.PARAMETER WhatIf
    Shows what would happen without making any changes.

.PARAMETER VerifyOnly
    Only verify existing configuration without making changes.

.NOTES
    Requires Administrator privileges to set system-wide environment variables.
    Run PowerShell as Administrator before executing this script.
#>

#Requires -RunAsAdministrator

param(
    [switch]$WhatIf,
    [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Status { param($Message) Write-Host "[*] " -ForegroundColor Cyan -NoNewline; Write-Host $Message }
function Write-Success { param($Message) Write-Host "[+] " -ForegroundColor Green -NoNewline; Write-Host $Message }
function Write-Warning { param($Message) Write-Host "[!] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
function Write-Error { param($Message) Write-Host "[-] " -ForegroundColor Red -NoNewline; Write-Host $Message }
function Write-Info { param($Message) Write-Host "    " -NoNewline; Write-Host $Message -ForegroundColor Gray }

# Banner
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "       Package Cache to Dev Drive Migration Script" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Username for NuGet path (auto-detected)
$currentUser = $env:USERNAME

# List of environment variables to check for previous run
$envVarsToCheck = @(
    "npm_config_cache",
    "NUGET_PACKAGES",
    "VCPKG_DEFAULT_BINARY_CACHE",
    "PIP_CACHE_DIR",
    "CARGO_HOME",
    "MAVEN_OPTS",
    "GRADLE_USER_HOME",
    "PNPM_HOME",
    "YARN_CACHE_FOLDER",
    "GOPATH",
    "GOCACHE",
    "GOMODCACHE",
    "BUN_INSTALL"
)

# Check if script has been run before by looking for any of our environment variables
$existingEnvVars = @()
foreach ($envVar in $envVarsToCheck) {
    $value = [Environment]::GetEnvironmentVariable($envVar, "Machine")
    if ($value) {
        $existingEnvVars += @{ Name = $envVar; Value = $value }
    }
}

# If previous configuration detected and not already in VerifyOnly mode, offer choice
if ($existingEnvVars.Count -gt 0 -and -not $VerifyOnly -and -not $WhatIf) {
    Write-Status "Previous configuration detected!"
    Write-Host ""
    Write-Info "The following package cache environment variables are already set:"
    Write-Host ""
    foreach ($ev in $existingEnvVars) {
        Write-Info "  $($ev.Name) = $($ev.Value)"
    }
    Write-Host ""

    $choice = Read-Host "Would you like to (V)erify existing setup, (R)econfigure, or (Q)uit? [V/R/Q]"

    switch -Regex ($choice) {
        '^[Vv]' {
            $VerifyOnly = $true
            Write-Host ""
            Write-Success "Running verification only..."
            Write-Host ""
        }
        '^[Rr]' {
            Write-Host ""
            Write-Info "Proceeding with reconfiguration..."
            Write-Host ""
        }
        '^[Qq]' {
            Write-Host ""
            Write-Info "Exiting..."
            exit 0
        }
        default {
            # Default to verify
            $VerifyOnly = $true
            Write-Host ""
            Write-Success "Running verification only..."
            Write-Host ""
        }
    }
}

# Get Dev Drive path from user (skip if VerifyOnly and we can detect it from existing vars)
$devDrive = $null

if ($VerifyOnly -and $existingEnvVars.Count -gt 0) {
    # Try to detect Dev Drive from existing environment variables
    foreach ($ev in $existingEnvVars) {
        if ($ev.Value -match '^([A-Za-z]:)') {
            $potentialDrive = $Matches[1]
            if (Test-Path $potentialDrive) {
                $devDrive = $potentialDrive
                Write-Info "Detected Dev Drive from existing config: $devDrive"
                Write-Host ""
                break
            }
        }
    }
}

if (-not $devDrive) {
    while (-not $devDrive) {
        $input = Read-Host "Enter your Dev Drive path (e.g., D: or D:\)"

        # Normalize the path
        $input = $input.TrimEnd('\')
        if ($input -match '^[A-Za-z]:?$') {
            $input = $input.TrimEnd(':') + ":"
        }

        # Validate the drive exists
        if (Test-Path $input) {
            $devDrive = $input
            Write-Success "Using Dev Drive: $devDrive"
        } else {
            Write-Error "Path '$input' does not exist. Please enter a valid drive path."
        }
    }
    Write-Host ""
}

# Package manager configurations
$packageManagers = @(
    @{
        Name = "npm (Node.js)"
        DetectionCommands = @("npm")
        DetectionPaths = @(
            "$env:ProgramFiles\nodejs\npm.cmd",
            "$env:ProgramFiles(x86)\nodejs\npm.cmd",
            "$env:APPDATA\npm\npm.cmd"
        )
        EnvVar = "npm_config_cache"
        NewPath = "$devDrive\packages\npm"
        OldPaths = @(
            "$env:APPDATA\npm-cache",
            "$env:LOCALAPPDATA\npm-cache"
        )
    },
    @{
        Name = "NuGet (.NET)"
        DetectionCommands = @("dotnet", "nuget")
        DetectionPaths = @(
            "$env:ProgramFiles\dotnet\dotnet.exe",
            "$env:ProgramFiles(x86)\dotnet\dotnet.exe"
        )
        EnvVar = "NUGET_PACKAGES"
        NewPath = "$devDrive\$currentUser\.nuget\packages"
        OldPaths = @(
            "$env:USERPROFILE\.nuget\packages"
        )
    },
    @{
        Name = "vcpkg"
        DetectionCommands = @("vcpkg")
        DetectionPaths = @()
        EnvVar = "VCPKG_DEFAULT_BINARY_CACHE"
        NewPath = "$devDrive\packages\vcpkg"
        OldPaths = @(
            "$env:LOCALAPPDATA\vcpkg\archives",
            "$env:APPDATA\vcpkg\archives"
        )
    },
    @{
        Name = "pip (Python)"
        DetectionCommands = @("pip", "pip3", "python", "python3")
        DetectionPaths = @(
            "$env:LOCALAPPDATA\Programs\Python\*\Scripts\pip.exe",
            "$env:ProgramFiles\Python*\Scripts\pip.exe"
        )
        EnvVar = "PIP_CACHE_DIR"
        NewPath = "$devDrive\packages\pip"
        OldPaths = @(
            "$env:LOCALAPPDATA\pip\Cache"
        )
    },
    @{
        Name = "Cargo (Rust)"
        DetectionCommands = @("cargo", "rustc")
        DetectionPaths = @(
            "$env:USERPROFILE\.cargo\bin\cargo.exe"
        )
        EnvVar = "CARGO_HOME"
        NewPath = "$devDrive\packages\cargo"
        OldPaths = @(
            "$env:USERPROFILE\.cargo"
        )
    },
    @{
        Name = "Maven (Java)"
        DetectionCommands = @("mvn")
        DetectionPaths = @()
        EnvVar = "MAVEN_OPTS"
        EnvValue = "-Dmaven.repo.local=$devDrive\packages\maven"
        NewPath = "$devDrive\packages\maven"
        OldPaths = @(
            "$env:USERPROFILE\.m2\repository"
        )
    },
    @{
        Name = "Gradle (Java)"
        DetectionCommands = @("gradle")
        DetectionPaths = @(
            "$env:USERPROFILE\.gradle\wrapper\dists\*\*\gradle-*\bin\gradle.bat"
        )
        EnvVar = "GRADLE_USER_HOME"
        NewPath = "$devDrive\packages\gradle"
        OldPaths = @(
            "$env:USERPROFILE\.gradle"
        )
    },
    @{
        Name = "pnpm"
        DetectionCommands = @("pnpm")
        DetectionPaths = @(
            "$env:LOCALAPPDATA\pnpm\pnpm.exe",
            "$env:APPDATA\npm\pnpm.cmd",
            "$env:ProgramFiles\nodejs\pnpm.cmd"
        )
        EnvVar = "PNPM_HOME"
        NewPath = "$devDrive\packages\pnpm"
        OldPaths = @(
            "$env:LOCALAPPDATA\pnpm",
            "$env:LOCALAPPDATA\pnpm-store",
            "$env:USERPROFILE\.pnpm-store"
        )
    },
    @{
        Name = "Yarn"
        DetectionCommands = @("yarn")
        DetectionPaths = @(
            "$env:APPDATA\npm\yarn.cmd",
            "$env:ProgramFiles\nodejs\yarn.cmd",
            "$env:LOCALAPPDATA\Yarn\bin\yarn.cmd"
        )
        EnvVar = "YARN_CACHE_FOLDER"
        NewPath = "$devDrive\packages\yarn"
        OldPaths = @(
            "$env:LOCALAPPDATA\Yarn\Cache",
            "$env:USERPROFILE\.yarn\cache"
        )
    },
    @{
        Name = "Go"
        DetectionCommands = @("go")
        DetectionPaths = @(
            "$env:ProgramFiles\Go\bin\go.exe",
            "$env:USERPROFILE\go\bin\go.exe",
            "$env:USERPROFILE\sdk\go*\bin\go.exe"
        )
        EnvVar = "GOPATH"
        NewPath = "$devDrive\packages\go"
        OldPaths = @(
            "$env:USERPROFILE\go"
        )
    },
    @{
        Name = "Go Cache"
        DetectionCommands = @("go")
        DetectionPaths = @(
            "$env:ProgramFiles\Go\bin\go.exe"
        )
        EnvVar = "GOCACHE"
        NewPath = "$devDrive\packages\go-cache"
        OldPaths = @(
            "$env:LOCALAPPDATA\go-build"
        )
    },
    @{
        Name = "Go Module Cache"
        DetectionCommands = @("go")
        DetectionPaths = @(
            "$env:ProgramFiles\Go\bin\go.exe"
        )
        EnvVar = "GOMODCACHE"
        NewPath = "$devDrive\packages\go\pkg\mod"
        OldPaths = @(
            "$env:USERPROFILE\go\pkg\mod"
        )
    },
    @{
        Name = "Bun"
        DetectionCommands = @("bun")
        DetectionPaths = @(
            "$env:USERPROFILE\.bun\bin\bun.exe",
            "$env:BUN_INSTALL\bin\bun.exe"
        )
        EnvVar = "BUN_INSTALL"
        NewPath = "$devDrive\packages\bun"
        OldPaths = @(
            "$env:USERPROFILE\.bun"
        )
    }
)

# Function to check if a command exists
function Test-CommandExists {
    param([string]$Command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            return $true
        }
    } catch {
        # Command not found
    }
    $ErrorActionPreference = $oldPreference
    return $false
}

# Function to check if any detection path exists (supports wildcards)
function Test-PathExists {
    param([string[]]$Paths)
    foreach ($path in $Paths) {
        if ($path -and (Get-Item -Path $path -ErrorAction SilentlyContinue)) {
            return $true
        }
    }
    return $false
}

# Function to detect if a package manager is installed
function Test-PackageManagerInstalled {
    param($PackageManager)

    # Check commands first
    foreach ($cmd in $PackageManager.DetectionCommands) {
        if (Test-CommandExists $cmd) {
            return $true
        }
    }

    # Check paths
    if (Test-PathExists $PackageManager.DetectionPaths) {
        return $true
    }

    return $false
}

# Track successfully migrated paths for cleanup prompt
$script:migratedPaths = @()

# Function to move directory contents
function Move-DirectoryContents {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$WhatIf
    )

    if (-not (Test-Path $Source)) {
        return $false
    }

    $sourceSize = (Get-ChildItem -Path $Source -Recurse -ErrorAction SilentlyContinue |
                   Measure-Object -Property Length -Sum).Sum
    $sourceSizeMB = [math]::Round($sourceSize / 1MB, 2)

    if ($sourceSizeMB -eq 0) {
        Write-Info "Source directory is empty, skipping migration"
        return $false
    }

    Write-Info "Found $sourceSizeMB MB of data to migrate from: $Source"

    if ($WhatIf) {
        Write-Info "[WhatIf] Would move contents from $Source to $Destination"
        return $true
    }

    try {
        # Create destination if it doesn't exist
        if (-not (Test-Path $Destination)) {
            New-Item -Path $Destination -ItemType Directory -Force | Out-Null
        }

        # Copy contents
        Write-Info "Copying contents to $Destination..."
        Copy-Item -Path "$Source\*" -Destination $Destination -Recurse -Force -ErrorAction Stop

        # Verify copy
        $destSize = (Get-ChildItem -Path $Destination -Recurse -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum).Sum

        if ($destSize -ge $sourceSize * 0.99) {  # Allow 1% variance
            Write-Success "Migration verified successfully!"
            # Track this path for potential cleanup
            $script:migratedPaths += @{
                Path = $Source
                SizeMB = $sourceSizeMB
            }
            return $true
        } else {
            Write-Warning "Migration may be incomplete. Please verify manually."
            return $true
        }
    } catch {
        Write-Error "Failed to migrate: $_"
        return $false
    }
}

# Function to set environment variable
function Set-EnvironmentVariableSystem {
    param(
        [string]$Name,
        [string]$Value,
        [switch]$WhatIf
    )

    $currentValue = [Environment]::GetEnvironmentVariable($Name, "Machine")

    if ($currentValue -eq $Value) {
        Write-Info "Environment variable $Name is already set correctly"
        return $true
    }

    if ($currentValue) {
        Write-Info "Current value: $currentValue"
        Write-Info "New value: $Value"
    }

    if ($WhatIf) {
        Write-Info "[WhatIf] Would set $Name = $Value"
        return $true
    }

    try {
        [Environment]::SetEnvironmentVariable($Name, $Value, "Machine")
        Write-Success "Set environment variable: $Name = $Value"
        return $true
    } catch {
        Write-Error "Failed to set environment variable: $_"
        return $false
    }
}

# Scan and process each package manager
Write-Host "Scanning for installed package managers..." -ForegroundColor Cyan
Write-Host ""

$detectedManagers = @()
$notDetectedManagers = @()

foreach ($pm in $packageManagers) {
    if (Test-PackageManagerInstalled $pm) {
        $detectedManagers += $pm
        Write-Success "$($pm.Name) - DETECTED"
    } else {
        $notDetectedManagers += $pm
        Write-Info "$($pm.Name) - not found"
    }
}

Write-Host ""

if ($detectedManagers.Count -eq 0) {
    Write-Warning "No supported package managers were detected on this system."
    Write-Host ""
    exit 0
}

# Skip processing if VerifyOnly mode
if (-not $VerifyOnly) {
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "       Processing Detected Package Managers" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""

    $processedCount = 0
    $skippedCount = 0

    foreach ($pm in $detectedManagers) {
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Status "Processing: $($pm.Name)"
        Write-Host ""

        # Create the new cache directory
        if (-not (Test-Path $pm.NewPath)) {
            if ($WhatIf) {
                Write-Info "[WhatIf] Would create directory: $($pm.NewPath)"
            } else {
                try {
                    New-Item -Path $pm.NewPath -ItemType Directory -Force | Out-Null
                    Write-Success "Created directory: $($pm.NewPath)"
                } catch {
                    Write-Error "Failed to create directory: $_"
                    $skippedCount++
                    continue
                }
            }
        } else {
            Write-Info "Directory already exists: $($pm.NewPath)"
        }

        # Set the environment variable
        if ($pm.EnvValue) {
            # Special case for MAVEN_OPTS which has a specific format
            $envSuccess = Set-EnvironmentVariableSystem -Name $pm.EnvVar -Value $pm.EnvValue -WhatIf:$WhatIf
        } else {
            $envSuccess = Set-EnvironmentVariableSystem -Name $pm.EnvVar -Value $pm.NewPath -WhatIf:$WhatIf
        }

        # Migrate existing cache data
        $migrated = $false
        foreach ($oldPath in $pm.OldPaths) {
            if (Test-Path $oldPath) {
                $migrated = Move-DirectoryContents -Source $oldPath -Destination $pm.NewPath -WhatIf:$WhatIf
                if ($migrated) {
                    break  # Only migrate from the first found location
                }
            }
        }

        if (-not $migrated) {
            Write-Info "No existing cache data found to migrate"
        }

        $processedCount++
        Write-Host ""
    }

    # Summary
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                         Summary" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Success "Processed: $processedCount package manager(s)"
    if ($skippedCount -gt 0) {
        Write-Warning "Skipped: $skippedCount package manager(s) due to errors"
    }
    Write-Host ""

    # Display environment variables that were set
    Write-Status "Environment variables configured:"
    Write-Host ""
    foreach ($pm in $detectedManagers) {
        if ($pm.EnvValue) {
            Write-Info "$($pm.EnvVar) = $($pm.EnvValue)"
        } else {
            Write-Info "$($pm.EnvVar) = $($pm.NewPath)"
        }
    }
    Write-Host ""

    # Prompt to delete old cache folders if any were migrated
    if ($script:migratedPaths.Count -gt 0 -and -not $WhatIf) {
        Write-Host "================================================================" -ForegroundColor Magenta
        Write-Host "              Delete Old Cache Folders?" -ForegroundColor Magenta
        Write-Host "================================================================" -ForegroundColor Magenta
        Write-Host ""
        Write-Status "The following old cache folders were successfully migrated:"
        Write-Host ""

        $totalSizeMB = 0
        foreach ($item in $script:migratedPaths) {
            Write-Info "$($item.Path) ($($item.SizeMB) MB)"
            $totalSizeMB += $item.SizeMB
        }
        Write-Host ""
        Write-Info "Total space that can be freed: $([math]::Round($totalSizeMB, 2)) MB"
        Write-Host ""

        $deleteChoice = Read-Host "Do you want to delete these old cache folders now? (Y/N)"

        if ($deleteChoice -match '^[Yy]') {
            Write-Host ""
            $deletedCount = 0
            $failedCount = 0

            foreach ($item in $script:migratedPaths) {
                try {
                    Write-Info "Deleting: $($item.Path)"
                    Remove-Item -Path $item.Path -Recurse -Force -ErrorAction Stop
                    Write-Success "Deleted: $($item.Path)"
                    $deletedCount++
                } catch {
                    Write-Error "Failed to delete $($item.Path): $_"
                    $failedCount++
                }
            }

            Write-Host ""
            if ($deletedCount -gt 0) {
                Write-Success "Successfully deleted $deletedCount old cache folder(s)"
            }
            if ($failedCount -gt 0) {
                Write-Warning "Failed to delete $failedCount folder(s). You may need to delete them manually."
            }
        } else {
            Write-Host ""
            Write-Info "Old cache folders were NOT deleted. You can delete them manually later."
        }
        Write-Host ""
    }
}

# Verification Section
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                    Verification" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Initialize verification tracking
$script:verificationResults = @{
    EnvVarsPassed = @()
    EnvVarsFailed = @()
    EnvVarsNotSet = @()
    DirsExist = @()
    DirsMissing = @()
    TotalCacheSizeMB = 0
    NuGetStatus = $null
    NuGetPath = $null
}

# Run verification if not in WhatIf mode, or if in VerifyOnly mode
if (-not $WhatIf -or $VerifyOnly) {
    Write-Status "Verifying environment variables are set correctly..."
    Write-Host ""

    foreach ($pm in $detectedManagers) {
        $expectedValue = if ($pm.EnvValue) { $pm.EnvValue } else { $pm.NewPath }
        $actualValue = [Environment]::GetEnvironmentVariable($pm.EnvVar, "Machine")

        if ($actualValue -eq $expectedValue) {
            Write-Success "$($pm.EnvVar) = $actualValue"
            $script:verificationResults.EnvVarsPassed += @{ Name = $pm.Name; EnvVar = $pm.EnvVar; Value = $actualValue }
        } elseif ($actualValue) {
            # Check if it's pointing to the same drive at least
            if ($actualValue -like "$devDrive*") {
                Write-Success "$($pm.EnvVar) = $actualValue"
                $script:verificationResults.EnvVarsPassed += @{ Name = $pm.Name; EnvVar = $pm.EnvVar; Value = $actualValue }
            } else {
                Write-Warning "$($pm.EnvVar) is set but not pointing to Dev Drive!"
                Write-Info "  Current:  $actualValue"
                Write-Info "  Expected: $expectedValue"
                $script:verificationResults.EnvVarsFailed += @{ Name = $pm.Name; EnvVar = $pm.EnvVar; Current = $actualValue; Expected = $expectedValue }
            }
        } else {
            Write-Error "$($pm.EnvVar) is NOT set!"
            Write-Info "  Expected: $expectedValue"
            $script:verificationResults.EnvVarsNotSet += @{ Name = $pm.Name; EnvVar = $pm.EnvVar; Expected = $expectedValue }
        }
    }

    Write-Host ""

    $passedCount = $script:verificationResults.EnvVarsPassed.Count
    $failedCount = $script:verificationResults.EnvVarsFailed.Count
    $notSetCount = $script:verificationResults.EnvVarsNotSet.Count

    if ($failedCount -eq 0 -and $notSetCount -eq 0) {
        Write-Success "All $passedCount environment variable(s) verified successfully!"
    } else {
        if ($passedCount -gt 0) {
            Write-Success "$passedCount environment variable(s) configured correctly"
        }
        if ($failedCount -gt 0) {
            Write-Warning "$failedCount environment variable(s) not pointing to Dev Drive"
        }
        if ($notSetCount -gt 0) {
            Write-Error "$notSetCount environment variable(s) not set"
        }
    }

    Write-Host ""

    # Check if cache directories exist on Dev Drive
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Status "Verifying cache directories exist on Dev Drive..."
    Write-Host ""

    foreach ($pm in $detectedManagers) {
        if (Test-Path $pm.NewPath) {
            $dirSize = (Get-ChildItem -Path $pm.NewPath -Recurse -ErrorAction SilentlyContinue |
                       Measure-Object -Property Length -Sum).Sum
            $dirSizeMB = [math]::Round($dirSize / 1MB, 2)
            Write-Success "$($pm.Name): $($pm.NewPath) ($dirSizeMB MB)"
            $script:verificationResults.DirsExist += @{ Name = $pm.Name; Path = $pm.NewPath; SizeMB = $dirSizeMB }
            $script:verificationResults.TotalCacheSizeMB += $dirSizeMB
        } else {
            Write-Warning "$($pm.Name): $($pm.NewPath) does not exist"
            $script:verificationResults.DirsMissing += @{ Name = $pm.Name; Path = $pm.NewPath }
        }
    }

    Write-Host ""

    # NuGet specific verification
    $nugetManager = $detectedManagers | Where-Object { $_.Name -eq "NuGet (.NET)" }
    if ($nugetManager) {
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Status "Verifying NuGet global-packages location..."
        Write-Host ""

        try {
            $nugetOutput = & dotnet nuget locals global-packages --list 2>&1
            $nugetOutputStr = $nugetOutput -join ""

            if ($nugetOutputStr -match "global-packages:\s*(.+)") {
                $nugetPath = $Matches[1].Trim()
                $script:verificationResults.NuGetPath = $nugetPath
                Write-Info "NuGet reports global-packages location:"
                Write-Info "  $nugetPath"
                Write-Host ""

                # Check if the path matches what we configured
                $expectedNugetPath = $nugetManager.NewPath
                if ($nugetPath -eq $expectedNugetPath) {
                    Write-Success "NuGet is using the configured Dev Drive path!"
                    $script:verificationResults.NuGetStatus = "OK"
                } elseif ($nugetPath -like "$devDrive*") {
                    Write-Success "NuGet is using a Dev Drive path"
                    $script:verificationResults.NuGetStatus = "OK"
                } else {
                    Write-Warning "NuGet is NOT using the Dev Drive path yet."
                    Write-Info "This may require a restart for the change to take effect."
                    Write-Info "After restarting, run this command to verify:"
                    Write-Info "  dotnet nuget locals global-packages --list"
                    $script:verificationResults.NuGetStatus = "PENDING_RESTART"
                }
            } else {
                Write-Info "NuGet output: $nugetOutputStr"
                $script:verificationResults.NuGetStatus = "UNKNOWN"
            }
        } catch {
            Write-Warning "Could not verify NuGet path: $_"
            Write-Info "Run this command manually to check:"
            Write-Info "  dotnet nuget locals global-packages --list"
            $script:verificationResults.NuGetStatus = "ERROR"
        }

        Write-Host ""
    }
} else {
    Write-Info "[WhatIf] Skipping verification in WhatIf mode"
    Write-Host ""
}

# Important notes (show different message for VerifyOnly mode)
if ($VerifyOnly) {
    # Calculate overall status
    $overallStatus = "PASS"
    if ($script:verificationResults.EnvVarsNotSet.Count -gt 0) {
        $overallStatus = "FAIL"
    } elseif ($script:verificationResults.EnvVarsFailed.Count -gt 0 -or $script:verificationResults.DirsMissing.Count -gt 0) {
        $overallStatus = "WARN"
    } elseif ($script:verificationResults.NuGetStatus -eq "PENDING_RESTART") {
        $overallStatus = "WARN"
    }

    # Set header color based on status
    $headerColor = switch ($overallStatus) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
    }

    Write-Host "================================================================" -ForegroundColor $headerColor
    Write-Host "                 VERIFICATION REPORT" -ForegroundColor $headerColor
    Write-Host "================================================================" -ForegroundColor $headerColor
    Write-Host ""

    # Overall Status
    Write-Host "  Overall Status: " -NoNewline
    switch ($overallStatus) {
        "PASS" { Write-Host "ALL CHECKS PASSED" -ForegroundColor Green }
        "WARN" { Write-Host "PASSED WITH WARNINGS" -ForegroundColor Yellow }
        "FAIL" { Write-Host "SOME CHECKS FAILED" -ForegroundColor Red }
    }
    Write-Host ""
    Write-Host "  Dev Drive: $devDrive" -ForegroundColor Gray
    Write-Host ""

    # Package Managers Detected
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  PACKAGE MANAGERS DETECTED" -ForegroundColor Cyan
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    foreach ($pm in $detectedManagers) {
        Write-Host "    - $($pm.Name)" -ForegroundColor Gray
    }
    Write-Host ""

    # Environment Variables Status
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  ENVIRONMENT VARIABLES" -ForegroundColor Cyan
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray

    if ($script:verificationResults.EnvVarsPassed.Count -gt 0) {
        Write-Host "  Configured correctly:" -ForegroundColor Green
        foreach ($ev in $script:verificationResults.EnvVarsPassed) {
            Write-Host "    [OK] $($ev.Name)" -ForegroundColor Green
            Write-Host "         $($ev.EnvVar) = $($ev.Value)" -ForegroundColor Gray
        }
    }

    if ($script:verificationResults.EnvVarsFailed.Count -gt 0) {
        Write-Host ""
        Write-Host "  Not pointing to Dev Drive:" -ForegroundColor Yellow
        foreach ($ev in $script:verificationResults.EnvVarsFailed) {
            Write-Host "    [WARN] $($ev.Name)" -ForegroundColor Yellow
            Write-Host "           Current:  $($ev.Current)" -ForegroundColor Gray
            Write-Host "           Expected: $($ev.Expected)" -ForegroundColor Gray
        }
    }

    if ($script:verificationResults.EnvVarsNotSet.Count -gt 0) {
        Write-Host ""
        Write-Host "  Not configured:" -ForegroundColor Red
        foreach ($ev in $script:verificationResults.EnvVarsNotSet) {
            Write-Host "    [FAIL] $($ev.Name)" -ForegroundColor Red
            Write-Host "           $($ev.EnvVar) is not set" -ForegroundColor Gray
        }
    }
    Write-Host ""

    # Cache Directories Status
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  CACHE DIRECTORIES ON DEV DRIVE" -ForegroundColor Cyan
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray

    if ($script:verificationResults.DirsExist.Count -gt 0) {
        foreach ($dir in $script:verificationResults.DirsExist) {
            Write-Host "    [OK] $($dir.Name): $($dir.SizeMB) MB" -ForegroundColor Green
            Write-Host "         $($dir.Path)" -ForegroundColor Gray
        }
    }

    if ($script:verificationResults.DirsMissing.Count -gt 0) {
        Write-Host ""
        foreach ($dir in $script:verificationResults.DirsMissing) {
            Write-Host "    [WARN] $($dir.Name): Directory not found" -ForegroundColor Yellow
            Write-Host "           $($dir.Path)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "  Total cache size on Dev Drive: $([math]::Round($script:verificationResults.TotalCacheSizeMB, 2)) MB" -ForegroundColor Cyan
    Write-Host ""

    # NuGet Status (if applicable)
    $nugetManager = $detectedManagers | Where-Object { $_.Name -eq "NuGet (.NET)" }
    if ($nugetManager) {
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  NUGET VERIFICATION" -ForegroundColor Cyan
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray

        switch ($script:verificationResults.NuGetStatus) {
            "OK" {
                Write-Host "    [OK] NuGet is using Dev Drive" -ForegroundColor Green
                Write-Host "         $($script:verificationResults.NuGetPath)" -ForegroundColor Gray
            }
            "PENDING_RESTART" {
                Write-Host "    [WARN] NuGet not yet using Dev Drive (restart required)" -ForegroundColor Yellow
                Write-Host "          Current: $($script:verificationResults.NuGetPath)" -ForegroundColor Gray
            }
            "ERROR" {
                Write-Host "    [WARN] Could not verify NuGet path" -ForegroundColor Yellow
            }
            default {
                Write-Host "    [WARN] NuGet status unknown" -ForegroundColor Yellow
            }
        }
        Write-Host ""
        Write-Host "  Note: There is a known issue where 'dotnet tool' commands" -ForegroundColor Gray
        Write-Host "  may not respect NUGET_PACKAGES. Fix planned for .NET 10." -ForegroundColor Gray
        Write-Host ""
    }

    # Final Summary
    Write-Host "================================================================" -ForegroundColor $headerColor
    $passedCount = $script:verificationResults.EnvVarsPassed.Count
    $totalCount = $detectedManagers.Count

    if ($overallStatus -eq "PASS") {
        Write-Success "All $passedCount of $totalCount package manager(s) verified successfully!"
    } elseif ($overallStatus -eq "WARN") {
        Write-Warning "Verification completed with warnings. Review items above."
        if ($script:verificationResults.NuGetStatus -eq "PENDING_RESTART") {
            Write-Info "A system restart may be required for all changes to take effect."
        }
    } else {
        Write-Error "Verification failed. Some package managers need configuration."
        Write-Info "Run this script without -VerifyOnly to configure missing items."
    }
} else {
    Write-Host "================================================================" -ForegroundColor Yellow
    Write-Host "                     IMPORTANT NOTES" -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Warning "1. RESTART REQUIRED: You must restart all open console windows"
    Write-Warning "   or reboot your computer for the changes to take effect."
    Write-Host ""

    # Check if verification showed issues that are likely due to needing a restart
    $hasVerificationIssues = ($script:verificationResults.NuGetStatus -eq "PENDING_RESTART") -or
                             ($script:verificationResults.EnvVarsFailed.Count -gt 0)

    if ($hasVerificationIssues) {
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Warning "2. VERIFICATION WARNINGS: Some verifications above may show warnings."
        Write-Warning "   This is NORMAL on first run - environment variable changes require"
        Write-Warning "   a restart before they take effect in running applications."
        Write-Host ""
        Write-Info "   After restarting, run this script again to verify everything is"
        Write-Info "   configured correctly:"
        Write-Host ""
        Write-Info "     .\Move-PackageCachesToDevDrive.ps1 -VerifyOnly"
        Write-Host ""
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    }

    if ($detectedManagers | Where-Object { $_.Name -eq "NuGet (.NET)" }) {
        Write-Warning "3. NuGet Note: There is a known issue where 'dotnet tool' commands"
        Write-Warning "   may not respect the NUGET_PACKAGES path. A fix is planned for"
        Write-Warning "   .NET 10 and servicing updates for 8.0 and 9.0."
        Write-Host ""
    }

    Write-Warning "4. To verify the NuGet global-packages folder after restart, run:"
    Write-Info "   dotnet nuget locals global-packages --list"
    Write-Host ""

    Write-Success "Script completed! Remember to restart before running verification."
}
Write-Host ""
