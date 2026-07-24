function Activate-WinRAR {
    try {
        # 1. Find installed WinRAR folder
        $possiblePaths = @(
            (Join-Path $env:ProgramFiles "WinRAR")
            (Join-Path ${env:ProgramFiles(x86)} "WinRAR")
        )

        $winrarFolder = $possiblePaths |
            Where-Object { Test-Path (Join-Path $_ "WinRAR.exe") } |
            Select-Object -First 1

        if (-not $winrarFolder) {
            [System.Windows.MessageBox]::Show(
                "WinRAR is not installed on this computer.`n`n" +
                "Please install WinRAR first from:`nhttps://www.win-rar.com/download.html`n`n" +
                "Then run this activator again.",
                "WinRAR Not Found",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            ) | Out-Null

            Set-Status "WinRAR is not installed." "#FFAA00"
            return
        }

        if (-not (Confirm-Action `
            "WinRAR was found at:`n$winrarFolder`n`nApply the license key?" `
            "Activate WinRAR")) {
            return
        }

        # 2. Download license
        $keyPath = Join-Path $script:TemporaryPath "rarreg.key"

        Set-Status "Downloading WinRAR license..." "#FFFF00"
        Invoke-TrackedDownload -Url $script:Links.Winrar -OutputFile $keyPath

        # 3. Validate: real rarreg.key starts with "RAR registration data"
        $content = Get-Content -Path $keyPath -Raw -ErrorAction Stop

        if ($content -notmatch 'RAR registration data') {
            throw "Downloaded file does not look like a valid rarreg.key."
        }

        # 4. Copy to WinRAR install folder
        Set-Status "Applying license..." "#FFFF00"
        $destination = Join-Path $winrarFolder "rarreg.key"

        Copy-Item -Path $keyPath -Destination $destination -Force

        if (Test-Path $destination) {
            Set-Status "WinRAR activated successfully!" "#00FF00"
            Set-Progress -Percent 100 -Text "Complete"

            [System.Windows.MessageBox]::Show(
                "WinRAR has been activated.`n`n" +
                "Open WinRAR to confirm - the title bar should no longer show a trial notice.",
                "WinRAR Activated",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        }
        else {
            throw "License file was not copied successfully."
        }
    }
    catch {
        Show-ToolError -Name "WinRAR Activation" -Exception $_
    }
    finally {
        Remove-Item -Path $keyPath -Force -ErrorAction SilentlyContinue
    }
}
