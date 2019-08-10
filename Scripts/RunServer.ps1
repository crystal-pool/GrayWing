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

$SERVICE_USER_PROFILE = "/tmp/graywing-profile/"

$RepoRoot = Resolve-Path "$PSScriptRoot/.."
$ServerRoot = Resolve-Path "$RepoRoot/GrayWing"

Write-Host "RepoRoot: $RepoRoot"
Write-Host "ServerRoot: $RepoRoot"
Write-Host "UserName: $([System.Environment]::UserName)"
cd $ServerRoot

# We should have already created logdir upon installation (with root privilege).
# We are just ensuring these folders are accessible.
New-Item $LogPath/.. -ItemType Directory -Force | Out-Null
New-Item $ErrLogPath/.. -ItemType Directory -Force | Out-Null

if ($HOME -eq "/" -or -not (Resolve-Path $HOME -ErrorAction SilentlyContinue)) {
    # dotnet need a home.
    $UserProfile = New-Item $SERVICE_USER_PROFILE -ItemType Directory -Force
    Write-Host "DOTNET_CLI_HOME: $UserProfile"
    $env:DOTNET_CLI_HOME = $UserProfile
}

# dotnet dev-certs https
# checkLastExitCode

$Correlation = (New-Guid).ToString("N")
Write-Host "Start server process. Correlation: $Correlation"

$Timestamp = Get-Date -Format o
"[$Correlation] | START | $Timestamp" >> $LogPath
"[$Correlation] | START | $Timestamp" >> $ErrLogPath
try {
    dotnet run -c:Release --launch-profile:Production 1>> $LogPath 2>> $ErrLogPath
}
finally {
    # We may received SIGINT now; place code in finally block.
    $Timestamp = Get-Date -Format o
    "[$Correlation] | END | $Timestamp | $LASTEXITCODE" >> $LogPath
    "[$Correlation] | END | $Timestamp | $LASTEXITCODE" >> $ErrLogPath
    checkLastExitCode
}
