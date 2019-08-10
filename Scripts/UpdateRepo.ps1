#!/usr/bin/env pwsh

<#
.Synopsis
GrayWing Query Service repository update utility.

.Description
Updates GrayWing repository, restarting the running service if needed.
This script can also install/uninstall cron jobs for automatic repository update checking.

.Parameter RestartService
Whether to restart graywing-qs service, if there are updates in the repository and code needs re-building.

.Parameter InstallCron
Install cron auto update job.

.Parameter UninstallCron
Uninstall cron auto update job.

.Outputs
System.Boolean. Whether there are updates applied to the local repository.
#>

param(
    [Parameter(ParameterSetName = "Execute")]
    [switch]
    $RestartService,

    [Parameter(ParameterSetName = "InstallCron", Mandatory = $true)]
    [switch]
    $InstallCron,

    [Parameter(ParameterSetName = "UninstallCron", Mandatory = $true)]
    [switch]
    $UninstallCron,

    [Parameter(ParameterSetName = "InstallCron")]
    [string]
    $CronLogPath = "/var/log/crystalpool/graywing-qs/updateRepo.log"
)

$MASTER_BRANCH = "master"
$RepoRoot = Resolve-Path "$PSScriptRoot/.."
$ClientRoot = Resolve-Path "$RepoRoot/graywing-client"
$ServerRoot = Resolve-Path "$RepoRoot/GrayWing"
$ServiceUnitName = "graywing-qs.service"
$SERVICE_USER = "crystalpool"
$SERVICE_USER_PROFILE = "/tmp/graywing-profile/"

trap {
    Write-Error $_
    Write-Host $_.ScriptStackTrace
    Exit 1
}

function checkLastExitCode() {
    if ($LASTEXITCODE) {
        throw [System.Exception]"Command exit code indicates failure: $LASTEXITCODE."
    }
}

function buildServer() {
    Write-Host "Build server app"
    cd $ServerRoot
    dotnet build -c:Release
    checkLastExitCode
}

function buildClient() {
    Write-Host "Build graywing-client"
    cd $ClientRoot
    npm install
    checkLastExitCode
    npm run build:prod
    checkLastExitCode
}

function validateRepoRoot() {
    Write-Host "Repository root: $RepoRoot"
    $GitDir = git rev-parse --git-dir
    checkLastExitCode
    Write-Host "Git dir: $GitDir"
    $GitRepoDir = Resolve-Path "$GitDir/.."
    if ($RepoRoot.Path -ne $GitRepoDir.Path) {
        throw [Exception]"Git repository root validation failure. Make sure Daemon.ps1 is in the correct location."
    }
}

function getCurrentBranchName() {
    $BranchList = git branch --no-color | sls ^\*
    checkLastExitCode
    if ($BranchList[0]) {
        return $BranchList[0].Line.Substring(1).Trim()
    }
}

function fetchRemoteUpdate() {
    $Correlation = (New-Guid).ToString("N")
    cd $RepoRoot
    if ((getCurrentBranchName) -ne $MASTER_BRANCH) {
        throw [Exception]"The repository is not on the $MASTER_BRANCH branch."
    }
    git fetch --prune
    checkLastExitCode
    $LocalHead = git rev-parse "@"
    checkLastExitCode
    $RemoteHead = git rev-parse "@{u}"
    checkLastExitCode
    if ($LocalHead -ne $RemoteHead) {
        Write-Host "[$Correlation][$(Get-Date -Format o)] Need to update local repository."
        Write-Host "[$Correlation] Local -> Remote: $LocalHead -> $RemoteHead"
        $needStartService = $false
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            if ($RestartService) {
                [string]$status = systemctl is-active $ServiceUnitName
                $status = $status.Trim()
                if ($status -eq "active") {
                    Write-Host "[$Correlation] Stop $ServiceUnitName"
                    systemctl stop $ServiceUnitName
                    checkLastExitCode
                    $needStartService = $true
                }
            }
            git reset --hard $RemoteHead
            checkLastExitCode
            buildClient
            buildServer
        }
        finally {
            Write-Host "[$Correlation] Time elapsed: $($sw.Elapsed)." 
            if ($needStartService) {
                Write-Host "[$Correlation] Start $ServiceUnitName"
                systemctl start $ServiceUnitName
                checkLastExitCode
            }
        }

        return $true
    }
    return $false
}

switch ($PSCmdlet.ParameterSetName) {
    "Execute" {
        if ($HOME -eq "/" -or -not (Resolve-Path $HOME -ErrorAction SilentlyContinue)) {
            # dotnet need a home.
            $UserProfile = New-Item $SERVICE_USER_PROFILE -ItemType Directory -Force
            Write-Host "DOTNET_CLI_HOME: $UserProfile"
            $env:DOTNET_CLI_HOME = $UserProfile
        }
        fetchRemoteUpdate
    }
    "InstallCron" {
        if ($InstallCron) {
            $ScriptPath = Resolve-Path $MyInvocation.InvocationName
            $Minutes = "$(Get-Random -Min:3 -Max:20),$(Get-Random -Min:23 -Max:40),$(Get-Random -Min:43 -Max:60)"
            $cronLine = @"
# Generated by graywing-qs/UpdateRepo.ps1 [BEGIN] DO NOT MODIFY THIS BLOCK MANUALLY
$Minutes * * * * "$ScriptPath" -RestartService &>> "$CronLogPath"
# Generated by graywing-qs/UpdateRepo.ps1 [END] DO NOT MODIFY THIS BLOCK MANUALLY
"@
            @(crontab -u $SERVICE_USER -l; $cronLine) | crontab -u $SERVICE_USER -
            checkLastExitCode
            Write-Host "Installed cron jobs for account $SERVICE_USER at (minute): $Minutes"
        }
    }
    "UninstallCron" {
        if ($UninstallCron) {
            $inRemovalBlock = $false
            $removedBlock = $false
            $crontab = crontab -u $SERVICE_USER -l
            checkLastExitCode
            if (-not $crontab) {
                Write-Host "crontab is empty."
                return
            }
            $crontab = $crontab | ? {
                if ($_ -match "^#.* by graywing-qs/UpdateRepo.ps1\s*\[Begin\]") {
                    $inRemovalBlock = $true
                    $removedBlock = $true
                    $false
                }
                elseif ($_ -match "^#.* by graywing-qs/UpdateRepo.ps1\s*\[End\]") {
                    $inRemovalBlock = $false
                    $false
                }
                else {
                    -not $inRemovalBlock 
                } 
            }
            if ($crontab -and $crontab[-1]) {
                # Add empty line at the end of crontab
                $crontab = @($crontab, "")
            }
            if ($inRemovalBlock) {
                throw [System.FormatException]"Cannot find end marker for corn job. Please check the output of ``crontab -l`` manually"
            }
            $crontab | crontab -u $SERVICE_USER -
            checkLastExitCode
            if ($removedBlock) {
                Write-Host "Removed cron jobs on account $SERVICE_USER."
                return $true
            }
            else {
                Write-Host "Cron jobs not found on account $SERVICE_USER."
                return $false
            }
        }
    }
}
