# Diagnose / fix a Windows CMake cache left over after moving or renaming the repo.
# CMake embeds the absolute source path in CMakeCache.txt; if the folder moves,
# configure fails before windows/CMakeLists.txt runs. Flutter will not auto-wipe it.
#
# Usage:
#   .\scripts\ensure_windows_cmake_cache.ps1           # report only
#   .\scripts\ensure_windows_cmake_cache.ps1 -Fix      # delete stale build\windows if mismatched
#   .\scripts\ensure_windows_cmake_cache.ps1 -Fix -All # flutter clean (full wipe)

param(
  [switch]$Fix,
  [switch]$All
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$CacheCandidates = @(
  (Join-Path $RepoRoot 'build\windows\x64\CMakeCache.txt'),
  (Join-Path $RepoRoot 'build\windows\arm64\CMakeCache.txt'),
  (Join-Path $RepoRoot 'build\windows\CMakeCache.txt')
)

function Get-CachedHomeDirectory {
  param([string]$CachePath)

  $line = Select-String -Path $CachePath -Pattern '^CMAKE_HOME_DIRECTORY:INTERNAL=(.+)$' |
    Select-Object -First 1
  if ($line) {
    return $line.Matches[0].Groups[1].Value
  }

  $line = Select-String -Path $CachePath -Pattern '^CMAKE_CACHEFILE_DIR:INTERNAL=(.+)$' |
    Select-Object -First 1
  if ($line) {
    return $line.Matches[0].Groups[1].Value
  }

  return $null
}

function ConvertTo-NormalizedPath {
  param([string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $null
  }
  $full = [System.IO.Path]::GetFullPath($Value)
  return $full.TrimEnd([char[]]@('\', '/')).ToLowerInvariant()
}

$found = $false
$stale = $false
$repoNorm = ConvertTo-NormalizedPath -Value $RepoRoot
$windowsDir = ConvertTo-NormalizedPath -Value (Join-Path $RepoRoot 'windows')

foreach ($cache in $CacheCandidates) {
  if (-not (Test-Path $cache)) {
    continue
  }
  $found = $true
  $cachedHome = Get-CachedHomeDirectory -CachePath $cache
  $cachedHomeNorm = ConvertTo-NormalizedPath -Value $cachedHome

  Write-Host "Cache: $cache"
  Write-Host "  CMAKE_HOME_DIRECTORY: $cachedHome"
  Write-Host "  Current repo root:    $RepoRoot"

  # Cache home is typically <repo>/windows or under this repo root.
  $ok = $false
  if ($cachedHomeNorm) {
    if ($cachedHomeNorm -eq $windowsDir) { $ok = $true }
    elseif ($cachedHomeNorm -eq $repoNorm) { $ok = $true }
    elseif ($cachedHomeNorm.StartsWith($repoNorm + '\')) { $ok = $true }
    elseif ($cachedHomeNorm.StartsWith($repoNorm + '/')) { $ok = $true }
  }

  if (-not $ok) {
    $stale = $true
    Write-Host "  STALE - path no longer matches this checkout." -ForegroundColor Yellow
  }
  else {
    Write-Host "  OK" -ForegroundColor Green
  }
}

if (-not $found) {
  Write-Host "No Windows CMakeCache.txt under build\ - nothing to fix."
  exit 0
}

if (-not $stale) {
  Write-Host "Windows CMake cache looks consistent with this repo path."
  exit 0
}

if (-not $Fix) {
  Write-Host ""
  Write-Host "Re-run with -Fix to delete build\windows, or -Fix -All for flutter clean."
  Write-Host "  .\scripts\ensure_windows_cmake_cache.ps1 -Fix"
  exit 1
}

if ($All) {
  Push-Location $RepoRoot
  try {
    flutter clean
  }
  finally {
    Pop-Location
  }
}
else {
  $winBuild = Join-Path $RepoRoot 'build\windows'
  if (Test-Path $winBuild) {
    Remove-Item -Recurse -Force $winBuild
    Write-Host "Removed $winBuild"
  }
}

Write-Host "Done. Run: flutter run -d windows"
exit 0
