#Requires -Version 7.0

param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePath,

    [string]$InstallRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InstallRoot) {
    $InstallRoot = if ((Split-Path $PSCommandPath -Leaf) -eq "herdr-custom-update.ps1") {
        Split-Path $PSScriptRoot
    } else {
        Join-Path $HOME ".herdr-custom"
    }
}

$archive = (Resolve-Path -LiteralPath $ArchivePath).Path
$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
$root = [IO.Path]::GetFullPath($InstallRoot)
$stage = Join-Path ([IO.Path]::GetTempPath()) ("herdr-custom-install-" + [guid]::NewGuid())

try {
    Expand-Archive -LiteralPath $archive -DestinationPath $stage
    $exe = Join-Path $stage "herdr.exe"
    foreach ($relative in @(
        "herdr.exe",
        "conpty\herdr-conpty.json",
        "conpty\conpty.dll",
        "conpty\x64\OpenConsole.exe",
        "conpty\arm64\OpenConsole.exe"
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $stage $relative) -PathType Leaf)) {
            throw "Incomplete custom package: missing $relative"
        }
    }
    $versionOutput = & $exe --version
    if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch '^herdr (\d+\.\d+\.\d+-custom\.[0-9A-Za-z.-]+)$') {
        throw "Expected a custom Herdr build, got: $versionOutput"
    }
    $version = $Matches[1]
    $destination = Join-Path (Join-Path $root "releases") $version
    if (Test-Path -LiteralPath $destination) {
        $installedHash = Get-Content -LiteralPath (Join-Path $destination "archive.sha256") -Raw
        if ($installedHash.Trim() -ne $archiveHash) {
            throw "$version is already installed with different contents; publish a new custom build ID"
        }
    } else {
        New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $stage "archive.sha256") -Value $archiveHash -Encoding ascii
        Move-Item -LiteralPath $stage -Destination $destination
    }

    $bin = Join-Path $root "bin"
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    $installedExe = Join-Path $destination "herdr.exe"
    Set-Content -LiteralPath (Join-Path $bin "herdr.cmd") -Encoding ascii -Value "@echo off`r`n`"$installedExe`" %*"
    $updateScript = Join-Path $bin "herdr-custom-update.ps1"
    if ([IO.Path]::GetFullPath($PSCommandPath) -ne [IO.Path]::GetFullPath($updateScript)) {
        Copy-Item -LiteralPath $PSCommandPath -Destination $updateScript -Force
    }
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $remaining = @($userPath -split ";" | Where-Object { $_ -and $_.TrimEnd("\") -ine $bin.TrimEnd("\") })
    [Environment]::SetEnvironmentVariable("Path", (@($bin) + $remaining -join ";"), "User")
    $env:Path = "$bin;$env:Path"
    & $installedExe --version
    if ($LASTEXITCODE -ne 0) {
        throw "Installed custom binary failed to start"
    }
    Write-Host "Installed in $destination"
    Write-Host "Open a new terminal to use the custom herdr command. Existing clients must reconnect."
    Write-Host "Running servers and configuration were not changed. Official installations are preserved."
} finally {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
