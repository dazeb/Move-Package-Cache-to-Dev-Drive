# Move Package Caches to Dev Drive

A PowerShell script that moves package manager caches to a Windows 11 Dev Drive for improved performance.

## Overview

Windows 11 Dev Drive uses the ReFS filesystem with Copy-on-Write (CoW) support, providing up to 30% faster build times for development workloads. This script automates the process of redirecting package manager caches to your Dev Drive.

## Supported Package Managers

| Package Manager | Environment Variable | Default Dev Drive Path |
|-----------------|---------------------|------------------------|
| npm (Node.js) | `npm_config_cache` | `D:\packages\npm` |
| pnpm | `PNPM_HOME` | `D:\packages\pnpm` |
| Yarn | `YARN_CACHE_FOLDER` | `D:\packages\yarn` |
| Bun | `BUN_INSTALL` | `D:\packages\bun` |
| NuGet (.NET) | `NUGET_PACKAGES` | `D:\<username>\.nuget\packages` |
| pip (Python) | `PIP_CACHE_DIR` | `D:\packages\pip` |
| Cargo (Rust) | `CARGO_HOME` | `D:\packages\cargo` |
| Go | `GOPATH` | `D:\packages\go` |
| Go Cache | `GOCACHE` | `D:\packages\go-cache` |
| Go Module Cache | `GOMODCACHE` | `D:\packages\go\pkg\mod` |
| Maven (Java) | `MAVEN_OPTS` | `D:\packages\maven` |
| Gradle (Java) | `GRADLE_USER_HOME` | `D:\packages\gradle` |
| vcpkg | `VCPKG_DEFAULT_BINARY_CACHE` | `D:\packages\vcpkg` |

## Requirements

- Windows 11 with a Dev Drive configured
- PowerShell 5.1 or later
- Administrator privileges

## Usage

### First Run (Migration)

```powershell
# Run as Administrator
.\Move-PackageCachesToDevDrive.ps1
```

The script will:
1. Ask for your Dev Drive path (e.g., `D:`)
2. Scan for installed package managers
3. Create cache directories on the Dev Drive
4. Set system environment variables
5. Migrate existing cache data
6. Offer to delete old cache folders
7. Run verification

### Verify Configuration

```powershell
.\Move-PackageCachesToDevDrive.ps1 -VerifyOnly
```

### Preview Changes (Dry Run)

```powershell
.\Move-PackageCachesToDevDrive.ps1 -WhatIf
```

### Subsequent Runs

When run again, the script detects existing configuration and offers:
- **(V)erify** - Check that everything is configured correctly
- **(R)econfigure** - Re-run the migration process
- **(Q)uit** - Exit without changes

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-WhatIf` | Shows what would happen without making changes |
| `-VerifyOnly` | Only verify existing configuration |

## What the Script Does

1. **Detects** installed package managers by checking commands and file paths
2. **Creates** cache directories on your Dev Drive
3. **Sets** system-wide environment variables
4. **Migrates** existing cache data to the new location
5. **Verifies** the configuration is correct
6. **Optionally deletes** old cache folders after successful migration

## Verification Report

The verification report shows:
- Overall status (PASS/WARN/FAIL)
- Environment variables status
- Cache directories with sizes
- NuGet-specific verification using `dotnet nuget locals`

Example output:
```
================================================================
                 VERIFICATION REPORT
================================================================

  Overall Status: ALL CHECKS PASSED

  Dev Drive: D:

----------------------------------------------------------------
  PACKAGE MANAGERS DETECTED
----------------------------------------------------------------
    - npm (Node.js)
    - NuGet (.NET)
    - pip (Python)

----------------------------------------------------------------
  ENVIRONMENT VARIABLES
----------------------------------------------------------------
  Configured correctly:
    [OK] npm (Node.js)
         npm_config_cache = D:\packages\npm
    [OK] NuGet (.NET)
         NUGET_PACKAGES = D:\dbenn\.nuget\packages

----------------------------------------------------------------
  CACHE DIRECTORIES ON DEV DRIVE
----------------------------------------------------------------
    [OK] npm (Node.js): 523.45 MB
         D:\packages\npm
    [OK] NuGet (.NET): 1024.32 MB
         D:\dbenn\.nuget\packages

  Total cache size on Dev Drive: 1547.77 MB

================================================================
[+] All 2 of 2 package manager(s) verified successfully!
```

## Important Notes

1. **Restart Required**: After running the script, restart all console windows or reboot for changes to take effect.

2. **NuGet Known Issue**: There is a known issue where `dotnet tool` commands may not respect the `NUGET_PACKAGES` path. A fix is planned for .NET 10.

3. **Verification After Restart**: Run `-VerifyOnly` after restarting to confirm everything is working:
   ```powershell
   .\Move-PackageCachesToDevDrive.ps1 -VerifyOnly
   ```

4. **Manual NuGet Verification**:
   ```powershell
   dotnet nuget locals global-packages --list
   ```

## Directory Structure

After running, your Dev Drive will have:
```
D:\
├── packages\
│   ├── npm\
│   ├── pnpm\
│   ├── yarn\
│   ├── bun\
│   ├── pip\
│   ├── cargo\
│   ├── go\
│   │   └── pkg\
│   │       └── mod\
│   ├── go-cache\
│   ├── maven\
│   ├── gradle\
│   └── vcpkg\
└── <username>\
    └── .nuget\
        └── packages\
```

## References

- [Set up a Dev Drive on Windows 11 - Microsoft Learn](https://learn.microsoft.com/en-us/windows/dev-drive/)
- [Dev Drive and Copy-on-Write for Developer Performance](https://devblogs.microsoft.com/engineering-at-microsoft/dev-drive-and-copy-on-write-for-developer-performance/)
- [Storing package cache on Dev Drive](https://learn.microsoft.com/en-us/windows/dev-drive/#storing-package-cache-on-dev-drive)

## License

MIT License - Feel free to use and modify as needed.
