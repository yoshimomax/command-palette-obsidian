<#
.SYNOPSIS
    Builds and installs the Command Palette Obsidian extension locally.
.DESCRIPTION
    Creates a self-signed certificate, builds the signed MSIX package,
    and installs it. No administrator privileges required.
    Requires Developer Mode to be enabled in Windows Settings.
.PARAMETER Configuration
    Build configuration (Debug or Release). Default: Release.
.PARAMETER Platform
    Target platform (x64 or ARM64). Default: x64.
.PARAMETER SkipBuild
    Skip the build step and install an existing package.
.EXAMPLE
    .\scripts\install.ps1
#>

param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [ValidateSet("x64", "ARM64")]
    [string]$Platform = "x64",

    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$repoRoot\CommandPaletteObsidian.sln")) {
    Write-Host "[ERROR] Cannot find CommandPaletteObsidian.sln" -ForegroundColor Red
    exit 1
}

Write-Host "=== Command Palette Obsidian - Install ===" -ForegroundColor Cyan
Write-Host ""

# --- Check Developer Mode ---
$devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
if (-not $devMode -or $devMode.AllowDevelopmentWithoutDevLicense -ne 1) {
    Write-Host "[ERROR] Developer Mode is not enabled." -ForegroundColor Red
    Write-Host "  Settings > System > For developers > Developer Mode" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Developer Mode" -ForegroundColor Green

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] dotnet CLI not found." -ForegroundColor Red
    Write-Host "  https://dotnet.microsoft.com/download/dotnet/9.0" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] dotnet $(dotnet --version)" -ForegroundColor Green
Write-Host ""

# --- Certificate (CurrentUser - no admin needed) ---
Write-Host "--- Certificate ---" -ForegroundColor Cyan
$certSubject = "CN=Dev"
$pfxPath = Join-Path $repoRoot "src\CommandPaletteObsidian\CommandPaletteObsidian_TemporaryKey.pfx"
$pfxPassword = ConvertTo-SecureString -String "CmdPalObsidian2024" -Force -AsPlainText

$existingCert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object {
    $_.Subject -eq $certSubject -and
    $_.NotAfter -gt (Get-Date) -and
    $_.EnhancedKeyUsageList.ObjectId -contains "1.3.6.1.5.5.7.3.3"
} | Select-Object -First 1

if ($existingCert) {
    $cert = $existingCert
    Write-Host "[OK] Reusing certificate: $($cert.Thumbprint)" -ForegroundColor Green
}
else {
    $cert = New-SelfSignedCertificate `
        -Type Custom `
        -Subject $certSubject `
        -KeyUsage DigitalSignature `
        -FriendlyName "CommandPaletteObsidian Dev" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
    Write-Host "[OK] Created certificate: $($cert.Thumbprint)" -ForegroundColor Green
}

Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $pfxPath -Password $pfxPassword | Out-Null

# Trust the certificate (CurrentUser\TrustedPeople - no admin needed)
$alreadyTrusted = Get-ChildItem -Path "Cert:\CurrentUser\TrustedPeople" -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
if (-not $alreadyTrusted) {
    $cerPath = Join-Path $repoRoot "CommandPaletteObsidian.cer"
    Export-Certificate -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $cerPath | Out-Null
    Import-Certificate -FilePath $cerPath -CertStoreLocation "Cert:\CurrentUser\TrustedPeople" | Out-Null
    Remove-Item $cerPath -ErrorAction SilentlyContinue
    Write-Host "[OK] Certificate trusted (CurrentUser)" -ForegroundColor Green
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

$existing = Get-AppxPackage -Name "*CommandPaletteObsidian*" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing previous version..."
    Remove-AppxPackage -Package $existing.PackageFullName
}

$searchBase = Join-Path $repoRoot "src\CommandPaletteObsidian\bin"
$msixFile = Get-ChildItem -Path $searchBase -Filter "*.msix" -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($msixFile) {
    Write-Host "Installing: $($msixFile.Name)"
    Add-AppxPackage -Path $msixFile.FullName
}
else {
    $manifest = Get-ChildItem -Path $searchBase -Filter "AppxManifest.xml" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($manifest) {
        Write-Host "Registering (loose files)..."
        Add-AppxPackage -Register $manifest.FullName
    }
    else {
        Write-Host "[ERROR] No package found in build output." -ForegroundColor Red
        exit 1
    }
}

Remove-Item $pfxPath -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Green
Write-Host ""
Write-Host "  1. Win+Alt+Space で Command Palette を開く"
Write-Host "  2. 'Reload Command Palette Extension' を実行"
Write-Host "  3. 'Search Obsidian Notes' で検索"
Write-Host ""
