# CrazyAlexTool

Windows maintenance and utility tool built with PowerShell and WPF.

## Features

- Office maintenance tools
- WinRAR utility
- System update tool
- SFC scan
- Network reset
- Wi-Fi profile export
- Windows product-key lookup
- Search bar
- Settings panel
- Dark-themed interface

## Run

Reviewing the script before execution is recommended:

```powershell
$path = "$env:TEMP\CrazyAlexTool.ps1"

Invoke-WebRequest `
    -Uri "https://crazyalex15.github.io/win" `
    -OutFile $path

notepad $path
