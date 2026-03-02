#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Builds and installs the Command Palette Obsidian extension locally.
.DESCRIPTION
    This script builds the MSIX package using dotnet CLI and installs it
    on your machine. Requires Developer Mode to be enabled in Windows Settings.
.PARAMETER Configuration
    Build configuration (Debug or Release). Default: Release.
.PARAMETER Platform
    Target platform (x64 or ARM64). Default: x64.
.PARAMETER SkipBuild
    Skip the build step and install an existing package.
.EXAMPLE
    .\scripts\install.ps1
.EXAMPLE
    .\scripts\install.ps1 -Configuration Debug -Platform x64
#>

param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [ValidateSet("x64", "ARM64")]
    [string]$Platform = "x64",

    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path "$repoRoot\CommandPaletteObsidian.sln")) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
}

Write-Host "=== Command Palette Obsidian - Install ===" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration"
Write-Host "Platform:      $Platform"
Write-Host ""

# Check Developer Mode
$devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
if (-not $devMode -or $devMode.AllowDevelopmentWithoutDevLicense -ne 1) {
    Write-Host "[ERROR] Developer Mode is not enabled." -ForegroundColor Red
    Write-Host "Enable it in: Settings > System > For developers > Developer Mode" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Developer Mode is enabled." -ForegroundColor Green

# Check dotnet
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] dotnet CLI is not installed." -ForegroundColor Red
    Write-Host "Install .NET 9 SDK from: https://dotnet.microsoft.com/download" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] dotnet CLI found: $(dotnet --version)" -ForegroundColor Green
Write-Host ""

# Build
if (-not $SkipBuild) {
    Write-Host "--- Building ---" -ForegroundColor Cyan
    Push-Location $repoRoot
    try {
        dotnet restore
        if ($LASTEXITCODE -ne 0) { throw "Restore failed" }

        dotnet build --configuration $Configuration -p:Platform=$Platform
        if ($LASTEXITCODE -ne 0) { throw "Build failed" }
    }
    finally {
        Pop-Location
    }
    Write-Host "[OK] Build succeeded." -ForegroundColor Green
    Write-Host ""
}

# Find MSIX package
Write-Host "--- Finding MSIX package ---" -ForegroundColor Cyan
$appPackagesDir = Join-Path $repoRoot "src\CommandPaletteObsidian\AppPackages"
$msixFiles = Get-ChildItem -Path $appPackagesDir -Filter "*.msix" -Recurse -ErrorAction SilentlyContinue

if (-not $msixFiles -or $msixFiles.Count -eq 0) {
    Write-Host "[WARN] No .msix file found in AppPackages." -ForegroundColor Yellow
    Write-Host "Trying loose-file registration instead..." -ForegroundColor Yellow
    Write-Host ""

    # Fallback: register as loose file (development mode)
    $appxManifestPath = Join-Path $repoRoot "src\CommandPaletteObsidian\bin\$Platform\$Configuration\net9.0-windows10.0.26100.0\win-$($Platform.ToLower())\AppX\AppxManifest.xml"

    if (-not (Test-Path $appxManifestPath)) {
        # Try alternative path
        $searchPath = Join-Path $repoRoot "src\CommandPaletteObsidian\bin"
        $appxManifest = Get-ChildItem -Path $searchPath -Filter "AppxManifest.xml" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($appxManifest) {
            $appxManifestPath = $appxManifest.FullName
        }
        else {
            Write-Host "[ERROR] Could not find AppxManifest.xml in build output." -ForegroundColor Red
            Write-Host "Search path: $searchPath" -ForegroundColor Yellow
            exit 1
        }
    }

    $appxDir = Split-Path -Parent $appxManifestPath
    Write-Host "Registering from: $appxDir"

    # Remove old registration if exists
    $existing = Get-AppxPackage -Name "CommandPaletteObsidian" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Removing existing installation..."
        Remove-AppxPackage -Package $existing.PackageFullName
    }

    Add-AppxPackage -Register $appxManifestPath
    if ($LASTEXITCODE -ne 0 -and -not $?) { throw "Registration failed" }
}
else {
    $msixFile = $msixFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host "Installing: $($msixFile.FullName)"

    # Remove old installation if exists
    $existing = Get-AppxPackage -Name "CommandPaletteObsidian" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Removing existing installation..."
        Remove-AppxPackage -Package $existing.PackageFullName
    }

    Add-AppxPackage -Path $msixFile.FullName
    if ($LASTEXITCODE -ne 0 -and -not $?) { throw "Installation failed" }
}

Write-Host ""
Write-Host "=== Installation complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open Command Palette (Win+Alt+Space)"
Write-Host "  2. Run 'Reload Command Palette Extension' if needed"
Write-Host "  3. Search for 'Search Obsidian Notes'"
Write-Host ""
