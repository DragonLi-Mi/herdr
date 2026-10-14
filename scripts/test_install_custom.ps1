#Requires -Version 7.0

param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$archive = (Resolve-Path -LiteralPath $ArchivePath).Path
$installer = Join-Path $PSScriptRoot "install-custom.ps1"
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("herdr-install-test-" + [guid]::NewGuid())
$installRoot = Join-Path $testRoot "custom install"
$originalUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$originalProcessPath = $env:Path

function Invoke-Installer {
    param([string]$Script, [string[]]$Arguments, [bool]$ShouldSucceed = $true)
    $output = & (Join-Path $PSHOME "pwsh.exe") -NoProfile -File $Script @Arguments 2>&1
    if (($LASTEXITCODE -eq 0) -ne $ShouldSucceed) {
        throw "Unexpected installer exit code $LASTEXITCODE`: $output"
    }
}

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    Invoke-Installer $installer @("-ArchivePath", $archive, "-InstallRoot", $installRoot)
    $launcher = Join-Path $installRoot "bin\herdr.cmd"
    $version = & $launcher --version
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '^herdr \d+\.\d+\.\d+-custom\.') {
        throw "Installed launcher did not run the custom version: $version"
    }
    $launcherBefore = Get-Content -LiteralPath $launcher -Raw
    $updater = Join-Path $installRoot "bin\herdr-custom-update.ps1"
    Invoke-Installer $updater @("-ArchivePath", $archive)
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $bin = Join-Path $installRoot "bin"
    if (($userPath -split ";")[0] -ne $bin -or @($userPath -split ";" | Where-Object { $_ -eq $bin }).Count -ne 1) {
        throw "Reinstallation did not preserve the custom root and one leading PATH entry"
    }

    $incomplete = Join-Path $testRoot "incomplete.zip"
    Set-Content -LiteralPath (Join-Path $testRoot "incomplete.txt") -Value "missing runtime"
    Compress-Archive -LiteralPath (Join-Path $testRoot "incomplete.txt") -DestinationPath $incomplete
    Invoke-Installer $installer @("-ArchivePath", $incomplete, "-InstallRoot", $installRoot) $false

    $changed = Join-Path $testRoot "changed.zip"
    Copy-Item -LiteralPath $archive -Destination $changed
    Compress-Archive -LiteralPath (Join-Path $testRoot "incomplete.txt") -DestinationPath $changed -Update
    Invoke-Installer $installer @("-ArchivePath", $changed, "-InstallRoot", $installRoot) $false
    if ((Get-Content -LiteralPath $launcher -Raw) -ne $launcherBefore -or
        [Environment]::GetEnvironmentVariable("Path", "User") -ne $userPath) {
        throw "Rejected package changed the active installation"
    }
    Write-Host "Custom installer integration tests passed"
} finally {
    [Environment]::SetEnvironmentVariable("Path", $originalUserPath, "User")
    $env:Path = $originalProcessPath
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
