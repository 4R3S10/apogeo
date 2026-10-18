@echo off
rem Apogeo: desinstalar el puente del Windows escondido (pide permiso de administrador)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0desinstalar.ps1""'"
