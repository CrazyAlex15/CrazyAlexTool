@echo off
chcp 65001 >nul 2>&1
title Custom PowerShell Runner

:: ==========================================
:: 1. ΕΛΕΓΧΟΣ ΓΙΑ ΔΙΚΑΙΩΜΑΤΑ ADMIN
:: ==========================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting Administrative Privileges...
    :: Κάνει επανεκκίνηση του εαυτού του ζητώντας δικαιώματα Admin
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: ==========================================
:: 2. ΕΚΤΕΛΕΣΗ ΤΗΣ ΕΝΤΟΛΗΣ ΣΟΥ (ΩΣ ADMIN ΠΛΕΟΝ)
:: ==========================================
color 0B
echo Running your custom PowerShell command...
echo.

:: ΒΑΛΕ ΤΗΝ ΕΝΤΟΛΗ ΣΟΥ ΑΝΑΜΕΣΑ ΣΤΑ ΑΓΚΙΣΤΡΑ ΤΗΣ ΠΑΡΑΚΑΤΩ ΓΡΑΜΜΗΣ:
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://get.activated.win | iex"
echo.
echo Command executed successfully!
pause