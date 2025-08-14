# Requires: msys2 (https://www.msys2.org/) with mingw-w64 toolchain installed and available in PATH
# Usage: Open MSYS2 MinGW 64-bit shell and run: pwsh ./scripts/windows_build_ffmpeg_mingw.ps1
# Or run from PowerShell if msys2/mingw64 binaries are in your PATH

param(
    [string]$FFmpegVersion = "6.1",
    [string]$Arch = "x86_64",
    [switch]$Verify
)

$ErrorActionPreference = 'Stop'

$FFmpegDir = "ffmpeg-$FFmpegVersion"
$OutputDir = "build_ffmpeg"
$ResourceTarget = "./windows/runner/resources"
$FFmpegTarget = "$ResourceTarget/ffmpeg.exe"
$LicenseTarget = "$ResourceTarget/LICENSE.md"

Write-Host "▶ Building FFmpeg $FFmpegVersion for $Arch with MinGW-w64"

if (!(Test-Path $FFmpegDir)) {
    Write-Host "Downloading FFmpeg $FFmpegVersion..."
    Invoke-WebRequest -Uri "https://ffmpeg.org/releases/ffmpeg-$FFmpegVersion.tar.bz2" -OutFile "ffmpeg-$FFmpegVersion.tar.bz2"
    tar -xjf "ffmpeg-$FFmpegVersion.tar.bz2"
}

# Ensure mingw-w64 gcc is available
if (-not (Get-Command gcc -ErrorAction SilentlyContinue)) {
    Write-Error "mingw-w64 gcc is required. Please install msys2 and the mingw-w64 toolchain, and ensure gcc is in your PATH."
}

Push-Location $FFmpegDir

# Clean previous builds
if (Test-Path Makefile) { bash -c "make distclean" }

$mingwPrefix = if ($Arch -eq "x86_64") { "/mingw64" } else { "/mingw32" }
$env:PKG_CONFIG_PATH = "$mingwPrefix/lib/pkgconfig"

$commonFlags = @(
    "--prefix=../$OutputDir/$Arch",
    "--arch=$Arch",
    "--target-os=mingw32",
    "--disable-everything",
    "--enable-protocol=file",
    "--enable-decoder=mp3,pcm_s16le",
    "--enable-encoder=pcm_s16le",
    "--enable-demuxer=mp3,wav",
    "--enable-muxer=wav,pcm_s16le",
    "--enable-filter=aresample",
    "--enable-small",
    "--disable-network",
    "--disable-autodetect",
    "--disable-doc",
    "--enable-static",
    "--disable-shared",
    "--disable-ffplay",
    "--disable-ffprobe"
)

Write-Host "⚙️  Configuring FFmpeg..."
# Use bash to run configure for proper environment
bash -c "./configure $($commonFlags -join ' ') --cc=gcc --cxx=g++"

Write-Host "🏗️  Building FFmpeg..."
bash -c "make -j$(nproc)"
bash -c "make install"

Pop-Location

# Copy binary and license
New-Item -ItemType Directory -Force -Path $ResourceTarget | Out-Null
Copy-Item "$OutputDir/$Arch/bin/ffmpeg.exe" $FFmpegTarget -Force
if (Test-Path "$FFmpegDir/LICENSE.md") {
    Copy-Item "$FFmpegDir/LICENSE.md" $LicenseTarget -Force
} else {
    Write-Warning "LICENSE.md missing; not copied."
}

if ($Verify) {
    Write-Host "🔍 Verifying binary execution..."
    & $FFmpegTarget -hide_banner -loglevel error -version | Write-Host
    if ($LASTEXITCODE -ne 0) { throw "Verification failed (cannot execute ffmpeg.exe)" }
    Write-Host "✅ Verification succeeded."
}

Write-Host "✅ Built ffmpeg at $FFmpegTarget and copied to $ResourceTarget"
Write-Host "(Artifacts retained for inspection; no cleanup performed.)"
