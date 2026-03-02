#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Builds and installs the Command Palette Obsidian extension locally.
.DESCRIPTION
    This script creates a self-signed certificate, builds the MSIX package,
    installs the certificate, and installs the extension.
    Requires Developer Mode to be enabled in Windows Settings.
.PARAMETER Configuration
    Build configuration (Debug or Release). Default: Release.
.PARAMETER Platform
    Target platform (x64 or ARM64). Default: x64.
.PARAMETER SkipBuild
    Skip the build step and install an existing package.
.EXAMPLE
    .\scripts\install.ps1
.EXAMPLE
    .\scripts\install.ps1 -Configuration Debug
#>

param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [ValidateSet("x64", "ARM64")]
    [string]$Platform = "x64",

    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

# Find repo root
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$repoRoot\CommandPaletteObsidian.sln")) {
    Write-Host "[ERROR] Cannot find CommandPaletteObsidian.sln at $repoRoot" -ForegroundColor Red
    exit 1
}

Write-Host "=== Command Palette Obsidian - Install ===" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration"
Write-Host "Platform:      $Platform"
Write-Host ""

# --- Check prerequisites ---

$devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
if (-not $devMode -or $devMode.AllowDevelopmentWithoutDevLicense -ne 1) {
    Write-Host "[ERROR] Developer Mode is not enabled." -ForegroundColor Red
    Write-Host "Enable it: Settings > System > For developers > Developer Mode" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Developer Mode enabled" -ForegroundColor Green

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] dotnet CLI not found. Install .NET 9 SDK: https://dotnet.microsoft.com/download/dotnet/9.0" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] dotnet $(dotnet --version)" -ForegroundColor Green
Write-Host ""

# --- Create or reuse self-signed certificate ---

Write-Host "--- Certificate ---" -ForegroundColor Cyan
$certSubject = "CN=Dev"
$pfxPath = Join-Path $repoRoot "src\CommandPaletteObsidian\CommandPaletteObsidian_TemporaryKey.pfx"
$pfxPassword = ConvertTo-SecureString -String "CmdPalObsidian2024" -Force -AsPlainText

# Check for existing valid certificate
$existingCert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object {
    $_.Subject -eq $certSubject -and
    $_.NotAfter -gt (Get-Date) -and
    $_.EnhancedKeyUsageList.ObjectId -contains "1.3.6.1.5.5.7.3.3"
} | Select-Object -First 1

if ($existingCert) {
    Write-Host "Reusing existing certificate: $($existingCert.Thumbprint)" -ForegroundColor Green
    $cert = $existingCert
}
else {
    Write-Host "Creating new self-signed certificate..."
    $cert = New-SelfSignedCertificate `
        -Type Custom `
        -Subject $certSubject `
        -KeyUsage DigitalSignature `
        -FriendlyName "CommandPaletteObsidian Dev Certificate" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
    Write-Host "Created certificate: $($cert.Thumbprint)" -ForegroundColor Green
}

# Export PFX for MSBuild
Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $pfxPath -Password $pfxPassword | Out-Null
Write-Host "[OK] PFX exported" -ForegroundColor Green

# Install certificate to Trusted People (so MSIX is trusted)
$trustedPeople = Get-ChildItem -Path "Cert:\LocalMachine\TrustedPeople" | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
if (-not $trustedPeople) {
    Write-Host "Installing certificate to Trusted People..."
    $cerPath = Join-Path $repoRoot "CommandPaletteObsidian.cer"
    Export-Certificate -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $cerPath | Out-Null
    Import-Certificate -FilePath $cerPath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople" | Out-Null
    Remove-Item $cerPath -ErrorAction SilentlyContinue
    Write-Host "[OK] Certificate trusted" -ForegroundColor Green
}
else {
    Write-Host "[OK] Certificate already trusted" -ForegroundColor Green
}
Write-Host ""

# --- Build ---

if (-not $SkipBuild) {
    Write-Host "--- Build ---" -ForegroundColor Cyan
    Push-Location $repoRoot
    try {
        dotnet restore
        if ($LASTEXITCODE -ne 0) { throw "Restore failed" }

        dotnet build --configuration $Configuration -p:Platform=$Platform `
            -p:AppxPackageSigningEnabled=true `
            -p:PackageCertificateThumbprint=$($cert.Thumbprint)
        if ($LASTEXITCODE -ne 0) { throw "Build failed" }
    }
    finally {
        Pop-Location
    }
    Write-Host "[OK] Build succeeded" -ForegroundColor Green
    Write-Host ""
}

# --- Install ---

Write-Host "--- Install ---" -ForegroundColor Cyan

# Remove old installation
$existing = Get-AppxPackage -Name "*CommandPaletteObsidian*" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing existing installation..."
    Remove-AppxPackage -Package $existing.PackageFullName
}

# Find MSIX
$searchBase = Join-Path $repoRoot "src\CommandPaletteObsidian\bin"
$msixFile = Get-ChildItem -Path $searchBase -Filter "*.msix" -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($msixFile) {
    Write-Host "Installing: $($msixFile.Name)"
    Add-AppxPackage -Path $msixFile.FullName
    Write-Host "[OK] MSIX installed" -ForegroundColor Green
}
else {
    # Fallback: loose-file registration
    Write-Host "No .msix found, trying loose-file registration..."
    $manifest = Get-ChildItem -Path $searchBase -Filter "AppxManifest.xml" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($manifest) {
        Add-AppxPackage -Register $manifest.FullName
        Write-Host "[OK] Registered (loose files)" -ForegroundColor Green
    }
    else {
        Write-Host "[ERROR] No installable package found." -ForegroundColor Red
        exit 1
    }
}

# Cleanup PFX (keep it out of git)
Remove-Item $pfxPath -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "  1. Win+Alt+Space で Command Palette を開く"
Write-Host "  2. 'Reload Command Palette Extension' を実行 (初回のみ)"
Write-Host "  3. 'Search Obsidian Notes' で検索"
Write-Host ""
