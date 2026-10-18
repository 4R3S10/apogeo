@echo off
rem Apogeo: que Windows entre solo para ir directo a tus juegos (pide permiso de administrador)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0entrar-solo.ps1""'"
