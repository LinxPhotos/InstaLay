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
$OutAbs = (Resolve-Path $OutputDir).Path
$InAbs = (Resolve-Path $InputDir).Path

if (-not (Test-Path $InAbs)) {
  throw "InputDir not found: $InputDir"
}

$ZipPath = Join-Path $OutAbs "$Name.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($InAbs, $ZipPath)

$Msix = Get-ChildItem -Path $InAbs -Filter *.msix -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($Msix) {
  Copy-Item $Msix.FullName (Join-Path $OutAbs "$Name.msix") -Force
}

$Iss = Join-Path $PSScriptRoot '..\packaging\windows\insta_lay.iss'
$Iscc = @(
  "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe",
  'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
  'C:\Program Files\Inno Setup 6\ISCC.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($Iscc -and (Test-Path $Iss)) {
  $outputBase = "$Name-setup"
  & $Iscc `
    "/DMyAppVersion=$Version" `
    "/DMyAppArch=$Arch" `
    "/DMyAppSource=$InAbs" `
    "/DMyAppOutputBase=$outputBase" `
    "/O$OutAbs" `
    (Resolve-Path $Iss).Path
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Inno Setup failed (exit $LASTEXITCODE); zip portable package is still available."
  }
}

Write-Host "Packaged $Name -> $OutAbs"
Get-ChildItem $OutAbs | Format-Table Name, Length
