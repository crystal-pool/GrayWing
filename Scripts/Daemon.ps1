#!/usr/bin/env pwsh

$MASTER_BRANCH = "master"
$RepoRoot = Resolve-Path "$PSScriptRoot/.."
$ClientRoot = Resolve-Path "$RepoRoot/graywing-client"
$ServerRoot = Resolve-Path "$RepoRoot/GrayWing"
$PidFile = "/var/run/crystalpool/graywing-qs-dotnet.pid"
$LogDir = "/var/log/crystalpool"
$IncomingLogDir = "/var/log/crystalpool/graywing-qs-dotnet-ic"
$LogFile = "graywing-qs.log"
$ErrLogFile = "graywing-qs.err.log"

function Write-Log([parameter(ValueFromPipeline)]$text) {
    try {
        $Timestamp = Get-Date -Format o
        Write-Host "[$Timestamp]$text"
        "[$Timestamp]$text" >> "$LogDir/$LogFile"
    }
    catch {
        Write-Error $_
    }
}

trap {
    Write-Error $_
    Write-Log "[FATAL]$_\n$($_.ScriptStackTrace)"
    Exit 1
}

function checkLastExitCode() {
    if ($LASTEXITCODE) {
        throw [System.Exception]"Command exit code indicates failure: $LASTEXITCODE."
    }
}

function getCurrentBranchName() {
    $BranchList = git branch --no-color | sls ^\*
    checkLastExitCode
    if ($BranchList[0]) {
        return $BranchList[0].Line.Substring(1).Trim()
    }
}

function buildClient() {
    cd $ClientRoot
    npm install | Write-Log
    checkLastExitCode
    npm run build:prod | Write-Log
    checkLastExitCode
}

function startServer() {
    cd $ServerRoot
    dotnet build -c:Release | Write-Log
    checkLastExitCode
    $CorrelationId = (New-Guid).ToString("N")
    New-Item $IncomingLogDir -ItemType Directory -Force | Out-Null
    New-Item "$PidFile/.." -ItemType Directory -Force | Out-Null
    "[$CorrelationId] Starting dotnet in $PWD." >> "$LogDir/$LogFile"
    $Process = Start-Process -FilePath dotnet -ArgumentList @("run", "-c:Release") `
        -RedirectStandardOutput "$IncomingLogDir/$CorrelationId.out" -RedirectStandardError "$IncomingLogDir/$CorrelationId.err" `
        -PassThru
    $ServerPid = $Process.Id
    "$ServerPid" > "$IncomingLogDir/$CorrelationId.pid"
    "$ServerPid $CorrelationId" >> $PidFile
    "[$CorrelationId][$ServerPid][$Timestamp] Started dotnet on PID $($ServerPid)" >> "$LogDir/$LogFile"
    Write-Log "[$CorrelationId] Started server on PID $($ServerPid)"
    # We shouldn't dispose $Process, or stdout won't be able to get written.
    return $ServerPid
}

function flushServerLogs([string]$CorrelationId) {
    $ServerPid = Get-Content "$IncomingLogDir/$CorrelationId.pid" -ErrorAction SilentlyContinue
    $LinePrefix = "[$CorrelationId][$ServerPid] "
    Get-Content "$IncomingLogDir/$CorrelationId.out" -ErrorAction SilentlyContinue | % { $LinePrefix + $_ } >> "$LogDir/$LogFile"
    Get-Content "$IncomingLogDir/$CorrelationId.err" -ErrorAction SilentlyContinue | % { $LinePrefix + $_ } >> "$LogDir/$ErrLogFile"
    Remove-Item @(
        "$IncomingLogDir/$CorrelationId.pid",
        "$IncomingLogDir/$CorrelationId.out", 
        "$IncomingLogDir/$CorrelationId.err"
    ) -ErrorAction SilentlyContinue
}

function isServerAlive([int]$Id) {
    try {
        $Process = Get-Process -Id $Id -ErrorAction SilentlyContinue
        if (-not $Process) {
            Write-Log "Process $ServerPid does not exist."
            return $false
        }
        if ($Process.HasExited) {
            Write-Log "Process $ServerPid has exited with code $($Process.ExitCode) on $($Process.ExitTime)."
        }
        return -not $Process.HasExited
    }
    finally {
        if ($Process) {
            $Process.Dispose()
        }
    }
}

function stopServer() {
    # Terminate running processes
    if (-not (Test-Path $PidFile -PathType Leaf)) {
        Write-Log "PID file does not exist."
        return $false
    }
    $PidFileContent = Get-Content $PidFile | % {
        $fields = $_.Split()
        return @{Pid = $fields[0]; Correlation = $fields[1] }
    }
    $RunningProcesses = Get-Process -Id $PidFileContent.Pid -ErrorAction SilentlyContinue
    try {
        Remove-Item $PidFile
        if ($RunningProcesses) {
            $ids = $RunningProcesses.Id;
            Write-Log "Stop process(es): $ids."
            # Escape pwsh alias
            /usr/bin/env kill -s INT $ids | Write-Log
            # Allow for 10 sec. for each process
            $RunningProcesses | % { $_.WaitForExit(10000) }
            Stop-Process $ids
        }
        $PidFileContent | % { flushServerLogs -CorrelationId $_.Correlation }
        return -not -not $RunningProcesses
    }
    finally {
        if ($RunningProcesses) {
            $RunningProcesses.Dispose()
        }
    }
}

function fetchRemoteUpdate() {
    cd $RepoRoot
    if ((getCurrentBranchName) -ne $MASTER_BRANCH) {
        throw [Exception]"The repository is not on the $MASTER_BRANCH branch."
    }
    git fetch --prune | Write-Log
    checkLastExitCode
    $LocalHead = git rev-parse "@"
    $RemoteHead = git rev-parse "@{u}"
    if ($LocalHead -ne $RemoteHead) {
        Write-Log "Need to update local repository."
        stopServer | Out-Null
        git reset --hard $RemoteHead
        checkLastExitCode
        buildClient
        return $true
    }
    return $false
}

function validateRepoRoot() {
    Write-Log "Repository root: $RepoRoot"
    $GitDir = git rev-parse --git-dir
    checkLastExitCode
    Write-Log "Git dir: $GitDir"
    $GitRepoDir = Resolve-Path "$GitDir/.."
    if ($RepoRoot.Path -ne $GitRepoDir.Path) {
        throw [Exception]"Git repository root validation failure. Make sure Daemon.ps1 is in the correct location."
    }
}

New-Item $LogDir -ItemType Directory -Force | Out-Null

validateRepoRoot
try {
    $LastIsServerAliveCount = 0
    $LastIsServerAlive = $true
    $ServerPid = 0
    while ($true) {
        # Until Ctrl+C
        $StartTick = [System.Environment]::TickCount
        $HasUpdate = fetchRemoteUpdate
        if (-not $ServerPid -or $HasUpdate) {
            Write-Log "Starting server process."
            $ServerPid = startServer
        }
        Start-Sleep 10
        $CurrentTick = [System.Environment]::TickCount
        while ($CurrentTick -lt $StartTick -or $CurrentTick - $StartTick -le 3600000) {
            $isAlive = isServerAlive -Id $ServerPid
            if (-not $isAlive) {
                if ($LastIsServerAliveCount -ge 10) {
                    throw [System.Exception]"Server fails to start for consecutive $LastIsServerAliveCount times."
                }
                Write-Log "Restarting server process."
                stopServer | Out-Null
                $ServerPid = startServer
                Start-Sleep 5
            }
            elseif ($LastIsServerAliveCount -le 10) {
                Start-Sleep 5
            }
            else {
                Start-Sleep (60 + (Get-Random 60))
            }
            if ($LastIsServerAlive -eq $isAlive) {
                $LastIsServerAliveCount++
            }
            else {
                $LastIsServerAlive = $isAlive
            }
            $CurrentTick = [System.Environment]::TickCount
        }
    }
}
finally {
    Write-Log "Finally stopping server."
    stopServer | Out-Null
}
