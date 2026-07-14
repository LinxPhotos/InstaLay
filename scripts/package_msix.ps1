# Build a Microsoft Store MSIX from the current Flutter Windows release.
param(
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][ValidateSet('x64', 'arm64')][string]$Arch,
  [Parameter(Mandatory = $true)][string]$OutputDir,
  [switch]$Store = $true
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$identity = if ($env:MS_STORE_IDENTITY_NAME) { $env:MS_STORE_IDENTITY_NAME } else { 'AMDphreak.InstaLay' }
$publisher = if ($env:MS_STORE_PUBLISHER) { $env:MS_STORE_PUBLISHER } else { 'CN=00000000-0000-0000-0000-000000000000' }
$pubDisplay = if ($env:MS_STORE_PUBLISHER_DISPLAY_NAME) { $env:MS_STORE_PUBLISHER_DISPLAY_NAME } else { 'AMDphreak' }

# MSIX versions are a.b.c.d — map semver 0.1.1 → 0.1.1.0
$parts = $Version.Split('.')
while ($parts.Count -lt 4) { $parts += '0' }
$msixVer = ($parts[0..3] -join '.')

$storeArg = @()
if ($Store) { $storeArg = @('--store') }

dart run msix:create @storeArg `
  --display-name "Insta Lay" `
  --publisher-display-name $pubDisplay `
  --identity-name $identity `
  --publisher $publisher `
  --version $msixVer

$built = Get-ChildItem -Path build -Filter *.msix -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $built) { throw 'No MSIX produced' }

$destName = "InstaLay-$Version-windows-$Arch-store.msix"
Copy-Item $built.FullName (Join-Path $OutputDir $destName) -Force
Write-Host "Store MSIX -> $(Join-Path $OutputDir $destName)"
