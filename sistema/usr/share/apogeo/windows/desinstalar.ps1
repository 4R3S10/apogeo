# Apogeo · Windows escondido · lo quita: tu cuenta vuelve al escritorio de siempre y se borra la tarea de arranque.
$ErrorActionPreference = 'Continue'
$usuario = (Get-CimInstance Win32_ComputerSystem).UserName
$sid = (New-Object System.Security.Principal.NTAccount($usuario)).Translate([System.Security.Principal.SecurityIdentifier]).Value
Remove-ItemProperty -Path "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name Shell -ErrorAction SilentlyContinue
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoAdminLogon -Value '0'
Unregister-ScheduledTask -TaskName 'Apogeo-Arranque' -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "  Quitado. Al reiniciar, Windows vuelve a ser el de siempre (C:\Apogeo puedes borrarlo)." -ForegroundColor Green
Read-Host "  Pulsa Intro para cerrar"
