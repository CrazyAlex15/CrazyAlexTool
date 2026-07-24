#requires -Version 5.1

<#
.SYNOPSIS
    CrazyAlexTool

.DESCRIPTION
    Windows utility and maintenance tool with:
    - Office setup (via Microsoft Office Deployment Tool)
    - Office Scrubber (dropdown picker)
    - Win Office Tools
    - WinRAR (silent install + license apply)
    - System Update
    - Download progress
    - System information dashboard with all drives
    - SFC scan
    - Network reset
    - Wi-Fi profile / password export
    - Windows product-key lookup
    - Search bar
    - Settings panel
    - Dark-themed WPF interface

.EXAMPLE
    irm https://crazyalex15.github.io/win | iex
#>

# ============================================================
# VERSION MARKER
# ============================================================

$script:AppVersion = "1.1.0"
Write-Host "[i] Loading CrazyAlexTool $script:AppVersion" -ForegroundColor Cyan

# ============================================================
# REMOTE EXECUTION / ADMINISTRATOR BOOTSTRAP
# ============================================================

$script:RemoteScriptUrl = "https://raw.githubusercontent.com/CrazyAlex15/CrazyAlexTool/main/CrazyAlexTool.ps1"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

if (-not (Test-IsAdministrator)) {
    $temporaryScript = $null

    try {
        $scriptPath = $PSCommandPath

        if (
            [string]::IsNullOrWhiteSpace($scriptPath) -or
            -not (Test-Path -LiteralPath $scriptPath)
        ) {
            $temporaryScript = Join-Path `
                $env:TEMP `
                ("CrazyAlexTool-" + [Guid]::NewGuid().ToString("N") + ".ps1")

            $remoteResponse = Invoke-WebRequest `
                -Uri $script:RemoteScriptUrl `
                -UseBasicParsing `
                -ErrorAction Stop

            $remoteCode = [string]$remoteResponse.Content

            if ([string]::IsNullOrWhiteSpace($remoteCode)) {
                throw "The remote script was empty."
            }

            $trimmed = $remoteCode.TrimStart()

            if (
                $trimmed -match '^<!DOCTYPE\s+html' -or
                $trimmed -match '^<html\b'
            ) {
                throw "The remote URL returned an HTML page instead of PowerShell."
            }

            $utf8 = New-Object System.Text.UTF8Encoding($false)

            [System.IO.File]::WriteAllText(
                $temporaryScript,
                $remoteCode,
                $utf8
            )

            $scriptPath = $temporaryScript
        }

        $powershellPath = Join-Path $PSHOME "powershell.exe"

        if (-not (Test-Path $powershellPath)) {
            $powershellPath = "powershell.exe"
        }

        $arguments = @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            "`"$scriptPath`""
        ) -join " "

        Start-Process `
            -FilePath $powershellPath `
            -ArgumentList $arguments `
            -Verb RunAs `
            -Wait `
            -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Could not start CrazyAlexTool as administrator: $($_.Exception.Message)"
    }
    finally {
        if (
            $temporaryScript -and
            (Test-Path -LiteralPath $temporaryScript)
        ) {
            Remove-Item `
                -LiteralPath $temporaryScript `
                -Force `
                -ErrorAction SilentlyContinue
        }
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

[Net.ServicePointManager]::SecurityProtocol =
    [Net.SecurityProtocolType]::Tls12

# ============================================================
# CONFIGURATION
# ============================================================

$script:AppName = "CrazyAlexTool"
$script:AppDataPath = Join-Path $env:APPDATA $script:AppName
$script:SettingsPath = Join-Path $script:AppDataPath "settings.json"
$script:TemporaryPath = Join-Path $env:TEMP $script:AppName
$script:DefaultDownloadFolder = Join-Path $env:USERPROFILE "Downloads\CrazyAlexTool"

$script:Links = [ordered]@{
    Scrubber = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/OfficeScrubber.zip"
    WinTools = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/WinOfficeTools.bat"
    Winrar   = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/rarreg.key"
    Update   = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/UpdateSystemWithPSCheck.bat"
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
}

$script:Settings = [ordered]@{}

# ============================================================
# SETTINGS
# ============================================================

function Initialize-AppData {
    if (-not (Test-Path $script:AppDataPath)) {
        New-Item -Path $script:AppDataPath -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path $script:TemporaryPath)) {
        New-Item -Path $script:TemporaryPath -ItemType Directory -Force | Out-Null
    }
}

function Load-AppSettings {
    Initialize-AppData

    $script:Settings = [ordered]@{}
    foreach ($key in $script:DefaultSettings.Keys) {
        $script:Settings[$key] = $script:DefaultSettings[$key]
    }

    if (Test-Path $script:SettingsPath) {
        try {
            $saved = Get-Content -Path $script:SettingsPath -Raw -ErrorAction Stop |
                ConvertFrom-Json

            if ($saved.DownloadFolder) {
                $script:Settings.DownloadFolder = [string]$saved.DownloadFolder
            }
            if ($null -ne $saved.ConfirmActions) {
                $script:Settings.ConfirmActions = [bool]$saved.ConfirmActions
            }
            if ($null -ne $saved.AutoRefresh) {
                $script:Settings.AutoRefresh = [bool]$saved.AutoRefresh
            }
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
        $script:Settings |
            ConvertTo-Json |
            Set-Content -Path $script:SettingsPath -Encoding UTF8
    }
    catch {
        Write-Warning "Could not save settings: $($_.Exception.Message)"
    }
}

Load-AppSettings

# ============================================================
# WPF XAML
# ============================================================

[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="CrazyAlexTool"
        Height="780"
        Width="1080"
        MinHeight="700"
        MinWidth="920"
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
                            <ContentPresenter
                                Content="{TemplateBinding Content}"
                                ContentTemplate="{TemplateBinding ContentTemplate}"
                                TextElement.Foreground="{TemplateBinding Foreground}"/>
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
                            <ToggleButton x:Name="ToggleButton"
                                          Focusable="False"
                                          ClickMode="Press"
                                          IsChecked="{Binding IsDropDownOpen,
                                            RelativeSource={RelativeSource TemplatedParent},
                                            Mode=TwoWay}">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="{x:Type ToggleButton}">
                                        <Border x:Name="ToggleBorder"
                                                Background="#25252B"
                                                BorderBrush="#444444"
                                                BorderThickness="1"
                                                CornerRadius="4">
                                            <Grid>
                                                <Path Data="M 0 0 L 5 5 L 10 0 Z"
                                                      Fill="#FFFFFF"
                                                      HorizontalAlignment="Right"
                                                      VerticalAlignment="Center"
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

                            <ContentPresenter
                                Content="{TemplateBinding SelectionBoxItem}"
                                ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                Margin="10,0,35,0"
                                VerticalAlignment="Center"
                                HorizontalAlignment="Left"
                                IsHitTestVisible="False"
                                TextElement.Foreground="#FFFFFF"/>

                            <Popup x:Name="Popup"
                                   Placement="Bottom"
                                   AllowsTransparency="True"
                                   Focusable="False"
                                   IsOpen="{TemplateBinding IsDropDownOpen}">
                                <Border Background="#1E1E22"
                                        BorderBrush="#00FFFF"
                                        BorderThickness="1"
                                        CornerRadius="4"
                                        MinWidth="{TemplateBinding ActualWidth}">
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
                        <Border x:Name="ButtonBorder"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center"
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
                <TextBlock Name="TitleText"
                           Text="CrazyAlexTool"
                           Foreground="#00FFFF"
                           FontSize="27"
                           FontWeight="Bold"/>
                <TextBlock Name="SubtitleText"
                           Text="Windows utility and maintenance tools"
                           Foreground="#888888"
                           FontSize="12"
                           Margin="0,2,0,0"/>
            </StackPanel>

            <TextBox Name="TxtSearch"
                     Grid.Column="1"
                     Height="36"
                     VerticalAlignment="Center"
                     ToolTip="Search tools"/>
        </Grid>

        <TabControl Name="MainTabs"
                    Grid.Row="1"
                    Margin="18,0,18,10"
                    Background="#121212"
                    BorderBrush="#333333">

            <TabItem Header="Dashboard">
                <Grid Margin="18">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.15*"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Column="0"
                            Background="#1B1B1F"
                            BorderBrush="#333333"
                            BorderThickness="1"
                            CornerRadius="6"
                            Padding="18"
                            Margin="0,0,15,0">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <TextBlock Name="HdrSystemInfo"
                                       Grid.Row="0"
                                       Text="SYSTEM INFORMATION"
                                       Foreground="#00FFFF"
                                       FontSize="16"
                                       FontWeight="Bold"
                                       Margin="0,0,0,15"/>

                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                <TextBlock Name="SystemInfoText"
                                           Foreground="#FFFFFF"
                                           FontSize="13"
                                           TextWrapping="Wrap"
                                           LineHeight="22"
                                           FontFamily="Consolas"/>
                            </ScrollViewer>

                            <Button Name="BtnRefreshInfo"
                                    Grid.Row="2"
                                    Content="Refresh System Information"
                                    Width="230"
                                    HorizontalAlignment="Left"
                                    Style="{StaticResource ToolButton}"
                                    Margin="0,15,0,0"
                                    Tag="system information dashboard refresh"/>
                        </Grid>
                    </Border>

                    <StackPanel Grid.Column="1">
                        <TextBlock Name="HdrQuickTools"
                                   Text="QUICK ACTIONS"
                                   Foreground="#00FFFF"
                                   FontSize="16"
                                   FontWeight="Bold"
                                   Margin="0,0,0,15"/>

                        <WrapPanel>
                            <Button Name="BtnSFC"
                                    Content="SFC Scan"
                                    Width="165"
                                    Style="{StaticResource ToolButton}"
                                    Tag="sfc system scan repair"/>

                            <Button Name="BtnWifi"
                                    Content="Fix Network"
                                    Width="165"
                                    Style="{StaticResource ToolButton}"
                                    Tag="wifi network dns reset"/>

                            <Button Name="BtnExportWifi"
                                    Content="Export Wi-Fi Passwords"
                                    Width="215"
                                    Style="{StaticResource ToolButton}"
                                    Tag="wifi wireless password export"/>

                            <Button Name="BtnKey"
                                    Content="Show Windows Key"
                                    Width="180"
                                    Style="{StaticResource ToolButton}"
                                    Tag="windows product key license"/>
                        </WrapPanel>

                        <Border Background="#211E18"
                                BorderBrush="#66552F"
                                BorderThickness="1"
                                CornerRadius="5"
                                Padding="14"
                                Margin="0,15,0,0">
                            <TextBlock Text="Wi-Fi exports contain sensitive information. Protect or delete the exported file when finished."
                                       Foreground="#E6C875"
                                       TextWrapping="Wrap"
                                       FontSize="12"/>
                        </Border>
                    </StackPanel>
                </Grid>
            </TabItem>

            <TabItem Header="Office Tools">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Margin="18">
                        <TextBlock Name="HdrOffice"
                                   Text="OFFICE TOOLS"
                                   Foreground="#00FFFF"
                                   FontSize="17"
                                   FontWeight="Bold"
                                   Margin="0,0,0,15"/>

                        <WrapPanel>
                            <Button Name="BtnOfficeODT"
                                    Content="Install Office (ODT)"
                                    Width="205"
                                    Height="48"
                                    Style="{StaticResource ToolButton}"
                                    Tag="office setup installer microsoft odt"/>

                            <Button Name="BtnScrubber"
                                    Content="Office Scrubber"
                                    Width="205"
                                    Height="48"
                                    Style="{StaticResource ToolButton}"
                                    Tag="office scrubber cleanup remove"/>

                            <Button Name="BtnWinTools"
                                    Content="Win Office Tools"
                                    Width="205"
                                    Height="48"
                                    Style="{StaticResource ToolButton}"
                                    Tag="office windows tools"/>

                            <Button Name="BtnWinrar"
                                    Content="WinRAR"
                                    Width="205"
                                    Height="48"
                                    Style="{StaticResource ToolButton}"
                                    Tag="winrar archive compression"/>
                        </WrapPanel>

                        <TextBlock Name="HdrScripts"
                                   Text="SYSTEM SCRIPTS"
                                   Foreground="#00FFFF"
                                   FontSize="17"
                                   FontWeight="Bold"
                                   Margin="0,25,0,15"/>

                        <WrapPanel>
                            <Button Name="BtnUpdate"
                                    Content="System Update"
                                    Width="205"
                                    Height="48"
                                    Style="{StaticResource ToolButton}"
                                    Tag="system update windows update"/>
                        </WrapPanel>

                        <Border Background="#211E18"
                                BorderBrush="#66552F"
                                BorderThickness="1"
                                CornerRadius="5"
                                Padding="14"
                                Margin="0,20,0,0">
                            <TextBlock Text="Only run tools from sources you trust. Downloaded files are stored temporarily and removed after execution."
                                       Foreground="#E6C875"
                                       TextWrapping="Wrap"
                                       FontSize="12"/>
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
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <TextBlock Name="HdrSettings"
                               Text="SETTINGS"
                               Foreground="#00FFFF"
                               FontSize="17"
                               FontWeight="Bold"
                               Margin="0,0,0,18"/>

                    <TextBlock Grid.Row="1"
                               Text="Temporary download folder"
                               Foreground="#FFFFFF"
                               Margin="0,0,0,7"/>

                    <Grid Grid.Row="2">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="110"/>
                        </Grid.ColumnDefinitions>

                        <TextBox Name="TxtDownloadFolder"
                                 Grid.Column="0"
                                 Height="35"/>

                        <Button Name="BtnBrowseFolder"
                                Grid.Column="1"
                                Content="Browse"
                                Width="95"
                                Style="{StaticResource ToolButton}"
                                Margin="10,0,0,10"/>
                    </Grid>

                    <CheckBox Name="ChkConfirmActions"
                              Grid.Row="3"
                              Content="Confirm sensitive actions"
                              Margin="0,14,0,5"/>

                    <CheckBox Name="ChkAutoRefresh"
                              Grid.Row="4"
                              Content="Automatically refresh system information"
                              Margin="0,5,0,0"
                              VerticalAlignment="Top"/>

                    <StackPanel Grid.Row="5"
                                Orientation="Horizontal"
                                Margin="0,18,0,0">

                        <TextBlock Text="Accent color:"
                                   Foreground="#FFFFFF"
                                   VerticalAlignment="Center"
                                   Margin="0,0,10,10"/>

                        <ComboBox Name="CmbAccent"
                                  Width="145"
                                  Height="36"
                                  Style="{StaticResource DarkComboBox}"
                                  Margin="0,0,15,10"/>

                        <Button Name="BtnSaveSettings"
                                Content="Save Settings"
                                Width="140"
                                Style="{StaticResource ToolButton}"
                                Tag="settings save preferences"/>

                        <Button Name="BtnResetSettings"
                                Content="Reset Settings"
                                Width="140"
                                Style="{StaticResource ToolButton}"
                                Tag="settings reset defaults"/>
                    </StackPanel>
                </Grid>
            </TabItem>
        </TabControl>

        <Border Grid.Row="2"
                Background="#1A1A1A"
                BorderBrush="#333333"
                BorderThickness="1,1,1,0"
                Padding="15,10">

            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="280"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="130"/>
                </Grid.ColumnDefinitions>

                <TextBlock Name="StatusText"
                           Grid.Column="0"
                           Text="Ready."
                           Foreground="#00FF00"
                           VerticalAlignment="Center"
                           TextWrapping="Wrap"/>

                <ProgressBar Name="MainProgress"
                             Grid.Column="1"
                             Height="9"
                             Minimum="0"
                             Maximum="100"
                             Value="0"
                             VerticalAlignment="Center"
                             Margin="15,0"/>

                <TextBlock Name="ProgressText"
                           Grid.Column="2"
                           Foreground="#AAAAAA"
                           VerticalAlignment="Center"
                           HorizontalAlignment="Right"/>
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

$BtnOfficeODT       = $Window.FindName("BtnOfficeODT")
$BtnScrubber        = $Window.FindName("BtnScrubber")
$BtnWinTools        = $Window.FindName("BtnWinTools")
$BtnWinrar          = $Window.FindName("BtnWinrar")
$BtnUpdate          = $Window.FindName("BtnUpdate")

$TxtDownloadFolder  = $Window.FindName("TxtDownloadFolder")
$BtnBrowseFolder    = $Window.FindName("BtnBrowseFolder")
$ChkConfirmActions  = $Window.FindName("ChkConfirmActions")
$ChkAutoRefresh     = $Window.FindName("ChkAutoRefresh")
$CmbAccent          = $Window.FindName("CmbAccent")
$BtnSaveSettings    = $Window.FindName("BtnSaveSettings")
$BtnResetSettings   = $Window.FindName("BtnResetSettings")

$Window.Title = "CrazyAlexTool $script:AppVersion"
$SubtitleText.Text = "Windows utility and maintenance tools - v$script:AppVersion"

# ============================================================
# UI HELPERS
# ============================================================

function New-Brush {
    param([string]$Color)
    $converter = New-Object System.Windows.Media.BrushConverter
    return $converter.ConvertFromString($Color)
}

function Set-Status {
    param(
        [string]$Message,
        [string]$Color = "#AAAAAA"
    )
    $StatusText.Text = $Message
    $StatusText.Foreground = New-Brush $Color
}

function Set-Progress {
    param(
        [double]$Percent = 0,
        [string]$Text = "",
        [switch]$Indeterminate
    )

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
    }
    catch { }
}

function Show-ToolError {
    param(
        [string]$Name,
        [object]$Exception
    )

    $message = if ($Exception) {
        $Exception.Exception.Message
    }
    else {
        "Unknown error."
    }

    Set-Status "Error: $Name" "#FF5555"
    Set-Progress -Percent 0

    [System.Windows.MessageBox]::Show(
        "$Name`n`n$message",
        "CrazyAlexTool Error",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
}

function Confirm-Action {
    param(
        [string]$Message,
        [string]$Title = "Confirm Action"
    )

    if ($ChkConfirmActions.IsChecked -ne $true) {
        return $true
    }

    $result = [System.Windows.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )

    return ($result -eq [System.Windows.MessageBoxResult]::Yes)
}

# ============================================================
# FILE PICKER (GenP-style dropdown)
# ============================================================

function Show-FilePicker {
    param(
        [string]$Title = "Select an option",
        [System.IO.FileInfo[]]$Files
    )

    [xml]$PickerXAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title"
        Height="260" Width="440"
        WindowStartupLocation="CenterOwner"
        Background="#1A1A1A"
        ResizeMode="NoResize"
        FontFamily="Segoe UI">

    <Window.Resources>

        <Style x:Key="PickerComboItem" TargetType="{x:Type ComboBoxItem}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBoxItem}">
                        <Border x:Name="B"
                                Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter TextElement.Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="B" Property="Background" Value="#005F73"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
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

        <Style x:Key="PickerCombo" TargetType="{x:Type ComboBox}">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#25252B"/>
            <Setter Property="ItemContainerStyle" Value="{StaticResource PickerComboItem}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBox}">
                        <Grid>
                            <ToggleButton Focusable="False"
                                          ClickMode="Press"
                                          IsChecked="{Binding IsDropDownOpen,
                                            RelativeSource={RelativeSource TemplatedParent},
                                            Mode=TwoWay}">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="{x:Type ToggleButton}">
                                        <Border x:Name="TBB"
                                                Background="#25252B"
                                                BorderBrush="#444444"
                                                BorderThickness="1"
                                                CornerRadius="4">
                                            <Path Data="M 0 0 L 5 5 L 10 0 Z"
                                                  Fill="#FFFFFF"
                                                  HorizontalAlignment="Right"
                                                  VerticalAlignment="Center"
                                                  Margin="0,0,12,0"/>
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True">
                                                <Setter TargetName="TBB" Property="BorderBrush" Value="#00FFFF"/>
                                            </Trigger>
                                            <Trigger Property="IsChecked" Value="True">
                                                <Setter TargetName="TBB" Property="BorderBrush" Value="#00FFFF"/>
                                            </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>

                            <ContentPresenter
                                Content="{TemplateBinding SelectionBoxItem}"
                                ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                Margin="10,0,35,0"
                                VerticalAlignment="Center"
                                HorizontalAlignment="Left"
                                IsHitTestVisible="False"
                                TextElement.Foreground="#FFFFFF"/>

                            <Popup Placement="Bottom"
                                   AllowsTransparency="True"
                                   Focusable="False"
                                   IsOpen="{TemplateBinding IsDropDownOpen}">
                                <Border Background="#1E1E22"
                                        BorderBrush="#00FFFF"
                                        BorderThickness="1"
                                        CornerRadius="4"
                                        MinWidth="{TemplateBinding ActualWidth}">
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

    </Window.Resources>

    <StackPanel Margin="22">
        <TextBlock Text="Select an option to run:"
                   Foreground="#00FFFF"
                   FontSize="14"
                   FontWeight="Bold"
                   Margin="0,0,0,16"/>

        <ComboBox Name="CmbFiles"
                  Style="{StaticResource PickerCombo}"
                  Height="38"
                  FontSize="13"
                  Margin="0,0,0,20"/>

        <StackPanel Orientation="Horizontal"
                    HorizontalAlignment="Right">
            <Button Name="BtnCancel"
                    Content="Cancel"
                    Width="100"
                    Height="36"
                    Margin="0,0,10,0"
                    Background="#2A2A30"
                    Foreground="White"
                    BorderThickness="1"
                    BorderBrush="#444444"
                    Cursor="Hand"/>
            <Button Name="BtnRun"
                    Content="Run Selected"
                    Width="140"
                    Height="36"
                    Background="#00B4D8"
                    Foreground="White"
                    BorderThickness="0"
                    Cursor="Hand"
                    FontWeight="SemiBold"/>
        </StackPanel>
    </StackPanel>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $PickerXAML
    $pickerWindow = [Windows.Markup.XamlReader]::Load($reader)

    $combo = $pickerWindow.FindName("CmbFiles")
    $btnRun = $pickerWindow.FindName("BtnRun")
    $btnCancel = $pickerWindow.FindName("BtnCancel")

    foreach ($f in $Files) {
        [void]$combo.Items.Add($f.Name)
    }
    $combo.SelectedIndex = 0

    $script:PickerResult = $null

    $btnRun.Add_Click({
        $chosen = $combo.SelectedItem
        $script:PickerResult = $Files |
            Where-Object { $_.Name -eq $chosen } |
            Select-Object -First 1
        $pickerWindow.Close()
    })

    $btnCancel.Add_Click({
        $script:PickerResult = $null
        $pickerWindow.Close()
    })

    $pickerWindow.Owner = $Window
    [void]$pickerWindow.ShowDialog()

    return $script:PickerResult
}

# ============================================================
# DOWNLOAD FUNCTIONS
# ============================================================

function Invoke-TrackedDownload {
    param(
        [string]$Url,
        [string]$OutputFile
    )

    if ($Url -notmatch '^https://') {
        throw "Only HTTPS downloads are allowed."
    }

    $parent = Split-Path -Path $OutputFile -Parent
    if (-not (Test-Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.UserAgent = "CrazyAlexTool"
    $request.AllowAutoRedirect = $true

    $response = $null
    $inputStream = $null
    $outputStream = $null

    try {
        $response = $request.GetResponse()
        $inputStream = $response.GetResponseStream()

        $outputStream = New-Object System.IO.FileStream(
            $OutputFile,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::Write
        )

        $totalBytes = $response.ContentLength
        $downloadedBytes = [int64]0
        $buffer = New-Object byte[] 65536

        if ($totalBytes -gt 0) {
            Set-Progress -Percent 0 -Text "0%"
        }
        else {
            Set-Progress -Indeterminate -Text "Downloading"
        }

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

    if (-not (Test-Path $Path)) {
        throw "Downloaded file was not found: $Path"
    }

    $directory = Split-Path -Path $Path -Parent
    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()

    if ($extension -in @(".bat", ".cmd")) {
        $wrapper = "/d /c `"pushd `"$directory`" && call `"$Path`" & echo. & echo [Finished] & pause`""

        Start-Process `
            -FilePath "cmd.exe" `
            -ArgumentList $wrapper `
            -WorkingDirectory $directory `
            -Wait
    }
    else {
        Start-Process `
            -FilePath $Path `
            -WorkingDirectory $directory `
            -Wait
    }
}

function Invoke-SingleFileTool {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Extension
    )

    $filePath = Join-Path $script:TemporaryPath "$Name$Extension"

    try {
        Set-Status "Downloading $Name..." "#FFFF00"
        Invoke-TrackedDownload -Url $Url -OutputFile $filePath

        Set-Status "Running $Name..." "#FFFF00"
        Start-DownloadedFile -Path $filePath

        Set-Status "$Name completed." "#00FF00"
        Set-Progress -Percent 100 -Text "Complete"
    }
    catch {
        Show-ToolError -Name $Name -Exception $_
    }
    finally {
        Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-ZipTool {
    param(
        [string]$Name,
        [string]$Url,
        [string]$TargetFile,
        [switch]$PickerMode,
        [string]$PickerPattern = "*.cmd"
    )

    $zipPath = Join-Path $script:TemporaryPath "$Name.zip"
    $extractPath = Join-Path $script:TemporaryPath "Extracted-$Name"

    try {
        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

        Set-Status "Downloading $Name..." "#FFFF00"
        Invoke-TrackedDownload -Url $Url -OutputFile $zipPath

        Set-Status "Extracting $Name..." "#FFFF00"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        if ($PickerMode) {
            $candidates = @(Get-ChildItem `
                -Path $extractPath `
                -Filter $PickerPattern `
                -File `
                -Recurse `
                -ErrorAction SilentlyContinue)

            if ($candidates.Count -eq 0) {
                throw "No files matching '$PickerPattern' were found in the archive."
            }

            Set-Status "Waiting for user selection..." "#FFFF00"
            $selected = Show-FilePicker -Title "Select $Name option" -Files $candidates

            if (-not $selected) {
                Set-Status "$Name cancelled." "#FFAA00"
                return
            }

            Set-Status "Running $($selected.Name)..." "#FFFF00"
            Start-DownloadedFile -Path $selected.FullName
        }
        else {
            $target = Get-ChildItem `
                -Path $extractPath `
                -Filter $TargetFile `
                -File `
                -Recurse `
                -ErrorAction SilentlyContinue |
                Select-Object -First 1

            if (-not $target) {
                throw "Could not find '$TargetFile' inside the archive."
            }

            Set-Status "Running $Name..." "#FFFF00"
            Start-DownloadedFile -Path $target.FullName
        }

        Set-Status "$Name completed." "#00FF00"
        Set-Progress -Percent 100 -Text "Complete"
    }
    catch {
        Show-ToolError -Name $Name -Exception $_
    }
    finally {
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# WINRAR INSTALL + ACTIVATE
# ============================================================

function Install-WinRAR {
    try {
        if (-not (Confirm-Action `
            "Download WinRAR, install it silently, and apply the license key?" `
            "Install WinRAR")) {
            return
        }

        $zipPath = Join-Path $script:TemporaryPath "WinRAR.zip"
        $extractPath = Join-Path $script:TemporaryPath "Extracted-WinRAR"

        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

        # 1. Download
        Set-Status "Downloading WinRAR..." "#FFFF00"
        Invoke-TrackedDownload -Url $script:Links.Winrar -OutputFile $zipPath

        # 2. Extract
        Set-Status "Extracting WinRAR archive..." "#FFFF00"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        # 3. Find the installer .exe
        $installer = Get-ChildItem `
            -Path $extractPath `
            -Filter "*.exe" `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -match 'winrar' -or
                $_.Name -match '^wrar'
            } |
            Select-Object -First 1

        if (-not $installer) {
            $installer = Get-ChildItem `
                -Path $extractPath `
                -Filter "*.exe" `
                -File `
                -Recurse `
                -ErrorAction SilentlyContinue |
                Select-Object -First 1
        }

        if (-not $installer) {
            throw "No WinRAR installer .exe was found inside the archive."
        }

        # 4. Find the license key file
        $licenseKey = Get-ChildItem `
            -Path $extractPath `
            -Filter "rarreg.key" `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        # 5. Install silently
        Set-Status "Installing WinRAR silently..." "#FFFF00"
        Set-Progress -Indeterminate -Text "Installing"

        $installProcess = Start-Process `
            -FilePath $installer.FullName `
            -ArgumentList "/s" `
            -Wait `
            -PassThru

        if ($installProcess.ExitCode -ne 0) {
            throw "WinRAR installer exited with code $($installProcess.ExitCode)."
        }

        # 6. Locate installed WinRAR folder
        $possiblePaths = @(
            (Join-Path $env:ProgramFiles "WinRAR")
            (Join-Path ${env:ProgramFiles(x86)} "WinRAR")
        )

        $winrarFolder = $possiblePaths |
            Where-Object { Test-Path (Join-Path $_ "WinRAR.exe") } |
            Select-Object -First 1

        if (-not $winrarFolder) {
            throw "WinRAR installed but its folder could not be located."
        }

        # 7. Apply the license
        if ($licenseKey) {
            Set-Status "Applying WinRAR license..." "#FFFF00"

            $destination = Join-Path $winrarFolder "rarreg.key"

            Copy-Item `
                -Path $licenseKey.FullName `
                -Destination $destination `
                -Force

            if (Test-Path $destination) {
                Set-Status "WinRAR installed and licensed." "#00FF00"
            }
            else {
                Set-Status "WinRAR installed but license copy failed." "#FFAA00"
            }
        }
        else {
            Set-Status "WinRAR installed (no license key found in archive)." "#FFAA00"
        }

        Set-Progress -Percent 100 -Text "Complete"
    }
    catch {
        Show-ToolError -Name "WinRAR" -Exception $_
    }
    finally {
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# OFFICE DEPLOYMENT TOOL
# ============================================================

function Install-OfficeODT {
    try {
        if (-not (Confirm-Action `
            "Download the official Microsoft Office Deployment Tool and start setup?" `
            "Install Office")) {
            return
        }

        $odtFolder = Join-Path $script:TemporaryPath "ODT"

        if (Test-Path $odtFolder) {
            Remove-Item -Path $odtFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path $odtFolder -ItemType Directory -Force | Out-Null

        $odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18227-20162.exe"
        $odtExe = Join-Path $odtFolder "ODT.exe"

        Set-Status "Downloading Office Deployment Tool..." "#FFFF00"
        Invoke-TrackedDownload -Url $odtUrl -OutputFile $odtExe

        Set-Status "Extracting Office Deployment Tool..." "#FFFF00"

        $extractProcess = Start-Process `
            -FilePath $odtExe `
            -ArgumentList "/extract:`"$odtFolder`" /quiet" `
            -Wait `
            -PassThru

        if ($extractProcess.ExitCode -ne 0) {
            throw "Failed to extract the Office Deployment Tool."
        }

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

        if (-not (Test-Path $setupExe)) {
            throw "setup.exe was not found after extraction."
        }

        Set-Status "Launching Office installer..." "#FFFF00"

        Start-Process `
            -FilePath $setupExe `
            -ArgumentList "/configure `"$configPath`"" `
            -Wait

        Set-Status "Office setup finished." "#00FF00"
    }
    catch {
        Show-ToolError -Name "Office (ODT)" -Exception $_
    }
}

# ============================================================
# SYSTEM INFORMATION
# ============================================================

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

        # --- Build drive list ---
        $partitionToDisk = @{}
        try {
            $physicalDisks = Get-CimInstance Win32_DiskDrive -ErrorAction Stop

            foreach ($disk in $physicalDisks) {
                $partitions = Get-CimAssociatedInstance `
                    -InputObject $disk `
                    -ResultClassName Win32_DiskPartition `
                    -ErrorAction SilentlyContinue

                foreach ($partition in $partitions) {
                    $logicalDisksForPart = Get-CimAssociatedInstance `
                        -InputObject $partition `
                        -ResultClassName Win32_LogicalDisk `
                        -ErrorAction SilentlyContinue

                    foreach ($ld in $logicalDisksForPart) {
                        $partitionToDisk[$ld.DeviceID] = $disk.Model.Trim()
                    }
                }
            }
        } catch { }

        $logicalDisks = Get-CimInstance Win32_LogicalDisk `
            -ErrorAction SilentlyContinue |
            Where-Object { $_.DriveType -in 2, 3, 4, 5 }

        $driveTypeMap = @{
            2 = "Removable Drive"
            3 = "Local Disk"
            4 = "Network Drive"
            5 = "CD/DVD Drive"
        }

        $driveLines = foreach ($ld in $logicalDisks) {
            $model = $partitionToDisk[$ld.DeviceID]
            if (-not $model) {
                $model = $driveTypeMap[[int]$ld.DriveType]
                if (-not $model) { $model = "Unknown" }
            }

            if ($ld.Size -gt 0) {
                $sizeGb = [Math]::Round($ld.Size / 1GB, 0)
                $freeGb = [Math]::Round($ld.FreeSpace / 1GB, 0)
                $usedPercent = [Math]::Round(
                    (($ld.Size - $ld.FreeSpace) / $ld.Size) * 100,
                    0
                )
                "  $($ld.DeviceID)  $model  |  $freeGb GB free of $sizeGb GB ($usedPercent% used)"
            }
            else {
                "  $($ld.DeviceID)  $model  |  (no media)"
            }
        }

        $driveText = if ($driveLines) {
            $driveLines -join [Environment]::NewLine
        }
        else {
            "  (No drives detected)"
        }

        $SystemInfoText.Text = @(
            "Operating System : $($os.Caption)"
            "Version          : $($os.Version)"
            "Computer         : $($env:COMPUTERNAME)"
            "User             : $($env:USERNAME)"
            ""
            "CPU              : $($cpu.Name)"
            "GPU              : $($gpu.Name)"
            "RAM              : $usedRam GB used of $totalRam GB"
            ""
            "Drives:"
            $driveText
            ""
            "Uptime           : $($uptime.Days) days, $($uptime.Hours) hours"
        ) -join [Environment]::NewLine

        Set-Status "System information updated." "#00FF00"
    }
    catch {
        Show-ToolError -Name "System information" -Exception $_
    }
}

# ============================================================
# SFC AND NETWORK
# ============================================================

function Invoke-ProcessWithProgress {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$Activity
    )

    Set-Status "$Activity..." "#FFFF00"
    Set-Progress -Indeterminate -Text "Working..."

    $argumentString = $Arguments -join " "

    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $argumentString `
        -PassThru `
        -WindowStyle Hidden

    while (-not $process.HasExited) {
        Pump-UI
        Start-Sleep -Milliseconds 150
        $process.Refresh()
    }

    Set-Progress -Percent 100 -Text "Complete"
    return $process.ExitCode
}

function Invoke-SFCScan {
    try {
        if (-not (Confirm-Action "Run an SFC system scan now?")) {
            return
        }

        $exitCode = Invoke-ProcessWithProgress `
            -FilePath "cmd.exe" `
            -Arguments @("/c", "sfc /scannow") `
            -Activity "Running SFC scan"

        if ($exitCode -ne 0) {
            throw "SFC exited with code $exitCode."
        }

        Set-Status "SFC scan completed." "#00FF00"
    }
    catch {
        Show-ToolError -Name "SFC scan" -Exception $_
    }
}

function Reset-Network {
    try {
        if (-not (Confirm-Action "Flush DNS and renew the network connection?")) {
            return
        }

        $commands = @(
            [pscustomobject]@{
                File = "ipconfig.exe"
                Args = @("/flushdns")
                Name = "Flushing DNS cache"
            }
            [pscustomobject]@{
                File = "ipconfig.exe"
                Args = @("/release")
                Name = "Releasing IP address"
            }
            [pscustomobject]@{
                File = "ipconfig.exe"
                Args = @("/renew")
                Name = "Renewing IP address"
            }
        )

        foreach ($command in $commands) {
            $exitCode = Invoke-ProcessWithProgress `
                -FilePath $command.File `
                -Arguments $command.Args `
                -Activity $command.Name

            if ($exitCode -ne 0) {
                throw "$($command.Name) failed."
            }
        }

        Set-Status "Network reset completed." "#00FF00"
    }
    catch {
        Show-ToolError -Name "Network reset" -Exception $_
    }
}

# ============================================================
# WI-FI PASSWORD EXPORT
# ============================================================

function Export-WiFiPasswords {
    try {
        if (-not (Confirm-Action `
            ("Export saved Wi-Fi passwords to a text file?`n`n" +
             "The file will contain sensitive information.") `
            "Wi-Fi Password Export")) {
            return
        }

        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Title = "Export Wi-Fi Profiles"
        $dialog.Filter = "Text files (*.txt)|*.txt"
        $dialog.FileName = "WiFi-Passwords-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        $dialog.InitialDirectory = $script:Settings.DownloadFolder

        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            return
        }

        Set-Status "Reading saved Wi-Fi profiles..." "#FFFF00"

        $profileOutput = & netsh.exe wlan show profiles 2>$null

        $profiles = @(
            foreach ($line in $profileOutput) {
                if ($line -match '^\s*(All User Profile|User Profile)\s*:\s*(.+?)\s*$') {
                    $Matches[2].Trim()
                }
            }
        ) | Sort-Object -Unique

        if ($profiles.Count -eq 0) {
            throw "No saved Wi-Fi profiles were found."
        }

        $output = New-Object System.Collections.Generic.List[string]

        $output.Add("CrazyAlexTool Wi-Fi Export")
        $output.Add("Created: $(Get-Date)")
        $output.Add("")
        $output.Add("This file contains sensitive information.")
        $output.Add("Delete it when it is no longer needed.")
        $output.Add("")

        foreach ($profile in $profiles) {
            Set-Status "Reading Wi-Fi profile: $profile" "#FFFF00"

            $details = & netsh.exe wlan show profile "name=$profile" key=clear 2>$null

            $password = $null

            foreach ($line in $details) {
                if ($line -match '^\s*Key Content\s*:\s*(.*)$') {
                    $password = $Matches[1].Trim()
                    break
                }
            }

            if ([string]::IsNullOrWhiteSpace($password)) {
                $password = "[No password found]"
            }

            $output.Add("Profile: $profile")
            $output.Add("Password: $password")
            $output.Add("")
        }

        $output | Set-Content -Path $dialog.FileName -Encoding UTF8

        Set-Status "Wi-Fi export completed." "#00FF00"

        [System.Windows.MessageBox]::Show(
            "Wi-Fi profiles were exported to:`n`n$($dialog.FileName)",
            "Export Complete",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
    }
    catch {
        Show-ToolError -Name "Wi-Fi export" -Exception $_
    }
}

# ============================================================
# WINDOWS PRODUCT KEY
# ============================================================

function Show-WindowsProductKey {
    try {
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform"

        $key = (Get-ItemProperty -Path $registryPath -ErrorAction Stop).BackupProductKeyDefault

        if ($key) {
            [System.Windows.MessageBox]::Show(
                "Windows Product Key:`n`n$key",
                "Windows Product Key",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null

            Set-Status "Product key displayed." "#00FF00"
        }
        else {
            [System.Windows.MessageBox]::Show(
                "No OEM product key was found in the registry.",
                "Windows Product Key",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null

            Set-Status "No OEM product key found." "#FFAA00"
        }
    }
    catch {
        Show-ToolError -Name "Windows product key" -Exception $_
    }
}

# ============================================================
# SETTINGS UI
# ============================================================

function Apply-AccentColor {
    $accentName = [string]$CmbAccent.SelectedItem

    if (-not $script:AccentMap.Contains($accentName)) {
        $accentName = "Cyan"
    }

    $brush = New-Brush $script:AccentMap[$accentName]

    $script:Settings.Accent = $accentName

    foreach ($name in @(
        "TitleText"
        "HdrSystemInfo"
        "HdrQuickTools"
        "HdrOffice"
        "HdrScripts"
        "HdrSettings"
    )) {
        $control = $Window.FindName($name)
        if ($control) {
            $control.Foreground = $brush
        }
    }

    $MainProgress.Foreground = $brush
}

function Save-SettingsFromUI {
    try {
        $folder = $TxtDownloadFolder.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($folder)) {
            $folder = $script:DefaultDownloadFolder
        }

        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }

        $script:Settings.DownloadFolder = $folder
        $script:Settings.ConfirmActions = ($ChkConfirmActions.IsChecked -eq $true)
        $script:Settings.AutoRefresh = ($ChkAutoRefresh.IsChecked -eq $true)
        $script:Settings.Accent = [string]$CmbAccent.SelectedItem

        Save-AppSettings
        Apply-AccentColor

        if ($script:Settings.AutoRefresh) {
            $script:InfoTimer.Start()
        }
        else {
            $script:InfoTimer.Stop()
        }

        Set-Status "Settings saved." "#00FF00"
    }
    catch {
        Show-ToolError -Name "Saving settings" -Exception $_
    }
}

function Reset-Settings {
    if (-not (Confirm-Action "Reset CrazyAlexTool settings to their defaults?")) {
        return
    }

    $TxtDownloadFolder.Text = $script:DefaultSettings.DownloadFolder
    $ChkConfirmActions.IsChecked = $script:DefaultSettings.ConfirmActions
    $ChkAutoRefresh.IsChecked = $script:DefaultSettings.AutoRefresh
    $CmbAccent.SelectedItem = $script:DefaultSettings.Accent

    Save-SettingsFromUI
}

# ============================================================
# SEARCH
# ============================================================

$script:SearchableControls = @(
    $BtnRefreshInfo
    $BtnSFC
    $BtnWifi
    $BtnExportWifi
    $BtnKey
    $BtnOfficeODT
    $BtnScrubber
    $BtnWinTools
    $BtnWinrar
    $BtnUpdate
    $BtnSaveSettings
    $BtnResetSettings
)

function Filter-Tools {
    $query = $TxtSearch.Text.Trim().ToLowerInvariant()

    foreach ($control in $script:SearchableControls) {
        $content = [string]$control.Content
        $tag = [string]$control.Tag
        $searchText = "$content $tag".ToLowerInvariant()

        $isMatch = (
            [string]::IsNullOrWhiteSpace($query) -or
            $searchText.Contains($query)
        )

        if ($isMatch) {
            $control.Visibility = [System.Windows.Visibility]::Visible
        }
        else {
            $control.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
}

# ============================================================
# INITIALIZATION
# ============================================================

foreach ($accentName in $script:AccentMap.Keys) {
    [void]$CmbAccent.Items.Add($accentName)
}

$TxtDownloadFolder.Text = $script:Settings.DownloadFolder
$ChkConfirmActions.IsChecked = $script:Settings.ConfirmActions
$ChkAutoRefresh.IsChecked = $script:Settings.AutoRefresh
$CmbAccent.SelectedItem = $script:Settings.Accent

Apply-AccentColor
Update-SystemInformation

$script:InfoTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:InfoTimer.Interval = [TimeSpan]::FromSeconds(10)

$script:InfoTimer.Add_Tick({
    if ($ChkAutoRefresh.IsChecked -eq $true) {
        Update-SystemInformation
    }
})

if ($script:Settings.AutoRefresh) {
    $script:InfoTimer.Start()
}

# ============================================================
# BUTTON EVENTS
# ============================================================

$TxtSearch.Add_TextChanged({ Filter-Tools })

$BtnRefreshInfo.Add_Click({ Update-SystemInformation })
$BtnSFC.Add_Click({ Invoke-SFCScan })
$BtnWifi.Add_Click({ Reset-Network })
$BtnExportWifi.Add_Click({ Export-WiFiPasswords })
$BtnKey.Add_Click({ Show-WindowsProductKey })

$BtnOfficeODT.Add_Click({ Install-OfficeODT })

$BtnScrubber.Add_Click({
    Invoke-ZipTool `
        -Name "OfficeScrubber" `
        -Url $script:Links.Scrubber `
        -PickerMode `
        -PickerPattern "*.cmd"
})

$BtnWinTools.Add_Click({
    Invoke-SingleFileTool `
        -Name "WinOfficeTools" `
        -Url $script:Links.WinTools `
        -Extension ".bat"
})

$BtnWinrar.Add_Click({ Activate-WinRAR })

$BtnUpdate.Add_Click({
    Invoke-SingleFileTool `
        -Name "SystemUpdate" `
        -Url $script:Links.Update `
        -Extension ".bat"
})

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

$ChkAutoRefresh.Add_Click({
    if ($ChkAutoRefresh.IsChecked -eq $true) {
        $script:InfoTimer.Start()
    }
    else {
        $script:InfoTimer.Stop()
    }
})

$CmbAccent.Add_SelectionChanged({ Apply-AccentColor })

$Window.Add_Closing({
    $script:InfoTimer.Stop()

    $script:Settings.DownloadFolder = $TxtDownloadFolder.Text
    $script:Settings.ConfirmActions = ($ChkConfirmActions.IsChecked -eq $true)
    $script:Settings.AutoRefresh = ($ChkAutoRefresh.IsChecked -eq $true)
    $script:Settings.Accent = [string]$CmbAccent.SelectedItem

    Save-AppSettings

    Remove-Item -Path $script:TemporaryPath -Recurse -Force -ErrorAction SilentlyContinue
})

# ============================================================
# LAUNCH
# ============================================================

[void]$Window.ShowDialog()
