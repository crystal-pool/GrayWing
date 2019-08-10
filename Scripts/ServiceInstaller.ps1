#!/usr/bin/env pwsh

<#
.Synopsis
(Linux only) GrayWing Query Service installer.

.Description
Installs/uninstalls the graywing-qs service under systemd.service framework.

.Parameter Install
Install the service, doing necessary configuration (such as creating service account).

.Parameter ChangeOwner
Whether to change the owner of the whole repository directory to graywing:graywing.

.Parameter Uninstall
Uninstall the service.

.Example
./ServiceInstaller.ps1 -i -co

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
    [Alias("CO")]
    [switch]
    $ChangeOwner,

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
$SERVICE_USER = "crystalpool"
$SERVICE_LOG_ROOT = "/var/log/crystalpool/graywing-qs"

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
    if ($IsLinux) {
        id -u $SERVICE_USER | Out-Null
        $userExists = -not $LASTEXITCODE
        id -g $SERVICE_USER | Out-Null
        $groupExists = -not $LASTEXITCODE
        if ($userExists -and $groupExists) {
            Write-Host "Service account exists: ${SERVICE_USER}:$SERVICE_USER"
        }
        elseif (-not $userExists -and -not $groupExists) {
            Write-Host "Create service account: ${SERVICE_USER}:$SERVICE_USER"
            useradd --system $SERVICE_USER
            checkLastExitCode
        }
        else {
            Write-Host "Is there already a real user with the same user name?"
            throw [System.InvalidOperationException]"Inconsistent account existence status. UserExists: $userExists, GroupExists: $groupExists."
        }
        if ($ChangeOwner) {
            $repoRoot = Resolve-Path "$PSScriptRoot/.."
            Write-Host "chown -R on $repoRoot"
            chown -R "${SERVICE_USER}:$SERVICE_USER" $repoRoot
            checkLastExitCode
        }
    }
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
        Write-Host "Make sure working folders are accessible."
        New-Item $SERVICE_LOG_ROOT -ItemType Directory -Force | Out-Null
        chown -R "${SERVICE_USER}:$SERVICE_USER" $SERVICE_LOG_ROOT
        chmod -R 664 $SERVICE_LOG_ROOT
    }
    Write-Host "You may start the service manually now."
    Write-Host "Use " -NoNewline
    Write-Host "systemctl [start|stop|restart] $SERVICE_NAME" -NoNewline -ForegroundColor DarkCyan
    Write-Host " to operate the service."
}
elseif ($Uninstall) {
    systemctl stop $SERVICE_NAME
    systemctl disable $SERVICE_NAME
    Remove-Item "$serviceTarget"
    systemctl daemon-reload
    systemctl reset-failed $SERVICE_NAME
    Write-Host "Uninstallation finished."
    Write-Host "Note: You may delete " -NoNewline
    Write-Host "${SERVICE_USER}:$SERVICE_USER" -NoNewline -ForegroundColor DarkCyan
    Write-Host " acconut manually, if necessary."
}
