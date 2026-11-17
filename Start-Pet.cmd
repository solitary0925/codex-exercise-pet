@echo off
start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0plugins\codex-exercise-pet\Pet.ps1" -DataDirectory "%~dp0.runtime" %*
