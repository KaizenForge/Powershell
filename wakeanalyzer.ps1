#Requires -Version 7.x

<#
.SYNOPSIS
    Checks what caused the computer to wake up automatically in Windows 11
.DESCRIPTION
    This script analyzes system logs and power management settings to determine
    what triggered the last system wake event. Requires administrator privileges.
.NOTES
    Author: Tomasz Ziembiewicz | tomasz at ziembiewicz dot pl
    Version: 1.0
    Date: 2023-10-01
    Tested on: Windows 11 Pro, PowerShell 7.5.1
    Requires: PowerShell 7.0+, Administrator privileges
#>

param(
    [switch]$Detailed,
    [int]$LastDays = 3
)

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check for admin privileges and elevate if needed
if (-not (Test-Administrator)) {
    Write-Host "This script requires administrator privileges. Attempting to elevate..." -ForegroundColor Yellow
    
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }
    
    $arguments = "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`""
    if ($Detailed) { $arguments += " -Detailed" }
    if ($LastDays -ne 7) { $arguments += " -LastDays $LastDays" }
    
    try {
        Start-Process -FilePath "pwsh.exe" -ArgumentList $arguments -Verb RunAs -Wait
        exit 0
    }
    catch {
        Write-Error "Failed to elevate privileges: $($_.Exception.Message)"
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Red
        pause
        exit 1
    }
}

# Main script execution starts here
Clear-Host
Write-Host "Windows 11 Wake Reason Analyzer" -ForegroundColor Magenta
Write-Host "================================" -ForegroundColor Magenta
Write-Host "Running with administrator privileges..." -ForegroundColor Green
Write-Host "Analyzing wake reasons for the last $LastDays days..." -ForegroundColor White
Write-Host "Detailed mode: $Detailed" -ForegroundColor Gray

# ===========================================
# WAKE SOURCE ANALYSIS
# ===========================================
Write-Host "`n=== WAKE SOURCE ANALYSIS ===" -ForegroundColor Cyan

Write-Host "Executing: powercfg /lastwake" -ForegroundColor Gray
try {
    $wakeSourceCmd = "powercfg /lastwake"
    $wakeSource = Invoke-Expression $wakeSourceCmd 2>&1
    
    if ($wakeSource -and $wakeSource.Count -gt 0) {
        Write-Host "`nLast Wake Source:" -ForegroundColor Green
        $wakeSource | ForEach-Object { 
            if ($_ -and $_.ToString().Trim()) {
                Write-Host "  $_" -ForegroundColor White
            }
        }
    } else {
        Write-Host "No wake source information available." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error executing powercfg /lastwake: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nExecuting: powercfg /devicequery wake_armed" -ForegroundColor Gray
try {
    $wakeDevicesCmd = "powercfg /devicequery wake_armed"
    $wakeDevices = Invoke-Expression $wakeDevicesCmd 2>&1
    
    Write-Host "`nDevices that can wake the computer:" -ForegroundColor Green
    if ($wakeDevices -and $wakeDevices.Count -gt 0) {
        $wakeDevices | ForEach-Object { 
            if ($_ -and $_.ToString().Trim()) {
                Write-Host "  • $_" -ForegroundColor White
            }
        }
    } else {
        Write-Host "  No wake-armed devices found." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error executing powercfg devicequery: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nExecuting: powercfg /waketimers" -ForegroundColor Gray
try {
    $wakeTimersCmd = "powercfg /waketimers"
    $wakeTimers = Invoke-Expression $wakeTimersCmd 2>&1
    
    Write-Host "`nActive Wake Timers:" -ForegroundColor Green
    if ($wakeTimers -and $wakeTimers.Count -gt 0) {
        $wakeTimers | ForEach-Object { 
            if ($_ -and $_.ToString().Trim()) {
                Write-Host "  $_" -ForegroundColor White
            }
        }
    } else {
        Write-Host "  No active wake timers found." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error executing powercfg waketimers: $($_.Exception.Message)" -ForegroundColor Red
}

# ===========================================
# SCHEDULED TASKS ANALYSIS
# ===========================================
Write-Host "`n=== SCHEDULED TASKS WITH WAKE CAPABILITY ===" -ForegroundColor Cyan

try {
    Write-Host "Analyzing scheduled tasks..." -ForegroundColor Gray
    $allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue
    $wakeTasksFound = 0
    
    Write-Host "`nTasks that can wake the computer:" -ForegroundColor Green
    
    foreach ($task in $allTasks) {
        try {
            if ($task.Settings.WakeToRun -eq $true) {
                $wakeTasksFound++
                $taskInfo = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
                
                Write-Host "`n  ► $($task.TaskName)" -ForegroundColor White
                Write-Host "    Path: $($task.TaskPath)" -ForegroundColor Gray
                Write-Host "    State: $($task.State)" -ForegroundColor $(if($task.State -eq 'Ready'){'Green'}else{'Yellow'})
                
                if ($taskInfo) {
                    if ($taskInfo.NextRunTime -and $taskInfo.NextRunTime -ne [DateTime]::MinValue) {
                        Write-Host "    Next Run: $($taskInfo.NextRunTime)" -ForegroundColor Cyan
                    }
                    if ($taskInfo.LastRunTime -and $taskInfo.LastRunTime -ne [DateTime]::MinValue) {
                        Write-Host "    Last Run: $($taskInfo.LastRunTime)" -ForegroundColor Gray
                    }
                }
                
                if ($task.Description) {
                    Write-Host "    Description: $($task.Description)" -ForegroundColor Gray
                }
                
                if ($Detailed -and $task.Triggers) {
                    Write-Host "    Triggers:" -ForegroundColor Yellow
                    foreach ($trigger in $task.Triggers) {
                        $triggerType = $trigger.CimClass.CimClassName -replace "MSFT_Task", ""
                        Write-Host "      • $triggerType" -ForegroundColor White
                        if ($trigger.StartBoundary) {
                            Write-Host "        Start: $($trigger.StartBoundary)" -ForegroundColor Gray
                        }
                    }
                }
            }
        } catch {
            # Skip tasks that can't be accessed
            continue
        }
    }
    
    if ($wakeTasksFound -eq 0) {
        Write-Host "  No scheduled tasks with wake capability found." -ForegroundColor Yellow
    } else {
        Write-Host "`nFound $wakeTasksFound tasks that can wake the computer." -ForegroundColor Green
    }
    
} catch {
    Write-Host "Error analyzing scheduled tasks: $($_.Exception.Message)" -ForegroundColor Red
}

# ===========================================
# SYSTEM EVENTS ANALYSIS
# ===========================================
Write-Host "`n=== SYSTEM WAKE EVENTS (Last $LastDays days) ===" -ForegroundColor Cyan

$startDate = (Get-Date).AddDays(-$LastDays)

try {
    Write-Host "Searching system event logs..." -ForegroundColor Gray
    
    # Get power-related events
    $powerEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        ID = @(1, 42, 107, 109)
        StartTime = $startDate
    } -ErrorAction SilentlyContinue | Sort-Object TimeCreated -Descending | Select-Object -First 15
    
    if ($powerEvents) {
        Write-Host "`nRecent Power Events:" -ForegroundColor Green
        foreach ($event in $powerEvents) {
            $timeStr = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
            $eventName = switch ($event.Id) {
                1 { "System Wake" }
                42 { "System Sleep" }
                107 { "System Wake from Sleep" }
                109 { "Kernel Power Event" }
                default { "Power Event" }
            }
            
            Write-Host "  [$timeStr] $eventName (ID: $($event.Id))" -ForegroundColor White
            
            if ($Detailed -and $event.Message) {
                $shortMessage = ($event.Message -split "`n")[0]
                if ($shortMessage.Length -gt 80) {
                    $shortMessage = $shortMessage.Substring(0, 77) + "..."
                }
                Write-Host "    $shortMessage" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "No power events found in the last $LastDays days." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Error analyzing system events: $($_.Exception.Message)" -ForegroundColor Red
}

# ===========================================
# NETWORK WAKE SETTINGS
# ===========================================
Write-Host "`n=== NETWORK WAKE SETTINGS ===" -ForegroundColor Cyan

try {
    Write-Host "Checking network adapters..." -ForegroundColor Gray
    $networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 5
    
    foreach ($adapter in $networkAdapters) {
        Write-Host "`nNetwork Adapter: $($adapter.Name)" -ForegroundColor Green
        
        try {
            $wakeSettings = Get-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue
            if ($wakeSettings) {
                Write-Host "  Wake on Magic Packet: $($wakeSettings.WakeOnMagicPacket)" -ForegroundColor White
                Write-Host "  Wake on Pattern Match: $($wakeSettings.WakeOnPattern)" -ForegroundColor White
            } else {
                Write-Host "  No power management settings available" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  Could not retrieve power settings" -ForegroundColor Gray
        }
    }
    
} catch {
    Write-Host "Error checking network settings: $($_.Exception.Message)" -ForegroundColor Red
}

# ===========================================
# COMPLETION
# ===========================================
Write-Host "`n=== ANALYSIS COMPLETE ===" -ForegroundColor Cyan
Write-Host "`nAdditional commands you can run manually:" -ForegroundColor Yellow
Write-Host "  powercfg /requests          - Show what's preventing sleep" -ForegroundColor White
Write-Host "  powercfg /devicequery wake_programmable - All wake-capable devices" -ForegroundColor White
Write-Host "  powercfg /devicedisablewake "HID-compliant mouse" - Disable wake for mouse" -ForegroundColor White
Write-Host "  Get-WinEvent -LogName System | Where-Object {`$_.Id -eq 1} - All wake events" -ForegroundColor White
Write-Host "`nParameters used: Days=$LastDays, Detailed=$Detailed" -ForegroundColor Gray
Write-Host "`nPress any key to exit..." -ForegroundColor Gray

$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
