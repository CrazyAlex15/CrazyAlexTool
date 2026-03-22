<#
    CrazyAlex Cloud Suite - v9.2 (Final Stable)
    - Removed OfficeIso
    - Integrated Terminal
    - Fixed XAML Typo
#>

# --- AUTO-ADMIN ELEVATION ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# ==========================================
# --- 1. VERIFIED LINKS ---
# ==========================================
$Links = @{
    Winrar       = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/Winrar.zip"
    GenP         = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/GenP-main.zip"
    Scrubber     = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/OfficeScrubber.zip"
    Office16     = "https://github.com/CrazyAlex15/CrazyAlexTool/releases/download/V1.0/Office_16-19.exe"
    UpdateSystem = "https://github.com/CrazyAlex15/CrazyAlexTool/raw/refs/heads/main/UpdateSystemWithPSCheck.bat"
}

# ==========================================
# --- 2. WPF GUI ---
# ==========================================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="CrazyAlex Cloud Suite" Height="700" Width="1000" 
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
                <TextBlock Text="CLOUD SUITE v9.2" Foreground="#AAAAAA" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,40"/>
                <TextBlock Text="STATUS:" Foreground="#777777" FontSize="12" Margin="0,0,0,5"/>
                <TextBlock Name="StatusText" Text="Ready." Foreground="#00FF00" FontSize="13" TextWrapping="Wrap" Margin="0,0,0,20"/>
            </StackPanel>
        </Border>

        <Grid Grid.Column="1" Margin="20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/> 
                <RowDefinition Height="*"/>    
            </Grid.RowDefinitions>

            <StackPanel Grid.Row="0">
                <TextBlock Text="OFFICE &amp; ACTIVATORS" Foreground="#00FFFF" FontSize="16" FontWeight="Bold" Margin="0,0,0,10"/>
                <WrapPanel>
                    <Button Name="BtnWinOfficeTools" Content="WinOfficeTools (MAS)" Width="180" Height="40" Margin="0,0,10,10" Background="#D81B60" Foreground="White" BorderThickness="0" FontWeight="Bold"/>
                    <Button Name="BtnOfficeAct" Content="Activate Office 16-19" Width="180" Height="40" Margin="0,0,10,10" Background="#2D2D30" Foreground="White" BorderThickness="0"/>
                    <Button Name="BtnScrubber" Content="Office Scrubber" Width="180" Height="40" Margin="0,0,10,10" Background="#2D2D30" Foreground="White" BorderThickness="0"/>
                    <Button Name="BtnGenP" Content="GenP-main" Width="180" Height="40" Margin="0,0,10,10" Background="#5C2E7E" Foreground="White" BorderThickness="0"/>
                    <Button Name="BtnWinrar" Content="Winrar" Width="180" Height="40" Margin="0,0,10,10" Background="#5C2E7E" Foreground="White" BorderThickness="0"/>
                    <Button Name="BtnUpdate" Content="System Update" Width="180" Height="40" Margin="0,0,10,10" Background="#1E5128" Foreground="White" BorderThickness="0"/>
                </WrapPanel>

                <TextBlock Text="SYSTEM TOOLS" Foreground="#00FFFF" FontSize="16" FontWeight="Bold" Margin="0,10,0,10"/>
                <WrapPanel Margin="0,0,0,15">
                    <Button Name="BtnSFC" Content="SFC Scan" Width="120" Height="40" Margin="0,0,10,10" Background="#1E5128" Foreground="White" BorderThickness="0"/>
                    <Button Name="BtnWifi" Content="Fix Network" Width="120" Height="40" Margin="0,0,10,10" Background="#1E5128" Foreground="White" BorderThickness="0"/>
                    <Button Name="BtnKey" Content="Show Windows Key" Width="150" Height="40" Margin="0,0,10,10" Background="#1E5128" Foreground="White" BorderThickness="0"/>
                </WrapPanel>
            </StackPanel>

            <GroupBox Header="Console Output" Grid.Row="1" Foreground="#00FFFF" BorderBrush="#333333" Margin="0,10,0,0">
                <TextBox Name="OutputBox" Background="#000000" Foreground="#00FF00" 
                         IsReadOnly="True" VerticalScrollBarVisibility="Auto" 
                         FontFamily="Consolas" FontSize="12" BorderThickness="0" 
                         AcceptsReturn="True" TextWrapping="Wrap"/>
            </GroupBox>
        </Grid>
    </Grid>
</Window>
"@

$Reader = (New-Object System.Xml.XmlNodeReader $XAML)
try {
    $Window = [Windows.Markup.XamlReader]::Load($Reader)
} catch {
    Write-Host "XAML Critical Error: $($_.Exception.Message)" -ForegroundColor Red
    pause; exit
}

$StatusText = $Window.FindName("StatusText")
$OutputBox = $Window.FindName("OutputBox")

# Helper to Update GUI and Terminal
function Write-Log ($Message) {
    $Timestamp = Get-Date -Format "HH:mm:ss"
    if ($OutputBox) {
        $OutputBox.AppendText("[$Timestamp] $Message`r`n")
        $OutputBox.ScrollToEnd()
    }
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{})
}

# --- FUNCTIONS ---
function Run-ScriptOrExe ($Name, $Url, $Extension) {
    $StatusText.Text = "Working..."; Write-Log "Downloading $Name..."
    $TempPath = Join-Path $env:TEMP "$Name$Extension"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $TempPath -UseBasicParsing
        Write-Log "Running $Name..."
        Start-Process -FilePath $TempPath -Wait
        Write-Log "Done."
    } catch { Write-Log "ERROR: $($_.Exception.Message)" }
    $StatusText.Text = "Ready."
}

function Run-Zip ($Name, $Url, $TargetFile) {
    $StatusText.Text = "Working..."; Write-Log "Downloading $Name (ZIP)..."
    $ZipPath = Join-Path $env:TEMP "$Name.zip"
    $ExtractPath = Join-Path $env:TEMP "CA_$Name"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing
        Write-Log "Extracting $Name..."
        if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
        $Exe = Get-ChildItem $ExtractPath -Filter $TargetFile -Recurse | Select -First 1
        if ($Exe) {
            Write-Log "Launching $($Exe.Name)..."
            Start-Process $Exe.FullName -Wait
            Write-Log "Task Finished."
        }
    } catch { Write-Log "ERROR: $($_.Exception.Message)" }
    $StatusText.Text = "Ready."
}

# --- BUTTON BINDINGS ---

$Window.FindName("BtnWinOfficeTools").Add_Click({
    Write-Log "Starting Microsoft Activation Scripts (MAS)..."
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://get.activated.win | iex"
    Write-Log "MAS Command Sent."
})

$Window.FindName("BtnOfficeAct").Add_Click({ Run-ScriptOrExe -Name "OfficeAct" -Url $Links.Office16 -Extension ".exe" })
$Window.FindName("BtnScrubber").Add_Click({ Run-Zip -Name "Scrubber" -Url $Links.Scrubber -TargetFile "OfficeScrubber.cmd" })
$Window.FindName("BtnWinrar").Add_Click({ Run-Zip -Name "Winrar" -Url $Links.Winrar -TargetFile "Winrar.cmd" })
$Window.FindName("BtnUpdate").Add_Click({ Run-ScriptOrExe -Name "Update" -Url $Links.UpdateSystem -Extension ".bat" })
$Window.FindName("BtnGenP").Add_Click({ Run-Zip -Name "GenP" -Url $Links.GenP -TargetFile "RunMe.exe" })

$Window.FindName("BtnSFC").Add_Click({ 
    Write-Log "Running SFC Scan in background..."
    Start-Process sfc -ArgumentList "/scannow" -Wait
    Write-Log "SFC Complete."
})

$Window.FindName("BtnWifi").Add_Click({ 
    Write-Log "Flushing DNS Cache..."
    ipconfig /flushdns | Out-Null
    Write-Log "Network DNS Flushed."
})

$Window.FindName("BtnKey").Add_Click({
    try {
        $k = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform').BackupProductKeyDefault
        Write-Log "Detected Key: $k"
        [System.Windows.MessageBox]::Show("Windows Key: $k")
    } catch { Write-Log "Error finding key." }
})

Write-Log "CrazyAlex Suite v9.2 Loaded. System Ready."
$Window.ShowDialog() | Out-Null
