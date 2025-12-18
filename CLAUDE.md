# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a PowerShell automation script that migrates package manager caches to Windows 11 Dev Drives for improved performance. The script is a single-file utility that detects package managers, creates cache directories, sets environment variables, and migrates existing cache data.

## Common Commands

### Running the script
```powershell
# First run (migration)
.\Move-PackageCachesToDevDrive.ps1

# Verify existing configuration
.\Move-PackageCachesToDevDrive.ps1 -VerifyOnly

# Preview changes without applying
.\Move-PackageCachesToDevDrive.ps1 -WhatIf
```

### Testing
There are no automated tests. Manual testing involves:
1. Running with `-WhatIf` to preview changes
2. Running the full migration on a test system
3. Using `-VerifyOnly` to validate configuration

### Interactive Mode Behavior
When the script detects previous configuration (lines 166-203):
- Checks all environment variables in `$envVarsToCheck` array (lines 140-154)
- If any are set, offers three options: (V)erify, (R)econfigure, or (Q)uit
- Default choice (Enter key) triggers Verify mode
- This prevents accidental re-configuration

## Architecture

### Script Structure

The script is organized into these logical sections:

1. **Module dependencies and output functions** (lines 1-150)
   - Checks for and optionally installs PwshSpectreConsole module
   - Defines dual-mode output functions (Spectre vs basic fallback)
   - `$global:UseSpectreConsole` flag controls which output mode is used

2. **Parameter handling and environment detection** (lines 150-250)
   - Checks for previous configuration via environment variables
   - Interactive mode selection (Verify/Reconfigure/Quit)
   - Dev Drive path input and validation

3. **Package manager definitions** (lines 250-420)
   - Array of hashtables defining each package manager
   - Each entry specifies: detection methods, environment variable, new/old paths
   - Detection uses both commands (via `Get-Command`) and file paths (with wildcard support)

4. **Core utility functions** (lines 420-560)
   - `Test-CommandExists`: Checks if a command is available
   - `Test-PathExists`: Checks if any path from array exists (supports wildcards)
   - `Test-PackageManagerInstalled`: Combines command and path detection
   - `Move-DirectoryContents`: Migrates cache data with size verification
   - `Set-EnvironmentVariableSystem`: Sets Machine-level environment variables

5. **Detection phase** (lines 560-600)
   - Scans all package managers to build detected/not-detected lists
   - Uses Spectre status spinner when available
   - Early exit if no package managers found

6. **Processing phase** (lines 600-740)
   - Skipped in VerifyOnly mode
   - Creates cache directories on Dev Drive
   - Sets environment variables (handles special case for MAVEN_OPTS format)
   - Migrates existing cache data from old locations
   - Prompts for deletion of old cache folders after successful migration

7. **Verification phase** (lines 740-880)
   - Validates environment variables are set correctly
   - Checks cache directory existence and calculates sizes
   - Special NuGet verification using `dotnet nuget locals global-packages --list`
   - Results stored in `$script:verificationResults` hashtable

8. **Reporting phase** (lines 880-1240)
   - Different output format for VerifyOnly vs normal mode
   - VerifyOnly: Structured report with OK/WARN/FAIL status indicators
   - Normal mode: Important notes about restart requirements and known issues

### Key Design Patterns

**Dual-Mode Output System**
The script uses a feature flag pattern for output:
- `$global:UseSpectreConsole` boolean determines output mode
- All output functions (Write-Status, Write-Success, etc.) check this flag
- Spectre mode: Uses `Write-SpectreHost` with markup tags like `[green]✓[/]`
- Basic mode: Uses `Write-Host` with `-ForegroundColor` parameter
- Graceful degradation ensures script works without PwshSpectreConsole
- Verification report has completely separate code paths for rich tables vs basic text

**Module Dependency Management**
- Script checks for PwshSpectreConsole at startup
- Offers interactive installation if missing
- Continues with basic output if installation declined or fails
- No hard dependency - script fully functional without the module

**Package Manager Configuration**
Each package manager is defined as a hashtable with:
- `Name`: Display name
- `DetectionCommands`: Array of commands to check
- `DetectionPaths`: Array of file paths (with wildcard support)
- `EnvVar`: Environment variable name to set
- `NewPath`: Target location on Dev Drive
- `OldPaths`: Array of possible existing cache locations
- `EnvValue`: (Optional) Custom value format (used by MAVEN_OPTS)

**Detection Logic**
- Commands checked via `Get-Command` with error suppression
- Paths checked with `Get-Item` supporting wildcards
- Package manager is "detected" if ANY command OR ANY path exists

**Migration Safety**
- Creates destination before copying
- Verifies copied size matches source (within 1% tolerance)
- Tracks migrated paths in `$script:migratedPaths` for cleanup prompt
- Only migrates from first found old location

**Environment Variable Handling**
- All variables set at Machine scope for system-wide effect
- Special handling for MAVEN_OPTS which uses format `-Dmaven.repo.local=<path>`
- Verification checks both exact match and "same drive" match

**Verification Results Structure**
The `$script:verificationResults` hashtable stores:
- `EnvVarsPassed`: Array of successfully configured variables
- `EnvVarsFailed`: Array of variables not pointing to Dev Drive
- `EnvVarsNotSet`: Array of variables not configured
- `DirsExist`/`DirsMissing`: Cache directory status
- `TotalCacheSizeMB`: Sum of all cache sizes
- `NuGetStatus`: Special status (OK/PENDING_RESTART/ERROR/UNKNOWN)
- `NuGetPath`: Path reported by `dotnet nuget locals`

## Important Constraints

**Administrator Privileges Required**
The script requires elevation due to `#Requires -RunAsAdministrator` (line 20). It sets Machine-level environment variables which require admin rights.

**NuGet Known Issue**
There is a documented .NET issue where `dotnet tool` commands may not respect `NUGET_PACKAGES`. The script acknowledges this in verification output (lines 997, 1124, 1172, 1210). A fix is planned for .NET 10.

**Restart Requirements**
Environment variable changes require restarting applications/shells or rebooting. The script warns about this (lines 1152-1168, 1187-1206) and recommends running `-VerifyOnly` after restart.

**Dev Drive Prerequisites**
The script assumes a Dev Drive (Windows 11 ReFS volume with Copy-on-Write) is already configured. It only validates that the provided drive path exists (line 234).

**Environment Variable Scope**
All environment variables are set at Machine scope (not User scope) via `[Environment]::SetEnvironmentVariable($Name, $Value, "Machine")` at line 552. This affects all users on the system.

**Error Action Preference**
The script sets `$ErrorActionPreference = "Stop"` at line 27, causing most errors to terminate execution. However, specific operations use `-ErrorAction SilentlyContinue` for graceful handling (e.g., command detection, file operations).

**Migration Size Verification**
The `Move-DirectoryContents` function (lines 467-524) verifies that copied data matches source size within 1% tolerance (line 508). This prevents silent data loss but allows minor variance due to file system metadata differences.

## Supported Package Managers

npm, pnpm, Yarn, Bun, NuGet (.NET), pip (Python), Cargo (Rust), Go (GOPATH/GOCACHE/GOMODCACHE), Maven (Java), Gradle (Java), vcpkg

## Modification Guidelines

**Adding a New Package Manager**
Add a hashtable to the `$packageManagers` array with required fields:
- Ensure `DetectionCommands` includes all possible command names
- Add `DetectionPaths` for installations not in PATH
- Specify environment variable and cache paths
- Add old cache locations for migration

**Changing Detection Logic**
Modify `Test-PackageManagerInstalled` function. Current logic is OR-based (any command OR any path triggers detection).

**Customizing Verification**
The verification phase can be extended by adding checks to the section starting around line 750. Update `$script:verificationResults` structure for new verification types.

**Modifying Output Formatting**
- Dual-mode output functions start at line 65
- Add new output functions that check `$global:UseSpectreConsole` flag
- Spectre report generation starts at line 886 (VerifyOnly mode)
- Basic fallback report starts at line 1017 (VerifyOnly mode)
- Both paths must be maintained for graceful degradation

## Troubleshooting

**Package Manager Not Detected**
Check both `DetectionCommands` and `DetectionPaths` in the package manager definition (lines 245-415). The script uses OR logic - either a command OR a path must exist.

**Environment Variable Not Taking Effect**
1. Verify it's set at Machine level: `[Environment]::GetEnvironmentVariable("VAR_NAME", "Machine")`
2. Restart your shell/IDE/application
3. Run verification: `.\Move-PackageCachesToDevDrive.ps1 -VerifyOnly`

**Migration Reports Incomplete**
Check the 1% variance tolerance at line 508. Size mismatches within this range are considered successful.

**Cleanup Fails for Old Folders**
The script prompts for deletion only after successful migration (lines 679-732). Failed deletions may be due to file locks - close all applications using the cache and try manual deletion.
