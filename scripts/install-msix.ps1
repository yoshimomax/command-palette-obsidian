<#
.SYNOPSIS
    Installs a pre-built MSIX package downloaded from GitHub Actions.
    No administrator privileges required.
.DESCRIPTION
    1. Installs the .cer certificate to CurrentUser\TrustedPeople
    2. Installs the .msix package via Add-AppxPackage
.PARAMETER Path
    Path to the folder containing the .msix and .cer files.
    Default: current directory.
.EXAMPLE
    .\install-msix.ps1 -Path "C:\Downloads\CommandPaletteObsidian-x64"
#>

param(
    [string]$Path = "."
)

$ErrorActionPreference = "Stop"
$Path = Resolve-Path $Path

Write-Host "=== Install Command Palette Obsidian ===" -ForegroundColor Cyan
Write-Host ""

# Developer Mode check
$devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
if (-not $devMode -or $devMode.AllowDevelopmentWithoutDevLicense -ne 1) {
    Write-Host "[ERROR] Developer Mode is not enabled." -ForegroundColor Red
    Write-Host "  Settings > System > For developers > Developer Mode" -ForegroundColor Yellow
    exit 1
}

# Install certificate (CurrentUser - no admin needed)
$cerFile = Get-ChildItem -Path $Path -Filter "*.cer" -Recurse | Select-Object -First 1
if ($cerFile) {
    Write-Host "Installing certificate: $($cerFile.Name)"
    Import-Certificate -FilePath $cerFile.FullName -CertStoreLocation "Cert:\CurrentUser\TrustedPeople" | Out-Null
    Write-Host "[OK] Certificate trusted" -ForegroundColor Green
}
else {
    Write-Host "[WARN] No .cer file found" -ForegroundColor Yellow
}

# Remove old version
$existing = Get-AppxPackage -Name "*CommandPaletteObsidian*" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing previous version..."
    Remove-AppxPackage -Package $existing.PackageFullName
}

# Install MSIX
$msixFile = Get-ChildItem -Path $Path -Filter "*.msix" -Recurse | Select-Object -First 1
if (-not $msixFile) {
    Write-Host "[ERROR] No .msix file found in $Path" -ForegroundColor Red
    exit 1
}

Write-Host "Installing: $($msixFile.Name)"
Add-AppxPackage -Path $msixFile.FullName

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Green
Write-Host ""
Write-Host "  1. Win+Alt+Space で Command Palette を開く"
Write-Host "  2. 'Reload Command Palette Extension' を実行"
Write-Host "  3. 'Search Obsidian Notes' で検索"
Write-Host ""
