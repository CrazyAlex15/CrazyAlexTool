<#
.SYNOPSIS
    CrazyAlex Cloud Suite - Ultimate WPF Edition (Final Stable Version)
#>

# --- AUTO-ADMIN ELEVATION ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# ==========================================
# --- 1. YOUR VERIFIED LINKS ---
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
# --- 2. WPF GUI (USER INTERFACE) ---
# ==========================================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="CrazyAlex Cloud Suite" Height="680" Width="880" 
        WindowStartupLocation="CenterScreen" Background="#121212" 
        FontFamily="Segoe UI" ResizeMode="NoResize">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="230"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <Border Background="#1E1E1E" Grid.Column="0">
            <StackPanel Margin="15">
                <TextBlock Text="CRAZY ALEX" Foreground="#00FFFF" FontSize="26" FontWeight="Black" Margin="0,15,0,0"/>
                <TextBlock Text="CLOUD SUITE v7" Foreground="#AAAAAA" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,40"/>
                
                <TextBlock Text="SYSTEM STATUS:" Foreground="#777777" FontSize="12" Margin="0,0,0,5"/>
                <TextBlock Name="StatusText" Text="Ready to deploy." Foreground="#00FF00" FontSize="13" TextWrapping="Wrap"/>
            </StackPanel>
        </Border>

        <Grid Grid.Column="1" Margin="25">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <TextBlock Text="OFFICE TOOLS" Foreground="#00FFFF" FontSize="18" FontWeight="Bold" Grid.Row="0" Margin="0,0,0,15"/>
            <WrapPanel Grid.Row="1" Margin="0,0,0,25">
                <Button Name="BtnOfficeSetup" Content="Office2019_x64_x86" Width="200" Height="45" Margin="0,0,15,15" Background="#2D2D30" Foreground="White" BorderThickness="0" Cursor="Hand"/>
                <Button Name="BtnOfficeAct" Content="Office_16-19" Width="200" Height="45" Margin="0,0,15,15" Background="#2D2D30" Foreground="White" BorderThickness="0" Cursor="Hand"/>
                <Button Name="BtnScrubber" Content="OfficeScrubber" Width="200" Height="45" Margin="0,0,15,15" Background="#2D2D30" Foreground="White" BorderThickness="0" Cursor="Hand"/>
                <Button Name="BtnWinTools" Content="WinOfficeTools" Width="200" Height="45" Margin="0,0,15,15" Background="#2D2D30" Foreground="White" BorderThickness="0" Cursor="Hand"/>
            </WrapPanel>

            <TextBlock Text="SCRIPTS" Foreground="#00FFFF" FontSize="18" FontWeight="Bold" Grid.Row="2" Margin="0,0,0,15"/>
            <WrapPanel Grid.Row="3" Margin="0,0,0,25">
                <Button Name="BtnGenP" Content="GenP-main" Width="200" Height="45" Margin="0,0,15,15" Background="#5C2E7E" Foreground="White" BorderThickness="0" Cursor="Hand"/>
                <Button Name="BtnWinrar" Content="Winrar" Width="200" Height="45" Margin="0,0,15,15" Background="#5C2E7E" Foreground="White" BorderThickness="0" Cursor="Hand"/>
            </WrapPanel>

            <TextBlock Text="SYSTEM TOOLS" Foreground="#00FFFF" FontSize="18" FontWeight="Bold" Grid.Row="4" Margin="0,0,0,15"/>
            <WrapPanel Grid.Row="5">
                <Button Name="BtnUpdate" Content="System Update" Width="200" Height="45" Margin="0,0,15,15" Background="#1E5128" Foreground="White" BorderThickness="0" Cursor="Hand"/>
                <Button Name="BtnSFC" Content="SFC Scan" Width="130" Height="45" Margin="0,0,15,15" Background="#1E5128" Foreground="White" BorderThickness="0" Cursor="Hand"/>
                <Button Name="BtnWifi" Content="Fix Network" Width="130" Height="45" Margin="0,0,15,15" Background="#1E5128" Foreground="White" BorderThickness="0" Cursor="Hand"/>
                <Button Name="BtnKey" Content="Show Win Key" Width="130" Height="45" Margin="0,0,15,15" Background="#1E5128" Foreground="White" BorderThickness="0" Cursor="Hand"/>
            </WrapPanel>
        </Grid>
    </Grid>
</Window>
"@

$Reader = (New-Object System.Xml.XmlNodeReader $XAML)
$Window = [Windows.Markup.XamlReader]::Load($Reader)

$StatusText = $Window.FindName("StatusText")
$BtnWinrar = $Window.FindName("BtnWinrar"); $BtnGenP = $Window.FindName("BtnGenP")
$BtnScrubber = $Window.FindName("BtnScrubber"); $BtnOfficeSetup = $Window.FindName("BtnOfficeSetup")
$BtnOfficeAct = $Window.FindName("BtnOfficeAct"); $BtnWinTools = $Window.FindName("BtnWinTools")
$BtnUpdate = $Window.FindName("BtnUpdate")
$BtnSFC = $Window.FindName("BtnSFC"); $BtnWifi = $Window.FindName("BtnWifi"); $BtnKey = $Window.FindName("BtnKey")

# ==========================================
# --- 3. EXECUTION FUNCTIONS ---
# ==========================================

function Run-ScriptOrExe ($Name, $Url, $Extension) {
    $StatusText.Text = "Downloading $Name..."; $StatusText.Foreground = "#FFFF00"
    $TempPath = Join-Path $env:TEMP "$Name$Extension"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $TempPath -UseBasicParsing
        $StatusText.Text = "Running $Name..."
        Start-Process -FilePath $TempPath -Wait
        Remove-Item -Path $TempPath -Force -ErrorAction SilentlyContinue
        $StatusText.Text = "$Name completed!"; $StatusText.Foreground = "#00FF00"
    } catch { $StatusText.Text = "Error in $Name"; $StatusText.Foreground = "Red" }
}

function Run-Zip ($Name, $Url, $TargetFile) {
    $StatusText.Text = "Downloading $Name..."; $StatusText.Foreground = "#FFFF00"
    $ZipPath = Join-Path $env:TEMP "$Name.zip"
    $ExtractPath = Join-Path $env:TEMP "CA_$Name"
    
    try {
        # Handle Google Drive Large Files
        if ($Url -like "*drive.google.com*") {
            $FileId = $Url.Split("id=")[1].Split("&")[0]
            $BaseUrl = "https://docs.google.com/uc?export=download&id=$FileId"
            $Response = Invoke-WebRequest -Uri $BaseUrl -SessionVariable "Session" -UserAgent "Mozilla/5.0" -UseBasicParsing
            $Token = $Response.Links | Where-Object { $_.href -like "*confirm=*" } | Select-Object -ExpandProperty href
            if ($Token) {
                $DirectLink = "https://docs.google.com/uc?export=download&confirm=$($Token.Split('=')[-1])&id=$FileId"
                Invoke-WebRequest -Uri $DirectLink -OutFile $ZipPath -UserAgent "Mozilla/5.0" -UseBasicParsing
            } else {
                Invoke-WebRequest -Uri $BaseUrl -OutFile $ZipPath -UserAgent "Mozilla/5.0" -UseBasicParsing
            }
        } else {
            Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing
        }

        $StatusText.Text = "Extracting $Name..."
        if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
        
        $ExeToRun = Get-ChildItem -Path $ExtractPath -Filter $TargetFile -Recurse | Select-Object -First 1
        
        if ($ExeToRun) {
            $StatusText.Text = "Running $Name..."
            $oldDir = Get-Location
            Set-Location $ExeToRun.DirectoryName
            Start-Process -FilePath $ExeToRun.FullName -Wait
            Set-Location $oldDir
        }
        
        Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        $StatusText.Text = "$Name completed!"; $StatusText.Foreground = "#00FF00"
    } catch { $StatusText.Text = "Error in $Name"; $StatusText.Foreground = "Red" }
}

function Run-GenP_Dynamic ($Url) {
    $StatusText.Text = "Downloading GenP-main..."; $StatusText.Foreground = "#FFFF00"
    $ZipPath = Join-Path $env:TEMP "GenP.zip"
    $ExtractPath = Join-Path $env:TEMP "CA_GenP"
    
    try {
        Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing
        $StatusText.Text = "Extracting GenP-main..."
        if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
        
        $ExeList = Get-ChildItem -Path "$ExtractPath\GenP-main\Releases" -Filter "*.exe" -Recurse
        
        if ($ExeList.Count -eq 0) {
            [System.Windows.MessageBox]::Show("No .exe files found!", "Error")
            return
        }

        [xml]$PickerXAML = @"
        <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="Select GenP Version" Height="250" Width="350" WindowStartupLocation="CenterScreen" Background="#1E1E1E" ResizeMode="NoResize">
            <StackPanel Margin="20">
                <TextBlock Text="Select Version:" Foreground="#00FFFF" Margin="0,0,0,10" FontWeight="Bold"/>
                <ComboBox Name="ComboVersions" Height="30" Margin="0,0,0,20"/>
                <Button Name="BtnRun" Content="Run Selected" Height="40" Background="#00B4D8" Foreground="White" BorderThickness="0" Cursor="Hand"/>
            </StackPanel>
        </Window>
"@
        $PickerReader = (New-Object System.Xml.XmlNodeReader $PickerXAML)
        $PickerWindow = [Windows.Markup.XamlReader]::Load($PickerReader)
        $Combo = $PickerWindow.FindName("ComboVersions")
        $BtnRun = $PickerWindow.FindName("BtnRun")
        
        foreach ($exe in $ExeList) { [void]$Combo.Items.Add($exe.Name) }
        $Combo.SelectedIndex = 0
        
        $BtnRun.Add_Click({
            $SelectedName = $Combo.SelectedItem
            $SelectedExe = $ExeList | Where-Object Name -eq $SelectedName
            $oldDir = Get-Location
            Set-Location $SelectedExe.DirectoryName
            Start-Process -FilePath $SelectedExe.FullName -Wait
            Set-Location $oldDir
            $PickerWindow.Close()
        })
        
        $StatusText.Text = "Waiting for GenP..."
        $PickerWindow.ShowDialog() | Out-Null
        
        Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        $StatusText.Text = "GenP finished!"; $StatusText.Foreground = "#00FF00"
    } catch { $StatusText.Text = "Error in GenP" }
}

# ==========================================
# --- 4. BUTTON BINDINGS ---
# ==========================================
$BtnOfficeSetup.Add_Click({ Run-Zip -Name "Office2019_x64_x86" -Url $Links.OfficeIso -TargetFile "setup.exe" })
$BtnOfficeAct.Add_Click({ Run-ScriptOrExe -Name "Office_16-19" -Url $Links.Office16 -Extension ".exe" })
$BtnScrubber.Add_Click({ Run-Zip -Name "OfficeScrubber" -Url $Links.Scrubber -TargetFile "OfficeScrubber.cmd" })
$BtnWinTools.Add_Click({ Run-ScriptOrExe -Name "WinOfficeTools" -Url $Links.WinTools -Extension ".bat" })
$BtnGenP.Add_Click({ Run-GenP_Dynamic -Url $Links.GenP })
$BtnWinrar.Add_Click({ Run-Zip -Name "Winrar" -Url $Links.Winrar -TargetFile "Winrar.cmd" })
$BtnUpdate.Add_Click({ Run-ScriptOrExe -Name "UpdateSystemWithPSCheck" -Url $Links.UpdateSystem -Extension ".bat" })

$BtnSFC.Add_Click({ Start-Process cmd -ArgumentList "/c sfc /scannow & pause" })
$BtnWifi.Add_Click({ ipconfig /flushdns | Out-Null; ipconfig /release | Out-Null; ipconfig /renew | Out-Null; $StatusText.Text = "Network Reset Complete!" })
$BtnKey.Add_Click({
    $k = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform' -ErrorAction SilentlyContinue).BackupProductKeyDefault
    if ($k) { [System.Windows.MessageBox]::Show("Key: $k", "Product Key") } else { [System.Windows.MessageBox]::Show("No OEM/Digital Key found.", "Product Key") }
})

$Window.ShowDialog() | Out-Null
