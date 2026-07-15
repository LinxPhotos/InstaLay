# Build a Microsoft Store MSIX from the current Flutter Windows release.
param(
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][ValidateSet('x64', 'arm64')][string]$Arch,
  [Parameter(Mandatory = $true)][string]$OutputDir,
  [switch]$Store = $true
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$identity = if ($env:MS_STORE_IDENTITY_NAME) { $env:MS_STORE_IDENTITY_NAME } else { 'LinxPhotos.InstaLay' }
$publisher = if ($env:MS_STORE_PUBLISHER) { $env:MS_STORE_PUBLISHER } else { 'CN=00000000-0000-0000-0000-000000000000' }
$pubDisplay = if ($env:MS_STORE_PUBLISHER_DISPLAY_NAME) { $env:MS_STORE_PUBLISHER_DISPLAY_NAME } else { 'Linx' }

# MSIX versions are a.b.c.d — map semver 0.1.2 → 0.1.2.0
$parts = $Version.Split('.')
while ($parts.Count -lt 4) { $parts += '0' }
$msixVer = ($parts[0..3] -join '.')

$storeArg = @()
if ($Store) { $storeArg = @('--store') }

# Flutter now writes arch-specific trees (x64/arm64). Tell msix which one;
# skip rebuild — caller already ran `flutter build windows --release`.
dart run msix:create @storeArg `
  --display-name "InstaLay" `
  --publisher-display-name $pubDisplay `
  --identity-name $identity `
  --publisher $publisher `
  --version $msixVer `
  --architecture $Arch `
  --build-windows false `
  --output-path $OutputDir `
  --output-name "InstaLay-$Version-windows-$Arch-store"

$built = Get-ChildItem -Path $OutputDir -Filter "*.msix" -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if (-not $built) {
  $built = Get-ChildItem -Path build -Filter *.msix -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
}
if (-not $built) { throw 'No MSIX produced' }

$destName = "InstaLay-$Version-windows-$Arch-store.msix"
$dest = Join-Path $OutputDir $destName
if ($built.FullName -ne (Resolve-Path $dest -ErrorAction SilentlyContinue)) {
  Copy-Item $built.FullName $dest -Force
}
Write-Host "Store MSIX -> $dest"
