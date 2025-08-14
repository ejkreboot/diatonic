# Requires: Visual Studio with C++ build tools, NASM (for assembly), and PowerShell 5+
# Usage: Run from a "x64 Native Tools Command Prompt for VS" or launch this script with the correct environment.
# Example: .\scripts\windows_build_ffmpeg_msvc.ps1

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

Write-Host "▶ Building FFmpeg $FFmpegVersion for $Arch with MSVC"

if (!(Test-Path $FFmpegDir)) {
    Write-Host "Downloading FFmpeg $FFmpegVersion..."
    Invoke-WebRequest -Uri "https://ffmpeg.org/releases/ffmpeg-$FFmpegVersion.tar.bz2" -OutFile "ffmpeg-$FFmpegVersion.tar.bz2"
    tar -xjf "ffmpeg-$FFmpegVersion.tar.bz2"
}

# Configure and build
Push-Location $FFmpegDir

# Clean previous builds
if (Test-Path Makefile) { & nmake distclean }

$commonFlags = @(
    '--toolchain=msvc',
    '--arch=x86_64',
    '--disable-everything',
    '--enable-protocol=file',
    '--enable-decoder=mp3,pcm_s16le',
    '--enable-encoder=pcm_s16le',
    '--enable-demuxer=mp3,wav',
    '--enable-muxer=wav,pcm_s16le',
    '--enable-filter=aresample',
    '--enable-small',
    '--disable-network',
    '--disable-autodetect',
    '--disable-doc',
    '--enable-static',
    '--disable-shared',
    '--disable-programs',
    '--enable-ffmpeg',
    '--disable-ffplay',
    '--disable-asm'
    '--disable-ffprobe'
)

# Configure
Write-Host "⚙️  Configuring FFmpeg..."
./configure @commonFlags --prefix="../$OutputDir/$Arch"

# Build
Write-Host "🏗️  Building FFmpeg..."
& nmake
& nmake install

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
