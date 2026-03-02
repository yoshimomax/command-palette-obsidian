<#
.SYNOPSIS
    Uninstalls the Command Palette Obsidian extension.
#>

$ErrorActionPreference = "Stop"

Write-Host "=== Command Palette Obsidian - Uninstall ===" -ForegroundColor Cyan

$pkg = Get-AppxPackage -Name "*CommandPaletteObsidian*" -ErrorAction SilentlyContinue
if ($pkg) {
    Write-Host "Removing: $($pkg.PackageFullName)"
    Remove-AppxPackage -Package $pkg.PackageFullName
    Write-Host "[OK] Uninstalled." -ForegroundColor Green
}
else {
    Write-Host "Extension is not installed." -ForegroundColor Yellow
}
