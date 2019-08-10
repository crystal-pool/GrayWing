#!/usr/bin/env pwsh

<#
.Synopsis
(Linux only) GrayWing Query Service installer.

.Description
Installs/uninstalls the graywing-qs service under systemd.service framework.

.Example
./ServiceInstaller.ps1 -i

.Example
./ServiceInstaller.ps1 -u
#>

param(
    [Parameter(ParameterSetName = "Install", Mandatory = $true)]
    [switch]
    $Install,

    [Parameter(ParameterSetName = "Uninstall", Mandatory = $true)]
    [switch]
    $Uninstall,

    [Parameter(ParameterSetName = "Install")]
    [Parameter(ParameterSetName = "Uninstall")]
    [string]
    $TargetDir = "/etc/systemd/system/",

    [Parameter(ParameterSetName = "Install")]
    [Parameter(ParameterSetName = "Uninstall")]
    [switch]
    $Force
)

$ErrorActionPreference = "Stop"

if (-not $Force -and -not $IsLinux) {
    throw [System.PlatformNotSupportedException]"The script is only supported on Linux OS."
}

$SERVICE_NAME = "graywing-qs.service"

function checkLastExitCode() {
    if ($LASTEXITCODE) {
        throw [System.Exception]"Command exit code indicates failure: $LASTEXITCODE."
    }
}

function findAssetPath([string]$ScriptName) {
    $path = Resolve-Path @("$PSScriptRoot/$ScriptName", "./$ScriptName") -ErrorAction SilentlyContinue
    if ($path) {
        return $path[0].Path
    }
    throw [System.IO.FileNotFoundException]"Cannot locate $ScriptName script."
}

$serviceTarget = Join-Path $TargetDir $SERVICE_NAME

if ($Install) {
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Warning "``pwsh`` is not available in your PATH. Service script might be unable to start."
    }
    $updateRepoPath = findAssetPath "UpdateRepo.ps1"
    $runServerPath = findAssetPath "RunServer.ps1"
    Write-Host "Repo updater: $updateRepoPath"
    Write-Host "Service entrypoint: $runServerPath"
    $serviceContent = Get-Content (findAssetPath $SERVICE_NAME)
    Write-Host
    $serviceContent = $serviceContent.`
        Replace("`$GRAY_WING_UPDATE_REPO_PATH", $updateRepoPath).`
        Replace("`$GRAY_WING_RUN_SERVER_PATH", $runServerPath)
    $serviceContent > $serviceTarget
    if ($IsLinux) {
        chmod 664 $serviceTarget
        checkLastExitCode
    }
    Write-Host "Installed: $serviceTarget"
    if ($IsLinux) {
        systemctl enable $SERVICE_NAME
        checkLastExitCode
        Write-Host "Enabled: $serviceTarget"
    }
    Write-Host "You may start the service manually now."
    Write-Host "Use " -NoNewline
    Write-Host "systemctl [start|stop|restart] $SERVICE_NAME" -NoNewline -ForegroundColor Green
    Write-Host " to operate the service."
}
elseif ($Uninstall) {
    systemctl stop $SERVICE_NAME
    systemctl disable $SERVICE_NAME
    Remove-Item "$serviceTarget"
    systemctl daemon-reload
    systemctl reset-failed $SERVICE_NAME
    Write-Host "Uninstallation finished."
}
