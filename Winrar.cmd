@echo off
chcp 65001 >nul 2>&1
title WinRAR Activator
color 0E

echo ===================================================
echo             ACTIVATING EXISTING WINRAR...
echo ===================================================
echo.

:: Check for the key in the same folder as the script
if exist "%~dp0rarreg.key" (
    echo [OK] Found 'rarreg.key' locally.
    
    :: Attempt to copy to the standard installation path
    if exist "%ProgramFiles%\WinRAR\" (
        copy /y "%~dp0rarreg.key" "%ProgramFiles%\WinRAR\" >nul 2>&1
        echo [SUCCESS] Key copied to Program Files.
    ) else if exist "%ProgramFiles(x86)%\WinRAR\" (
        copy /y "%~dp0rarreg.key" "%ProgramFiles(x86)%\WinRAR\" >nul 2>&1
        echo [SUCCESS] Key copied to Program Files (x86).
    ) else (
        echo [ERROR] WinRAR installation folder not found.
    )
) else (
    echo [!] 'rarreg.key' missing locally. Attempting Online Activation...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://captainfahim7.github.io/WinRAR_Activator/WAS.ps1 | iex"
)

echo.
echo [!] Activation task finished!
timeout /t 3 >nul
exit