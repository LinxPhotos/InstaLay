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

# Flutter Windows Release is a folder of runner + engine + plugins + data/.
# A failed native link (e.g. jxl_ffi) can leave only instalay.exe; never ship that.
# Missing plugin DLLs surface later as "The code execution cannot proceed because X.dll was not found."
$required = @(
  'instalay.exe',
  'flutter_windows.dll',
  'data',
  'window_manager_plugin.dll',
  'screen_retriever_windows_plugin.dll'
)
foreach ($name in $required) {
  $path = Join-Path $InAbs $name
  if (-not (Test-Path $path)) {
    throw "Incomplete Windows Release at $InAbs (missing $name). Refusing to package a broken build."
  }
}
$dllCount = @(Get-ChildItem -Path $InAbs -Filter '*.dll' -File).Count
if ($dllCount -lt 8) {
  throw "Incomplete Windows Release at $InAbs (only $dllCount DLL(s); expected engine + plugins). Refusing to package."
}

$ZipPath = Join-Path $OutAbs "$Name.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($InAbs, $ZipPath)

$Msix = Get-ChildItem -Path $InAbs -Filter *.msix -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($Msix) {
  Copy-Item $Msix.FullName (Join-Path $OutAbs "$Name.msix") -Force
}

$Iss = Join-Path $PSScriptRoot '..\packaging\windows\instalay.iss'
$Iscc = @(
  "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe",
  'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
  'C:\Program Files\Inno Setup 6\ISCC.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1

$inCi = [bool]($env:CI -or $env:GITHUB_ACTIONS)
if ($inCi -and (-not $Iscc -or -not (Test-Path $Iss))) {
  throw "Inno Setup 6 (ISCC.exe) and packaging/windows/instalay.iss are required in CI."
}

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
    throw "Inno Setup failed (exit $LASTEXITCODE)."
  }
  $setupExe = Join-Path $OutAbs "$outputBase.exe"
  if (-not (Test-Path $setupExe)) {
    throw "Inno Setup did not produce $setupExe"
  }
} else {
  Write-Warning "Inno Setup not found; skipping setup EXE (ZIP only)."
}


Write-Host "Packaged $Name -> $OutAbs"
Get-ChildItem $OutAbs | Format-Table Name, Length
