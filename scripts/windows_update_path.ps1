param(
  [string]$MsysRoot = "C:\msys64",
  [switch]$AllUsers  # add to Machine PATH instead of User PATH
)

function Normalize-PathList {
  param([string]$pathValue)
  $pathValue -split ";" |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne "" } |
    Select-Object -Unique
}

# Sanity checks
$usrBin   = Join-Path $MsysRoot "usr\bin"
$mingwBin = Join-Path $MsysRoot "mingw64\bin"

if (-not (Test-Path (Join-Path $usrBin "bash.exe"))) {
  Write-Warning "bash.exe not found at $usrBin. Is MSYS2 installed in $MsysRoot ?"
}

$targetScope = if ($AllUsers) { "Machine" } else { "User" }
$currentPath = [Environment]::GetEnvironmentVariable("Path", $targetScope)

$need = @($usrBin, $mingwBin)
$normalized = Normalize-PathList -pathValue $currentPath

foreach ($p in $need) {
  if (-not ($normalized | Where-Object { $_ -ieq $p })) {
    $normalized += $p
    Write-Host "Adding $p to $targetScope PATH"
  } else {
    Write-Host "Already present: $p"
  }
}

$newPath = ($normalized -join ";")
[Environment]::SetEnvironmentVariable("Path", $newPath, $targetScope)

# Refresh current session PATH (so you don't have to open a new shell)
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath    = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path    = "$machinePath;$userPath"

Write-Host "`n✅ Done. Current session PATH updated."
Write-Host "Check:  bash --version"
