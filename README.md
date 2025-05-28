# Windows 11 Wake Reason Analyzer

[![PowerShell 7.x](https://img.shields.io/badge/PowerShell-7.x-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Windows 11](https://img.shields.io/badge/Windows-11-blue?logo=windows)](https://www.microsoft.com/windows/)

A PowerShell script to analyze and display information about what caused your Windows 11 PC to wake up from sleep or hibernation. The script checks system logs, scheduled tasks, devices, wake timers, and network adapters, providing clear diagnostics to help you troubleshoot unwanted wake events.

---

## Features

- **Analyzes recent system wake events** with explanations
- **Lists devices capable of waking the computer**
- **Shows scheduled tasks that can wake the computer**
- **Displays active wake timers**
- **Checks network adapters' wake settings**
- **Supports detailed output**
- **Self-elevates to Administrator if required**

---

## Requirements

- **Operating System:** Windows 11 (tested on Windows 11 Pro)
- **PowerShell Version:** 7.0 or higher  
- **Permissions:** Administrator privileges required

---

## Installation

1. Download the script file:  
   [`Show-WakeReasons.ps1`](Show-WakeReasons.ps1)
2. Place it in a folder on your PC, e.g. `C:\Users\<youruser>\DevOps\Windows\Wakeup\`
3. Open PowerShell 7 and run the script. You will be prrompted to elevate privileges to run it as Administrator.

---

## Usage

```powershell
# Basic usage
pwsh .\Show-WakeReasons.ps1

# With detailed output for deeper analysis
pwsh .\Show-WakeReasons.ps1 -Detailed

# Specify how many days back to analyze (default: 3)
pwsh -NoProfile -File .\Show-WakeReasons.ps1 -LastDays 7
