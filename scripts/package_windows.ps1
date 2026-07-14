# Package Flutter Windows Release folder into zip (+ optional Inno / MSIX).
# Usage: .\scripts\package_windows.ps1 -Version 0.1.0 -Arch x64 -InputDir build\windows\x64\runner\Release -OutputDir dist
param(
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][ValidateSet('x64', 'arm64')][string]$Arch,
  [Parameter(Mandatory = $true)][string]$InputDir,
  [Parameter(Mandatory = $true)][string]$OutputDir
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$Name = "InstaLay-$Version-windows-$Arch"

if (-not (Test-Path $InputDir)) {
  throw "InputDir not found: $InputDir"
}

$ZipPath = Join-Path (Resolve-Path $OutputDir).Path "$Name.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
  (Resolve-Path $InputDir).Path,
  $ZipPath
)

$Msix = Get-ChildItem -Path $InputDir -Filter *.msix -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($Msix) {
  Copy-Item $Msix.FullName (Join-Path $OutputDir "$Name.msix") -Force
}

$Iss = Join-Path $PSScriptRoot '..\packaging\windows\insta_lay.iss'
$Iscc = @(
  "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe",
  'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
  'C:\Program Files\Inno Setup 6\ISCC.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($Iscc -and (Test-Path $Iss)) {
  & $Iscc `
    "/DMyAppVersion=$Version" `
    "/DMyAppArch=$Arch" `
    "/DMyAppSource=$((Resolve-Path $InputDir).Path)" `
    "/O$((Resolve-Path $OutputDir).Path)" `
    "/F`"$Name-setup`"" `
    (Resolve-Path $Iss).Path
}

Write-Host "Packaged $Name -> $OutputDir"
Get-ChildItem $OutputDir | Format-Table Name, Length
