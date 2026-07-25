#requires -Version 5.1

<#
.SYNOPSIS
    CrazyAlexTool

.DESCRIPTION
    Windows utility and maintenance tool with:
    - Office setup (via Microsoft Office Deployment Tool)
    - Office Scrubber (WPF dropdown replaces CMD menu)
    - Win Office Tools
    - WinRAR activation (license apply only)
    - GenP activator (dropdown picker)
    - System Update
    - Download progress
    - System information dashboard (all drives + battery + network + GPU temps)
    - SFC scan (background)
    - Network reset (background)
    - Wi-Fi profile / password export (background)
    - Windows product-key lookup with clipboard copy
    - Search bar
    - Settings panel
    - Update Tool button
    - Toast notifications
    - Log file
    - Right-click drives for Explorer / Properties
    - External tools.json config
    - Dark-themed WPF interface

.EXAMPLE
    irm https://crazyalex15.github.io/win | iex
#>

# ============================================================
# VERSION MARKER
# ============================================================

$script:AppVersion = "1.3.0"
Write-Host "[i] Loading CrazyAlexTool $script:AppVersion" -ForegroundColor Cyan

# ============================================================
# CLEAN SLATE (safe to re-run in the same PowerShell session)
# ============================================================

$leftoverVarNames = @(
    "AppName", "AppDataPath", "SettingsPath", "TemporaryPath", "LogPath",
    "DefaultDownloadFolder", "Links", "AccentMap",
    "DefaultSettings", "Settings", "InfoTimer",
    "SearchableControls", "PickerResult", "LabelPickerResult",
    "RemoteScriptUrl", "ToolsJsonUrl", "LhmDllUrl",
    "Window", "Reader", "XAML",
    "TitleText", "SubtitleText", "TxtSearch", "MainTabs",
    "SystemInfoText", "StatusText", "ProgressText", "MainProgress",
    "BtnRefreshInfo", "BtnSFC", "BtnWifi", "BtnExportWifi", "BtnKey",
    "OfficePanel", "ScriptsPanel",
    "TxtDownloadFolder", "BtnBrowseFolder", "ChkConfirmActions",
    "ChkAutoRefresh", "CmbAccent", "BtnSaveSettings", "BtnResetSettings",
    "BtnUpdateTool", "BtnOpenAppData", "BtnViewLog",
    "ActiveJobs", "JobPoller",
    "LhmComputer", "LhmLoaded",
    "ToolCatalog"
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

[GC]::Collect()
[GC]::WaitForPendingFinalizers()
[GC]::Collect()

# ============================================================
# REMOTE EXECUTION / ADMINISTRATOR BOOTSTRAP
# Always relaunch in fresh Windows PowerShell 5.1
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
            $scriptPath = Join-Path $env:TEMP `
                ("CrazyAlexTool-" + [Guid]::NewGuid().ToString("N") + ".ps1")

            $remoteResponse = Invoke-WebRequest -Uri $script:RemoteScriptUrl -UseBasicParsing -ErrorAction Stop
            $remoteCode = [string]$remoteResponse.Content

            if ([string]::IsNullOrWhiteSpace($remoteCode)) {
                throw "The remote script was empty."
            }

            $trimmed = $remoteCode.TrimStart()
            if ($trimmed -match '^<!DOCTYPE\s+html' -or $trimmed -match '^<html\b') {
                throw "The remote URL returned HTML instead of PowerShell."
            }

            $utf8 = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($scriptPath, $remoteCode, $utf8)
        }

        $powershellPath = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
        if (-not (Test-Path $powershellPath)) {
            throw "Windows PowerShell 5.1 not found."
        }

        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

        if (Test-IsAdministrator) {
            Start-Process -FilePath $powershellPath -ArgumentList $arguments -ErrorAction Stop | Out-Null
        }
        else {
            Start-Process -FilePath $powershellPath -ArgumentList $arguments -Verb RunAs -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-Error "Could not launch CrazyAlexTool: $($_.Exception.Message)"
    }

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

# LibreHardwareMonitor DLL for temperature readings (all GPU vendors)
$script:LhmDllUrl = "https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases/download/v0.9.4/LibreHardwareMonitorLib.dll"
$script:LhmDllPath = Join-Path $script:AppDataPath "LibreHardwareMonitorLib.dll"
$script:LhmComputer = $null
$script:LhmLoaded = $false

# Hardcoded fallback links (used only if tools.json fails to load)
$script:Links = [ordered]@{
    Scrubber = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/OfficeScrubber.zip"
    WinTools = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/WinOfficeTools.bat"
    Winrar   = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/rarreg.key"
    Update   = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/UpdateSystemWithPSCheck.bat"
    GenP     = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/GenP-main.zip"
}

$script:AccentMap = [ordered]@{
    Cyan   = "#00FFFF"
    Blue   = "#4DA3FF"
    Green  = "#66D17A"
    Orange = "#FFB347"
    Purple = "#C084FC"
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
# LOGGING
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
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    if ($script:Settings -and $script:Settings.EnableLog -eq $false) {
        return
    }

    try {
        Initialize-AppData
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp [$Level] $Message" | Add-Content -Path $script:LogPath -ErrorAction SilentlyContinue

        # Trim log if over 500KB
        if ((Test-Path $script:LogPath) -and (Get-Item $script:LogPath).Length -gt 500KB) {
            $lines = Get-Content $script:LogPath -Tail 2000
            Set-Content $script:LogPath -Value $lines -Encoding UTF8
        }
    } catch { }
}

# ============================================================
# SETTINGS
# ============================================================

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
        }
        catch {
            Write-Warning "Could not load settings: $($_.Exception.Message)"
        }
    }
}

function Save-AppSettings {
    try {
        Initialize-AppData
        $script:Settings | ConvertTo-Json | Set-Content -Path $script:SettingsPath -Encoding UTF8
    }
    catch {
        Write-Warning "Could not save settings: $($_.Exception.Message)"
    }
}

Load-AppSettings
Write-Log "CrazyAlexTool $script:AppVersion started"

# ============================================================
# LOAD tools.json (with hardcoded fallback)
# ============================================================

function Load-ToolCatalog {
    try {
        $response = Invoke-WebRequest -Uri $script:ToolsJsonUrl -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
        $parsed = $response.Content | ConvertFrom-Json

        if ($parsed.tools) {
            $script:ToolCatalog = $parsed.tools
            Write-Log "Loaded tools.json from remote ($($script:ToolCatalog.Count) tools)"
            return
        }
    }
    catch {
        Write-Log "Failed to load tools.json: $($_.Exception.Message)" "WARN"
    }

    # Fallback catalog
    Write-Log "Using hardcoded fallback tool catalog"
    $script:ToolCatalog = @(
        [pscustomobject]@{ id="officeODT"; label="Install Office (ODT)"; type="builtin"; action="Install-OfficeODT"; category="office"; width=205; tag="office setup installer microsoft odt" }
        [pscustomobject]@{ id="scrubber"; label="Office Scrubber"; type="builtin"; action="Invoke-OfficeScrubber"; category="office"; width=205; tag="office scrubber cleanup remove" }
        [pscustomobject]@{ id="winTools"; label="Win Office Tools"; type="single-file"; url=$script:Links.WinTools; extension=".bat"; category="office"; width=205; tag="office windows tools" }
        [pscustomobject]@{ id="winrar"; label="Activate WinRAR"; type="builtin"; action="Activate-WinRAR"; category="office"; width=205; tag="winrar activate license key" }
        [pscustomobject]@{ id="genp"; label="GenP Activator"; type="builtin"; action="Invoke-GenP"; category="scripts"; width=205; tag="genp activator adobe" }
        [pscustomobject]@{ id="update"; label="System Update"; type="single-file"; url=$script:Links.Update; extension=".bat"; category="scripts"; width=205; tag="system update windows update" }
    )
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
                        <Border x:Name="ItemBorder"
                                Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}">
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
                            <ToggleButton x:Name="ToggleButton" Focusable="False" ClickMode="Press"
                                IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="{x:Type ToggleButton}">
                                        <Border x:Name="ToggleBorder" Background="#25252B" BorderBrush="#444444"
                                                BorderThickness="1" CornerRadius="4">
                                            <Grid>
                                                <Path Data="M 0 0 L 5 5 L 10 0 Z" Fill="#FFFFFF"
                                                      HorizontalAlignment="Right" VerticalAlignment="Center"
                                                      Margin="0,0,12,0"/>
                                            </Grid>
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True">
                                                <Setter TargetName="ToggleBorder" Property="BorderBrush" Value="#00FFFF"/>
                                            </Trigger>
                                            <Trigger Property="IsChecked" Value="True">
                                                <Setter TargetName="ToggleBorder" Property="BorderBrush" Value="#00FFFF"/>
                                            </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              Margin="10,0,35,0" VerticalAlignment="Center"
                                              HorizontalAlignment="Left" IsHitTestVisible="False"
                                              TextElement.Foreground="#FFFFFF"/>
                            <Popup Placement="Bottom" AllowsTransparency="True" Focusable="False"
                                   IsOpen="{TemplateBinding IsDropDownOpen}">
                                <Border Background="#1E1E22" BorderBrush="#00FFFF" BorderThickness="1"
                                        CornerRadius="4" MinWidth="{TemplateBinding ActualWidth}">
                                    <ScrollViewer MaxHeight="260">
                                        <ItemsPresenter/>
                                    </ScrollViewer>
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
                        <Border x:Name="ButtonBorder" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"
                                              TextElement.Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Background" Value="#35353D"/>
                                <Setter TargetName="ButtonBorder" Property="BorderBrush" Value="#00FFFF"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Background" Value="#174A5A"/>
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
                <TextBlock Name="TitleText" Text="CrazyAlexTool"
                           Foreground="#00FFFF" FontSize="27" FontWeight="Bold"/>
                <TextBlock Name="SubtitleText" Text="Windows utility and maintenance tools"
                           Foreground="#888888" FontSize="12" Margin="0,2,0,0"/>
            </StackPanel>

            <TextBox Name="TxtSearch" Grid.Column="1" Height="36"
                     VerticalAlignment="Center" ToolTip="Search tools"/>
        </Grid>

        <TabControl Name="MainTabs" Grid.Row="1" Margin="18,0,18,10"
                    Background="#121212" BorderBrush="#333333">

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
                                       Foreground="#00FFFF" FontSize="16" FontWeight="Bold"
                                       Margin="0,0,0,15"/>

                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                <TextBlock Name="SystemInfoText" Foreground="#FFFFFF" FontSize="13"
                                           TextWrapping="Wrap" LineHeight="22" FontFamily="Consolas"/>
                            </ScrollViewer>

                            <Button Name="BtnRefreshInfo" Grid.Row="2" Content="Refresh System Information"
                                    Width="230" HorizontalAlignment="Left"
                                    Style="{StaticResource ToolButton}" Margin="0,15,0,0"
                                    Tag="system information dashboard refresh"/>
                        </Grid>
                    </Border>

                    <StackPanel Grid.Column="1">
                        <TextBlock Name="HdrQuickTools" Text="QUICK ACTIONS"
                                   Foreground="#00FFFF" FontSize="16" FontWeight="Bold" Margin="0,0,0,15"/>

                        <WrapPanel>
                            <Button Name="BtnSFC" Content="SFC Scan" Width="165"
                                    Style="{StaticResource ToolButton}" Tag="sfc system scan repair"/>
                            <Button Name="BtnWifi" Content="Fix Network" Width="165"
                                    Style="{StaticResource ToolButton}" Tag="wifi network dns reset"/>
                            <Button Name="BtnExportWifi" Content="Export Wi-Fi Passwords" Width="215"
                                    Style="{StaticResource ToolButton}" Tag="wifi wireless password export"/>
                            <Button Name="BtnKey" Content="Show Windows Key" Width="180"
                                    Style="{StaticResource ToolButton}" Tag="windows product key license"/>
                        </WrapPanel>

                        <Border Background="#211E18" BorderBrush="#66552F" BorderThickness="1"
                                CornerRadius="5" Padding="14" Margin="0,15,0,0">
                            <TextBlock Text="Long tasks run in the background - you can keep using the tool while they finish."
                                       Foreground="#E6C875" TextWrapping="Wrap" FontSize="12"/>
                        </Border>
                    </StackPanel>
                </Grid>
            </TabItem>

            <TabItem Header="Office Tools">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Margin="18">
                        <TextBlock Name="HdrOffice" Text="OFFICE TOOLS"
                                   Foreground="#00FFFF" FontSize="17" FontWeight="Bold" Margin="0,0,0,15"/>
                        <WrapPanel Name="OfficePanel"/>

                        <TextBlock Name="HdrScripts" Text="SCRIPTS"
                                   Foreground="#00FFFF" FontSize="17" FontWeight="Bold" Margin="0,25,0,15"/>
                        <WrapPanel Name="ScriptsPanel"/>

                        <Border Background="#211E18" BorderBrush="#66552F" BorderThickness="1"
                                CornerRadius="5" Padding="14" Margin="0,20,0,0">
                            <TextBlock Text="Only run tools from sources you trust. Downloaded files are stored temporarily and removed after execution."
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

                    <CheckBox Name="ChkConfirmActions" Grid.Row="3"
                              Content="Confirm sensitive actions" Margin="0,14,0,5"/>
                    <CheckBox Name="ChkAutoRefresh" Grid.Row="4"
                              Content="Automatically refresh system information" Margin="0,5,0,5"/>
                    <CheckBox Name="ChkShowToasts" Grid.Row="5"
                              Content="Show toast notifications when tasks complete" Margin="0,5,0,5"/>
                    <CheckBox Name="ChkEnableLog" Grid.Row="6"
                              Content="Enable log file" Margin="0,5,0,5"/>

                    <StackPanel Grid.Row="7" Orientation="Horizontal" Margin="0,18,0,0">
                        <TextBlock Text="Accent color:" Foreground="#FFFFFF"
                                   VerticalAlignment="Center" Margin="0,0,10,10"/>
                        <ComboBox Name="CmbAccent" Width="145" Height="36"
                                  Style="{StaticResource DarkComboBox}" Margin="0,0,15,10"/>
                    </StackPanel>

                    <StackPanel Grid.Row="9" Orientation="Horizontal" Margin="0,10,0,0">
                        <Button Name="BtnSaveSettings" Content="Save Settings" Width="130"
                                Style="{StaticResource ToolButton}" Tag="settings save preferences"/>
                        <Button Name="BtnResetSettings" Content="Reset Settings" Width="130"
                                Style="{StaticResource ToolButton}" Tag="settings reset defaults"/>
                        <Button Name="BtnUpdateTool" Content="Update Tool" Width="130"
                                Style="{StaticResource ToolButton}" Tag="update tool refresh reload"/>
                        <Button Name="BtnOpenAppData" Content="Open App Folder" Width="140"
                                Style="{StaticResource ToolButton}" Tag="open appdata folder"/>
                        <Button Name="BtnViewLog" Content="View Log" Width="110"
                                Style="{StaticResource ToolButton}" Tag="log view file"/>
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

$OfficePanel        = $Window.FindName("OfficePanel")
$ScriptsPanel       = $Window.FindName("ScriptsPanel")

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
    $converter = New-Object System.Windows.Media.BrushConverter
    return $converter.ConvertFromString($Color)
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
    $result = [System.Windows.MessageBox]::Show(
        $Message, $Title,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    return ($result -eq [System.Windows.MessageBoxResult]::Yes)
}

# ============================================================
# TOAST NOTIFICATIONS
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
            "Error" { [System.Windows.Forms.ToolTipIcon]::Error }
            default { [System.Windows.Forms.ToolTipIcon]::Info }
        }

        $script:ToastNotifier.ShowBalloonTip(4000, $Title, $Message, $icon)
    } catch {
        Write-Log "Toast failed: $($_.Exception.Message)" "WARN"
    }
}

# ============================================================
# BACKGROUND JOB SYSTEM
# ============================================================

function Start-BackgroundTask {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock,
        [scriptblock]$OnComplete = { param($result) }
    )

    Write-Log "Starting background task: $Name"
    Set-Status "$Name running in background..." "#FFFF00"

    $job = Start-Job -Name $Name -ScriptBlock $ScriptBlock

    $script:ActiveJobs[$job.Id] = @{
        Name = $Name
        Job = $job
        OnComplete = $OnComplete
        StartTime = Get-Date
    }

    return $job
}

# Timer polls active jobs and calls their OnComplete
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
                }
                else {
                    Write-Log "Task $($entry.Name) completed"
                    & $entry.OnComplete $result
                }
            }
            catch {
                Write-Log "Task cleanup failed: $($_.Exception.Message)" "ERROR"
            }
            finally {
                Remove-Job $job -Force -ErrorAction SilentlyContinue
                $keysToRemove += $id
            }
        }
    }

    foreach ($k in $keysToRemove) {
        $script:ActiveJobs.Remove($k)
    }

    if ($script:ActiveJobs.Count -eq 0) {
        Set-Progress -Percent 100 -Text ""
    }
})

$script:JobPoller.Start()

# ============================================================
# DOWNLOAD FUNCTIONS
# ============================================================

function Invoke-TrackedDownload {
    param([string]$Url, [string]$OutputFile)

    if ($Url -notmatch '^https://') { throw "Only HTTPS downloads are allowed." }

    $parent = Split-Path -Path $OutputFile -Parent
    if (-not (Test-Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.UserAgent = "CrazyAlexTool"
    $request.AllowAutoRedirect = $true

    $response = $null; $inputStream = $null; $outputStream = $null

    try {
        $response = $request.GetResponse()
        $inputStream = $response.GetResponseStream()
        $outputStream = New-Object System.IO.FileStream(
            $OutputFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write
        )

        $totalBytes = $response.ContentLength
        $downloadedBytes = [int64]0
        $buffer = New-Object byte[] 65536

        if ($totalBytes -gt 0) { Set-Progress -Percent 0 -Text "0%" }
        else { Set-Progress -Indeterminate -Text "Downloading" }

        while ($true) {
            $read = $inputStream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
            $outputStream.Write($buffer, 0, $read)
            $downloadedBytes += $read

            if ($totalBytes -gt 0) {
                $percent = ($downloadedBytes / $totalBytes) * 100
                $downloadedMb = [Math]::Round($downloadedBytes / 1MB, 1)
                $totalMb = [Math]::Round($totalBytes / 1MB, 1)
                Set-Progress -Percent $percent -Text "$downloadedMb MB / $totalMb MB"
            }
            Pump-UI
        }
        Set-Progress -Percent 100 -Text "Complete"
    }
    catch {
        Remove-Item -Path $OutputFile -Force -ErrorAction SilentlyContinue
        throw
    }
    finally {
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
        if ($response) { $response.Dispose() }
    }
}

function Start-DownloadedFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) { throw "Downloaded file was not found: $Path" }

    $directory = Split-Path -Path $Path -Parent
    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()

    if ($extension -in @(".bat", ".cmd")) {
        # Only pause if the script errors, so successful runs auto-close
        $wrapper = "/d /c `"pushd `"$directory`" && call `"$Path`" & if errorlevel 1 (echo. & echo [Error] Press any key to close... & pause>nul)`""
        Start-Process -FilePath "cmd.exe" -ArgumentList $wrapper -WorkingDirectory $directory -Wait
    }
    else {
        Start-Process -FilePath $Path -WorkingDirectory $directory -Wait
    }
}

function Invoke-SingleFileTool {
    param([string]$Name, [string]$Url, [string]$Extension)

    $filePath = Join-Path $script:TemporaryPath "$Name$Extension"

    try {
        Write-Log "Running single-file tool: $Name"
        Set-Status "Downloading $Name..." "#FFFF00"
        Invoke-TrackedDownload -Url $Url -OutputFile $filePath

        Set-Status "Running $Name..." "#FFFF00"
        Start-DownloadedFile -Path $filePath

        Set-Status "$Name completed." "#00FF00"
        Set-Progress -Percent 100 -Text "Complete"
        Show-Toast "Tool finished" "$Name completed successfully"
    }
    catch {
        Show-ToolError -Name $Name -Exception $_
    }
    finally {
        Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# FILE PICKER
# ============================================================

function Show-FilePicker {
    param([string]$Title = "Select an option", [System.IO.FileInfo[]]$Files)

    [xml]$PickerXAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Height="260" Width="440"
        WindowStartupLocation="CenterOwner" Background="#1A1A1A"
        ResizeMode="NoResize" FontFamily="Segoe UI">
    <Window.Resources>
        <Style x:Key="PCI" TargetType="{x:Type ComboBoxItem}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBoxItem}">
                        <Border x:Name="B" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter TextElement.Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="B" Property="Background" Value="#005F73"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="B" Property="Background" Value="#174A5A"/>
                                <Setter Property="Foreground" Value="#00FFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="PC" TargetType="{x:Type ComboBox}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="ItemContainerStyle" Value="{StaticResource PCI}"/>
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
                                    <ScrollViewer MaxHeight="300"><ItemsPresenter/></ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <StackPanel Margin="22">
        <TextBlock Text="Select an option to run:" Foreground="#00FFFF" FontSize="14"
                   FontWeight="Bold" Margin="0,0,0,16"/>
        <ComboBox Name="CmbFiles" Style="{StaticResource PC}" Height="38" FontSize="13" Margin="0,0,0,20"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="BtnCancel" Content="Cancel" Width="100" Height="36" Margin="0,0,10,0"
                    Background="#2A2A30" Foreground="White" BorderThickness="1" BorderBrush="#444444" Cursor="Hand"/>
            <Button Name="BtnRun" Content="Run Selected" Width="140" Height="36"
                    Background="#00B4D8" Foreground="White" BorderThickness="0" Cursor="Hand" FontWeight="SemiBold"/>
        </StackPanel>
    </StackPanel>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $PickerXAML
    $pickerWindow = [Windows.Markup.XamlReader]::Load($reader)
    $combo = $pickerWindow.FindName("CmbFiles")
    $btnRun = $pickerWindow.FindName("BtnRun")
    $btnCancel = $pickerWindow.FindName("BtnCancel")

    foreach ($f in $Files) { [void]$combo.Items.Add($f.Name) }
    $combo.SelectedIndex = 0

    $script:PickerResult = $null

    $btnRun.Add_Click({
        $chosen = $combo.SelectedItem
        $script:PickerResult = $Files | Where-Object { $_.Name -eq $chosen } | Select-Object -First 1
        $pickerWindow.Close()
    })
    $btnCancel.Add_Click({ $script:PickerResult = $null; $pickerWindow.Close() })

    $pickerWindow.Owner = $Window
    [void]$pickerWindow.ShowDialog()
    return $script:PickerResult
}

# ============================================================
# LABEL PICKER
# ============================================================

function Show-LabelPicker {
    param([string]$Title = "Select an option", [string]$Prompt = "Select an option:", [object[]]$Options)

    [xml]$PickerXAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Height="280" Width="460"
        WindowStartupLocation="CenterOwner" Background="#1A1A1A"
        ResizeMode="NoResize" FontFamily="Segoe UI">
    <Window.Resources>
        <Style x:Key="PCI" TargetType="{x:Type ComboBoxItem}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBoxItem}">
                        <Border x:Name="B" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter TextElement.Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="B" Property="Background" Value="#005F73"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="B" Property="Background" Value="#174A5A"/>
                                <Setter Property="Foreground" Value="#00FFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="PC" TargetType="{x:Type ComboBox}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="ItemContainerStyle" Value="{StaticResource PCI}"/>
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
                                    <ScrollViewer MaxHeight="300"><ItemsPresenter/></ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <StackPanel Margin="22">
        <TextBlock Text="$Prompt" Foreground="#00FFFF" FontSize="14"
                   FontWeight="Bold" Margin="0,0,0,16" TextWrapping="Wrap"/>
        <ComboBox Name="CmbOptions" Style="{StaticResource PC}" Height="38" FontSize="13" Margin="0,0,0,22"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="BtnCancel" Content="Cancel" Width="100" Height="36" Margin="0,0,10,0"
                    Background="#2A2A30" Foreground="White" BorderThickness="1" BorderBrush="#444444" Cursor="Hand"/>
            <Button Name="BtnRun" Content="Run Selected" Width="140" Height="36"
                    Background="#00B4D8" Foreground="White" BorderThickness="0" Cursor="Hand" FontWeight="SemiBold"/>
        </StackPanel>
    </StackPanel>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $PickerXAML
    $pickerWindow = [Windows.Markup.XamlReader]::Load($reader)
    $combo = $pickerWindow.FindName("CmbOptions")
    $btnRun = $pickerWindow.FindName("BtnRun")
    $btnCancel = $pickerWindow.FindName("BtnCancel")

    foreach ($opt in $Options) { [void]$combo.Items.Add($opt.Label) }
    $combo.SelectedIndex = 0

    $script:LabelPickerResult = $null
    $btnRun.Add_Click({
        $chosenLabel = $combo.SelectedItem
        $script:LabelPickerResult = $Options | Where-Object { $_.Label -eq $chosenLabel } | Select-Object -First 1
        $pickerWindow.Close()
    })
    $btnCancel.Add_Click({ $script:LabelPickerResult = $null; $pickerWindow.Close() })

    $pickerWindow.Owner = $Window
    [void]$pickerWindow.ShowDialog()
    return $script:LabelPickerResult
}

# ============================================================
# BUILT-IN TOOL FUNCTIONS
# ============================================================

function Invoke-GenP {
    try {
        Write-Log "GenP tool started"
        if (-not (Confirm-Action "Download GenP and choose a version to run?" "GenP Activator")) { return }

        $zipPath = Join-Path $script:TemporaryPath "GenP.zip"
        $extractPath = Join-Path $script:TemporaryPath "Extracted-GenP"

        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

        Set-Status "Downloading GenP..." "#FFFF00"
        Invoke-TrackedDownload -Url $script:Links.GenP -OutputFile $zipPath

        Set-Status "Extracting GenP..." "#FFFF00"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        $releasesPath = Join-Path $extractPath "GenP-main\Releases"
        if (-not (Test-Path $releasesPath)) { $releasesPath = $extractPath }

        $exeList = @(Get-ChildItem -Path $releasesPath -Filter "*.exe" -File -Recurse -ErrorAction SilentlyContinue)

        if ($exeList.Count -eq 0) {
            throw "No .exe files were found in GenP archive (may have been quarantined)."
        }

        $selected = Show-FilePicker -Title "Select GenP Version" -Files $exeList
        if (-not $selected) { Set-Status "GenP cancelled." "#FFAA00"; return }

        Set-Status "Running $($selected.Name)..." "#FFFF00"
        Start-DownloadedFile -Path $selected.FullName

        Set-Status "GenP completed." "#00FF00"
        Show-Toast "GenP finished" "GenP completed successfully"
    }
    catch { Show-ToolError -Name "GenP" -Exception $_ }
    finally {
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-OfficeScrubber {
    try {
        Write-Log "Office Scrubber started"
        $scrubberOptions = @(
            [pscustomobject]@{ Label = "Scrub ALL"; Key = "1" }
            [pscustomobject]@{ Label = "Scrub Office C2R (*)"; Key = "2" }
            [pscustomobject]@{ Label = "Scrub Office 2016"; Key = "3" }
            [pscustomobject]@{ Label = "Scrub Office 2013"; Key = "4" }
            [pscustomobject]@{ Label = "Scrub Office 2010"; Key = "5" }
            [pscustomobject]@{ Label = "Scrub Office 2007"; Key = "6" }
            [pscustomobject]@{ Label = "Scrub Office 2003"; Key = "7" }
            [pscustomobject]@{ Label = "Scrub Office UWP"; Key = "8" }
            [pscustomobject]@{ Label = "Clean vNext Licenses"; Key = "C" }
            [pscustomobject]@{ Label = "Remove all Licenses"; Key = "R" }
            [pscustomobject]@{ Label = "Reset C2R Licenses"; Key = "T" }
            [pscustomobject]@{ Label = "Uninstall all Keys"; Key = "U" }
        )

        $selected = Show-LabelPicker -Title "Office Scrubber" `
            -Prompt "Choose which Office Scrubber action to run:" -Options $scrubberOptions

        if (-not $selected) { Set-Status "Office Scrubber cancelled." "#FFAA00"; return }

        if (-not (Confirm-Action "Run Office Scrubber option:`n`n$($selected.Label)`n`nContinue?" "Office Scrubber")) { return }

        $zipPath = Join-Path $script:TemporaryPath "OfficeScrubber.zip"
        $extractPath = Join-Path $script:TemporaryPath "Extracted-OfficeScrubber"

        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

        Set-Status "Downloading Office Scrubber..." "#FFFF00"
        Invoke-TrackedDownload -Url $script:Links.Scrubber -OutputFile $zipPath

        Set-Status "Extracting Office Scrubber..." "#FFFF00"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        $scrubberCmd = Get-ChildItem -Path $extractPath -Filter "OfficeScrubber.cmd" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $scrubberCmd) {
            $scrubberCmd = Get-ChildItem -Path $extractPath -Filter "*.cmd" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if (-not $scrubberCmd) { throw "OfficeScrubber.cmd was not found." }

        Set-Status "Running: $($selected.Label)..." "#FFFF00"
        Set-Progress -Indeterminate -Text "Working..."

        $workingDir = $scrubberCmd.DirectoryName
        $cmdPath = $scrubberCmd.FullName
        $wrapper = "/d /c ""pushd """"$workingDir"""" && (echo $($selected.Key)& echo 0) | """"$cmdPath"""" & if errorlevel 1 (echo. & echo [Error] Press any key... & pause>nul)"""

        Start-Process -FilePath "cmd.exe" -ArgumentList $wrapper -WorkingDirectory $workingDir -Wait

        Set-Progress -Percent 100 -Text "Complete"
        Set-Status "Office Scrubber finished: $($selected.Label)" "#00FF00"
        Show-Toast "Office Scrubber done" $selected.Label
    }
    catch { Show-ToolError -Name "Office Scrubber" -Exception $_ }
    finally {
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Activate-WinRAR {
    try {
        Write-Log "WinRAR activation started"
        $possiblePaths = @(
            (Join-Path $env:ProgramFiles "WinRAR")
            (Join-Path ${env:ProgramFiles(x86)} "WinRAR")
        )
        $winrarFolder = $possiblePaths | Where-Object { Test-Path (Join-Path $_ "WinRAR.exe") } | Select-Object -First 1

        if (-not $winrarFolder) {
            [System.Windows.MessageBox]::Show(
                "WinRAR is not installed.`n`nInstall it from https://www.win-rar.com/download.html then try again.",
                "WinRAR Not Found",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            ) | Out-Null
            Set-Status "WinRAR not installed." "#FFAA00"
            return
        }

        if (-not (Confirm-Action "WinRAR found at:`n$winrarFolder`n`nApply the license key?" "Activate WinRAR")) { return }

        $keyPath = Join-Path $script:TemporaryPath "rarreg.key"
        Set-Status "Downloading license..." "#FFFF00"
        Invoke-TrackedDownload -Url $script:Links.Winrar -OutputFile $keyPath

        $content = Get-Content -Path $keyPath -Raw -ErrorAction Stop
        if ($content -notmatch 'RAR registration data') {
            throw "Downloaded file is not a valid rarreg.key."
        }

        Copy-Item -Path $keyPath -Destination (Join-Path $winrarFolder "rarreg.key") -Force

        Set-Status "WinRAR activated!" "#00FF00"
        Show-Toast "WinRAR activated" "License applied successfully"
        [System.Windows.MessageBox]::Show(
            "WinRAR has been activated.",
            "WinRAR Activated",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
    }
    catch { Show-ToolError -Name "WinRAR Activation" -Exception $_ }
    finally { Remove-Item -Path $keyPath -Force -ErrorAction SilentlyContinue }
}

function Install-OfficeODT {
    try {
        Write-Log "Office ODT install started"
        if (-not (Confirm-Action "Download Microsoft Office Deployment Tool and start setup?" "Install Office")) { return }

        $odtFolder = Join-Path $script:TemporaryPath "ODT"
        if (Test-Path $odtFolder) {
            Remove-Item -Path $odtFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path $odtFolder -ItemType Directory -Force | Out-Null

        $odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18227-20162.exe"
        $odtExe = Join-Path $odtFolder "ODT.exe"

        Set-Status "Downloading Office Deployment Tool..." "#FFFF00"
        Invoke-TrackedDownload -Url $odtUrl -OutputFile $odtExe

        Set-Status "Extracting ODT..." "#FFFF00"
        $extractProcess = Start-Process -FilePath $odtExe -ArgumentList "/extract:`"$odtFolder`" /quiet" -Wait -PassThru
        if ($extractProcess.ExitCode -ne 0) { throw "Failed to extract the ODT." }

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
        $configPath = Join-Path $odtFolder "config.xml"
        Set-Content -Path $configPath -Value $configXml -Encoding UTF8

        $setupExe = Join-Path $odtFolder "setup.exe"
        if (-not (Test-Path $setupExe)) { throw "setup.exe not found." }

        Set-Status "Launching Office installer..." "#FFFF00"
        Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configPath`"" -Wait

        Set-Status "Office setup finished." "#00FF00"
        Show-Toast "Office setup finished" "Installer completed"
    }
    catch { Show-ToolError -Name "Office (ODT)" -Exception $_ }
}

# ============================================================
# LIBREHARDWAREMONITOR (temps for NVIDIA, AMD, Intel, CPU)
# ============================================================

function Ensure-Lhm {
    if ($script:LhmLoaded) { return $true }

    try {
        if (-not (Test-Path $script:LhmDllPath)) {
            Write-Log "Downloading LibreHardwareMonitor DLL..."
            Set-Status "Downloading hardware monitor library (first-time only)..." "#FFFF00"

            $request = [System.Net.HttpWebRequest]::Create($script:LhmDllUrl)
            $request.UserAgent = "CrazyAlexTool"
            $response = $request.GetResponse()
            $inputStream = $response.GetResponseStream()
            $outputStream = New-Object System.IO.FileStream(
                $script:LhmDllPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write
            )
            $inputStream.CopyTo($outputStream)
            $outputStream.Dispose()
            $inputStream.Dispose()
            $response.Dispose()
        }

        # Unblock the DLL if needed
        try { Unblock-File -Path $script:LhmDllPath -ErrorAction SilentlyContinue } catch { }

        Add-Type -Path $script:LhmDllPath -ErrorAction Stop

        $script:LhmComputer = New-Object LibreHardwareMonitor.Hardware.Computer
        $script:LhmComputer.IsCpuEnabled = $true
        $script:LhmComputer.IsGpuEnabled = $true
        $script:LhmComputer.IsMotherboardEnabled = $false
        $script:LhmComputer.IsStorageEnabled = $false
        $script:LhmComputer.Open()

        $script:LhmLoaded = $true
        Write-Log "LibreHardwareMonitor loaded successfully"
        return $true
    }
    catch {
        Write-Log "LibreHardwareMonitor load failed: $($_.Exception.Message)" "WARN"
        return $false
    }
}

function Get-HardwareTemperatures {
    if (-not (Ensure-Lhm)) { return @{} }

    $temps = @{
        CPU = $null
        GPU = @()
    }

    try {
        foreach ($hw in $script:LhmComputer.Hardware) {
            $hw.Update()

            $isCpu = $hw.HardwareType.ToString() -match 'Cpu'
            $isGpu = $hw.HardwareType.ToString() -match 'Gpu'

            if (-not ($isCpu -or $isGpu)) { continue }

            foreach ($sensor in $hw.Sensors) {
                if ($sensor.SensorType.ToString() -ne "Temperature") { continue }
                if ($null -eq $sensor.Value) { continue }

                if ($isCpu -and ($sensor.Name -match 'Package|CPU|Tctl' -or -not $temps.CPU)) {
                    $temps.CPU = [Math]::Round($sensor.Value, 0)
                }
                elseif ($isGpu -and $sensor.Name -match 'Core|GPU|Hot Spot|Edge') {
                    $temps.GPU += [pscustomobject]@{
                        Name = $hw.Name
                        SensorName = $sensor.Name
                        Value = [Math]::Round($sensor.Value, 0)
                    }
                }
            }
        }
    } catch {
        Write-Log "Temperature read failed: $($_.Exception.Message)" "WARN"
    }

    return $temps
}

# ============================================================
# SYSTEM INFORMATION
# ============================================================

function Get-DrivesInfoBlock {
    $partitionToDisk = @{}
    try {
        $physicalDisks = Get-CimInstance Win32_DiskDrive -ErrorAction Stop
        foreach ($disk in $physicalDisks) {
            $partitions = Get-CimAssociatedInstance -InputObject $disk `
                -ResultClassName Win32_DiskPartition -ErrorAction SilentlyContinue
            foreach ($partition in $partitions) {
                $logicalDisksForPart = Get-CimAssociatedInstance -InputObject $partition `
                    -ResultClassName Win32_LogicalDisk -ErrorAction SilentlyContinue
                foreach ($ld in $logicalDisksForPart) {
                    $partitionToDisk[$ld.DeviceID] = $disk.Model.Trim()
                }
            }
        }
    } catch { }

    $logicalDisks = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue |
        Where-Object { $_.DriveType -in 2, 3, 4, 5 }

    $driveTypeMap = @{
        2 = "Removable Drive"; 3 = "Local Disk"
        4 = "Network Drive"; 5 = "CD/DVD Drive"
    }

    $lines = foreach ($ld in $logicalDisks) {
        $model = $partitionToDisk[$ld.DeviceID]
        if (-not $model) {
            $model = $driveTypeMap[[int]$ld.DriveType]
            if (-not $model) { $model = "Unknown" }
        }

        if ($ld.Size -gt 0) {
            $sizeGb = [Math]::Round($ld.Size / 1GB, 0)
            $freeGb = [Math]::Round($ld.FreeSpace / 1GB, 0)
            $usedPercent = [Math]::Round((($ld.Size - $ld.FreeSpace) / $ld.Size) * 100, 0)
            "  $($ld.DeviceID)  $model  |  $freeGb GB free of $sizeGb GB ($usedPercent% used)"
        }
        else {
            "  $($ld.DeviceID)  $model  |  (no media)"
        }
    }

    if ($lines) { return $lines -join [Environment]::NewLine }
    return "  (No drives detected)"
}

function Get-BatteryInfoLine {
    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if (-not $battery) { return $null }

        $statusMap = @{
            1 = "Discharging"; 2 = "On AC"; 3 = "Fully Charged"; 4 = "Low"
            5 = "Critical"; 6 = "Charging"; 7 = "Charging High"
            8 = "Charging Low"; 9 = "Charging Critical"; 10 = "Undefined"
            11 = "Partially Charged"
        }
        $statusText = $statusMap[[int]$battery.BatteryStatus]
        if (-not $statusText) { $statusText = "Unknown" }

        return "Battery          : $($battery.EstimatedChargeRemaining)% ($statusText)"
    } catch { return $null }
}

function Get-NetworkInfoLines {
    try {
        $adapter = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
            Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
            Select-Object -First 1

        if (-not $adapter) { return @() }

        $lines = @()
        $lines += "Network          : $($adapter.InterfaceAlias)"
        if ($adapter.IPv4Address) {
            $lines += "IPv4 Address     : $($adapter.IPv4Address[0].IPAddress)"
        }
        if ($adapter.IPv4DefaultGateway) {
            $lines += "Gateway          : $($adapter.IPv4DefaultGateway[0].NextHop)"
        }
        return $lines
    } catch { return @() }
}

function Update-SystemInformation {
    try {
        Set-Status "Reading system information..." "#FFFF00"

        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $computer = Get-CimInstance Win32_ComputerSystem
        $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1

        $totalRam = [Math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
        $freeRam = [Math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedRam = [Math]::Round($totalRam - $freeRam, 2)
        $uptime = (Get-Date) - $os.LastBootUpTime

        # Try to get temperatures (may fail silently)
        $temps = Get-HardwareTemperatures

        $cpuLine = "CPU              : $($cpu.Name)"
        if ($temps.CPU) { $cpuLine += "  ($($temps.CPU) C)" }

        $gpuLine = "GPU              : $($gpu.Name)"
        if ($temps.GPU.Count -gt 0) {
            $gpuTemp = $temps.GPU[0].Value
            $gpuLine += "  ($gpuTemp C)"
        }

        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add("Operating System : $($os.Caption)")
        $lines.Add("Version          : $($os.Version)")
        $lines.Add("Computer         : $($env:COMPUTERNAME)")
        $lines.Add("User             : $($env:USERNAME)")
        $lines.Add("")
        $lines.Add($cpuLine)
        $lines.Add($gpuLine)
        $lines.Add("RAM              : $usedRam GB used of $totalRam GB")

        $batteryLine = Get-BatteryInfoLine
        if ($batteryLine) { $lines.Add($batteryLine) }

        $netLines = Get-NetworkInfoLines
        if ($netLines.Count -gt 0) {
            $lines.Add("")
            foreach ($nl in $netLines) { $lines.Add($nl) }
        }

        $lines.Add("")
        $lines.Add("Drives:")
        $lines.Add((Get-DrivesInfoBlock))
        $lines.Add("")
        $lines.Add("Uptime           : $($uptime.Days) days, $($uptime.Hours) hours")

        $SystemInfoText.Text = $lines -join [Environment]::NewLine

        Set-Status "System information updated." "#00FF00"
    }
    catch { Show-ToolError -Name "System information" -Exception $_ }
}

# ============================================================
# QUICK ACTIONS (background jobs where appropriate)
# ============================================================

function Invoke-SFCScan {
    if (-not (Confirm-Action "Run an SFC system scan in the background?")) { return }

    Start-BackgroundTask -Name "SFC Scan" -ScriptBlock {
        $output = & sfc.exe /scannow 2>&1 | Out-String
        return @{ Output = $output; ExitCode = $LASTEXITCODE }
    } -OnComplete {
        param($result)
        if ($result.ExitCode -eq 0 -or $result.Output -match "Windows Resource Protection") {
            Set-Status "SFC scan completed." "#00FF00"
            Show-Toast "SFC scan finished" "System file check complete"
        } else {
            Set-Status "SFC scan finished with issues." "#FFAA00"
            Show-Toast "SFC scan finished" "Check log for details" "Warning"
        }
        Write-Log "SFC output: $($result.Output -replace '\r\n',' | ')" "INFO"
    }
}

function Reset-Network {
    if (-not (Confirm-Action "Flush DNS and renew network in the background?")) { return }

    Start-BackgroundTask -Name "Network Reset" -ScriptBlock {
        $out = ""
        $out += (& ipconfig.exe /flushdns 2>&1 | Out-String)
        $out += (& ipconfig.exe /release 2>&1 | Out-String)
        $out += (& ipconfig.exe /renew 2>&1 | Out-String)
        return $out
    } -OnComplete {
        param($result)
        Set-Status "Network reset completed." "#00FF00"
        Show-Toast "Network reset" "DNS flushed and IP renewed"
    }
}

function Export-WiFiPasswords {
    if (-not (Confirm-Action "Export saved Wi-Fi passwords? File will contain sensitive data." "Wi-Fi Export")) { return }

    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = "Export Wi-Fi Profiles"
    $dialog.Filter = "Text files (*.txt)|*.txt"
    $dialog.FileName = "WiFi-Passwords-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $dialog.InitialDirectory = $script:Settings.DownloadFolder

    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $outputFile = $dialog.FileName

    Start-BackgroundTask -Name "Wi-Fi Export" -ScriptBlock {
        param($outFile)

        $profileOutput = & netsh.exe wlan show profiles 2>$null
        $profiles = @(
            foreach ($line in $profileOutput) {
                if ($line -match '^\s*(All User Profile|User Profile)\s*:\s*(.+?)\s*$') {
                    $Matches[2].Trim()
                }
            }
        ) | Sort-Object -Unique

        if ($profiles.Count -eq 0) { throw "No Wi-Fi profiles found." }

        $output = New-Object System.Collections.Generic.List[string]
        $output.Add("CrazyAlexTool Wi-Fi Export")
        $output.Add("Created: $(Get-Date)")
        $output.Add("")

        foreach ($p in $profiles) {
            $details = & netsh.exe wlan show profile "name=$p" key=clear 2>$null
            $password = $null
            foreach ($line in $details) {
                if ($line -match '^\s*Key Content\s*:\s*(.*)$') {
                    $password = $Matches[1].Trim(); break
                }
            }
            if (-not $password) { $password = "[No password found]" }
            $output.Add("Profile: $p")
            $output.Add("Password: $password")
            $output.Add("")
        }

        $output | Set-Content -Path $outFile -Encoding UTF8
        return $outFile
    } -ArgumentList $outputFile -OnComplete {
        param($result)
        Set-Status "Wi-Fi export completed." "#00FF00"
        Show-Toast "Wi-Fi export done" "Saved to $result"
        [System.Windows.MessageBox]::Show(
            "Wi-Fi profiles exported to:`n`n$result",
            "Export Complete",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
    }
}

# We need to add -ArgumentList support to Start-BackgroundTask
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
        Name = $Name
        Job = $job
        OnComplete = $OnComplete
        StartTime = Get-Date
    }

    return $job
}

# ============================================================
# WINDOWS PRODUCT KEY (with clipboard copy)
# ============================================================

function Show-WindowsProductKey {
    try {
        Write-Log "Product key requested"
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform"
        $key = (Get-ItemProperty -Path $registryPath -ErrorAction Stop).BackupProductKeyDefault

        if ($key) {
            $result = [System.Windows.MessageBox]::Show(
                "Windows Product Key:`n`n$key`n`nCopy to clipboard?",
                "Windows Product Key",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Information
            )
            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                Set-Clipboard -Value $key
                Set-Status "Product key copied to clipboard." "#00FF00"
                Show-Toast "Product key copied" "Ready to paste"
            } else {
                Set-Status "Product key displayed." "#00FF00"
            }
        }
        else {
            [System.Windows.MessageBox]::Show(
                "No OEM product key was found in the registry.",
                "Windows Product Key",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
            Set-Status "No OEM key found." "#FFAA00"
        }
    }
    catch { Show-ToolError -Name "Product key" -Exception $_ }
}

# ============================================================
# BUILD OFFICE / SCRIPTS PANELS FROM tools.json
# ============================================================

function Build-ToolPanels {
    $OfficePanel.Children.Clear()
    $ScriptsPanel.Children.Clear()

    foreach ($tool in $script:ToolCatalog) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $tool.label
        $btn.Width = [double]($tool.width)
        $btn.Height = 48
        $btn.Style = $Window.FindResource("ToolButton")
        $btn.Tag = $tool.tag
        $btn.Name = "BtnTool_$($tool.id)"

        $toolRef = $tool  # capture

        $btn.Add_Click({
            param($sender, $args)
            $senderTool = $script:ToolCatalog | Where-Object { $_.id -eq $sender.Name.Substring(8) } | Select-Object -First 1
            if (-not $senderTool) { return }

            try {
                if ($senderTool.type -eq "builtin") {
                    & $senderTool.action
                }
                elseif ($senderTool.type -eq "single-file") {
                    Invoke-SingleFileTool -Name $senderTool.id -Url $senderTool.url -Extension $senderTool.extension
                }
                else {
                    Show-ToolError -Name $senderTool.label -Exception @{
                        Exception = @{ Message = "Unknown tool type: $($senderTool.type)" }
                    }
                }
            }
            catch { Show-ToolError -Name $senderTool.label -Exception $_ }
        })

        if ($tool.category -eq "office") {
            [void]$OfficePanel.Children.Add($btn)
        }
        else {
            [void]$ScriptsPanel.Children.Add($btn)
        }
    }
}

# ============================================================
# SETTINGS UI
# ============================================================

function Apply-AccentColor {
    $accentName = [string]$CmbAccent.SelectedItem
    if ([string]::IsNullOrWhiteSpace($accentName) -or -not $script:AccentMap.Contains($accentName)) {
        $accentName = "Cyan"
    }
    $colorHex = $script:AccentMap[$accentName]
    if ([string]::IsNullOrWhiteSpace($colorHex)) { $colorHex = "#00FFFF" }

    $brush = New-Brush $colorHex
    $script:Settings.Accent = $accentName

    foreach ($name in @("TitleText","HdrSystemInfo","HdrQuickTools","HdrOffice","HdrScripts","HdrSettings")) {
        $control = $Window.FindName($name)
        if ($control) { $control.Foreground = $brush }
    }
    if ($MainProgress) { $MainProgress.Foreground = $brush }
}

function Save-SettingsFromUI {
    try {
        $folder = $TxtDownloadFolder.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($folder)) { $folder = $script:DefaultDownloadFolder }
        if (-not (Test-Path $folder)) { New-Item -Path $folder -ItemType Directory -Force | Out-Null }

        $script:Settings.DownloadFolder = $folder
        $script:Settings.ConfirmActions = ($ChkConfirmActions.IsChecked -eq $true)
        $script:Settings.AutoRefresh = ($ChkAutoRefresh.IsChecked -eq $true)
        $script:Settings.ShowToasts = ($ChkShowToasts.IsChecked -eq $true)
        $script:Settings.EnableLog = ($ChkEnableLog.IsChecked -eq $true)
        $script:Settings.Accent = [string]$CmbAccent.SelectedItem

        Save-AppSettings
        Apply-AccentColor

        if ($script:Settings.AutoRefresh) { $script:InfoTimer.Start() } else { $script:InfoTimer.Stop() }

        Set-Status "Settings saved." "#00FF00"
        Write-Log "Settings saved"
    }
    catch { Show-ToolError -Name "Saving settings" -Exception $_ }
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
    $list = @(
        $BtnRefreshInfo, $BtnSFC, $BtnWifi, $BtnExportWifi, $BtnKey,
        $BtnSaveSettings, $BtnResetSettings, $BtnUpdateTool, $BtnOpenAppData, $BtnViewLog
    )
    foreach ($child in $OfficePanel.Children) { $list += $child }
    foreach ($child in $ScriptsPanel.Children) { $list += $child }
    return $list
}

function Filter-Tools {
    $query = $TxtSearch.Text.Trim().ToLowerInvariant()
    foreach ($control in (Get-AllSearchableControls)) {
        $content = [string]$control.Content
        $tag = [string]$control.Tag
        $searchText = "$content $tag".ToLowerInvariant()
        $isMatch = [string]::IsNullOrWhiteSpace($query) -or $searchText.Contains($query)
        $control.Visibility = if ($isMatch) {
            [System.Windows.Visibility]::Visible
        } else {
            [System.Windows.Visibility]::Collapsed
        }
    }
}

# ============================================================
# DRIVE CONTEXT MENU (right-click on system info)
# ============================================================

$SystemInfoText.Add_MouseRightButtonUp({
    $menu = New-Object System.Windows.Controls.ContextMenu

    # Get letter under cursor
    $pos = [System.Windows.Input.Mouse]::GetPosition($SystemInfoText)
    $hitTest = $SystemInfoText.InputHitTest($pos)

    # Simple: look at all fixed drives and offer them
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue

    foreach ($drive in $drives) {
        $subMenu = New-Object System.Windows.Controls.MenuItem
        $subMenu.Header = "$($drive.DeviceID) drive"

        $openItem = New-Object System.Windows.Controls.MenuItem
        $openItem.Header = "Open in Explorer"
        $letter = $drive.DeviceID
        $openItem.Add_Click([Windows.RoutedEventHandler]{
            Start-Process explorer.exe $letter
        }.GetNewClosure())
        [void]$subMenu.Items.Add($openItem)

        $propsItem = New-Object System.Windows.Controls.MenuItem
        $propsItem.Header = "Show Properties"
        $propsItem.Add_Click([Windows.RoutedEventHandler]{
            $shell = New-Object -ComObject Shell.Application
            $folder = $shell.Namespace($letter)
            if ($folder) { $folder.Self.InvokeVerb("Properties") }
        }.GetNewClosure())
        [void]$subMenu.Items.Add($propsItem)

        [void]$menu.Items.Add($subMenu)
    }

    $SystemInfoText.ContextMenu = $menu
    $menu.IsOpen = $true
})

# ============================================================
# INITIALIZATION
# ============================================================

foreach ($accentName in $script:AccentMap.Keys) {
    [void]$CmbAccent.Items.Add($accentName)
}

$folder = $script:Settings.DownloadFolder
if ([string]::IsNullOrWhiteSpace($folder)) { $folder = $script:DefaultSettings.DownloadFolder }
$TxtDownloadFolder.Text = [string]$folder

$ChkConfirmActions.IsChecked = [bool]$script:Settings.ConfirmActions
$ChkAutoRefresh.IsChecked = [bool]$script:Settings.AutoRefresh
$ChkShowToasts.IsChecked = [bool]$script:Settings.ShowToasts
$ChkEnableLog.IsChecked = [bool]$script:Settings.EnableLog

$accentToSelect = $script:Settings.Accent
if ([string]::IsNullOrWhiteSpace($accentToSelect) -or -not $script:AccentMap.Contains($accentToSelect)) {
    $accentToSelect = "Cyan"
}
$CmbAccent.SelectedItem = $accentToSelect

Build-ToolPanels
Apply-AccentColor
Update-SystemInformation

$script:InfoTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:InfoTimer.Interval = [TimeSpan]::FromSeconds(10)
$script:InfoTimer.Add_Tick({
    if ($ChkAutoRefresh.IsChecked -eq $true) { Update-SystemInformation }
})
if ($script:Settings.AutoRefresh) { $script:InfoTimer.Start() }

# ============================================================
# BUTTON EVENTS
# ============================================================

$TxtSearch.Add_TextChanged({ Filter-Tools })

$BtnRefreshInfo.Add_Click({ Update-SystemInformation })
$BtnSFC.Add_Click({ Invoke-SFCScan })
$BtnWifi.Add_Click({ Reset-Network })
$BtnExportWifi.Add_Click({ Export-WiFiPasswords })
$BtnKey.Add_Click({ Show-WindowsProductKey })

$BtnBrowseFolder.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the CrazyAlexTool download folder"
    $dialog.SelectedPath = $TxtDownloadFolder.Text
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtDownloadFolder.Text = $dialog.SelectedPath
    }
})

$BtnSaveSettings.Add_Click({ Save-SettingsFromUI })
$BtnResetSettings.Add_Click({ Reset-Settings })

$BtnUpdateTool.Add_Click({
    if (-not (Confirm-Action "Restart CrazyAlexTool from GitHub with the latest version?" "Update Tool")) { return }
    Write-Log "Update Tool triggered"
    $Window.Close()
    Start-Process powershell.exe -ArgumentList "-NoProfile -Command `"irm crazyalex15.github.io/win | iex`""
})

$BtnOpenAppData.Add_Click({ Start-Process explorer.exe $script:AppDataPath })

$BtnViewLog.Add_Click({
    if (Test-Path $script:LogPath) {
        Start-Process notepad.exe $script:LogPath
    } else {
        [System.Windows.MessageBox]::Show("Log file does not exist yet.", "View Log") | Out-Null
    }
})

$ChkAutoRefresh.Add_Click({
    if ($ChkAutoRefresh.IsChecked -eq $true) { $script:InfoTimer.Start() } else { $script:InfoTimer.Stop() }
})

$CmbAccent.Add_SelectionChanged({ Apply-AccentColor })

$Window.Add_Closing({
    param($sender, $eventArgs)

    # Warn if background jobs are still running
    if ($script:ActiveJobs.Count -gt 0) {
        $runningNames = ($script:ActiveJobs.Values | ForEach-Object { $_.Name }) -join ", "
        $result = [System.Windows.MessageBox]::Show(
            "Background tasks still running:`n`n$runningNames`n`nClose anyway?",
            "Task in progress",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($result -ne [System.Windows.MessageBoxResult]::Yes) {
            $eventArgs.Cancel = $true
            return
        }

        # Stop all jobs
        foreach ($entry in $script:ActiveJobs.Values) {
            try {
                Stop-Job $entry.Job -ErrorAction SilentlyContinue
                Remove-Job $entry.Job -Force -ErrorAction SilentlyContinue
            } catch { }
        }
    }

    try {
        if ($script:JobPoller) { $script:JobPoller.Stop() }
        if ($script:InfoTimer) { $script:InfoTimer.Stop(); $script:InfoTimer = $null }
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

    try {
        if ($script:LhmComputer) { $script:LhmComputer.Close() }
    } catch { }

    try {
        if ($script:ToastNotifier) {
            $script:ToastNotifier.Visible = $false
            $script:ToastNotifier.Dispose()
        }
    } catch { }

    try {
        Remove-Item -Path $script:TemporaryPath -Recurse -Force -ErrorAction SilentlyContinue
    } catch { }

    Write-Log "CrazyAlexTool closed"
})

$Window.Add_Closed({
    try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() } catch { }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers(); [GC]::Collect()
})

# ============================================================
# LAUNCH
# ============================================================

[void]$Window.ShowDialog()
