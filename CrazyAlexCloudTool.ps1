<#
.SYNOPSIS
    CrazyAlex Cloud Suite - Ultimate WPF Edition (Fully Dark-Themed)
.DESCRIPTION
    - Auto-adds Windows Defender exclusion for $env:TEMP at startup.
    - AV-aware error handler with clear fix instructions.
    - Unified download / extract / run pipeline (no duplicated logic).
    - Fully dark-themed ComboBox (readable when not hovered).
    - Non-blocking network reset, centralized temp paths, proper cleanup.
#>

# ==========================================
# --- AUTO-ADMIN ELEVATION ---
# ==========================================
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList `
        "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# ==========================================
# --- AUTO-ADD DEFENDER EXCLUSION (TEMP) ---
# ==========================================
try {
    $tempExclusion = $env:TEMP
    $existing = @()
    try { $existing = (Get-MpPreference -ErrorAction Stop).ExclusionPath } catch { }
    if ($existing -notcontains $tempExclusion) {
        Add-MpPreference -ExclusionPath $tempExclusion -ErrorAction Stop | Out-Null
        Write-Host "[+] Defender exclusion added for: $tempExclusion" -ForegroundColor Green
    } else {
        Write-Host "[=] Defender exclusion already present for: $tempExclusion" -ForegroundColor DarkGray
    }
} catch {
    Write-Host "[!] Could not add Defender exclusion (Tamper Protection may be ON)." -ForegroundColor Yellow
    Write-Host "    If a tool gets blocked, add the exclusion manually or pause Real-time protection." -ForegroundColor Yellow
}

# ==========================================
# --- CONFIGURATION / VERIFIED LINKS ---
# ==========================================
$Links = @{
    Winrar       = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/Winrar.zip"
    GenP         = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/GenP-main.zip"
    Scrubber     = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/OfficeScrubber.zip"
    Office16     = "https://github.com/CrazyAlex15/CrazyAlexTool/releases/download/V1.0/Office_16-19.exe"
    OfficeIso    = "https://drive.google.com/uc?export=download&confirm=t&id=15zkq2ieVA4IAnoSrY-oBHNE_Qzq6yN_E"
    WinTools     = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/WinOfficeTools.bat"
    UpdateSystem = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/UpdateSystemWithPSCheck.bat"
}

# ==========================================
# --- WPF SETUP ---
# ==========================================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# ==========================================
# --- SHARED DARK THEME RESOURCE STRING ---
# Injected into both windows' <Window.Resources>
# ==========================================
$DarkThemeResources = @"
        <!-- =========================================
             SHARED DARK THEME RESOURCES
             ========================================= -->

        <!-- ComboBox toggle button (dropdown arrow area) -->
        <ControlTemplate x:Key="ComboBoxToggleButton" TargetType="ToggleButton">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="24"/>
                </Grid.ColumnDefinitions>
                <Border x:Name="Border"
                        Grid.ColumnSpan="2"
                        Background="#2A2A30"
                        BorderBrush="#444444"
                        BorderThickness="1"
                        CornerRadius="3"/>
                <Path x:Name="Arrow"
                      Grid.Column="1"
                      HorizontalAlignment="Center"
                      VerticalAlignment="Center"
                      Data="M 0 0 L 4 4 L 8 0 Z"
                      Fill="#00FFFF"/>
            </Grid>
            <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter TargetName="Border" Property="BorderBrush" Value="#00FFFF"/>
                </Trigger>
                <Trigger Property="IsChecked" Value="True">
                    <Setter TargetName="Border" Property="BorderBrush" Value="#00FFFF"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>

        <!-- Dropdown item style -->
        <Style x:Key="DarkComboBoxItem" TargetType="ComboBoxItem">
            <Setter Property="Background" Value="#2A2A30"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Padding" Value="10,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="Bd"
                                Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}"
                                SnapsToDevicePixels="True">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#00B4D8"/>
                                <Setter Property="Foreground" Value="#000000"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#005F73"/>
                                <Setter Property="Foreground" Value="#00FFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ComboBox main style -->
        <Style x:Key="DarkComboBox" TargetType="ComboBox">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#2A2A30"/>
            <Setter Property="BorderBrush" Value="#444444"/>
            <Setter Property="ItemContainerStyle" Value="{StaticResource DarkComboBoxItem}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="ToggleButton"
                                          Template="{StaticResource ComboBoxToggleButton}"
                                          Grid.Column="2"
                                          Focusable="false"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                          ClickMode="Press"/>
                            <ContentPresenter x:Name="ContentSite"
                                              IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                                              Margin="10,3,30,3"
                                              VerticalAlignment="Center"
                                              HorizontalAlignment="Left"/>
                            <TextBox x:Name="PART_EditableTextBox"
                                     Style="{x:Null}"
                                     HorizontalAlignment="Left"
                                     VerticalAlignment="Center"
                                     Margin="10,3,30,3"
                                     Focusable="True"
                                     Background="Transparent"
                                     Foreground="#FFFFFF"
                                     Visibility="Hidden"
                                     IsReadOnly="{TemplateBinding IsReadOnly}"/>
                            <Popup x:Name="Popup"
                                   Placement="Bottom"
                                   IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True"
                                   Focusable="False"
                                   PopupAnimation="Slide">
                                <Grid x:Name="DropDown"
                                      SnapsToDevicePixels="True"
                                      MinWidth="{TemplateBinding ActualWidth}"
                                      MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <Border x:Name="DropDownBorder"
                                            Background="#1E1E22"
                                            BorderThickness="1"
                                            BorderBrush="#00FFFF"
                                            CornerRadius="3"/>
                                    <ScrollViewer Margin="4" SnapsToDevicePixels="True">
                                        <StackPanel IsItemsHost="True"
                                                    KeyboardNavigation.DirectionalNavigation="Contained"/>
                                    </ScrollViewer>
                                </Grid>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
"@

# ==========================================
# --- MAIN WINDOW XAML ---
# ==========================================
[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="CrazyAlex Cloud Suite"
        Height="720" Width="900"
        WindowStartupLocation="CenterScreen"
        Background="#121212"
        FontFamily="Segoe UI"
        ResizeMode="NoResize">

    <Window.Resources>
$DarkThemeResources
    </Window.Resources>

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="240"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- SIDEBAR -->
        <Border Background="#1A1A1A" Grid.Column="0" CornerRadius="0,8,8,0">
            <StackPanel Margin="18">
                <TextBlock Text="CRAZY ALEX"
                           Foreground="#00FFFF"
                           FontSize="26"
                           FontWeight="Black"
                           Margin="0,20,0,2"/>
                <TextBlock Text="CLOUD SUITE v8"
                           Foreground="#888888"
                           FontSize="13"
                           FontWeight="SemiBold"
                           Margin="0,0,0,30"/>
                <Separator Background="#333333" Margin="0,0,0,20"/>

                <TextBlock Text="SYSTEM STATUS"
                           Foreground="#555555"
                           FontSize="11"
                           Margin="0,0,0,8"
                           FontWeight="SemiBold"/>
                <TextBlock Name="StatusText"
                           Text="Ready to deploy."
                           Foreground="#00FF00"
                           FontSize="13"
                           TextWrapping="Wrap"
                           LineHeight="20"/>

                <Separator Background="#333333" Margin="0,25,0,20"/>

                <TextBlock Text="LAST ACTION"
                           Foreground="#555555"
                           FontSize="11"
                           Margin="0,0,0,8"
                           FontWeight="SemiBold"/>
                <TextBlock Name="LastActionText"
                           Text="None"
                           Foreground="#AAAAAA"
                           FontSize="12"
                           TextWrapping="Wrap"/>
            </StackPanel>
        </Border>

        <!-- MAIN CONTENT -->
        <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="28,20,28,20">

                <!-- OFFICE TOOLS -->
                <TextBlock Text="OFFICE TOOLS"
                           Foreground="#00FFFF"
                           FontSize="16"
                           FontWeight="Bold"
                           Margin="0,0,0,12"/>
                <WrapPanel Margin="0,0,0,28">
                    <Button Name="BtnOfficeSetup"
                            Content="&#x1F4BE;  Office 2019 Setup"
                            Width="205" Height="48" Margin="0,0,12,12"
                            Background="#2A2A30" Foreground="#FFFFFF"
                            BorderThickness="1" BorderBrush="#444444"
                            Cursor="Hand" FontSize="13"/>
                    <Button Name="BtnOfficeAct"
                            Content="&#x1F511;  Office 16-19 Act"
                            Width="205" Height="48" Margin="0,0,12,12"
                            Background="#2A2A30" Foreground="#FFFFFF"
                            BorderThickness="1" BorderBrush="#444444"
                            Cursor="Hand" FontSize="13"/>
                    <Button Name="BtnScrubber"
                            Content="&#x1F9F9;  Office Scrubber"
                            Width="205" Height="48" Margin="0,0,12,12"
                            Background="#2A2A30" Foreground="#FFFFFF"
                            BorderThickness="1" BorderBrush="#444444"
                            Cursor="Hand" FontSize="13"/>
                    <Button Name="BtnWinTools"
                            Content="&#x1F6E0;  Win Office Tools"
                            Width="205" Height="48" Margin="0,0,12,12"
                            Background="#2A2A30" Foreground="#FFFFFF"
                            BorderThickness="1" BorderBrush="#444444"
                            Cursor="Hand" FontSize="13"/>
                </WrapPanel>

                <!-- SCRIPTS -->
                <TextBlock Text="SCRIPTS"
                           Foreground="#00FFFF"
                           FontSize="16"
                           FontWeight="Bold"
                           Margin="0,0,0,12"/>
                <WrapPanel Margin="0,0,0,28">
                    <Button Name="BtnGenP"
                            Content="&#x26A1;  GenP Activator"
                            Width="205" Height="48" Margin="0,0,12,12"
                            Background="#4A235A" Foreground="#FFFFFF"
                            BorderThickness="1" BorderBrush="#7B3FA0"
                            Cursor="Hand" FontSize="13"/>
                    <Button Name="BtnWinrar"
                            Content="&#x1F4E6;  WinRAR"
                            Width="205" Height="48" Margin="0,0,12,12"
                            Background="#4A235A" Foreground="#FFFFFF"
                            BorderThickness="1" BorderBrush="#7B3FA0"
                            Cursor="Hand" FontSize="13"/>
                </WrapPanel>

                <!-- SYSTEM TOOLS -->
                <TextBlock Text="SYSTEM TOOLS"
                           Foreground="#00FFFF"
                           FontSize="16"
                           FontWeight="Bold"
                           Margin="0,0,0,12"/>
                <WrapPanel>
                    <Button Name="BtnUpdate"
                            Content="&#x1F504;  System Update"
                            Width="205" Height="48" Margin="0,0,12,12"
                            Background="#1A4A2A" Foreground="#FFFFFF"
                            BorderThickness="1" BorderBrush="#2D7A40"
                            Cursor="Hand" FontSize="13"/>
                    <Button Name="BtnSFC"
                            Content="&#x1F50D;  SFC Scan"
                            Width="150" Height="48" Margin="0,0,12,12"
                            Background="#1A4A2A" Foreground="#FFFFFF"
                            BorderThickness="1" BorderBrush="#2D7A40"
                            Cursor="Hand" FontSize="13"/>
                    <Button Name="BtnWifi"
                            Content="&#x1F4F6;  Fix Network"
                            Width="150" Height="48" Margin="0,0,12,12"
                            Background="#1A4A2A" Foreground="#FFFFFF"
                            BorderThickness="1" BorderBrush="#2D7A40"
                            Cursor="Hand" FontSize="13"/>
                    <Button Name="BtnKey"
                            Content="&#x1F5DD;  Win Key"
                            Width="150" Height="48" Margin="0,0,12,12"
                            Background="#1A4A2A" Foreground="#FFFFFF"
                            BorderThickness="1" BorderBrush="#2D7A40"
                            Cursor="Hand" FontSize="13"/>
                </WrapPanel>

            </StackPanel>
        </ScrollViewer>
    </Grid>
</Window>
"@

$Reader = New-Object System.Xml.XmlNodeReader $XAML
$Window = [Windows.Markup.XamlReader]::Load($Reader)

# --- Resolve named controls ---
$StatusText     = $Window.FindName("StatusText")
$LastActionText = $Window.FindName("LastActionText")

$BtnOfficeSetup = $Window.FindName("BtnOfficeSetup")
$BtnOfficeAct   = $Window.FindName("BtnOfficeAct")
$BtnScrubber    = $Window.FindName("BtnScrubber")
$BtnWinTools    = $Window.FindName("BtnWinTools")
$BtnGenP        = $Window.FindName("BtnGenP")
$BtnWinrar      = $Window.FindName("BtnWinrar")
$BtnUpdate      = $Window.FindName("BtnUpdate")
$BtnSFC         = $Window.FindName("BtnSFC")
$BtnWifi        = $Window.FindName("BtnWifi")
$BtnKey         = $Window.FindName("BtnKey")

# ==========================================
# --- HELPER: STATUS UPDATER ---
# ==========================================
function Set-Status {
    param(
        [string]$Message,
        [string]$Color = "#AAAAAA"
    )
    $StatusText.Text       = $Message
    $StatusText.Foreground = $Color
    $LastActionText.Text   = $Message
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [action]{}
    )
}

# ==========================================
# --- HELPER: AV-AWARE ERROR REPORTER ---
# ==========================================
function Show-ToolError {
    param(
        [string]$Name,
        [object]$Exception
    )
    $msg = if ($Exception) { $Exception.Message } else { "Unknown error" }

    if ($msg -match 'virus|potentially unwanted|Operation did not complete|threat|quarantin') {
        Set-Status "$Name blocked by Antivirus!" "#FF4444"
        [System.Windows.MessageBox]::Show(
            "$Name was blocked by Windows Defender / Antivirus.`n`n" +
            "The file was likely quarantined during extraction.`n`n" +
            "FIX (run once in Admin PowerShell):`n" +
            "  Add-MpPreference -ExclusionPath `"`$env:TEMP`"`n`n" +
            "Or temporarily pause Real-time protection:`n" +
            "  Windows Security > Virus & threat protection > Manage settings`n`n" +
            "Detail: $msg",
            "Antivirus Blocked", "OK", "Warning"
        )
    }
    else {
        Set-Status "Error in $Name : $msg" "#FF4444"
        [System.Windows.MessageBox]::Show(
            "Failed: $Name`n`n$msg",
            "Error", "OK", "Error"
        )
    }
}

# ==========================================
# --- HELPER: DOWNLOAD (handles Google Drive)
# ==========================================
function Invoke-Download {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$Label = "file"
    )

    Set-Status "Downloading $Label..." "#FFFF00"

    if ($Url -like "*drive.google.com*") {
        if ($Url -match '[?&]id=([^&]+)') {
            $FileId = $Matches[1]
        } else {
            throw "Cannot parse Google Drive file ID from URL: $Url"
        }

        $BaseUrl  = "https://docs.google.com/uc?export=download&id=$FileId"
        $Response = Invoke-WebRequest -Uri $BaseUrl `
                        -SessionVariable "GDriveSession" `
                        -UserAgent "Mozilla/5.0" `
                        -UseBasicParsing

        $ConfirmLink = $Response.Links |
            Where-Object { $_.href -like "*confirm=*" } |
            Select-Object -ExpandProperty href -First 1

        $DownloadUrl = if ($ConfirmLink) {
            if ($ConfirmLink -match 'confirm=([^&]+)') {
                "https://docs.google.com/uc?export=download&confirm=$($Matches[1])&id=$FileId"
            } else { $BaseUrl }
        } else { $BaseUrl }

        Invoke-WebRequest -Uri $DownloadUrl `
            -OutFile $OutFile `
            -UserAgent "Mozilla/5.0" `
            -WebSession $GDriveSession `
            -UseBasicParsing
    }
    else {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    }
}

# ==========================================
# --- HELPER: TEMP PATH FACTORY ---
# ==========================================
function Get-TempPath {
    param([string]$Name, [string]$Extension = "")
    return (Join-Path $env:TEMP "CA_$Name$Extension")
}

# ==========================================
# --- CORE: Run a single downloaded file
# ==========================================
function Invoke-SingleFile {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Extension
    )

    $TempFile = Get-TempPath -Name $Name -Extension $Extension

    try {
        Invoke-Download -Url $Url -OutFile $TempFile -Label $Name
        Set-Status "Running $Name..." "#FFFF00"
        Start-Process -FilePath $TempFile -Wait
        Set-Status "$Name completed successfully!" "#00FF00"
    }
    catch {
        Show-ToolError -Name $Name -Exception $_.Exception
    }
    finally {
        Remove-Item -Path $TempFile -Force -ErrorAction SilentlyContinue
    }
}

# ==========================================
# --- CORE: Download ZIP, extract, run target
# ==========================================
function Invoke-ZipTool {
    param(
        [string]$Name,
        [string]$Url,
        [string]$TargetFile,
        [switch]$GenPPickerMode
    )

    $ZipPath     = Get-TempPath -Name $Name -Extension ".zip"
    $ExtractPath = Get-TempPath -Name $Name

    try {
        Invoke-Download -Url $Url -OutFile $ZipPath -Label $Name

        Set-Status "Extracting $Name..." "#FFFF00"
        if (Test-Path $ExtractPath) {
            Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force

        if ($GenPPickerMode) {
            $ReleasesPath = Join-Path $ExtractPath "GenP-main\Releases"
            if (-not (Test-Path $ReleasesPath)) { $ReleasesPath = $ExtractPath }
            $ExeList = @(Get-ChildItem -Path $ReleasesPath -Filter "*.exe" -Recurse)

            if ($ExeList.Count -eq 0) {
                throw "No .exe files found inside GenP archive (likely quarantined by Antivirus)."
            }

            Invoke-GenPPicker -ExeList $ExeList
        }
        else {
            $FoundFile = Get-ChildItem -Path $ExtractPath `
                             -Filter $TargetFile -Recurse |
                             Select-Object -First 1

            if (-not $FoundFile) {
                throw "Target file '$TargetFile' not found inside '$Name' archive."
            }

            Set-Status "Running $Name..." "#FFFF00"
            $previousDir = Get-Location
            try {
                Set-Location $FoundFile.DirectoryName
                Start-Process -FilePath $FoundFile.FullName -Wait
            }
            finally {
                Set-Location $previousDir
            }
        }

        Set-Status "$Name completed successfully!" "#00FF00"
    }
    catch {
        Show-ToolError -Name $Name -Exception $_.Exception
    }
    finally {
        Remove-Item -Path $ZipPath     -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ==========================================
# --- GenP VERSION PICKER (dark themed) ---
# ==========================================
function Invoke-GenPPicker {
    param([System.IO.FileInfo[]]$ExeList)

    [xml]$PickerXAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Select GenP Version"
        Height="260" Width="380"
        WindowStartupLocation="CenterScreen"
        Background="#1A1A1A"
        ResizeMode="NoResize"
        FontFamily="Segoe UI">

    <Window.Resources>
$DarkThemeResources
    </Window.Resources>

    <StackPanel Margin="24">
        <TextBlock Text="Select GenP Version to Run:"
                   Foreground="#00FFFF"
                   FontSize="14"
                   FontWeight="Bold"
                   Margin="0,0,0,16"/>
        <ComboBox Name="ComboVersions"
                  Style="{StaticResource DarkComboBox}"
                  Height="36"
                  FontSize="13"
                  Margin="0,0,0,20"/>
        <Button Name="BtnRun"
                Content="&#x25B6;  Run Selected"
                Height="42"
                Background="#00B4D8"
                Foreground="White"
                BorderThickness="0"
                Cursor="Hand"
                FontSize="13"
                FontWeight="SemiBold"/>
    </StackPanel>
</Window>
"@

    $PickerReader = New-Object System.Xml.XmlNodeReader $PickerXAML
    $PickerWindow = [Windows.Markup.XamlReader]::Load($PickerReader)

    $Combo  = $PickerWindow.FindName("ComboVersions")
    $BtnRun = $PickerWindow.FindName("BtnRun")

    foreach ($exe in $ExeList) { [void]$Combo.Items.Add($exe.Name) }
    $Combo.SelectedIndex = 0

    $BtnRun.Add_Click({
        $selectedExe = $ExeList | Where-Object Name -eq $Combo.SelectedItem | Select-Object -First 1
        if ($selectedExe) {
            $previousDir = Get-Location
            try {
                Set-Location $selectedExe.DirectoryName
                Start-Process -FilePath $selectedExe.FullName -Wait
            }
            finally {
                Set-Location $previousDir
            }
        }
        $PickerWindow.Close()
    })

    Set-Status "Waiting for GenP selection..." "#FFFF00"
    [void]$PickerWindow.ShowDialog()
}

# ==========================================
# --- SYSTEM TOOL: Network Reset (async) ---
# ==========================================
function Invoke-NetworkReset {
    Set-Status "Resetting network..." "#FFFF00"
    try {
        $job = Start-Job -ScriptBlock {
            ipconfig /flushdns | Out-Null
            ipconfig /release  | Out-Null
            ipconfig /renew    | Out-Null
        }

        while ($job.State -eq 'Running') {
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [action]{}
            )
            Start-Sleep -Milliseconds 200
        }
        Receive-Job $job -ErrorAction SilentlyContinue | Out-Null
        Remove-Job  $job

        Set-Status "Network reset complete!" "#00FF00"
    }
    catch {
        Set-Status "Network reset failed: $($_.Exception.Message)" "#FF4444"
    }
}

# ==========================================
# --- SYSTEM TOOL: Windows Product Key ---
# ==========================================
function Get-WindowsKey {
    try {
        $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform'
        $key = (Get-ItemProperty -Path $regPath -ErrorAction Stop).BackupProductKeyDefault

        if ($key -and $key -ne '') {
            [System.Windows.MessageBox]::Show(
                "Windows Product Key:`n`n$key",
                "Product Key", "OK", "Information"
            )
            Set-Status "Product key retrieved." "#00FF00"
        }
        else {
            [System.Windows.MessageBox]::Show(
                "No OEM/Digital product key found in registry.`n`n" +
                "Your license may be linked to your Microsoft account.",
                "Product Key", "OK", "Information"
            )
            Set-Status "No OEM key found." "#FFAA00"
        }
    }
    catch {
        Set-Status "Error reading key: $($_.Exception.Message)" "#FF4444"
    }
}

# ==========================================
# --- BUTTON BINDINGS ---
# ==========================================

# Office Tools
$BtnOfficeSetup.Add_Click({
    Invoke-ZipTool -Name "OfficeSetup" -Url $Links.OfficeIso -TargetFile "setup.exe"
})
$BtnOfficeAct.Add_Click({
    Invoke-SingleFile -Name "Office_16-19" -Url $Links.Office16 -Extension ".exe"
})
$BtnScrubber.Add_Click({
    Invoke-ZipTool -Name "OfficeScrubber" -Url $Links.Scrubber -TargetFile "OfficeScrubber.cmd"
})
$BtnWinTools.Add_Click({
    Invoke-SingleFile -Name "WinOfficeTools" -Url $Links.WinTools -Extension ".bat"
})

# Scripts
$BtnGenP.Add_Click({
    Invoke-ZipTool -Name "GenP" -Url $Links.GenP -TargetFile "*.exe" -GenPPickerMode
})
$BtnWinrar.Add_Click({
    Invoke-ZipTool -Name "Winrar" -Url $Links.Winrar -TargetFile "Winrar.cmd"
})

# System Tools
$BtnUpdate.Add_Click({
    Invoke-SingleFile -Name "SystemUpdate" -Url $Links.UpdateSystem -Extension ".bat"
})
$BtnSFC.Add_Click({
    Set-Status "Running SFC scan (this may take several minutes)..." "#FFFF00"
    Start-Process cmd -ArgumentList "/c sfc /scannow & pause" -Wait
    Set-Status "SFC scan launched." "#00FF00"
})
$BtnWifi.Add_Click({ Invoke-NetworkReset })
$BtnKey.Add_Click({ Get-WindowsKey })

# ==========================================
# --- LAUNCH ---
# ==========================================
[void]$Window.ShowDialog()
