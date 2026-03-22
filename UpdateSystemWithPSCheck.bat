@echo off
chcp 65001 >nul 2>&1
title Windows Update ^& PS Check

:: Ελεγχος Admin
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [!] Please run this tool as Administrator.
    pause
    exit
)

color 0A
echo ===================================================
echo     CRAZY ALEX - AUTOMATIC SYSTEM UPDATE TOOL
echo ===================================================
echo.
echo [1] Checking PowerShell execution policies...
powershell -Command "Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force"

echo [2] Triggering Windows Update Service...
:: Ξεκινάει το service των Updates αν είναι κλειστό
net start wuauserv >nul 2>&1

echo [3] Searching for Updates...
:: Χρησιμοποιεί το κρυφό εργαλείο των Windows (UsoClient) για να ξεκινήσει το Update
UsoClient ScanInstallWait

echo.
echo [OK] Update process has been started in the background!
echo You can check the Windows Update Settings to see the progress.
echo.
pause