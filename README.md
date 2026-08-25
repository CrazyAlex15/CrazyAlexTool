# CrazyAlexTool

**Current app version:** `1.8.3`  
**Current catalog version:** `9`

CrazyAlexTool is a PowerShell-based maintenance and utility launcher for Windows and macOS. On Windows it uses a WPF desktop interface; on macOS it opens a local browser interface and exposes the macOS-compatible catalog entries.

## Platform compatibility

| Platform | Requirement | Interface | Notes |
|---|---|---|---|
| Windows 10/11 | Windows PowerShell 5.1 | WPF desktop application | Administrator access is requested automatically when required. |
| macOS | PowerShell 7 or newer (`pwsh`) | Local browser interface | The terminal must remain open while the tool is running. |

Windows PowerShell 7 is detected automatically and the application relaunches itself in Windows PowerShell 5.1 for full WPF compatibility.

## Main features

- Dynamic tool categories loaded from `tools.json`
- Local catalog override for testing and development
- Cached catalog with background GitHub refresh
- Platform-aware Windows and macOS tool filtering
- Tool search
- Per-tool status, progress and cancellation
- Configurable download folder
- Automatic system-information refresh
- SFC system-file scan
- Network reset
- Saved Wi-Fi profile and password export
- Windows product-key lookup
- Confirmation prompts for important actions
- Optional desktop notifications and logging
- Configurable accent colour
- In-app update and restart

## Current tool catalog

The catalog is divided into three categories.

### OFFICE WINDOWS

| Tool | Purpose |
|---|---|
| Install Office | Downloads the Microsoft Office Deployment Tool and starts an Office installation. |
| 365ProPlusRetail64 | Downloads the Microsoft 365 Apps for enterprise 64-bit installer. |
| ProPlus2024Retail64 | Downloads the Office Professional Plus 2024 Retail 64-bit installer. |
| Office Scrubber | Provides Office cleanup, removal and licence-state reset options. |
| Win Office Tools | Downloads and runs the configured Windows Office tools script. |

### OFFICE macOS

| Tool | Purpose |
|---|---|
| Office macOS | Downloads the Microsoft Office installer for macOS. |
| Office-Reset tool 2.0 Beta1 | Downloads the configured Office Reset package. |
| Activator (Serializer) | Downloads the configured Office LTSC 2024 volume-licence serializer package. A valid organisational entitlement is required. |

### SCRIPTS

| Tool | Purpose |
|---|---|
| Activate WinRAR | Applies the configured WinRAR registration file to an installed WinRAR copy. |
| GenP Activator | Downloads the configured GenP archive and presents the available executable versions. |
| GenP v4.2.1 | Downloads and runs the configured v4.2.1 executable. |
| System Update | Starts the configured Windows update script. |

Windows-only tools remain visible but disabled in the macOS interface. On Windows, macOS `.pkg` files are downloaded to the configured download folder instead of being executed.

## Run on Windows

### Quick launch

The following command matches the current launcher and the in-app update action:

```powershell
irm "https://crazyalex15.github.io/win?x=$(Get-Random)" | iex
```

### Review the script before running

```powershell
$path = Join-Path $env:TEMP "CrazyAlexTool.ps1"
$uri = "https://raw.githubusercontent.com/CrazyAlex15/CrazyAlexTool/main/CrazyAlexTool.ps1?x=$(Get-Random)"

Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $path
notepad.exe $path
```

After reviewing the downloaded file, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path
```

The application will request administrator access and relaunch itself when necessary.

## Run on macOS

1. Install PowerShell 7 or newer.
2. Open Terminal.
3. Start PowerShell:

```bash
pwsh
```

4. Run the launcher from the PowerShell prompt:

```powershell
irm "https://crazyalex15.github.io/win?x=$(Get-Random)" | iex
```

CrazyAlexTool starts a local-only HTTP listener on a random `127.0.0.1` port and opens the interface in the default browser. Keep the PowerShell terminal open until you have finished.

macOS packages are downloaded to:

```text
~/Downloads/CrazyAlexTool
```

The selected package is opened with the macOS Installer after the download completes.

## Catalog behaviour

The production catalog is stored in [`tools.json`](tools.json).

Catalog loading follows this order:

1. A valid `tools.json` beside `CrazyAlexTool.ps1` is used as a local development override.
2. Otherwise, the last valid cached catalog is loaded immediately.
3. If no valid cache exists, the built-in fallback catalog is displayed.
4. The GitHub catalog refreshes in the background after the interface opens.

To test catalog changes locally, place these files in the same folder:

```text
CrazyAlexTool.ps1
tools.json
```

The local file is not overwritten by the background GitHub refresh during that run.

## Application data

### Windows

| Data | Default location |
|---|---|
| Settings | `%APPDATA%\CrazyAlexTool\settings.json` |
| Log | `%APPDATA%\CrazyAlexTool\log.txt` |
| Catalog cache | `%APPDATA%\CrazyAlexTool\tools.json` |
| Temporary files | `%TEMP%\CrazyAlexTool` |
| Default downloads | `%USERPROFILE%\Downloads\CrazyAlexTool` |

Temporary and session-tracked files are cleaned up when the application closes.

### macOS

| Data | Default location |
|---|---|
| Catalog cache | `~/Library/Application Support/CrazyAlexTool/tools.json` |
| Package downloads | `~/Downloads/CrazyAlexTool` |

The macOS download folder is tool-managed and old interrupted-download leftovers are cleared when a new session starts.

## Troubleshooting

### The Windows interface does not open

- Confirm that you are running Windows 10 or Windows 11.
- Confirm that Windows PowerShell 5.1 is installed at its standard system location.
- If you started the script from PowerShell 7, wait for the automatic Windows PowerShell 5.1 relaunch.
- Accept the administrator prompt.

### The macOS interface does not open

- Run `pwsh --version` and confirm that it reports PowerShell 7 or newer.
- Keep the terminal open.
- Check the terminal for the generated local `http://127.0.0.1:<port>/` address and open it manually if the browser does not launch.

### The tool list is outdated

- Restart CrazyAlexTool and allow the background catalog refresh to complete.
- Check whether a local `tools.json` beside the script is overriding the GitHub catalog.
- If necessary, remove the cached `tools.json` from the application-data location and restart.

### A download or tool fails

- Check the internet connection.
- Confirm that GitHub and the configured download source are reachable.
- Review `%APPDATA%\CrazyAlexTool\log.txt` on Windows when logging is enabled.
- Run only files and scripts that you trust.

## Repository layout

| File | Purpose |
|---|---|
| `CrazyAlexTool.ps1` | Main cross-platform application and Windows WPF interface |
| `tools.json` | Remote tool catalog and categories |
| `OfficeScrubber.zip` | Office Scrubber payload used by the built-in action |
| `WinOfficeTools.bat` | Windows Office tools launcher |
| `UpdateSystemWithPSCheck.bat` | Windows system-update launcher |
| `Microsoft_Office_Reset_2.0.0.pkg` | Office Reset package for macOS |
| `Microsoft_Office_LTSC_2024_VL_Serializer.pkg` | Office LTSC 2024 serializer package for macOS |
| `GenP-main.zip` | Archive used by the built-in GenP action |
| `rarreg.key` | Registration file used by the WinRAR action |

## Security and licensing

CrazyAlexTool can download and execute external scripts, installers and packages, sometimes with administrator privileges. Review the source, verify downloaded files and use only software for which you have the necessary licences or organisational entitlement.

The repository owner is not responsible for damage, data loss, licensing violations or other consequences resulting from third-party tools or modified catalog entries.

## Updating

Use **Settings → Update Tool** inside CrazyAlexTool to close the current session and restart from the latest launcher. The tool catalog can update independently through `tools.json`, so new catalog entries do not always require a new application version.
