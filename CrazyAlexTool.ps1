#requires -Version 5.1

<#
.SYNOPSIS
    CrazyAlexTool

.DESCRIPTION
    Windows utility and maintenance tool.

.EXAMPLE
    irm https://crazyalex15.github.io/win | iex
#>

# ============================================================
# VERSION MARKER
# ============================================================

$script:AppVersion = "1.7.1"
# Keep this source ASCII-safe and save with a UTF-8 BOM for Windows PowerShell 5.1.
Write-Host "[i] Loading CrazyAlexTool $script:AppVersion" -ForegroundColor Cyan

# ============================================================
# PLATFORM DETECTION / macOS ENTRY POINT
# ============================================================

$script:IsWindowsPlatform = $false
$script:IsMacOSPlatform = $false
try {
    if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
        $script:IsWindowsPlatform = [bool]$IsWindows
        $script:IsMacOSPlatform = [bool]$IsMacOS
    }
    else {
        $osDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
        $script:IsWindowsPlatform = $osDescription -match 'Windows'
        $script:IsMacOSPlatform = $osDescription -match 'Darwin|macOS'
    }
}
catch {
    $script:IsWindowsPlatform = ($env:OS -eq 'Windows_NT')
}

function Get-CatalogToolPlatform {
    param($Tool)

    if ($Tool -and $Tool.PSObject.Properties['platform']) {
        $declared = ([string]$Tool.platform).Trim().ToLowerInvariant()
        if ($declared -in @('windows','macos','all')) { return $declared }
    }

    # Backward compatibility for older tools.json files.
    if ($Tool -and ([string]$Tool.category -eq 'office_macos' -or [string]$Tool.extension -eq '.pkg')) {
        return 'macos'
    }
    return 'windows'
}

function Start-CrazyAlexToolMacOS {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw 'CrazyAlexTool on macOS requires PowerShell 7 or newer (pwsh).'
    }

    $remoteToolsUrl = 'https://raw.githubusercontent.com/CrazyAlex15/CrazyAlexTool/main/tools.json'
    $appData = Join-Path $HOME 'Library/Application Support/CrazyAlexTool'
    $cachePath = Join-Path $appData 'tools.json'
    $downloadFolder = Join-Path $HOME 'Downloads/CrazyAlexTool'
    $localToolsPath = $null
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        try { $localToolsPath = Join-Path (Split-Path -Parent $PSCommandPath) 'tools.json' } catch { }
    }

    foreach ($folder in @($appData, $downloadFolder)) {
        if (-not (Test-Path -LiteralPath $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }
    }

    $fallbackJson = @'
{
  "version": 9,
  "categories": [
    { "id": "office_windows", "label": "OFFICE WINDOWS" },
    { "id": "office_macos", "label": "OFFICE macOS" },
    { "id": "scripts", "label": "SCRIPTS" }
  ],
  "tools": [
    { "id": "officeODT", "label": "Install Office (ODT)", "type": "builtin", "action": "Install-OfficeODT", "category": "office_windows", "width": 205, "tag": "office setup installer microsoft odt", "platform": "windows" },
    { "id": "o365ProPlusRetail64", "label": "365ProPlusRetail64", "type": "single-file", "url": "https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=O365ProPlusRetail&platform=x64&language=en-us&version=O16GA", "extension": ".exe", "category": "office_windows", "width": 205, "tag": "office 365 pro plus retail x64 en-us", "platform": "windows" },
    { "id": "proPlus2024Retail64", "label": "ProPlus2024Retail64", "type": "single-file", "url": "https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=ProPlus2024Retail&platform=x64&language=en-us&version=O16GA", "extension": ".exe", "category": "office_windows", "width": 205, "tag": "office 2024 pro plus retail x64 en-us", "platform": "windows" },
    { "id": "scrubber", "label": "Office Scrubber", "type": "builtin", "action": "Invoke-OfficeScrubber", "category": "office_windows", "width": 205, "tag": "office scrubber cleanup remove", "platform": "windows" },
    { "id": "winTools", "label": "Win Office Tools", "type": "single-file", "url": "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/WinOfficeTools.bat", "extension": ".bat", "category": "office_windows", "width": 205, "tag": "office windows tools", "platform": "windows" },
    { "id": "winrar", "label": "Activate WinRAR", "type": "builtin", "action": "Activate-WinRAR", "category": "office_windows", "width": 205, "tag": "winrar activate license key", "platform": "windows" },
    { "id": "officeMacOS", "label": "Office macOS", "type": "single-file", "url": "https://go.microsoft.com/fwlink/p/?linkid=2009112", "extension": ".pkg", "category": "office_macos", "width": 205, "tag": "office macos mac microsoft installer pkg", "platform": "macos" },
    { "id": "officeResetMacOS", "label": "Office-Reset tool 2.0 Beta 1 (macOS)", "type": "single-file", "url": "https://raw.githubusercontent.com/CrazyAlex15/CrazyAlexTool/main/Microsoft_Office_Reset_2.0.0.pkg", "extension": ".pkg", "category": "office_macos", "width": 205, "tag": "office reset tool 2.0 beta 1 macos mac pkg", "platform": "macos" },
    { "id": "officeSerializerMacOS", "label": "Activator (Serializer macOS)", "type": "single-file", "url": "https://raw.githubusercontent.com/CrazyAlex15/CrazyAlexTool/main/Microsoft_Office_LTSC_2024_VL_Serializer.pkg", "extension": ".pkg", "category": "office_macos", "width": 205, "tag": "office ltsc 2024 vl serializer macos mac pkg", "platform": "macos" },
    { "id": "genp", "label": "GenP Activator", "type": "builtin", "action": "Invoke-GenP", "category": "scripts", "width": 205, "tag": "genp activator adobe", "platform": "windows" },
    { "id": "update", "label": "System Update", "type": "single-file", "url": "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/UpdateSystemWithPSCheck.bat", "extension": ".bat", "category": "scripts", "width": 205, "tag": "system update windows update", "platform": "windows" }
  ]
}
'@

    function Test-MacCatalog {
        param($Catalog)
        if (-not $Catalog -or -not $Catalog.categories -or -not $Catalog.tools) { return $false }
        return (@($Catalog.categories).Count -gt 0 -and @($Catalog.tools).Count -gt 0)
    }

    $catalog = $null
    $usingLocalCatalog = $false
    if ($localToolsPath -and (Test-Path -LiteralPath $localToolsPath)) {
        try {
            $candidate = Get-Content -LiteralPath $localToolsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if (Test-MacCatalog $candidate) {
                $catalog = $candidate
                $usingLocalCatalog = $true
            }
        } catch { Write-Warning "Local tools.json is invalid: $($_.Exception.Message)" }
    }

    if (-not $catalog -and (Test-Path -LiteralPath $cachePath)) {
        try {
            $candidate = Get-Content -LiteralPath $cachePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if (Test-MacCatalog $candidate) { $catalog = $candidate }
        } catch { }
    }

    if (-not $catalog) { $catalog = $fallbackJson | ConvertFrom-Json }

    $refreshJob = $null
    if (-not $usingLocalCatalog) {
        try {
            $refreshJob = Start-Job -ScriptBlock {
                param($Url)
                try {
                    $r = Invoke-WebRequest -Uri $Url -TimeoutSec 5 -ErrorAction Stop
                    [string]$r.Content
                } catch { throw $_ }
            } -ArgumentList $remoteToolsUrl
        } catch { }
    }

    function Save-MacCatalogRefresh {
        if (-not $refreshJob) { return }
        if ($refreshJob.State -notin @('Completed','Failed','Stopped')) { return }
        try {
            if ($refreshJob.State -eq 'Completed') {
                $text = [string](Receive-Job $refreshJob -ErrorAction Stop | Select-Object -First 1)
                $candidate = $text | ConvertFrom-Json -ErrorAction Stop
                if (Test-MacCatalog $candidate) {
                    [System.IO.File]::WriteAllText($cachePath, $text, (New-Object System.Text.UTF8Encoding($false)))
                }
            }
        } catch { }
        try { Remove-Job $refreshJob -Force -ErrorAction SilentlyContinue } catch { }
        $script:MacRefreshFinished = $true
    }

    function Escape-Html([string]$Text) {
        return [System.Net.WebUtility]::HtmlEncode($Text)
    }

    function Escape-JsSingle([string]$Text) {
        if ($null -eq $Text) { return '' }
        return $Text.Replace('\','\\').Replace("'","\\'").Replace("`r",'').Replace("`n",'\\n')
    }

    $categoryHtml = New-Object System.Text.StringBuilder
    foreach ($category in @($catalog.categories)) {
        [void]$categoryHtml.Append("<section class='category'><h2>$(Escape-Html ([string]$category.label))</h2><div class='tools'>")
        foreach ($tool in @($catalog.tools | Where-Object { [string]$_.category -eq [string]$category.id })) {
            $platform = Get-CatalogToolPlatform $tool
            $labelHtml = Escape-Html ([string]$tool.label)
            $idJs = Escape-JsSingle ([string]$tool.id)
            $labelJs = Escape-JsSingle ([string]$tool.label)
            if ($platform -eq 'windows') {
                [void]$categoryHtml.Append("<button class='tool disabled' disabled title='Windows-only tool - unavailable on macOS'><span>$labelHtml</span><small>Windows only</small></button>")
            }
            else {
                $buttonHtml = '<button class="tool" onclick="showMacNotice(''{0}'',''{1}'')"><span>{2}</span><small>macOS</small></button>' -f $idJs, $labelJs, $labelHtml
                [void]$categoryHtml.Append($buttonHtml)
            }
        }
        [void]$categoryHtml.Append('</div></section>')
    }

    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CrazyAlexTool $($script:AppVersion)</title>
<style>
:root{color-scheme:dark;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}*{box-sizing:border-box}body{margin:0;background:#111217;color:#f4f6f8}.shell{max-width:1080px;margin:0 auto;padding:36px 26px 70px}.top{display:flex;justify-content:space-between;gap:20px;align-items:flex-start;margin-bottom:28px}.title{font-size:30px;font-weight:800;margin:0}.sub{color:#9aa4ad;margin:7px 0 0}.pill{background:#16272b;color:#67e8f9;border:1px solid #27535a;padding:8px 12px;border-radius:999px;font-size:13px}.notice{background:#171a20;border:1px solid #2b3038;border-radius:12px;padding:13px 15px;color:#aeb7c0;margin-bottom:28px}.category{margin:30px 0}.category h2{font-size:16px;color:#67e8f9;letter-spacing:.04em;margin:0 0 13px}.tools{display:grid;grid-template-columns:repeat(auto-fit,minmax(205px,1fr));gap:12px}.tool{min-height:58px;border:1px solid #343a44;background:#242832;color:#fff;border-radius:10px;padding:10px 13px;text-align:left;font-size:14px;font-weight:700;cursor:pointer;transition:.15s}.tool:hover{background:#2d3540;border-color:#4e6871;transform:translateY(-1px)}.tool small{display:block;margin-top:5px;color:#8fd8e4;font-size:11px;font-weight:600}.tool.disabled{opacity:.38;cursor:not-allowed;background:#1b1d22;border-color:#282b31;transform:none}.tool.disabled small{color:#a1a1aa}.footer{display:flex;gap:12px;align-items:center;margin-top:32px}.exit{border:1px solid #4b5563;background:#20242b;color:#fff;padding:9px 15px;border-radius:8px;cursor:pointer}.status{color:#9aa4ad;font-size:13px}.modal-bg{display:none;position:fixed;inset:0;background:rgba(0,0,0,.68);align-items:center;justify-content:center;padding:24px;z-index:10}.modal{max-width:680px;width:100%;background:#1b1f26;border:1px solid #39414b;border-radius:14px;padding:24px;box-shadow:0 20px 60px rgba(0,0,0,.4)}.modal h3{margin:0 0 14px;color:#67e8f9}.modal li{margin:9px 0;line-height:1.45;color:#d3d8dd}.actions{display:flex;justify-content:flex-end;gap:10px;margin-top:20px}.actions button{padding:9px 14px;border-radius:8px;border:1px solid #444b55;cursor:pointer}.cancel{background:#252932;color:#fff}.continue{background:#0e7490;color:white;border-color:#0891b2!important}
</style>
</head>
<body>
<div class="shell">
  <div class="top"><div><h1 class="title">CrazyAlexTool</h1><p class="sub">macOS mode - PowerShell $($PSVersionTable.PSVersion)</p></div><div class="pill">macOS</div></div>
  <div class="notice">Windows-only tools are shown for catalog consistency but are disabled on macOS. macOS packages are downloaded to <b>~/Downloads/CrazyAlexTool</b> and opened with Installer.</div>
  $categoryHtml
  <div class="footer"><button class="exit" onclick="quitTool()">Exit Tool</button><span id="status" class="status">Ready.</span></div>
</div>
<div id="modalBg" class="modal-bg">
 <div class="modal">
  <h3>Office Activation / Licensing - macOS</h3>
  <ul>
   <li>Install Office for your macOS version if it is not already installed.</li>
   <li>If Office has previously been opened, use the Office-Reset tool to clean existing Office licensing state before changing licenses.</li>
   <li>If your organization provided a valid Microsoft Office LTSC 2024 volume-license serializer, install that package before opening Office apps.</li>
   <li>Open Office and confirm activation with your properly licensed Microsoft account or organization entitlement.</li>
  </ul>
  <div class="actions"><button class="cancel" onclick="closeModal()">Cancel</button><button class="continue" onclick="continueTool()">Continue</button></div>
 </div>
</div>
<script>
let pendingId=null,pendingLabel=null;
function showMacNotice(id,label){pendingId=id;pendingLabel=label;document.getElementById('modalBg').style.display='flex';}
function closeModal(){document.getElementById('modalBg').style.display='none';pendingId=null;pendingLabel=null;}
async function continueTool(){let id=pendingId,label=pendingLabel;closeModal();if(!id)return;let s=document.getElementById('status');s.textContent='Downloading '+label+'...';try{let r=await fetch('/tool?id='+encodeURIComponent(id));let j=await r.json();s.textContent=j.message||'Finished.';if(!j.ok)alert(j.message||'Tool failed.');}catch(e){s.textContent='Error: '+e;alert('Error: '+e);}}
async function quitTool(){try{await fetch('/quit');}catch(e){} window.close();document.body.innerHTML='<div style="font-family:-apple-system;background:#111217;color:white;padding:40px">CrazyAlexTool stopped. You may close this tab.</div>';}
</script>
</body></html>
"@

    # Pick an unused loopback port, then start a local-only HTTP listener.
    $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $probe.Start()
    $port = ([System.Net.IPEndPoint]$probe.LocalEndpoint).Port
    $probe.Stop()

    $listener = [System.Net.HttpListener]::new()
    $prefix = "http://127.0.0.1:$port/"
    $listener.Prefixes.Add($prefix)
    $listener.Start()

    function Send-MacResponse {
        param($Context, [string]$Body, [string]$ContentType = 'text/html; charset=utf-8', [int]$StatusCode = 200)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $Context.Response.StatusCode = $StatusCode
        $Context.Response.ContentType = $ContentType
        $Context.Response.ContentLength64 = $bytes.Length
        $Context.Response.OutputStream.Write($bytes,0,$bytes.Length)
        $Context.Response.OutputStream.Close()
    }

    function Send-MacJson {
        param($Context, [bool]$Ok, [string]$Message, [int]$StatusCode = 200)
        $json = @{ ok=$Ok; message=$Message } | ConvertTo-Json -Compress
        Send-MacResponse -Context $Context -Body $json -ContentType 'application/json; charset=utf-8' -StatusCode $StatusCode
    }

    Write-Host "[i] macOS interface: $prefix" -ForegroundColor Cyan
    Write-Host '[i] Keep this terminal open while using the tool.' -ForegroundColor DarkGray
    & /usr/bin/open $prefix

    $running = $true
    try {
        while ($running -and $listener.IsListening) {
            $ctx = $listener.GetContext()
            $path = $ctx.Request.Url.AbsolutePath
            try {
                if ($path -eq '/') {
                    Send-MacResponse -Context $ctx -Body $html
                }
                elseif ($path -eq '/favicon.ico') {
                    Send-MacResponse -Context $ctx -Body '' -StatusCode 204
                }
                elseif ($path -eq '/quit') {
                    Send-MacJson -Context $ctx -Ok $true -Message 'CrazyAlexTool stopped.'
                    $running = $false
                }
                elseif ($path -eq '/tool') {
                    $id = [string]$ctx.Request.QueryString['id']
                    $tool = @($catalog.tools | Where-Object { [string]$_.id -eq $id }) | Select-Object -First 1
                    if (-not $tool) {
                        Send-MacJson -Context $ctx -Ok $false -Message 'Tool not found.' -StatusCode 404
                        continue
                    }

                    $platform = Get-CatalogToolPlatform $tool
                    if ($platform -eq 'windows') {
                        Send-MacJson -Context $ctx -Ok $false -Message 'This tool is Windows-only and is disabled on macOS.' -StatusCode 403
                        continue
                    }
                    if ([string]$tool.type -ne 'single-file') {
                        Send-MacJson -Context $ctx -Ok $false -Message 'This tool action is not implemented for macOS.' -StatusCode 400
                        continue
                    }

                    $ext = [string]$tool.extension
                    if ([string]::IsNullOrWhiteSpace($ext)) { $ext = '.download' }
                    $leaf = ''
                    try {
                        $uri = [Uri][string]$tool.url
                        $leaf = [System.Uri]::UnescapeDataString([IO.Path]::GetFileName($uri.AbsolutePath))
                    } catch { }
                    if ([string]::IsNullOrWhiteSpace($leaf) -or -not $leaf.ToLowerInvariant().EndsWith($ext.ToLowerInvariant())) {
                        $leaf = ([string]$tool.id) + $ext
                    }
                    $leaf = [regex]::Replace($leaf, '[\\/:*?"<>|]', '_')
                    $outFile = Join-Path $downloadFolder $leaf

                    try {
                        Write-Host "[i] Downloading $($tool.label)..." -ForegroundColor Yellow
                        Invoke-WebRequest -Uri ([string]$tool.url) -OutFile $outFile -TimeoutSec 180 -ErrorAction Stop
                        if (-not (Test-Path -LiteralPath $outFile) -or (Get-Item -LiteralPath $outFile).Length -le 0) {
                            throw 'The downloaded file is empty.'
                        }
                        if ($ext.ToLowerInvariant() -eq '.pkg') {
                            & /usr/bin/open $outFile
                            Send-MacJson -Context $ctx -Ok $true -Message "$($tool.label) downloaded. Installer opened."
                        }
                        else {
                            & /usr/bin/open -R $outFile
                            Send-MacJson -Context $ctx -Ok $true -Message "$($tool.label) downloaded to $outFile"
                        }
                    }
                    catch {
                        try { Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue } catch { }
                        Send-MacJson -Context $ctx -Ok $false -Message "Download failed: $($_.Exception.Message)" -StatusCode 500
                    }
                }
                else {
                    Send-MacResponse -Context $ctx -Body 'Not found' -ContentType 'text/plain; charset=utf-8' -StatusCode 404
                }
            }
            catch {
                try { Send-MacJson -Context $ctx -Ok $false -Message $_.Exception.Message -StatusCode 500 } catch { }
            }

            if ($refreshJob -and -not $script:MacRefreshFinished) { Save-MacCatalogRefresh }
        }
    }
    finally {
        try { $listener.Stop(); $listener.Close() } catch { }
        if ($refreshJob) {
            try { Stop-Job $refreshJob -ErrorAction SilentlyContinue } catch { }
            try { Remove-Job $refreshJob -Force -ErrorAction SilentlyContinue } catch { }
        }
    }
}

if ($script:IsMacOSPlatform) {
    try { Start-CrazyAlexToolMacOS }
    catch { Write-Error "Could not launch CrazyAlexTool on macOS: $($_.Exception.Message)" }
    return
}
elseif (-not $script:IsWindowsPlatform) {
    Write-Error 'CrazyAlexTool currently supports Windows and macOS only.'
    return
}

# ============================================================
# CLEAN SLATE
# ============================================================

$leftoverVarNames = @(
    "AppName", "AppDataPath", "SettingsPath", "TemporaryPath", "LogPath",
    "DefaultDownloadFolder", "Links", "AccentMap",
    "DefaultSettings", "Settings", "InfoTimer",
    "SearchableControls", "PickerResult", "LabelPickerResult",
    "RemoteScriptUrl", "ToolsJsonUrl", "ToolsCachePath", "LocalToolsJsonPath", "UseLocalToolsJson",
    "CatalogRefreshJob", "CatalogRefreshTimer", "StartupTimer", "StartupComplete",
    "Window", "Reader", "XAML",
    "TitleText", "SubtitleText", "TxtSearch", "MainTabs",
    "SystemInfoText", "StatusText", "ProgressText", "MainProgress",
    "BtnRefreshInfo", "BtnSFC", "BtnWifi", "BtnExportWifi", "BtnKey",
    "CategoryHost", "CategoryPanels", "CategoryHeaders", "ToolCategories",
    "TxtDownloadFolder", "BtnBrowseFolder", "ChkConfirmActions",
    "ChkAutoRefresh", "ChkShowToasts", "ChkEnableLog",
    "CmbAccent", "BtnSaveSettings", "BtnResetSettings",
    "BtnUpdateTool", "BtnOpenAppData", "BtnViewLog",
    "ActiveJobs", "JobPoller",
    "ToolCatalog", "ToastNotifier"
)

foreach ($varName in $leftoverVarNames) {
    foreach ($scope in @("Script", "Global")) {
        try {
            if (Get-Variable -Name $varName -Scope $scope -ErrorAction SilentlyContinue) {
                Remove-Variable -Name $varName -Scope $scope -Force -ErrorAction SilentlyContinue
            }
        } catch { }
    }
}

# Clean up leftover LHM cache from previous versions if present
try {
    $lhmOldFolder = Join-Path $env:APPDATA "CrazyAlexTool\LHM"
    if (Test-Path $lhmOldFolder) {
        Remove-Item -Path $lhmOldFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    $lhmOldDll = Join-Path $env:APPDATA "CrazyAlexTool\LibreHardwareMonitorLib.dll"
    if (Test-Path $lhmOldDll) {
        Remove-Item -Path $lhmOldDll -Force -ErrorAction SilentlyContinue
    }
} catch { }

# ============================================================
# ADMIN / RELAUNCH IN POWERSHELL 5.1
# ============================================================

$script:RemoteScriptUrl = "https://raw.githubusercontent.com/CrazyAlex15/CrazyAlexTool/main/CrazyAlexTool.ps1"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$isRemoteExecution = [string]::IsNullOrWhiteSpace($PSCommandPath) -or
                     -not (Test-Path -LiteralPath $PSCommandPath -ErrorAction SilentlyContinue)
$isPowerShell7 = $PSVersionTable.PSVersion.Major -ge 6

if ((-not (Test-IsAdministrator)) -or $isRemoteExecution -or $isPowerShell7) {
    try {
        $scriptPath = $PSCommandPath
        if ([string]::IsNullOrWhiteSpace($scriptPath) -or -not (Test-Path -LiteralPath $scriptPath)) {
            $scriptPath = Join-Path $env:TEMP ("CrazyAlexTool-" + [Guid]::NewGuid().ToString("N") + ".ps1")

            $remoteResponse = Invoke-WebRequest -Uri $script:RemoteScriptUrl -UseBasicParsing -ErrorAction Stop
            $remoteCode = [string]$remoteResponse.Content
            if ([string]::IsNullOrWhiteSpace($remoteCode)) { throw "Remote script was empty." }

            $trimmed = $remoteCode.TrimStart()
            if ($trimmed -match '^<!DOCTYPE\s+html' -or $trimmed -match '^<html\b') {
                throw "Remote URL returned HTML."
            }

            $utf8Bom = New-Object System.Text.UTF8Encoding($true)
            [System.IO.File]::WriteAllText($scriptPath, $remoteCode, $utf8Bom)
        }

        $powershellPath = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
        if (-not (Test-Path $powershellPath)) { throw "Windows PowerShell 5.1 not found." }

        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

        if (Test-IsAdministrator) {
            Start-Process -FilePath $powershellPath -ArgumentList $arguments -ErrorAction Stop | Out-Null
        } else {
            Start-Process -FilePath $powershellPath -ArgumentList $arguments -Verb RunAs -ErrorAction Stop | Out-Null
        }
    }
    catch { Write-Error "Could not launch CrazyAlexTool: $($_.Exception.Message)" }
    return
}

# ============================================================
# ASSEMBLIES
# ============================================================

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ============================================================
# CONFIGURATION
# ============================================================

$script:AppName = "CrazyAlexTool"
$script:AppDataPath = Join-Path $env:APPDATA $script:AppName
$script:SettingsPath = Join-Path $script:AppDataPath "settings.json"
$script:LogPath = Join-Path $script:AppDataPath "log.txt"
$script:TemporaryPath = Join-Path $env:TEMP $script:AppName
$script:DefaultDownloadFolder = Join-Path $env:USERPROFILE "Downloads\CrazyAlexTool"

$script:ToolsJsonUrl = "https://raw.githubusercontent.com/CrazyAlex15/CrazyAlexTool/main/tools.json"
$script:ToolsCachePath = Join-Path $script:AppDataPath "tools.json"
$script:LocalToolsJsonPath = $null
$script:UseLocalToolsJson = $false
try {
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $script:LocalToolsJsonPath = Join-Path (Split-Path -Parent $PSCommandPath) "tools.json"
    }
} catch { }

$script:Links = [ordered]@{
    Scrubber = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/OfficeScrubber.zip"
    WinTools = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/WinOfficeTools.bat"
    Winrar   = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/rarreg.key"
    Update   = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/UpdateSystemWithPSCheck.bat"
    GenP     = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/GenP-main.zip"
    O365ProPlusRetail64 = "https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=O365ProPlusRetail&platform=x64&language=en-us&version=O16GA"
    ProPlus2024Retail64 = "https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=ProPlus2024Retail&platform=x64&language=en-us&version=O16GA"
    OfficeMacOS = "https://go.microsoft.com/fwlink/p/?linkid=2009112"
    OfficeResetMacOS = "https://raw.githubusercontent.com/CrazyAlex15/CrazyAlexTool/main/Microsoft_Office_Reset_2.0.0.pkg"
    OfficeSerializerMacOS = "https://raw.githubusercontent.com/CrazyAlex15/CrazyAlexTool/main/Microsoft_Office_LTSC_2024_VL_Serializer.pkg"
}

$script:AccentMap = [ordered]@{
    Cyan="#00FFFF"; Blue="#4DA3FF"; Green="#66D17A"; Orange="#FFB347"; Purple="#C084FC"
}

$script:DefaultSettings = [ordered]@{
    DownloadFolder = $script:DefaultDownloadFolder
    ConfirmActions = $true
    AutoRefresh    = $true
    Accent         = "Cyan"
    ShowToasts     = $true
    EnableLog      = $true
}

$script:Settings = [ordered]@{}
$script:ActiveJobs = @{}
$script:ToolCatalog = @()

# ============================================================
# LOGGING & SETTINGS
# ============================================================

function Initialize-AppData {
    if (-not (Test-Path $script:AppDataPath)) {
        New-Item -Path $script:AppDataPath -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path $script:TemporaryPath)) {
        New-Item -Path $script:TemporaryPath -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if ($script:Settings -and $script:Settings.EnableLog -eq $false) { return }
    try {
        Initialize-AppData
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp [$Level] $Message" | Add-Content -Path $script:LogPath -ErrorAction SilentlyContinue
        if ((Test-Path $script:LogPath) -and (Get-Item $script:LogPath).Length -gt 500KB) {
            $lines = Get-Content $script:LogPath -Tail 2000
            Set-Content $script:LogPath -Value $lines -Encoding UTF8
        }
    } catch { }
}

function Load-AppSettings {
    Initialize-AppData
    $script:Settings = [ordered]@{}
    foreach ($key in $script:DefaultSettings.Keys) {
        $script:Settings[$key] = $script:DefaultSettings[$key]
    }
    if (Test-Path $script:SettingsPath) {
        try {
            $saved = Get-Content -Path $script:SettingsPath -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($saved.DownloadFolder) { $script:Settings.DownloadFolder = [string]$saved.DownloadFolder }
            if ($null -ne $saved.ConfirmActions) { $script:Settings.ConfirmActions = [bool]$saved.ConfirmActions }
            if ($null -ne $saved.AutoRefresh) { $script:Settings.AutoRefresh = [bool]$saved.AutoRefresh }
            if ($null -ne $saved.ShowToasts) { $script:Settings.ShowToasts = [bool]$saved.ShowToasts }
            if ($null -ne $saved.EnableLog) { $script:Settings.EnableLog = [bool]$saved.EnableLog }
            if ($saved.Accent -and $script:AccentMap.Contains($saved.Accent)) {
                $script:Settings.Accent = [string]$saved.Accent
            }
        } catch { Write-Warning "Could not load settings: $($_.Exception.Message)" }
    }
}

function Save-AppSettings {
    try {
        Initialize-AppData
        $script:Settings | ConvertTo-Json | Set-Content -Path $script:SettingsPath -Encoding UTF8
    } catch { Write-Warning "Could not save settings: $($_.Exception.Message)" }
}

Load-AppSettings
Write-Log "CrazyAlexTool $script:AppVersion started"

# ============================================================
# LOAD / CACHE tools.json
# ============================================================

function Get-FallbackToolCatalog {
    $categories = @(
        [pscustomobject]@{ id="office_windows"; label="OFFICE WINDOWS" }
        [pscustomobject]@{ id="office_macos"; label="OFFICE macOS" }
        [pscustomobject]@{ id="scripts"; label="SCRIPTS" }
    )

    $tools = @(
        [pscustomobject]@{ id="officeODT"; label="Install Office (ODT)"; type="builtin"; action="Install-OfficeODT"; category="office_windows"; width=205; tag="office setup installer microsoft odt"; platform="windows" }
        [pscustomobject]@{ id="o365ProPlusRetail64"; label="365ProPlusRetail64"; type="single-file"; url=$script:Links.O365ProPlusRetail64; extension=".exe"; category="office_windows"; width=205; tag="office 365 pro plus retail x64 en-us"; platform="windows" }
        [pscustomobject]@{ id="proPlus2024Retail64"; label="ProPlus2024Retail64"; type="single-file"; url=$script:Links.ProPlus2024Retail64; extension=".exe"; category="office_windows"; width=205; tag="office 2024 pro plus retail x64 en-us"; platform="windows" }
        [pscustomobject]@{ id="scrubber"; label="Office Scrubber"; type="builtin"; action="Invoke-OfficeScrubber"; category="office_windows"; width=205; tag="office scrubber cleanup remove"; platform="windows" }
        [pscustomobject]@{ id="winTools"; label="Win Office Tools"; type="single-file"; url=$script:Links.WinTools; extension=".bat"; category="office_windows"; width=205; tag="office windows tools"; platform="windows" }
        [pscustomobject]@{ id="winrar"; label="Activate WinRAR"; type="builtin"; action="Activate-WinRAR"; category="office_windows"; width=205; tag="winrar activate license key"; platform="windows" }
        [pscustomobject]@{ id="officeMacOS"; label="Office macOS"; type="single-file"; url=$script:Links.OfficeMacOS; extension=".pkg"; category="office_macos"; width=205; tag="office macos mac microsoft installer pkg"; platform="macos" }
        [pscustomobject]@{ id="officeResetMacOS"; label="Office-Reset tool 2.0 Beta 1 (macOS)"; type="single-file"; url=$script:Links.OfficeResetMacOS; extension=".pkg"; category="office_macos"; width=205; tag="office reset tool 2.0 beta 1 macos mac pkg"; platform="macos" }
        [pscustomobject]@{ id="officeSerializerMacOS"; label="Activator (Serializer macOS)"; type="single-file"; url=$script:Links.OfficeSerializerMacOS; extension=".pkg"; category="office_macos"; width=205; tag="office ltsc 2024 vl serializer macos mac pkg"; platform="macos" }
        [pscustomobject]@{ id="genp"; label="GenP Activator"; type="builtin"; action="Invoke-GenP"; category="scripts"; width=205; tag="genp activator adobe"; platform="windows" }
        [pscustomobject]@{ id="update"; label="System Update"; type="single-file"; url=$script:Links.Update; extension=".bat"; category="scripts"; width=205; tag="system update windows update"; platform="windows" }
    )

    return [pscustomobject]@{
        Categories = $categories
        Tools = $tools
    }
}

function ConvertFrom-ToolCatalogJson {
    param([string]$Json)

    if ([string]::IsNullOrWhiteSpace($Json)) { throw "tools.json was empty." }
    $parsed = $Json | ConvertFrom-Json -ErrorAction Stop
    if (-not $parsed.tools) { throw "tools.json does not contain a tools collection." }

    $tools = @($parsed.tools)
    if ($tools.Count -eq 0) { throw "tools.json contains no tools." }

    # Backward compatibility: old catalogs without a categories collection still work.
    if ($parsed.categories -and @($parsed.categories).Count -gt 0) {
        $categories = @($parsed.categories)
    }
    else {
        $categories = @(
            [pscustomobject]@{ id="office"; label="OFFICE TOOLS" }
            [pscustomobject]@{ id="scripts"; label="SCRIPTS" }
        )
    }

    $categoryIds = @{}
    foreach ($category in $categories) {
        if ([string]::IsNullOrWhiteSpace([string]$category.id) -or
            [string]::IsNullOrWhiteSpace([string]$category.label)) {
            throw "tools.json contains an invalid category entry. Each category requires id and label."
        }
        $categoryId = [string]$category.id
        if ($categoryIds.ContainsKey($categoryId)) {
            throw "tools.json contains duplicate category id '$categoryId'."
        }
        $categoryIds[$categoryId] = $true
    }

    $toolIds = @{}
    foreach ($tool in $tools) {
        if ([string]::IsNullOrWhiteSpace([string]$tool.id) -or
            [string]::IsNullOrWhiteSpace([string]$tool.label) -or
            [string]::IsNullOrWhiteSpace([string]$tool.type) -or
            [string]::IsNullOrWhiteSpace([string]$tool.category)) {
            throw "tools.json contains an invalid tool entry."
        }

        $toolId = [string]$tool.id
        if ($toolIds.ContainsKey($toolId)) {
            throw "tools.json contains duplicate tool id '$toolId'."
        }
        $toolIds[$toolId] = $true

        $toolCategory = [string]$tool.category
        if (-not $categoryIds.ContainsKey($toolCategory)) {
            throw "Tool '$toolId' references unknown category '$toolCategory'. Add that category to the categories array."
        }

        if ($tool.PSObject.Properties['platform']) {
            $toolPlatform = ([string]$tool.platform).Trim().ToLowerInvariant()
            if ($toolPlatform -notin @('windows','macos','all')) {
                throw "Tool '$toolId' has invalid platform '$toolPlatform'. Use windows, macos, or all."
            }
        }
    }

    return [pscustomobject]@{
        Categories = $categories
        Tools = $tools
    }
}

function Save-ToolCatalogCache {
    param([string]$Json)
    try {
        Initialize-AppData
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($script:ToolsCachePath, $Json, $utf8)
    } catch {
        Write-Log "Could not save tools.json cache: $($_.Exception.Message)" "WARN"
    }
}

function Load-ToolCatalog {
    Initialize-AppData

    # Local development override: when tools.json is beside this .ps1 file,
    # use it directly and do not replace it with the GitHub catalog during this run.
    if (-not [string]::IsNullOrWhiteSpace($script:LocalToolsJsonPath) -and (Test-Path $script:LocalToolsJsonPath)) {
        try {
            $localJson = [System.IO.File]::ReadAllText($script:LocalToolsJsonPath)
            $catalog = ConvertFrom-ToolCatalogJson -Json $localJson
            $script:ToolCategories = @($catalog.Categories)
            $script:ToolCatalog = @($catalog.Tools)
            $script:UseLocalToolsJson = $true
            Write-Log "Loaded local tools.json ($($script:ToolCategories.Count) categories, $($script:ToolCatalog.Count) tools): $script:LocalToolsJsonPath"
            return
        }
        catch {
            Write-Log "Local tools.json is invalid: $($_.Exception.Message)" "WARN"
        }
    }

    # Fast path: use the local cache immediately on repeat launches.
    if (Test-Path $script:ToolsCachePath) {
        try {
            $cachedJson = [System.IO.File]::ReadAllText($script:ToolsCachePath)
            $catalog = ConvertFrom-ToolCatalogJson -Json $cachedJson
            $script:ToolCategories = @($catalog.Categories)
            $script:ToolCatalog = @($catalog.Tools)
            Write-Log "Loaded cached tools.json ($($script:ToolCategories.Count) categories, $($script:ToolCatalog.Count) tools)"
            return
        }
        catch {
            Write-Log "Cached tools.json is invalid: $($_.Exception.Message)" "WARN"
            Remove-Item -Path $script:ToolsCachePath -Force -ErrorAction SilentlyContinue
        }
    }

    # First run / missing cache: do not block startup on the network. The GUI
    # opens with the built-in catalog and the online catalog refreshes later.
    Write-Log "No valid tools.json cache; using built-in catalog until background refresh completes"
    $fallback = Get-FallbackToolCatalog
    $script:ToolCategories = @($fallback.Categories)
    $script:ToolCatalog = @($fallback.Tools)
}

function Start-ToolCatalogRefresh {
    if ($script:UseLocalToolsJson) {
        Write-Log "Skipping GitHub catalog refresh because local tools.json override is active"
        return
    }

    # Repeat launches already have a usable local catalog. Refresh the cache
    # silently after the GUI is visible so GitHub never blocks normal startup.
    if ($script:CatalogRefreshJob -and $script:CatalogRefreshJob.State -in @("Running", "NotStarted")) { return }

    try {
        $script:CatalogRefreshJob = Start-Job -ScriptBlock {
            param($Url)
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            try {
                $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                [string]$r.Content
            } catch {
                throw $_
            }
        } -ArgumentList $script:ToolsJsonUrl

        $script:CatalogRefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:CatalogRefreshTimer.Interval = [TimeSpan]::FromMilliseconds(700)
        $script:CatalogRefreshTimer.Add_Tick({
            if (-not $script:CatalogRefreshJob) { return }
            if ($script:CatalogRefreshJob.State -notin @("Completed", "Failed", "Stopped")) { return }

            $script:CatalogRefreshTimer.Stop()
            try {
                if ($script:CatalogRefreshJob.State -eq "Completed") {
                    $remoteJson = [string](Receive-Job $script:CatalogRefreshJob -ErrorAction Stop | Select-Object -First 1)
                    $remoteCatalog = ConvertFrom-ToolCatalogJson -Json $remoteJson
                    $remoteCategories = @($remoteCatalog.Categories)
                    $remoteTools = @($remoteCatalog.Tools)

                    $oldJson = $null
                    if (Test-Path $script:ToolsCachePath) {
                        try { $oldJson = [System.IO.File]::ReadAllText($script:ToolsCachePath) } catch { }
                    }

                    $catalogChanged = [string]::IsNullOrWhiteSpace($oldJson) -or ($oldJson.Trim() -ne $remoteJson.Trim())
                    Save-ToolCatalogCache -Json $remoteJson

                    if ($catalogChanged) {
                        $script:ToolCategories = $remoteCategories
                        $script:ToolCatalog = $remoteTools
                        Build-ToolPanels
                        Apply-AccentColor
                        Filter-Tools
                        Write-Log "Refreshed tools.json cache and live tool catalog ($($remoteCategories.Count) categories, $($remoteTools.Count) tools)"
                    } else {
                        Write-Log "tools.json cache is already current ($($remoteTools.Count) tools)"
                    }
                } else {
                    $reason = $script:CatalogRefreshJob.ChildJobs[0].JobStateInfo.Reason
                    Write-Log "Background tools.json refresh failed: $reason" "WARN"
                }
            }
            catch {
                Write-Log "Background tools.json refresh failed: $($_.Exception.Message)" "WARN"
            }
            finally {
                Remove-Job $script:CatalogRefreshJob -Force -ErrorAction SilentlyContinue
                $script:CatalogRefreshJob = $null
                $script:CatalogRefreshTimer = $null
            }
        })
        $script:CatalogRefreshTimer.Start()
    }
    catch {
        Write-Log "Could not start tools.json background refresh: $($_.Exception.Message)" "WARN"
    }
}

Load-ToolCatalog

# ============================================================
# WPF XAML
# ============================================================

[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="CrazyAlexTool"
        Height="800" Width="1080"
        MinHeight="720" MinWidth="920"
        WindowStartupLocation="CenterScreen"
        Background="#121212"
        FontFamily="Segoe UI">

    <Window.Resources>
        <Style x:Key="DarkComboItem" TargetType="{x:Type ComboBoxItem}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBoxItem}">
                        <Border x:Name="ItemBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter TextElement.Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="#005F73"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="#174A5A"/>
                                <Setter Property="Foreground" Value="#00FFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="DarkComboBox" TargetType="{x:Type ComboBox}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="ItemContainerStyle" Value="{StaticResource DarkComboItem}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBox}">
                        <Grid>
                            <ToggleButton Focusable="False" ClickMode="Press"
                                IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="{x:Type ToggleButton}">
                                        <Border x:Name="TB" Background="#25252B" BorderBrush="#444444"
                                                BorderThickness="1" CornerRadius="4">
                                            <Path Data="M 0 0 L 5 5 L 10 0 Z" Fill="#FFFFFF"
                                                  HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,12,0"/>
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True">
                                                <Setter TargetName="TB" Property="BorderBrush" Value="#00FFFF"/>
                                            </Trigger>
                                            <Trigger Property="IsChecked" Value="True">
                                                <Setter TargetName="TB" Property="BorderBrush" Value="#00FFFF"/>
                                            </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter Content="{TemplateBinding SelectionBoxItem}"
                                              Margin="10,0,35,0" VerticalAlignment="Center"
                                              IsHitTestVisible="False" TextElement.Foreground="#FFFFFF"/>
                            <Popup Placement="Bottom" AllowsTransparency="True" Focusable="False"
                                   IsOpen="{TemplateBinding IsDropDownOpen}">
                                <Border Background="#1E1E22" BorderBrush="#00FFFF" BorderThickness="1"
                                        CornerRadius="4" MinWidth="{TemplateBinding ActualWidth}">
                                    <ScrollViewer MaxHeight="260"><ItemsPresenter/></ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ToolButton" TargetType="{x:Type Button}">
            <Setter Property="Background" Value="#2A2A30"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#444444"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="Margin" Value="0,0,10,10"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type Button}">
                        <Border x:Name="BB" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"
                                              TextElement.Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="BB" Property="Background" Value="#35353D"/>
                                <Setter TargetName="BB" Property="BorderBrush" Value="#00FFFF"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="BB" Property="Background" Value="#174A5A"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="{x:Type TextBox}">
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#444444"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="9,6"/>
        </Style>

        <Style TargetType="{x:Type CheckBox}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Margin" Value="0,7"/>
        </Style>

        <Style TargetType="{x:Type TabItem}">
            <Setter Property="Foreground" Value="#AAAAAA"/>
            <Setter Property="Background" Value="#1A1A1A"/>
            <Setter Property="Padding" Value="15,9"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Grid Grid.Row="0" Margin="22,18,22,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="330"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
                <TextBlock Name="TitleText" Text="CrazyAlexTool" Foreground="#00FFFF" FontSize="27" FontWeight="Bold"/>
                <TextBlock Name="SubtitleText" Text="Windows utility and maintenance tools"
                           Foreground="#888888" FontSize="12" Margin="0,2,0,0"/>
            </StackPanel>
            <TextBox Name="TxtSearch" Grid.Column="1" Height="36" VerticalAlignment="Center" ToolTip="Search tools"/>
        </Grid>

        <TabControl Name="MainTabs" Grid.Row="1" Margin="18,0,18,10" Background="#121212" BorderBrush="#333333">

            <TabItem Header="Dashboard">
                <Grid Margin="18">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.15*"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Column="0" Background="#1B1B1F" BorderBrush="#333333"
                            BorderThickness="1" CornerRadius="6" Padding="18" Margin="0,0,15,0">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <TextBlock Name="HdrSystemInfo" Grid.Row="0" Text="SYSTEM INFORMATION"
                                       Foreground="#00FFFF" FontSize="16" FontWeight="Bold" Margin="0,0,0,15"/>
                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                <TextBlock Name="SystemInfoText" Foreground="#FFFFFF" FontSize="13"
                                           TextWrapping="Wrap" LineHeight="22" FontFamily="Consolas"/>
                            </ScrollViewer>
                            <Button Name="BtnRefreshInfo" Grid.Row="2" Content="Refresh System Information"
                                    Width="230" HorizontalAlignment="Left" Style="{StaticResource ToolButton}"
                                    Margin="0,15,0,0" Tag="system information dashboard refresh"/>
                        </Grid>
                    </Border>

                    <StackPanel Grid.Column="1">
                        <TextBlock Name="HdrQuickTools" Text="QUICK ACTIONS"
                                   Foreground="#00FFFF" FontSize="16" FontWeight="Bold" Margin="0,0,0,15"/>
                        <WrapPanel>
                            <Button Name="BtnSFC" Content="SFC Scan" Width="165" Style="{StaticResource ToolButton}" Tag="sfc system scan repair"/>
                            <Button Name="BtnWifi" Content="Fix Network" Width="165" Style="{StaticResource ToolButton}" Tag="wifi network dns reset"/>
                            <Button Name="BtnExportWifi" Content="Export Wi-Fi Passwords" Width="215" Style="{StaticResource ToolButton}" Tag="wifi wireless password export"/>
                            <Button Name="BtnKey" Content="Show Windows Key" Width="180" Style="{StaticResource ToolButton}" Tag="windows product key license"/>
                        </WrapPanel>
                        <Border Background="#211E18" BorderBrush="#66552F" BorderThickness="1"
                                CornerRadius="5" Padding="14" Margin="0,15,0,0">
                            <TextBlock Text="Long tasks run in the background - you can keep using the tool while they finish."
                                       Foreground="#E6C875" TextWrapping="Wrap" FontSize="12"/>
                        </Border>
                    </StackPanel>
                </Grid>
            </TabItem>

            <TabItem Header="Tools">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Margin="18">
                        <StackPanel Name="CategoryHost"/>
                        <Border Background="#211E18" BorderBrush="#66552F" BorderThickness="1"
                                CornerRadius="5" Padding="14" Margin="0,20,0,0">
                            <TextBlock Text="Only run tools from sources you trust."
                                       Foreground="#E6C875" TextWrapping="Wrap" FontSize="12"/>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <TabItem Header="Settings">
                <Grid Margin="18">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <TextBlock Name="HdrSettings" Text="SETTINGS"
                               Foreground="#00FFFF" FontSize="17" FontWeight="Bold" Margin="0,0,0,18"/>
                    <TextBlock Grid.Row="1" Text="Temporary download folder"
                               Foreground="#FFFFFF" Margin="0,0,0,7"/>
                    <Grid Grid.Row="2">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="110"/>
                        </Grid.ColumnDefinitions>
                        <TextBox Name="TxtDownloadFolder" Grid.Column="0" Height="35"/>
                        <Button Name="BtnBrowseFolder" Grid.Column="1" Content="Browse"
                                Width="95" Style="{StaticResource ToolButton}" Margin="10,0,0,10"/>
                    </Grid>
                    <CheckBox Name="ChkConfirmActions" Grid.Row="3" Content="Confirm sensitive actions" Margin="0,14,0,5"/>
                    <CheckBox Name="ChkAutoRefresh" Grid.Row="4" Content="Automatically refresh system information" Margin="0,5,0,5"/>
                    <CheckBox Name="ChkShowToasts" Grid.Row="5" Content="Show toast notifications when tasks complete" Margin="0,5,0,5"/>
                    <CheckBox Name="ChkEnableLog" Grid.Row="6" Content="Enable log file" Margin="0,5,0,5"/>
                    <StackPanel Grid.Row="7" Orientation="Horizontal" Margin="0,18,0,0">
                        <TextBlock Text="Accent color:" Foreground="#FFFFFF"
                                   VerticalAlignment="Center" Margin="0,0,10,10"/>
                        <ComboBox Name="CmbAccent" Width="145" Height="36"
                                  Style="{StaticResource DarkComboBox}" Margin="0,0,15,10"/>
                    </StackPanel>
                    <StackPanel Grid.Row="9" Orientation="Horizontal" Margin="0,10,0,0">
                        <Button Name="BtnSaveSettings" Content="Save Settings" Width="130" Style="{StaticResource ToolButton}" Tag="settings save preferences"/>
                        <Button Name="BtnResetSettings" Content="Reset Settings" Width="130" Style="{StaticResource ToolButton}" Tag="settings reset defaults"/>
                        <Button Name="BtnUpdateTool" Content="Update Tool" Width="130" Style="{StaticResource ToolButton}" Tag="update tool refresh reload"/>
                        <Button Name="BtnOpenAppData" Content="Open App Folder" Width="140" Style="{StaticResource ToolButton}" Tag="open appdata folder"/>
                        <Button Name="BtnViewLog" Content="View Log" Width="110" Style="{StaticResource ToolButton}" Tag="log view file"/>
                    </StackPanel>
                </Grid>
            </TabItem>
        </TabControl>

        <Border Grid.Row="2" Background="#1A1A1A" BorderBrush="#333333"
                BorderThickness="1,1,1,0" Padding="15,10">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="280"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="130"/>
                </Grid.ColumnDefinitions>
                <TextBlock Name="StatusText" Grid.Column="0" Text="Ready."
                           Foreground="#00FF00" VerticalAlignment="Center" TextWrapping="Wrap"/>
                <ProgressBar Name="MainProgress" Grid.Column="1" Height="9" Minimum="0" Maximum="100"
                             Value="0" VerticalAlignment="Center" Margin="15,0"/>
                <TextBlock Name="ProgressText" Grid.Column="2" Foreground="#AAAAAA"
                           VerticalAlignment="Center" HorizontalAlignment="Right"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$Reader = New-Object System.Xml.XmlNodeReader $XAML
$Window = [Windows.Markup.XamlReader]::Load($Reader)

# ============================================================
# CONTROL REFERENCES
# ============================================================

$TitleText          = $Window.FindName("TitleText")
$SubtitleText       = $Window.FindName("SubtitleText")
$TxtSearch          = $Window.FindName("TxtSearch")
$MainTabs           = $Window.FindName("MainTabs")
$SystemInfoText     = $Window.FindName("SystemInfoText")
$StatusText         = $Window.FindName("StatusText")
$ProgressText       = $Window.FindName("ProgressText")
$MainProgress       = $Window.FindName("MainProgress")
$BtnRefreshInfo     = $Window.FindName("BtnRefreshInfo")
$BtnSFC             = $Window.FindName("BtnSFC")
$BtnWifi            = $Window.FindName("BtnWifi")
$BtnExportWifi      = $Window.FindName("BtnExportWifi")
$BtnKey             = $Window.FindName("BtnKey")
$CategoryHost       = $Window.FindName("CategoryHost")
$script:CategoryPanels = @{}
$script:CategoryHeaders = @()
$TxtDownloadFolder  = $Window.FindName("TxtDownloadFolder")
$BtnBrowseFolder    = $Window.FindName("BtnBrowseFolder")
$ChkConfirmActions  = $Window.FindName("ChkConfirmActions")
$ChkAutoRefresh     = $Window.FindName("ChkAutoRefresh")
$ChkShowToasts      = $Window.FindName("ChkShowToasts")
$ChkEnableLog       = $Window.FindName("ChkEnableLog")
$CmbAccent          = $Window.FindName("CmbAccent")
$BtnSaveSettings    = $Window.FindName("BtnSaveSettings")
$BtnResetSettings   = $Window.FindName("BtnResetSettings")
$BtnUpdateTool      = $Window.FindName("BtnUpdateTool")
$BtnOpenAppData     = $Window.FindName("BtnOpenAppData")
$BtnViewLog         = $Window.FindName("BtnViewLog")

$Window.Title = "CrazyAlexTool $script:AppVersion"
$SubtitleText.Text = "Windows utility and maintenance tools - v$script:AppVersion"

# ============================================================
# UI HELPERS
# ============================================================

function New-Brush {
    param([string]$Color)
    if ([string]::IsNullOrWhiteSpace($Color)) { $Color = "#FFFFFF" }
    $conv = New-Object System.Windows.Media.BrushConverter
    return $conv.ConvertFromString($Color)
}

function Set-Status {
    param([string]$Message, [string]$Color = "#AAAAAA")
    $StatusText.Text = $Message
    $StatusText.Foreground = New-Brush $Color
}

function Set-Progress {
    param([double]$Percent = 0, [string]$Text = "", [switch]$Indeterminate)
    $MainProgress.IsIndeterminate = $Indeterminate.IsPresent
    if (-not $Indeterminate.IsPresent) {
        $MainProgress.Value = [Math]::Max(0, [Math]::Min(100, $Percent))
    }
    $ProgressText.Text = $Text
}

function Pump-UI {
    try {
        $Window.Dispatcher.Invoke(
            [Action]{},
            [System.Windows.Threading.DispatcherPriority]::Background
        )
    } catch { }
}

function Show-ToolError {
    param([string]$Name, [object]$Exception)
    $message = if ($Exception) { $Exception.Exception.Message } else { "Unknown error." }
    Write-Log "ERROR in $Name : $message" "ERROR"
    Set-Status "Error: $Name" "#FF5555"
    Set-Progress -Percent 0
    [System.Windows.MessageBox]::Show(
        "$Name`n`n$message", "CrazyAlexTool Error",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
}

function Confirm-Action {
    param([string]$Message, [string]$Title = "Confirm Action")
    if ($ChkConfirmActions.IsChecked -ne $true) { return $true }
    $r = [System.Windows.MessageBox]::Show(
        $Message, $Title,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    return ($r -eq [System.Windows.MessageBoxResult]::Yes)
}

# ============================================================
# TOAST
# ============================================================

$script:ToastNotifier = $null

function Show-Toast {
    param([string]$Title, [string]$Message, [string]$Type = "Info")
    if ($script:Settings.ShowToasts -eq $false) { return }
    try {
        if (-not $script:ToastNotifier) {
            $script:ToastNotifier = New-Object System.Windows.Forms.NotifyIcon
            $script:ToastNotifier.Icon = [System.Drawing.SystemIcons]::Information
            $script:ToastNotifier.Visible = $true
            $script:ToastNotifier.Text = "CrazyAlexTool"
        }
        $icon = switch ($Type) {
            "Warning" { [System.Windows.Forms.ToolTipIcon]::Warning }
            "Error"   { [System.Windows.Forms.ToolTipIcon]::Error }
            default   { [System.Windows.Forms.ToolTipIcon]::Info }
        }
        $script:ToastNotifier.ShowBalloonTip(4000, $Title, $Message, $icon)
    } catch { Write-Log "Toast failed: $($_.Exception.Message)" "WARN" }
}

# ============================================================
# BACKGROUND JOB SYSTEM
# ============================================================

function Start-BackgroundTask {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock,
        [scriptblock]$OnComplete = { param($result) },
        [object[]]$ArgumentList = @()
    )
    Write-Log "Starting background task: $Name"
    Set-Status "$Name running in background..." "#FFFF00"
    $job = Start-Job -Name $Name -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
    $script:ActiveJobs[$job.Id] = @{
        Name = $Name; Job = $job; OnComplete = $OnComplete; StartTime = Get-Date
    }
    return $job
}

$script:JobPoller = New-Object System.Windows.Threading.DispatcherTimer
$script:JobPoller.Interval = [TimeSpan]::FromMilliseconds(500)
$script:JobPoller.Add_Tick({
    if ($script:ActiveJobs.Count -eq 0) { return }
    $keysToRemove = @()
    foreach ($id in @($script:ActiveJobs.Keys)) {
        $entry = $script:ActiveJobs[$id]
        $job = $entry.Job
        if ($job.State -in @("Completed", "Failed", "Stopped")) {
            try {
                $result = Receive-Job $job -ErrorAction SilentlyContinue
                if ($job.State -eq "Failed") {
                    $err = $job.ChildJobs[0].JobStateInfo.Reason
                    Write-Log "Task $($entry.Name) failed: $err" "ERROR"
                    Set-Status "$($entry.Name) failed." "#FF5555"
                    Show-Toast "$($entry.Name) failed" "See log for details" "Error"
                } else {
                    Write-Log "Task $($entry.Name) completed"
                    & $entry.OnComplete $result
                }
            } catch { Write-Log "Task cleanup failed: $($_.Exception.Message)" "ERROR" }
            finally {
                Remove-Job $job -Force -ErrorAction SilentlyContinue
                $keysToRemove += $id
            }
        }
    }
    foreach ($k in $keysToRemove) { $script:ActiveJobs.Remove($k) }
    if ($script:ActiveJobs.Count -eq 0) { Set-Progress -Percent 100 -Text "" }
})
$script:JobPoller.Start()

# ============================================================
# DOWNLOAD FUNCTIONS
# ============================================================

function Invoke-TrackedDownload {
    param([string]$Url, [string]$OutputFile)
    if ($Url -notmatch '^https://') { throw "Only HTTPS downloads are allowed." }
    $parent = Split-Path -Path $OutputFile -Parent
    if (-not (Test-Path $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }

    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.UserAgent = "CrazyAlexTool"
    $req.AllowAutoRedirect = $true
    $resp = $null; $in = $null; $out = $null
    try {
        $resp = $req.GetResponse()
        $in = $resp.GetResponseStream()
        $out = New-Object System.IO.FileStream($OutputFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        $total = $resp.ContentLength
        $done = [int64]0
        $buffer = New-Object byte[] 65536
        if ($total -gt 0) { Set-Progress -Percent 0 -Text "0%" } else { Set-Progress -Indeterminate -Text "Downloading" }
        while ($true) {
            $r = $in.Read($buffer, 0, $buffer.Length)
            if ($r -le 0) { break }
            $out.Write($buffer, 0, $r)
            $done += $r
            if ($total -gt 0) {
                $pct = ($done / $total) * 100
                $dMb = [Math]::Round($done / 1MB, 1)
                $tMb = [Math]::Round($total / 1MB, 1)
                Set-Progress -Percent $pct -Text "$dMb MB / $tMb MB"
            }
            Pump-UI
        }
        Set-Progress -Percent 100 -Text "Complete"
    } catch {
        Remove-Item -Path $OutputFile -Force -ErrorAction SilentlyContinue
        throw
    } finally {
        if ($out) { $out.Dispose() }
        if ($in) { $in.Dispose() }
        if ($resp) { $resp.Dispose() }
    }
}

function Start-DownloadedFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Downloaded file was not found: $Path" }
    $dir = Split-Path -Path $Path -Parent
    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($ext -in @(".bat", ".cmd")) {
        $wrap = "/d /c `"pushd `"$dir`" && call `"$Path`" & if errorlevel 1 (echo. & echo [Error] Press any key... & pause>nul)`""
        Start-Process -FilePath "cmd.exe" -ArgumentList $wrap -WorkingDirectory $dir -Wait
    } else {
        Start-Process -FilePath $Path -WorkingDirectory $dir -Wait
    }
}

function Invoke-SingleFileTool {
    param([string]$Name, [string]$Url, [string]$Extension)

    $normalizedExtension = [string]$Extension
    if (-not [string]::IsNullOrWhiteSpace($normalizedExtension)) {
        $normalizedExtension = $normalizedExtension.ToLowerInvariant()
    }

    # macOS packages cannot run on Windows. Keep them in the configured
    # download folder so the user can transfer/install them on a Mac.
    if ($normalizedExtension -eq ".pkg") {
        try {
            $downloadFolder = [string]$script:Settings.DownloadFolder
            if ([string]::IsNullOrWhiteSpace($downloadFolder)) { $downloadFolder = $script:DefaultDownloadFolder }
            if (-not (Test-Path $downloadFolder)) { New-Item -Path $downloadFolder -ItemType Directory -Force | Out-Null }

            $filePath = Join-Path $downloadFolder "$Name$Extension"
            Write-Log "Downloading macOS package: $Name"
            Set-Status "Downloading $Name..." "#FFFF00"
            Invoke-TrackedDownload -Url $Url -OutputFile $filePath
            Set-Status "$Name downloaded." "#00FF00"
            Show-Toast "Download finished" "$Name was saved to $filePath"
            Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$filePath`"" -ErrorAction SilentlyContinue | Out-Null
        }
        catch { Show-ToolError -Name $Name -Exception $_ }
        return
    }

    $filePath = Join-Path $script:TemporaryPath "$Name$Extension"
    try {
        Write-Log "Running single-file tool: $Name"
        Set-Status "Downloading $Name..." "#FFFF00"
        Invoke-TrackedDownload -Url $Url -OutputFile $filePath
        Set-Status "Running $Name..." "#FFFF00"
        Start-DownloadedFile -Path $filePath
        Set-Status "$Name completed." "#00FF00"
        Show-Toast "Tool finished" "$Name completed successfully"
    } catch { Show-ToolError -Name $Name -Exception $_ }
    finally { Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue }
}

# ============================================================
# BUILT-IN TOOLS
# ============================================================

function Invoke-GenP {
    try {
        Write-Log "GenP tool started"
        if (-not (Confirm-Action "Download GenP and choose a version to run?" "GenP Activator")) { return }
        $zipPath = Join-Path $script:TemporaryPath "GenP.zip"
        $extractPath = Join-Path $script:TemporaryPath "Extracted-GenP"
        if (Test-Path $extractPath) { Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

        Set-Status "Downloading GenP..." "#FFFF00"
        Invoke-TrackedDownload -Url $script:Links.GenP -OutputFile $zipPath
        Set-Status "Extracting GenP..." "#FFFF00"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        $releasesPath = Join-Path $extractPath "GenP-main\Releases"
        if (-not (Test-Path $releasesPath)) { $releasesPath = $extractPath }
        $exeList = @(Get-ChildItem -Path $releasesPath -Filter "*.exe" -File -Recurse -ErrorAction SilentlyContinue)
        if ($exeList.Count -eq 0) { throw "No .exe files found in GenP archive." }

        $selected = Show-FilePicker -Title "Select GenP Version" -Files $exeList
        if (-not $selected) { Set-Status "GenP cancelled." "#FFAA00"; return }

        Set-Status "Running $($selected.Name)..." "#FFFF00"
        Start-DownloadedFile -Path $selected.FullName
        Set-Status "GenP completed." "#00FF00"
        Show-Toast "GenP finished" "GenP completed successfully"
    } catch { Show-ToolError -Name "GenP" -Exception $_ }
    finally {
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-OfficeScrubber {
    try {
        Write-Log "Office Scrubber started"
        $opts = @(
            [pscustomobject]@{ Label="Scrub ALL"; Key="1" }
            [pscustomobject]@{ Label="Scrub Office C2R (*)"; Key="2" }
            [pscustomobject]@{ Label="Scrub Office 2016"; Key="3" }
            [pscustomobject]@{ Label="Scrub Office 2013"; Key="4" }
            [pscustomobject]@{ Label="Scrub Office 2010"; Key="5" }
            [pscustomobject]@{ Label="Scrub Office 2007"; Key="6" }
            [pscustomobject]@{ Label="Scrub Office 2003"; Key="7" }
            [pscustomobject]@{ Label="Scrub Office UWP"; Key="8" }
            [pscustomobject]@{ Label="Clean vNext Licenses"; Key="C" }
            [pscustomobject]@{ Label="Remove all Licenses"; Key="R" }
            [pscustomobject]@{ Label="Reset C2R Licenses"; Key="T" }
            [pscustomobject]@{ Label="Uninstall all Keys"; Key="U" }
        )
        $sel = Show-LabelPicker -Title "Office Scrubber" -Prompt "Choose which Office Scrubber action to run:" -Options $opts
        if (-not $sel) { Set-Status "Office Scrubber cancelled." "#FFAA00"; return }
        if (-not (Confirm-Action "Run Office Scrubber option:`n`n$($sel.Label)`n`nContinue?" "Office Scrubber")) { return }

        $zipPath = Join-Path $script:TemporaryPath "OfficeScrubber.zip"
        $extractPath = Join-Path $script:TemporaryPath "Extracted-OfficeScrubber"
        if (Test-Path $extractPath) { Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

        Set-Status "Downloading Office Scrubber..." "#FFFF00"
        Invoke-TrackedDownload -Url $script:Links.Scrubber -OutputFile $zipPath
        Set-Status "Extracting Office Scrubber..." "#FFFF00"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        $scrubberCmd = Get-ChildItem -Path $extractPath -Filter "OfficeScrubber.cmd" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $scrubberCmd) {
            $scrubberCmd = Get-ChildItem -Path $extractPath -Filter "*.cmd" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if (-not $scrubberCmd) { throw "OfficeScrubber.cmd not found." }

        Set-Status "Running: $($sel.Label)..." "#FFFF00"
        Set-Progress -Indeterminate -Text "Working..."
        $wd = $scrubberCmd.DirectoryName
        $cp = $scrubberCmd.FullName
        $wrap = "/d /c ""pushd """"$wd"""" && (echo $($sel.Key)& echo 0) | """"$cp"""" & if errorlevel 1 (echo. & echo [Error] Press any key... & pause>nul)"""
        Start-Process -FilePath "cmd.exe" -ArgumentList $wrap -WorkingDirectory $wd -Wait

        Set-Progress -Percent 100 -Text "Complete"
        Set-Status "Office Scrubber finished: $($sel.Label)" "#00FF00"
        Show-Toast "Office Scrubber done" $sel.Label
    } catch { Show-ToolError -Name "Office Scrubber" -Exception $_ }
    finally {
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Activate-WinRAR {
    try {
        Write-Log "WinRAR activation started"
        $paths = @( (Join-Path $env:ProgramFiles "WinRAR"), (Join-Path ${env:ProgramFiles(x86)} "WinRAR") )
        $folder = $paths | Where-Object { Test-Path (Join-Path $_ "WinRAR.exe") } | Select-Object -First 1
        if (-not $folder) {
            [System.Windows.MessageBox]::Show("WinRAR is not installed.", "WinRAR Not Found",
                [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            Set-Status "WinRAR not installed." "#FFAA00"; return
        }
        if (-not (Confirm-Action "WinRAR found at:`n$folder`n`nApply the license key?" "Activate WinRAR")) { return }

        $keyPath = Join-Path $script:TemporaryPath "rarreg.key"
        Set-Status "Downloading license..." "#FFFF00"
        Invoke-TrackedDownload -Url $script:Links.Winrar -OutputFile $keyPath

        $content = Get-Content -Path $keyPath -Raw -ErrorAction Stop
        if ($content -notmatch 'RAR registration data') { throw "Downloaded file is not a valid rarreg.key." }
        Copy-Item -Path $keyPath -Destination (Join-Path $folder "rarreg.key") -Force

        Set-Status "WinRAR activated!" "#00FF00"
        Show-Toast "WinRAR activated" "License applied successfully"
        [System.Windows.MessageBox]::Show("WinRAR has been activated.", "WinRAR Activated",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    } catch { Show-ToolError -Name "WinRAR Activation" -Exception $_ }
    finally { Remove-Item -Path $keyPath -Force -ErrorAction SilentlyContinue }
}

function Install-OfficeODT {
    try {
        Write-Log "Office ODT install started"
        if (-not (Confirm-Action "Download Microsoft Office Deployment Tool and start setup?" "Install Office")) { return }
        $odtFolder = Join-Path $script:TemporaryPath "ODT"
        if (Test-Path $odtFolder) { Remove-Item -Path $odtFolder -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -Path $odtFolder -ItemType Directory -Force | Out-Null

        $odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18227-20162.exe"
        $odtExe = Join-Path $odtFolder "ODT.exe"
        Set-Status "Downloading Office Deployment Tool..." "#FFFF00"
        Invoke-TrackedDownload -Url $odtUrl -OutputFile $odtExe

        Set-Status "Extracting ODT..." "#FFFF00"
        $p = Start-Process -FilePath $odtExe -ArgumentList "/extract:`"$odtFolder`" /quiet" -Wait -PassThru
        if ($p.ExitCode -ne 0) { throw "Failed to extract ODT." }

        $configXml = @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us"/>
      <ExcludeApp ID="Groove"/>
      <ExcludeApp ID="Lync"/>
    </Product>
  </Add>
  <Display Level="Full" AcceptEULA="TRUE"/>
</Configuration>
"@
        $cfg = Join-Path $odtFolder "config.xml"
        Set-Content -Path $cfg -Value $configXml -Encoding UTF8
        $setup = Join-Path $odtFolder "setup.exe"
        if (-not (Test-Path $setup)) { throw "setup.exe not found." }
        Set-Status "Launching Office installer..." "#FFFF00"
        Start-Process -FilePath $setup -ArgumentList "/configure `"$cfg`"" -Wait
        Set-Status "Office setup finished." "#00FF00"
        Show-Toast "Office setup finished" "Installer completed"
    } catch { Show-ToolError -Name "Office (ODT)" -Exception $_ }
}

# ============================================================
# PICKERS
# ============================================================

function Show-FilePicker {
    param([string]$Title = "Select an option", [System.IO.FileInfo[]]$Files)
    [xml]$PickerXAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Height="260" Width="440" WindowStartupLocation="CenterOwner"
        Background="#1A1A1A" ResizeMode="NoResize" FontFamily="Segoe UI">
    <Window.Resources>
        <Style x:Key="PickerComboItem" TargetType="{x:Type ComboBoxItem}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBoxItem}">
                        <Border x:Name="ItemBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter TextElement.Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="#005F73"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="#174A5A"/>
                                <Setter Property="Foreground" Value="#00FFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="PickerComboBox" TargetType="{x:Type ComboBox}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="BorderBrush" Value="#444444"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="ItemContainerStyle" Value="{StaticResource PickerComboItem}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBox}">
                        <Grid>
                            <ToggleButton Focusable="False" ClickMode="Press"
                                          IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="{x:Type ToggleButton}">
                                        <Border x:Name="PickerToggle" Background="#25252B" BorderBrush="#444444"
                                                BorderThickness="1" CornerRadius="4">
                                            <Path Data="M 0 0 L 5 5 L 10 0 Z" Fill="#FFFFFF"
                                                  HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,12,0"/>
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True">
                                                <Setter TargetName="PickerToggle" Property="BorderBrush" Value="#00FFFF"/>
                                            </Trigger>
                                            <Trigger Property="IsChecked" Value="True">
                                                <Setter TargetName="PickerToggle" Property="BorderBrush" Value="#00FFFF"/>
                                            </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter Content="{TemplateBinding SelectionBoxItem}"
                                              Margin="10,0,35,0" VerticalAlignment="Center"
                                              IsHitTestVisible="False" TextElement.Foreground="#FFFFFF"/>
                            <Popup Placement="Bottom" AllowsTransparency="True" Focusable="False"
                                   IsOpen="{TemplateBinding IsDropDownOpen}">
                                <Border Background="#1E1E22" BorderBrush="#00FFFF" BorderThickness="1"
                                        CornerRadius="4" MinWidth="{TemplateBinding ActualWidth}">
                                    <ScrollViewer MaxHeight="260"><ItemsPresenter/></ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <StackPanel Margin="22">
        <TextBlock Text="Select an option to run:" Foreground="#00FFFF" FontSize="14" FontWeight="Bold" Margin="0,0,0,16"/>
        <ComboBox Name="CmbFiles" Style="{StaticResource PickerComboBox}" Height="38" FontSize="13" Margin="0,0,0,20"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="BtnCancel" Content="Cancel" Width="100" Height="36" Margin="0,0,10,0"
                    Background="#2A2A30" Foreground="White" BorderThickness="1" BorderBrush="#444444" Cursor="Hand"/>
            <Button Name="BtnRun" Content="Run Selected" Width="140" Height="36"
                    Background="#00B4D8" Foreground="White" BorderThickness="0" Cursor="Hand" FontWeight="SemiBold"/>
        </StackPanel>
    </StackPanel>
</Window>
"@
    $r = New-Object System.Xml.XmlNodeReader $PickerXAML
    $pw = [Windows.Markup.XamlReader]::Load($r)
    $c = $pw.FindName("CmbFiles"); $br = $pw.FindName("BtnRun"); $bc = $pw.FindName("BtnCancel")
    foreach ($f in $Files) { [void]$c.Items.Add($f.Name) }
    $c.SelectedIndex = 0
    $script:PickerResult = $null
    $br.Add_Click({ $chosen = $c.SelectedItem; $script:PickerResult = $Files | Where-Object { $_.Name -eq $chosen } | Select-Object -First 1; $pw.Close() })
    $bc.Add_Click({ $script:PickerResult = $null; $pw.Close() })
    $pw.Owner = $Window
    [void]$pw.ShowDialog()
    return $script:PickerResult
}

function Show-LabelPicker {
    param([string]$Title = "Select an option", [string]$Prompt = "Select:", [object[]]$Options)
    [xml]$PickerXAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Height="280" Width="460" WindowStartupLocation="CenterOwner"
        Background="#1A1A1A" ResizeMode="NoResize" FontFamily="Segoe UI">
    <Window.Resources>
        <Style x:Key="PickerComboItem" TargetType="{x:Type ComboBoxItem}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBoxItem}">
                        <Border x:Name="ItemBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter TextElement.Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="#005F73"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="#174A5A"/>
                                <Setter Property="Foreground" Value="#00FFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="PickerComboBox" TargetType="{x:Type ComboBox}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="BorderBrush" Value="#444444"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="ItemContainerStyle" Value="{StaticResource PickerComboItem}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBox}">
                        <Grid>
                            <ToggleButton Focusable="False" ClickMode="Press"
                                          IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="{x:Type ToggleButton}">
                                        <Border x:Name="PickerToggle" Background="#25252B" BorderBrush="#444444"
                                                BorderThickness="1" CornerRadius="4">
                                            <Path Data="M 0 0 L 5 5 L 10 0 Z" Fill="#FFFFFF"
                                                  HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,12,0"/>
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True">
                                                <Setter TargetName="PickerToggle" Property="BorderBrush" Value="#00FFFF"/>
                                            </Trigger>
                                            <Trigger Property="IsChecked" Value="True">
                                                <Setter TargetName="PickerToggle" Property="BorderBrush" Value="#00FFFF"/>
                                            </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter Content="{TemplateBinding SelectionBoxItem}"
                                              Margin="10,0,35,0" VerticalAlignment="Center"
                                              IsHitTestVisible="False" TextElement.Foreground="#FFFFFF"/>
                            <Popup Placement="Bottom" AllowsTransparency="True" Focusable="False"
                                   IsOpen="{TemplateBinding IsDropDownOpen}">
                                <Border Background="#1E1E22" BorderBrush="#00FFFF" BorderThickness="1"
                                        CornerRadius="4" MinWidth="{TemplateBinding ActualWidth}">
                                    <ScrollViewer MaxHeight="260"><ItemsPresenter/></ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <StackPanel Margin="22">
        <TextBlock Text="$Prompt" Foreground="#00FFFF" FontSize="14" FontWeight="Bold" Margin="0,0,0,16" TextWrapping="Wrap"/>
        <ComboBox Name="CmbOptions" Style="{StaticResource PickerComboBox}" Height="38" FontSize="13" Margin="0,0,0,22"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="BtnCancel" Content="Cancel" Width="100" Height="36" Margin="0,0,10,0"
                    Background="#2A2A30" Foreground="White" BorderThickness="1" BorderBrush="#444444" Cursor="Hand"/>
            <Button Name="BtnRun" Content="Run Selected" Width="140" Height="36"
                    Background="#00B4D8" Foreground="White" BorderThickness="0" Cursor="Hand" FontWeight="SemiBold"/>
        </StackPanel>
    </StackPanel>
</Window>
"@
    $r = New-Object System.Xml.XmlNodeReader $PickerXAML
    $pw = [Windows.Markup.XamlReader]::Load($r)
    $c = $pw.FindName("CmbOptions"); $br = $pw.FindName("BtnRun"); $bc = $pw.FindName("BtnCancel")
    foreach ($o in $Options) { [void]$c.Items.Add($o.Label) }
    $c.SelectedIndex = 0
    $script:LabelPickerResult = $null
    $br.Add_Click({ $ch = $c.SelectedItem; $script:LabelPickerResult = $Options | Where-Object { $_.Label -eq $ch } | Select-Object -First 1; $pw.Close() })
    $bc.Add_Click({ $script:LabelPickerResult = $null; $pw.Close() })
    $pw.Owner = $Window
    [void]$pw.ShowDialog()
    return $script:LabelPickerResult
}

# ============================================================
# SYSTEM INFORMATION (no temperatures)
# ============================================================

function Get-DrivesInfoBlock {
    $ptd = @{}
    try {
        $disks = Get-CimInstance Win32_DiskDrive -ErrorAction Stop
        foreach ($d in $disks) {
            $parts = Get-CimAssociatedInstance -InputObject $d -ResultClassName Win32_DiskPartition -ErrorAction SilentlyContinue
            foreach ($p in $parts) {
                $lds = Get-CimAssociatedInstance -InputObject $p -ResultClassName Win32_LogicalDisk -ErrorAction SilentlyContinue
                foreach ($ld in $lds) { $ptd[$ld.DeviceID] = $d.Model.Trim() }
            }
        }
    } catch { }

    $lds = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -in 2,3,4,5 }
    $map = @{ 2="Removable Drive"; 3="Local Disk"; 4="Network Drive"; 5="CD/DVD Drive" }
    $lines = foreach ($ld in $lds) {
        $model = $ptd[$ld.DeviceID]
        if (-not $model) { $model = $map[[int]$ld.DriveType]; if (-not $model) { $model = "Unknown" } }
        if ($ld.Size -gt 0) {
            $s = [Math]::Round($ld.Size / 1GB, 0); $f = [Math]::Round($ld.FreeSpace / 1GB, 0)
            $u = [Math]::Round((($ld.Size - $ld.FreeSpace) / $ld.Size) * 100, 0)
            "  $($ld.DeviceID)  $model  |  $f GB free of $s GB ($u% used)"
        } else { "  $($ld.DeviceID)  $model  |  (no media)" }
    }
    if ($lines) { return $lines -join [Environment]::NewLine } else { return "  (No drives detected)" }
}

function Get-BatteryInfoLine {
    try {
        $b = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if (-not $b) { return $null }
        $m = @{ 1="Discharging"; 2="On AC"; 3="Fully Charged"; 4="Low"; 5="Critical"; 6="Charging"; 7="Charging High"; 8="Charging Low"; 9="Charging Critical"; 10="Undefined"; 11="Partially Charged" }
        $s = $m[[int]$b.BatteryStatus]; if (-not $s) { $s = "Unknown" }
        return "Battery          : $($b.EstimatedChargeRemaining)% ($s)"
    } catch { return $null }
}

function Get-NetworkInfoLines {
    try {
        $a = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
            Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
        if (-not $a) { return @() }
        $l = @("Network          : $($a.InterfaceAlias)")
        if ($a.IPv4Address) { $l += "IPv4 Address     : $($a.IPv4Address[0].IPAddress)" }
        if ($a.IPv4DefaultGateway) { $l += "Gateway          : $($a.IPv4DefaultGateway[0].NextHop)" }
        return $l
    } catch { return @() }
}

function Update-SystemInformation {
    try {
        Set-Status "Reading system information..." "#FFFF00"
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $comp = Get-CimInstance Win32_ComputerSystem
        $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1

        $totalRam = [Math]::Round($comp.TotalPhysicalMemory / 1GB, 2)
        $freeRam = [Math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedRam = [Math]::Round($totalRam - $freeRam, 2)
        $up = (Get-Date) - $os.LastBootUpTime

        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add("Operating System : $($os.Caption)")
        $lines.Add("Version          : $($os.Version)")
        $lines.Add("Computer         : $($env:COMPUTERNAME)")
        $lines.Add("User             : $($env:USERNAME)")
        $lines.Add("")
        $lines.Add("CPU              : $($cpu.Name)")
        $lines.Add("GPU              : $($gpu.Name)")
        $lines.Add("RAM              : $usedRam GB used of $totalRam GB")

        $bl = Get-BatteryInfoLine
        if ($bl) { $lines.Add($bl) }

        $nl = Get-NetworkInfoLines
        if ($nl.Count -gt 0) { $lines.Add(""); foreach ($n in $nl) { $lines.Add($n) } }

        $lines.Add("")
        $lines.Add("Drives:")
        $lines.Add((Get-DrivesInfoBlock))
        $lines.Add("")
        $lines.Add("Uptime           : $($up.Days) days, $($up.Hours) hours")

        $SystemInfoText.Text = $lines -join [Environment]::NewLine
        Set-Status "System information updated." "#00FF00"
    } catch { Show-ToolError -Name "System information" -Exception $_ }
}

# ============================================================
# QUICK ACTIONS (background)
# ============================================================

function Invoke-SFCScan {
    if (-not (Confirm-Action "Run an SFC system scan in the background?")) { return }
    Start-BackgroundTask -Name "SFC Scan" -ScriptBlock {
        $out = & sfc.exe /scannow 2>&1 | Out-String
        return @{ Output = $out; ExitCode = $LASTEXITCODE }
    } -OnComplete {
        param($r)
        if ($r.ExitCode -eq 0 -or $r.Output -match "Windows Resource Protection") {
            Set-Status "SFC scan completed." "#00FF00"
            Show-Toast "SFC scan finished" "System file check complete"
        } else {
            Set-Status "SFC scan finished with issues." "#FFAA00"
            Show-Toast "SFC scan finished" "Check log" "Warning"
        }
        Write-Log "SFC output: $($r.Output -replace '\r\n',' | ')"
    }
}

function Reset-Network {
    if (-not (Confirm-Action "Flush DNS and renew network in the background?")) { return }
    Start-BackgroundTask -Name "Network Reset" -ScriptBlock {
        $o = ""; $o += (& ipconfig.exe /flushdns 2>&1 | Out-String)
        $o += (& ipconfig.exe /release 2>&1 | Out-String)
        $o += (& ipconfig.exe /renew 2>&1 | Out-String); return $o
    } -OnComplete {
        param($r); Set-Status "Network reset completed." "#00FF00"
        Show-Toast "Network reset" "DNS flushed and IP renewed"
    }
}

function Export-WiFiPasswords {
    if (-not (Confirm-Action "Export saved Wi-Fi passwords? File will contain sensitive data." "Wi-Fi Export")) { return }
    $d = New-Object System.Windows.Forms.SaveFileDialog
    $d.Title = "Export Wi-Fi Profiles"; $d.Filter = "Text files (*.txt)|*.txt"
    $d.FileName = "WiFi-Passwords-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $d.InitialDirectory = $script:Settings.DownloadFolder
    if ($d.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $outFile = $d.FileName

    Start-BackgroundTask -Name "Wi-Fi Export" -ScriptBlock {
        param($of)
        $po = & netsh.exe wlan show profiles 2>$null
        $ps = @( foreach ($ln in $po) { if ($ln -match '^\s*(All User Profile|User Profile)\s*:\s*(.+?)\s*$') { $Matches[2].Trim() } } ) | Sort-Object -Unique
        if ($ps.Count -eq 0) { throw "No Wi-Fi profiles found." }
        $out = New-Object System.Collections.Generic.List[string]
        $out.Add("CrazyAlexTool Wi-Fi Export"); $out.Add("Created: $(Get-Date)"); $out.Add("")
        foreach ($p in $ps) {
            $dt = & netsh.exe wlan show profile "name=$p" key=clear 2>$null
            $pw = $null
            foreach ($ln in $dt) { if ($ln -match '^\s*Key Content\s*:\s*(.*)$') { $pw = $Matches[1].Trim(); break } }
            if (-not $pw) { $pw = "[No password found]" }
            $out.Add("Profile: $p"); $out.Add("Password: $pw"); $out.Add("")
        }
        $out | Set-Content -Path $of -Encoding UTF8
        return $of
    } -ArgumentList $outFile -OnComplete {
        param($r); Set-Status "Wi-Fi export completed." "#00FF00"
        Show-Toast "Wi-Fi export done" "Saved to $r"
        [System.Windows.MessageBox]::Show("Wi-Fi profiles exported to:`n`n$r", "Export Complete",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    }
}

# ============================================================
# WINDOWS PRODUCT KEY (with clipboard)
# ============================================================

function Show-WindowsProductKey {
    try {
        Write-Log "Product key requested"
        $rp = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform"
        $key = (Get-ItemProperty -Path $rp -ErrorAction Stop).BackupProductKeyDefault
        if ($key) {
            $r = [System.Windows.MessageBox]::Show(
                "Windows Product Key:`n`n$key`n`nCopy to clipboard?", "Windows Product Key",
                [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Information)
            if ($r -eq [System.Windows.MessageBoxResult]::Yes) {
                Set-Clipboard -Value $key
                Set-Status "Product key copied to clipboard." "#00FF00"
                Show-Toast "Product key copied" "Ready to paste"
            } else { Set-Status "Product key displayed." "#00FF00" }
        } else {
            [System.Windows.MessageBox]::Show("No OEM product key found.", "Windows Product Key",
                [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            Set-Status "No OEM key found." "#FFAA00"
        }
    } catch { Show-ToolError -Name "Product key" -Exception $_ }
}

function Show-OfficeMacOSInstructions {
    $message = @"
This is a macOS-only button.

The selected .pkg file cannot run on Windows. If you continue, CrazyAlexTool will only DOWNLOAD the package so you can transfer it to a Mac.

Office Activation / Licensing - macOS

- Install Office for your macOS version if it is not already installed.
- If Office has previously been opened, use the Office-Reset tool to clean existing Office licensing state before changing licenses.
- If your organization provided a valid Microsoft Office LTSC 2024 volume-license serializer, install that package before opening Office apps.
- Open Office and confirm activation using your properly licensed Microsoft account or organization entitlement.

Press OK to download the selected macOS package, or Cancel to go back.
"@

    $result = [System.Windows.MessageBox]::Show(
        $message,
        "macOS-only tool",
        [System.Windows.MessageBoxButton]::OKCancel,
        [System.Windows.MessageBoxImage]::Warning
    )

    return ($result -eq [System.Windows.MessageBoxResult]::OK)
}

# ============================================================
# BUILD PANELS FROM tools.json
# ============================================================

function Build-ToolPanels {
    $CategoryHost.Children.Clear()
    $script:CategoryPanels = @{}
    $script:CategoryHeaders = @()

    $categoryIndex = 0
    foreach ($category in $script:ToolCategories) {
        $categoryId = [string]$category.id
        $categoryLabel = [string]$category.label

        $header = New-Object System.Windows.Controls.TextBlock
        $header.Text = $categoryLabel
        $header.Foreground = New-Brush "#00FFFF"
        $header.FontSize = 17
        $header.FontWeight = [System.Windows.FontWeights]::Bold
        if ($categoryIndex -eq 0) {
            $header.Margin = New-Object System.Windows.Thickness -ArgumentList 0,0,0,15
        }
        else {
            $header.Margin = New-Object System.Windows.Thickness -ArgumentList 0,25,0,15
        }
        [void]$CategoryHost.Children.Add($header)
        $script:CategoryHeaders += $header

        $panel = New-Object System.Windows.Controls.WrapPanel
        [void]$CategoryHost.Children.Add($panel)
        $script:CategoryPanels[$categoryId] = $panel
        $categoryIndex++
    }

    foreach ($tool in $script:ToolCatalog) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $tool.label
        $btn.Width = [double]($tool.width)
        $btn.Height = 48
        $btn.Style = $Window.FindResource("ToolButton")
        $btn.Tag = $tool.tag
        $btn.Name = "BtnTool_$($tool.id)"
        $btn.Add_Click({
            param($sender, $args)
            $id = $sender.Name.Substring(8)
            $t = $script:ToolCatalog | Where-Object { $_.id -eq $id } | Select-Object -First 1
            if (-not $t) { return }

            # macOS-only tools remain downloadable from Windows, but Windows
            # always warns that the selected package cannot run on this OS.
            if ((Get-CatalogToolPlatform $t) -eq "macos") {
                if (-not (Show-OfficeMacOSInstructions)) {
                    Set-Status "macOS tool cancelled." "#FFAA00"
                    return
                }
            }

            try {
                if ($t.type -eq "builtin") { & $t.action }
                elseif ($t.type -eq "single-file") {
                    Invoke-SingleFileTool -Name $t.id -Url $t.url -Extension $t.extension
                }
                else {
                    throw "Unsupported tool type '$($t.type)' for '$($t.id)'."
                }
            } catch { Show-ToolError -Name $t.label -Exception $_ }
        })

        $categoryId = [string]$tool.category
        if ($script:CategoryPanels.ContainsKey($categoryId)) {
            [void]$script:CategoryPanels[$categoryId].Children.Add($btn)
        }
        else {
            Write-Log "Skipping tool '$($tool.id)': category '$categoryId' does not exist." "WARN"
        }
    }
}

# ============================================================
# SETTINGS UI
# ============================================================

function Apply-AccentColor {
    $an = [string]$CmbAccent.SelectedItem
    if ([string]::IsNullOrWhiteSpace($an) -or -not $script:AccentMap.Contains($an)) { $an = "Cyan" }
    $ch = $script:AccentMap[$an]; if ([string]::IsNullOrWhiteSpace($ch)) { $ch = "#00FFFF" }
    $b = New-Brush $ch
    $script:Settings.Accent = $an
    foreach ($n in @("TitleText","HdrSystemInfo","HdrQuickTools","HdrSettings")) {
        $c = $Window.FindName($n); if ($c) { $c.Foreground = $b }
    }
    foreach ($header in $script:CategoryHeaders) {
        if ($header) { $header.Foreground = $b }
    }
    if ($MainProgress) { $MainProgress.Foreground = $b }
}

function Save-SettingsFromUI {
    try {
        $f = $TxtDownloadFolder.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($f)) { $f = $script:DefaultDownloadFolder }
        if (-not (Test-Path $f)) { New-Item -Path $f -ItemType Directory -Force | Out-Null }
        $script:Settings.DownloadFolder = $f
        $script:Settings.ConfirmActions = ($ChkConfirmActions.IsChecked -eq $true)
        $script:Settings.AutoRefresh = ($ChkAutoRefresh.IsChecked -eq $true)
        $script:Settings.ShowToasts = ($ChkShowToasts.IsChecked -eq $true)
        $script:Settings.EnableLog = ($ChkEnableLog.IsChecked -eq $true)
        $script:Settings.Accent = [string]$CmbAccent.SelectedItem
        Save-AppSettings
        Apply-AccentColor
        if ($script:Settings.AutoRefresh) { $script:InfoTimer.Start() } else { $script:InfoTimer.Stop() }
        Set-Status "Settings saved." "#00FF00"; Write-Log "Settings saved"
    } catch { Show-ToolError -Name "Saving settings" -Exception $_ }
}

function Reset-Settings {
    if (-not (Confirm-Action "Reset settings to defaults?")) { return }
    $TxtDownloadFolder.Text = $script:DefaultSettings.DownloadFolder
    $ChkConfirmActions.IsChecked = $script:DefaultSettings.ConfirmActions
    $ChkAutoRefresh.IsChecked = $script:DefaultSettings.AutoRefresh
    $ChkShowToasts.IsChecked = $script:DefaultSettings.ShowToasts
    $ChkEnableLog.IsChecked = $script:DefaultSettings.EnableLog
    $CmbAccent.SelectedItem = $script:DefaultSettings.Accent
    Save-SettingsFromUI
}

# ============================================================
# SEARCH
# ============================================================

function Get-AllSearchableControls {
    $l = @($BtnRefreshInfo, $BtnSFC, $BtnWifi, $BtnExportWifi, $BtnKey,
           $BtnSaveSettings, $BtnResetSettings, $BtnUpdateTool, $BtnOpenAppData, $BtnViewLog)
    foreach ($panel in $script:CategoryPanels.Values) {
        foreach ($c in $panel.Children) { $l += $c }
    }
    return $l
}

function Filter-Tools {
    $q = $TxtSearch.Text.Trim().ToLowerInvariant()
    foreach ($c in (Get-AllSearchableControls)) {
        $ct = [string]$c.Content; $tg = [string]$c.Tag
        $st = "$ct $tg".ToLowerInvariant()
        $m = [string]::IsNullOrWhiteSpace($q) -or $st.Contains($q)
        $c.Visibility = if ($m) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    }
}

# ============================================================
# DRIVE RIGHT-CLICK MENU
# ============================================================

$SystemInfoText.Add_MouseRightButtonUp({
    $menu = New-Object System.Windows.Controls.ContextMenu
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
    foreach ($drive in $drives) {
        $sm = New-Object System.Windows.Controls.MenuItem
        $sm.Header = "$($drive.DeviceID) drive"
        $letter = $drive.DeviceID
        $oi = New-Object System.Windows.Controls.MenuItem
        $oi.Header = "Open in Explorer"
        $oi.Add_Click([Windows.RoutedEventHandler]{ Start-Process explorer.exe $letter }.GetNewClosure())
        [void]$sm.Items.Add($oi)
        $pi = New-Object System.Windows.Controls.MenuItem
        $pi.Header = "Show Properties"
        $pi.Add_Click([Windows.RoutedEventHandler]{
            $sh = New-Object -ComObject Shell.Application
            $fo = $sh.Namespace($letter)
            if ($fo) { $fo.Self.InvokeVerb("Properties") }
        }.GetNewClosure())
        [void]$sm.Items.Add($pi)
        [void]$menu.Items.Add($sm)
    }
    $SystemInfoText.ContextMenu = $menu
    $menu.IsOpen = $true
})

# ============================================================
# INITIALIZATION
# ============================================================

foreach ($an in $script:AccentMap.Keys) { [void]$CmbAccent.Items.Add($an) }
$folder = $script:Settings.DownloadFolder
if ([string]::IsNullOrWhiteSpace($folder)) { $folder = $script:DefaultSettings.DownloadFolder }
$TxtDownloadFolder.Text = [string]$folder
$ChkConfirmActions.IsChecked = [bool]$script:Settings.ConfirmActions
$ChkAutoRefresh.IsChecked = [bool]$script:Settings.AutoRefresh
$ChkShowToasts.IsChecked = [bool]$script:Settings.ShowToasts
$ChkEnableLog.IsChecked = [bool]$script:Settings.EnableLog
$as = $script:Settings.Accent
if ([string]::IsNullOrWhiteSpace($as) -or -not $script:AccentMap.Contains($as)) { $as = "Cyan" }
$CmbAccent.SelectedItem = $as

Build-ToolPanels
Apply-AccentColor
$SystemInfoText.Text = "Loading system information..."
Set-Status "Ready." "#00FF00"

$script:InfoTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:InfoTimer.Interval = [TimeSpan]::FromSeconds(10)
$script:InfoTimer.Add_Tick({ if ($ChkAutoRefresh.IsChecked -eq $true) { Update-SystemInformation } })

# ============================================================
# EVENT WIRING
# ============================================================

$TxtSearch.Add_TextChanged({ Filter-Tools })
$BtnRefreshInfo.Add_Click({ Update-SystemInformation })
$BtnSFC.Add_Click({ Invoke-SFCScan })
$BtnWifi.Add_Click({ Reset-Network })
$BtnExportWifi.Add_Click({ Export-WiFiPasswords })
$BtnKey.Add_Click({ Show-WindowsProductKey })

$BtnBrowseFolder.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = "Select the CrazyAlexTool download folder"
    $d.SelectedPath = $TxtDownloadFolder.Text
    if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $TxtDownloadFolder.Text = $d.SelectedPath }
})

$BtnSaveSettings.Add_Click({ Save-SettingsFromUI })
$BtnResetSettings.Add_Click({ Reset-Settings })

$BtnUpdateTool.Add_Click({
    if (-not (Confirm-Action "Restart CrazyAlexTool with the latest version from GitHub?" "Update Tool")) { return }
    Write-Log "Update Tool triggered"
    $Window.Close()
    $updateCommand = 'irm "https://crazyalex15.github.io/win?x=$(Get-Random)" | iex'
    Start-Process powershell.exe -ArgumentList @("-NoProfile", "-Command", $updateCommand)
})

$BtnOpenAppData.Add_Click({ Start-Process explorer.exe $script:AppDataPath })
$BtnViewLog.Add_Click({
    if (Test-Path $script:LogPath) { Start-Process notepad.exe $script:LogPath }
    else { [System.Windows.MessageBox]::Show("Log file does not exist yet.", "View Log") | Out-Null }
})

$ChkAutoRefresh.Add_Click({
    if ($ChkAutoRefresh.IsChecked -eq $true) { $script:InfoTimer.Start() } else { $script:InfoTimer.Stop() }
})
$CmbAccent.Add_SelectionChanged({ Apply-AccentColor })


# Let WPF paint the window first. Slow CIM/WMI work and GitHub refreshes begin
# shortly afterward, which makes startup feel much faster without requiring PS7.
$Window.Add_ContentRendered({
    if ($script:StartupComplete -eq $true) { return }
    $script:StartupComplete = $true

    $script:StartupTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:StartupTimer.Interval = [TimeSpan]::FromMilliseconds(150)
    $script:StartupTimer.Add_Tick({
        $script:StartupTimer.Stop()
        $script:StartupTimer = $null

        try { Update-SystemInformation } catch { }
        if ($script:Settings.AutoRefresh -and $ChkAutoRefresh.IsChecked -eq $true) {
            $script:InfoTimer.Start()
        }

        Start-ToolCatalogRefresh
    })
    $script:StartupTimer.Start()
})

$Window.Add_Closing({
    param($s, $e)
    if ($script:ActiveJobs.Count -gt 0) {
        $rn = ($script:ActiveJobs.Values | ForEach-Object { $_.Name }) -join ", "
        $r = [System.Windows.MessageBox]::Show(
            "Background tasks still running:`n`n$rn`n`nClose anyway?", "Task in progress",
            [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($r -ne [System.Windows.MessageBoxResult]::Yes) { $e.Cancel = $true; return }
        foreach ($en in $script:ActiveJobs.Values) {
            try { Stop-Job $en.Job -ErrorAction SilentlyContinue; Remove-Job $en.Job -Force -ErrorAction SilentlyContinue } catch { }
        }
    }
    try {
        if ($script:JobPoller) { $script:JobPoller.Stop() }
        if ($script:InfoTimer) { $script:InfoTimer.Stop(); $script:InfoTimer = $null }
        if ($script:StartupTimer) { $script:StartupTimer.Stop(); $script:StartupTimer = $null }
        if ($script:CatalogRefreshTimer) { $script:CatalogRefreshTimer.Stop(); $script:CatalogRefreshTimer = $null }
        if ($script:CatalogRefreshJob) {
            Stop-Job $script:CatalogRefreshJob -ErrorAction SilentlyContinue
            Remove-Job $script:CatalogRefreshJob -Force -ErrorAction SilentlyContinue
            $script:CatalogRefreshJob = $null
        }
    } catch { }
    try {
        $script:Settings.DownloadFolder = $TxtDownloadFolder.Text
        $script:Settings.ConfirmActions = ($ChkConfirmActions.IsChecked -eq $true)
        $script:Settings.AutoRefresh = ($ChkAutoRefresh.IsChecked -eq $true)
        $script:Settings.ShowToasts = ($ChkShowToasts.IsChecked -eq $true)
        $script:Settings.EnableLog = ($ChkEnableLog.IsChecked -eq $true)
        $script:Settings.Accent = [string]$CmbAccent.SelectedItem
        Save-AppSettings
    } catch { }
    try { if ($script:ToastNotifier) { $script:ToastNotifier.Visible = $false; $script:ToastNotifier.Dispose() } } catch { }
    try { Remove-Item -Path $script:TemporaryPath -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    Write-Log "CrazyAlexTool closed"
})

$Window.Add_Closed({
    try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() } catch { }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers(); [GC]::Collect()
})

[void]$Window.ShowDialog()
