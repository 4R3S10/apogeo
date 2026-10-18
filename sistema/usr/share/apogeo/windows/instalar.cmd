@echo off
rem Apogeo: instalar el puente del Windows escondido (pide permiso de administrador)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0instalar.ps1""'"
