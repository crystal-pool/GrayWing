#!/usr/bin/env pwsh
#requires -Version 7.3

<#
.Synopsis
(Linux only) CrystalPool Query Service (GrayWing) repository update utility.

.Description
Updates GrayWing repository, restarting the running service if needed.
This script can also install/uninstall cron jobs for automatic repository update checking.
This script should be run as the service user (e.g. crystalpool), not as root.

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

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$MASTER_BRANCH = "master"
$SERVICE_NAME = "graywing-qs.service"

$RepoRoot = Resolve-Path "$PSScriptRoot/.."
$ClientRoot = Resolve-Path "$RepoRoot/graywing-client"
$ServerRoot = Resolve-Path "$RepoRoot/GrayWing"
$Correlation = (New-Guid).ToString("N")

trap {
    Write-Error $_
    Write-Host $_.ScriptStackTrace
    Exit 1
}

if (-not $IsLinux) {
    throw [System.PlatformNotSupportedException]"The script is only supported on Linux OS."
}

Write-Host "Running as user=$(id -un) group=$(id -gn)"

if ((id -u) -eq 0) {
    throw [System.InvalidOperationException]"The script should not be run as root. Run as the service user instead."
}

function Write-Log([object]$Item) {
    $Item | % { Write-Host "[$Correlation][$(Get-Date -Format o)] $_" }
}

function getCrontab() {
    $PSNativeCommandUseErrorActionPreference = $false
    $output = crontab -l 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        # Filter out ErrorRecord objects (stderr) and return only stdout strings
        return @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
    }
    $stderrText = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() }) -join "`n"
    if ($stderrText -match "no crontab for") {
        return @()
    }
    throw "crontab -l failed with exit code ${exitCode}: $stderrText"
}

function buildServer() {
    Write-Log "Build server app"
    cd $ServerRoot
    dotnet build -c:Release
}

function buildClient() {
    Write-Log "Build graywing-client"
    cd $ClientRoot
    yarn
    # --openssl-legacy-provider: compat on Node 16+ to suppress ERR_OSSL_EVP_UNSUPPORTED
    NODE_OPTIONS=--openssl-legacy-provider yarn build:prod
}

function validateRepoRoot() {
    Write-Log "Repository root: $RepoRoot"
    cd $RepoRoot
    $GitDir = git rev-parse --git-dir
    Write-Log "Git dir: $GitDir"
    $GitRepoDir = Resolve-Path "$GitDir/.."
    if ($RepoRoot.Path -ne $GitRepoDir.Path) {
        throw [Exception]"Git repository root validation failure. Make sure UpdateRepo.ps1 is in the correct location."
    }
}

function getCurrentBranchName() {
    $BranchList = git branch --no-color | sls ^\*
    if ($BranchList[0]) {
        return $BranchList[0].Line.Substring(1).Trim()
    }
}

function fetchRemoteUpdate() {
    cd $RepoRoot
    if ((getCurrentBranchName) -ne $MASTER_BRANCH) {
        throw [Exception]"The repository is not on the $MASTER_BRANCH branch."
    }
    git fetch --prune
    $LocalHead = git rev-parse "@"
    $RemoteHead = git rev-parse "@{u}"
    if ($LocalHead -ne $RemoteHead) {
        Write-Log "Need to update local repository."
        Write-Log "Local -> Remote: $LocalHead -> $RemoteHead"
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            # We can safely change the files on Linux.
            git reset --hard $RemoteHead
            buildClient
            buildServer
            if ($RestartService) {
                # systemctl restart is allowed without sudo via polkit rules
                # installed by ServiceInstaller.ps1 (see 50-graywing-qs.rules).
                [string]$status = systemctl is-active $SERVICE_NAME
                if ($status.Trim() -eq "active") {
                    Write-Log "Restart $SERVICE_NAME"
                    systemctl restart $SERVICE_NAME
                }
            }
        }
        finally {
            Write-Log "Time elapsed: $($sw.Elapsed)." 
        }

        return $true
    }
    return $false
}


switch ($PSCmdlet.ParameterSetName) {
    "Execute" {
        validateRepoRoot
        fetchRemoteUpdate
    }
    "InstallCron" {
        if ($InstallCron) {
            $PSPath = @(
                (Resolve-Path $PSHOME/pwsh -ErrorAction SilentlyContinue),
                (Resolve-Path $PSHOME/pwsh-preview -ErrorAction SilentlyContinue),
                (Resolve-Path $PSHOME/pwsh.exe -ErrorAction SilentlyContinue),
                (Resolve-Path $PSHOME/pwsh-preview.exe -ErrorAction SilentlyContinue)
            ) | Select-Object -First 1
            if (-not $PSPath) {
                throw [System.InvalidOperationException]"Cannot determine the PowerShell path."
            }
            $ScriptPath = Resolve-Path $MyInvocation.InvocationName
            $BaseMinute = (Get-Date).Minute
            $Minutes = @(2, (20 + (Get-Random 5)), (40 + (Get-Random 5))) | % { ($BaseMinute + $_) % 60 }
            $Minutes = $Minutes -join ","
            $cronLine = @"
# Generated by graywing-qs/UpdateRepo.ps1 [BEGIN] DO NOT MODIFY THIS BLOCK MANUALLY
$Minutes * * * * "$PSPath" -Command "$ScriptPath" -RestartService *\>\> "$CronLogPath"
# Generated by graywing-qs/UpdateRepo.ps1 [END] DO NOT MODIFY THIS BLOCK MANUALLY
"@
            @((getCrontab); $cronLine) | crontab -
            Write-Host "Installed cron jobs at (minute): $Minutes"
        }
    }
    "UninstallCron" {
        if ($UninstallCron) {
            $inRemovalBlock = $false
            $removedBlock = $false
            $crontab = getCrontab
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
                throw [System.FormatException]"Cannot find end marker for cron job. Please check the output of ``crontab -l`` manually"
            }
            $crontab | crontab -
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
