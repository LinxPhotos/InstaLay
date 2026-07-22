# Build libjxl static libs for jxl_ffi on Windows with the local MSVC toolset.
# Official GitHub release archives are often built with a newer STL ABI and then
# fail to link (__std_min_element_*, etc.). Prefer this local prebuilt tree.
#
# Usage:
#   .\scripts\build_libjxl_prebuilt_windows.ps1
#   .\scripts\build_libjxl_prebuilt_windows.ps1 -Version 0.12.0 -OutDir packages\jxl_ffi\native\prebuilt\windows-x64

param(
  [string]$Version = '0.12.0',
  [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $OutDir) {
  $OutDir = Join-Path $RepoRoot 'packages\jxl_ffi\native\prebuilt\windows-x64'
}
$OutAbs = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
$Marker = Join-Path $OutAbs 'lib\jxl.lib'
if (Test-Path $Marker) {
  Write-Host "libjxl prebuilt already present at $OutAbs"
  exit 0
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) {
  throw 'vswhere.exe not found. Install Visual Studio 2022 with C++ workload.'
}
$vsDevCmd = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find 'Common7\Tools\VsDevCmd.bat' |
  Select-Object -First 1
if (-not $vsDevCmd) {
  throw 'VsDevCmd.bat not found. Install VS C++ build tools.'
}
$vsVer = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationVersion |
  Select-Object -First 1
$vsMajor = if ($vsVer) { [int]($vsVer.Split('.')[0]) } else { 17 }
# CMake generator names track the VS product year marketed with that major.
$cmakeGenerator = switch ($vsMajor) {
  18 { 'Visual Studio 18 2026' }
  17 { 'Visual Studio 17 2022' }
  16 { 'Visual Studio 16 2019' }
  default { throw "Unsupported Visual Studio major version: $vsMajor ($vsVer)" }
}
Write-Host "Using CMake generator: $cmakeGenerator (VS $vsVer)"

$Work = Join-Path $env:TEMP ("libjxl-build-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $Work | Out-Null
$Src = Join-Path $Work 'libjxl'
$Build = Join-Path $Work 'build'

try {
  Write-Host "Cloning libjxl v$Version..."
  git clone --depth 1 --branch "v$Version" --recurse-submodules `
    https://github.com/libjxl/libjxl.git $Src

  # Configure + build inside a VS developer environment (VS generator; no Ninja required).
  $configure = @"
call "$vsDevCmd" -arch=x64 -host_arch=x64 >nul
cmake -S "$Src" -B "$Build" -G "$cmakeGenerator" -A x64 ^
  -DCMAKE_INSTALL_PREFIX="$OutAbs" ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL ^
  -DBUILD_SHARED_LIBS=OFF ^
  -DBUILD_TESTING=OFF ^
  -DJPEGXL_ENABLE_TESTS=OFF ^
  -DJPEGXL_ENABLE_TOOLS=OFF ^
  -DJPEGXL_ENABLE_DEVTOOLS=OFF ^
  -DJPEGXL_ENABLE_BENCHMARK=OFF ^
  -DJPEGXL_ENABLE_EXAMPLES=OFF ^
  -DJPEGXL_ENABLE_MANPAGES=OFF ^
  -DJPEGXL_ENABLE_JNI=OFF ^
  -DJPEGXL_ENABLE_SJPEG=OFF ^
  -DJPEGXL_ENABLE_OPENEXR=OFF ^
  -DJPEGXL_ENABLE_SKCMS=ON ^
  -DJPEGXL_BUNDLE_SKCMS=ON ^
  -DJPEGXL_ENABLE_VIEWERS=OFF ^
  -DJPEGXL_ENABLE_PLUGINS=OFF ^
  -DJPEGXL_ENABLE_TCMALLOC=OFF
if errorlevel 1 exit /b 1
cmake --build "$Build" --config Release --parallel
if errorlevel 1 exit /b 1
cmake --install "$Build" --config Release
if errorlevel 1 exit /b 1
"@
  $bat = Join-Path $Work 'build.bat'
  Set-Content -Path $bat -Value $configure -Encoding ASCII
  Write-Host "Building libjxl (this can take several minutes)..."
  & cmd.exe /c $bat
  if ($LASTEXITCODE -ne 0) {
    throw "libjxl build failed with exit code $LASTEXITCODE"
  }

  if (-not (Test-Path $Marker)) {
    # Some installs use lib/jxl-static.lib naming; normalize.
    $alt = Get-ChildItem (Join-Path $OutAbs 'lib') -Filter 'jxl*.lib' -ErrorAction SilentlyContinue |
      Select-Object -First 5
    throw "Install did not produce $Marker. Found: $($alt.Name -join ', ')"
  }
  Write-Host "Installed libjxl prebuilt -> $OutAbs"
}
finally {
  Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
}
