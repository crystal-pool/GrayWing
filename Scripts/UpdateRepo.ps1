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
    [Parameter(ParameterSetName = "Run")]
    [switch]
    $RestartService,

    [Parameter(ParameterSetName = "InstallCron", Mandatory = $true)]
    [switch]
    $InstallCron,

    [Parameter(ParameterSetName = "UninstallCron", Mandatory = $true)]
    [switch]
    $UninstallCron
)

$MASTER_BRANCH = "master"
$RepoRoot = Resolve-Path "$PSScriptRoot/.."
$ClientRoot = Resolve-Path "$RepoRoot/graywing-client"
$ServerRoot = Resolve-Path "$RepoRoot/GrayWing"
$ServiceUnitName = "graywing-qs.service"

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

function fetchRemoteUpdate() {
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
        Write-Host "Need to update local repository."
        $needStartService = $false
        try {
            if ($RestartService) {
                [string]$status = systemctl is-active $ServiceUnitName
                $status = $status.Trim()
                if ($status -eq "active") {
                    Write-Host "Stop $ServiceUnitName"
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
            if ($needStartService) {
                Write-Host "Start $ServiceUnitName"
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
        fetchRemoteUpdate
    }
    "Install" {
        if ($InstallCron) {
            $ScriptPath = Resolve-Path $MyInvocation.InvocationName
            $Minutes = "$(Get-Random -Min:3 -Max:20),$(Get-Random -Min:23 -Max:40),$(Get-Random -Min:43 -Max:60)"
            $cronLine = @"
# Generated by graywing-qs/UpdateRepo.ps1 [BEGIN] DO NOT MODIFY THIS BLOCK MANUALLY
$Minutes * * * * "$ScriptPath" -RestartService
# Generated by graywing-qs/UpdateRepo.ps1 [END] DO NOT MODIFY THIS BLOCK MANUALLY
"@
            @(crontab -l; $cronLine) | crontab -
            checkLastExitCode
            Write-Host "Installed cron jobs at (minute): $Minutes"
        }
    }
    "Uninstall" {
        if ($UninstallCron) {
            $inRemovalBlock = $false
            $removedBlock = $false
            $crontab = crontab -l
            checkLastExitCode
            if (-not $crontab) {
                Write-Host "crontab is empty."
                return
            }
            $crontab = $crontab | % {
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
            if ($crontab[-1]) {
                # Add empty line at the end of crontab
                $crontab = @($crontab, "")
            }
            if ($inRemovalBlock) {
                throw [System.FormatException]"Cannot find end marker for corn job. Please check the output of ``crontab -l`` manually"
            }
            $crontab | crontab -
            checkLastExitCode
            if ($removedBlock) {
                Write-Host "Removed cron jobs."
                return $true
            }
            else {
                Write-Host "Cron jobs not found."
                return $false
            }
        }
    }
}
