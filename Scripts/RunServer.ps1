#!/usr/bin/env pwsh

<#
.Synopsis
(Linux only) GrayWing Query Service entrypoint.
#>

trap {
    Write-Error $_
    Write-Host $_.ScriptStackTrace
    Exit 1
}

function checkLastExitCode() {
    if ($LASTEXITCODE) {
        Exit $LASTEXITCODE
    }
}

$RepoRoot = Resolve-Path "$PSScriptRoot/.."
$ServerRoot = Resolve-Path "$RepoRoot/GrayWing"

Write-Host "RepoRoot: $RepoRoot"
Write-Host "ServerRoot: $RepoRoot"
cd $ServerRoot

dotnet build -c:Release
checkLastExitCode
dotnet run -c:Release
checkLastExitCode
