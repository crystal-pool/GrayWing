#!/usr/bin/env pwsh
#requires -Version 7.3

<#
.Synopsis
(Linux only, root) GrayWing Query Service (GrayWing) installer.

.Description
Installs/uninstalls the graywing-qs service under systemd.service framework.
You need to have root privilege to execute the script.

.Parameter Install
Install the service, doing necessary configuration (such as creating crystalpool:crystalpool service account).

.Parameter ChangeOwner
Whether to change the owner of the whole repository directory to crysstalpool:crystalpool.

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
    $SystemUnitDir = "/etc/systemd/system",

    [Parameter(ParameterSetName = "Install")]
    [Parameter(ParameterSetName = "Uninstall")]
    [string]
    $LogRotateConfigDir = "/etc/logrotate.d",

    [Parameter(ParameterSetName = "Install")]
    [Parameter(ParameterSetName = "Uninstall")]
    [string]
    $PolkitRulesDir = "/etc/polkit-1/rules.d",

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
$PSNativeCommandUseErrorActionPreference = $true

if (-not $Force) {
    if (-not $IsLinux) {
        throw [System.PlatformNotSupportedException]"The script is only supported on Linux OS."
    }
    if ((id -u) -ne 0) {
        Write-Warning "The script requires to run with root access. You may see errors below."
    }
}

$SERVICE_NAME = "graywing-qs.service"
$LOGROTATE_NAME = "graywing-qs.logrotate"
$POLKIT_RULES_NAME = "50-graywing-qs.rules"
$SERVICE_USER = "crystalpool"
$SERVICE_LOG_ROOT = "/var/log/crystalpool/graywing-qs"

function findAssetPath([string]$ScriptName) {
    $path = Resolve-Path @("$PSScriptRoot/$ScriptName", "./$ScriptName") -ErrorAction SilentlyContinue
    if ($path) {
        return $path[0].Path
    }
    throw [System.IO.FileNotFoundException]"Cannot locate $ScriptName script."
}

function promptReplace([string]$Path) {
    $Resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
    if ($Resolved) {
        if (-not $PSCmdlet.ShouldContinue("Replace `"$Resolved`".", "File already exists. Overwrite?")) {
            return $false
        }
    }
    return $true
}

$serviceTarget = Join-Path $SystemUnitDir $SERVICE_NAME
$logRotateTarget = Join-Path $LogRotateConfigDir $LOGROTATE_NAME
$polkitRulesTarget = Join-Path $PolkitRulesDir $POLKIT_RULES_NAME

if ($Install) {
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Warning "``pwsh`` is not available in your PATH. Service script might be unable to start."
    }
    $updateRepoPath = findAssetPath "UpdateRepo.ps1"
    $runServerPath = findAssetPath "RunServer.ps1"
    Write-Host "Repo updater: $updateRepoPath"
    Write-Host "Service entrypoint: $runServerPath"
    if ($IsLinux) {
        $userExists = & {
            $PSNativeCommandUseErrorActionPreference = $false
            id -u $SERVICE_USER | Out-Null
            -not $LASTEXITCODE
        }
        $groupExists = & {
            $PSNativeCommandUseErrorActionPreference = $false
            id -g $SERVICE_USER | Out-Null
            -not $LASTEXITCODE
        }
        if ($userExists -and $groupExists) {
            # ${} needed for adjacent :
            Write-Host "Service account exists: ${SERVICE_USER}:$SERVICE_USER"
        }
        elseif (-not $userExists -and -not $groupExists) {
            Write-Host "Create service account: ${SERVICE_USER}:$SERVICE_USER"
            useradd --system --create-home --shell /usr/sbin/nologin $SERVICE_USER
        }
        else {
            Write-Host "Is there already a real user with the same user name?"
            throw [System.InvalidOperationException]"Inconsistent account existence status. UserExists: $userExists, GroupExists: $groupExists."
        }
    }
    $serviceContent = Get-Content (findAssetPath $SERVICE_NAME)
    $serviceContent = $serviceContent.`
        Replace("`$GRAY_WING_UPDATE_REPO_PATH", $updateRepoPath).`
        Replace("`$GRAY_WING_RUN_SERVER_PATH", $runServerPath)
    if ($IsLinux) {
        [string]$status = & {
            $PSNativeCommandUseErrorActionPreference = $false
            systemctl is-active $SERVICE_NAME
        }
        if ($status.Trim() -eq "active") {
            systemctl stop $SERVICE_NAME
        }
    }
    if (-not (promptReplace $serviceTarget)) {
        return
    }
    $serviceContent > $serviceTarget
    if ($IsLinux) {
        chmod 664 $serviceTarget
    }
    Write-Host "Installed: $serviceTarget"
    if ($IsLinux) {
        systemctl daemon-reload
        systemctl enable $SERVICE_NAME
        Write-Host "Enabled: $serviceTarget"
    }
    Write-Host "Setup logrotate."
    $logRotateContent = Get-Content (findAssetPath $LOGROTATE_NAME)
    if (-not (promptReplace $logRotateTarget)) {
        return
    }
    $logRotateContent > $logRotateTarget
    Write-Host "Setup polkit rules."
    $polkitRulesContent = Get-Content (findAssetPath $POLKIT_RULES_NAME)
    if (-not (promptReplace $polkitRulesTarget)) {
        return
    }
    $polkitRulesContent > $polkitRulesTarget
    Write-Host "Installed: $polkitRulesTarget"
    if ($ChangeOwner) {
        $repoRoot = Resolve-Path "$PSScriptRoot/.."
        Write-Host "chown -R on $repoRoot"
        chown -R "${SERVICE_USER}:$SERVICE_USER" $repoRoot
    }
    if ($IsLinux) {
        Write-Host "Make sure working folders are accessible."
        New-Item $SERVICE_LOG_ROOT -ItemType Directory -Force | Out-Null
        chown -R "${SERVICE_USER}:$SERVICE_USER" $SERVICE_LOG_ROOT
        chmod 754 $SERVICE_LOG_ROOT
    }
    Write-Host
    Write-Host "All set. You may start the service manually now."
    Write-Host "Use " -NoNewline
    Write-Host "systemctl [start|stop|restart] $SERVICE_NAME" -NoNewline -ForegroundColor DarkCyan
    Write-Host " to operate the service."
}
elseif ($Uninstall) {
    systemctl stop $SERVICE_NAME
    systemctl disable $SERVICE_NAME
    Remove-Item $serviceTarget -Verbose -ErrorAction Continue
    Remove-Item $polkitRulesTarget -Verbose -ErrorAction Continue
    systemctl daemon-reload
    Write-Host "Uninstallation finished."
    Write-Host "Note: You may delete " -NoNewline
    Write-Host "${SERVICE_USER}:$SERVICE_USER" -NoNewline -ForegroundColor DarkCyan
    Write-Host " acconut manually, if necessary."
}
