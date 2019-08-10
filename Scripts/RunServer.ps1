#!/usr/bin/env pwsh

<#
.Synopsis
(Linux only) GrayWing Query Service entrypoint.
#>

param (
    [Parameter()]
    [string]
    $LogPath = "/var/log/crystalpool/graywing-qs/server.log",
    [Parameter()]
    [string]
    $ErrLogPath = "/var/log/crystalpool/graywing-qs/server.err.log"
)

trap {
    Write-Error $_
    Write-Host $_.ScriptStackTrace
    Exit 1
}

function checkLastExitCode() {
    if ($LASTEXITCODE) {
        Write-Error "Command exit code indicates failure: $LASTEXITCODE"
        Exit $LASTEXITCODE
    }
}

$RepoRoot = Resolve-Path "$PSScriptRoot/.."
$ServerRoot = Resolve-Path "$RepoRoot/GrayWing"

Write-Host "RepoRoot: $RepoRoot"
Write-Host "ServerRoot: $RepoRoot"
cd $ServerRoot

New-Item $LogPath/.. -ItemType Directory -Force | Out-Null
New-Item $ErrLogPath/.. -ItemType Directory -Force | Out-Null

dotnet run -c:Release 1>> $LogPath 2>> $ErrLogPath
checkLastExitCode
