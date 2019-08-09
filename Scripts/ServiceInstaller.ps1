#!/usr/bin/env pwsh

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
    $TargetDir = "/etc/init.d",

    [Parameter(ParameterSetName = "Install")]
    [Parameter(ParameterSetName = "Uninstall")]
    [switch]
    $Force
)

if (-not $Force -and -not $IsLinux) {
    throw [System.PlatformNotSupportedException]"The script is only supported on Linux OS."
}

function findPowerShellPath() {
    $path = Resolve-Path @("$PSHOME/pwsh", "$PSHOME/pwsh.exe", "$PSHOME/pwsh-preview", "$PSHOME/pwsh-preview.exe") -ErrorAction SilentlyContinue
    if ($path) {
        return $path[0].Path
    }
    throw [System.IO.FileNotFoundException]"Cannot locate powershell executable."
}

function findDaemonPath() {
    $path = Resolve-Path @("$PSScriptRoot/Daemon.ps1", "./Daemon.ps1") -ErrorAction SilentlyContinue
    if ($path) {
        return $path[0].Path
    }
    throw [System.IO.FileNotFoundException]"Cannot locate daemon script."
}

if ($Install) {
    $PwshPath = findPowerShellPath
    Write-Host "PowerShell path: $PwshPath"
    $daemonPath = findDaemonPath
    Write-Host "Daemon path: $daemonPath"
    $initScript = Get-Content "./init.d.sh"
    Write-Host
    $initScript = $initScript.Replace("`$PWSH_PATH", $PwshPath).Replace("`$GRAY_WING_DAEMON_PATH", $daemonPath)
    $initScript > "$TargetDir/graywing-qs"
    if ($IsLinux) {
        chmod a+x "$TargetDir/graywing-qs"
    }
    Write-Host "Installation finished."
    Write-Host "Use service graywing-qs [start|stop|restart] to operate the service."
} elseif ($Uninstall) {
    Remove-Item "$TargetDir/graywing-qs"
    Write-Host "Uninstallation finished."
}
