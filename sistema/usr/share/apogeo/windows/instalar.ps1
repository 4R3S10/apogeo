# Apogeo · Windows escondido · se ejecuta una vez dentro de Windows (como administrador, con instalar.cmd) y lo deja
# preparado para que Apogeo lo use solo para los juegos que no van en Apogeo:
#  - C:\Apogeo con el puente (lo que ves al entrar), la tarea de arranque, el logo y la letra de Apogeo;
#  - la tarea «Apogeo-Arranque» (como SISTEMA al encender: lee la nota de Apogeo y, al acabar, vuelve);
#  - tu cuenta entra directamente en el puente en vez de en el escritorio (el escritorio sigue a mano: «Ir a Windows a
#    instalar» desde la consola de Apogeo, o encender Windows a mano);
#  - sin inicio rápido (Windows apagado del todo: si no, el disco se queda a medias y Apogeo no puede dejar su nota).
# Para quitarlo: desinstalar.cmd.
$ErrorActionPreference = 'Stop'
$Origen = $PSScriptRoot
$Base = 'C:\Apogeo'

Write-Host "`n  Apogeo · preparando el Windows escondido`n" -ForegroundColor Magenta

# ---------- Los archivos ----------
New-Item -ItemType Directory -Force -Path $Base, "$Base\estado" | Out-Null
foreach ($f in 'arranque.ps1', 'puente.ps1', 'puente.vbs', 'logo.png', 'desinstalar.ps1', 'desinstalar.cmd', 'LEEME.txt') {
    if (Test-Path "$Origen\$f") { Copy-Item -Force "$Origen\$f" "$Base\$f" }
}
# Tu cuenta puede dejar en «estado» la orden de volver
icacls "$Base\estado" /grant '*S-1-5-32-545:(OI)(CI)M' | Out-Null

# ---------- La letra de Apogeo ----------
foreach ($ttf in Get-ChildItem "$Origen\letra" -Filter *.ttf -ErrorAction SilentlyContinue) {
    $dest = Join-Path $env:WINDIR "Fonts\$($ttf.Name)"
    if (-not (Test-Path $dest)) {
        Copy-Item $ttf.FullName $dest
        $nombre = [IO.Path]::GetFileNameWithoutExtension($ttf.Name) -replace '-', ' '
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -Name "$nombre (TrueType)" -Value $ttf.Name -Force | Out-Null
    }
}

# ---------- La tarea de arranque ----------
$accion = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Base\arranque.ps1`""
$cuando = New-ScheduledTaskTrigger -AtStartup
$quien = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$como = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName 'Apogeo-Arranque' -Action $accion -Trigger $cuando -Principal $quien -Settings $como -Force | Out-Null

# ---------- Tu cuenta entra en el puente ----------
# (la cuenta que está usando Windows, aunque este programa corra como otro administrador)
$usuario = (Get-CimInstance Win32_ComputerSystem).UserName
$sid = (New-Object System.Security.Principal.NTAccount($usuario)).Translate([System.Security.Principal.SecurityIdentifier]).Value
$clave = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
New-Item -Path $clave -Force | Out-Null
Set-ItemProperty -Path $clave -Name Shell -Value "wscript.exe `"$Base\puente.vbs`""

# ---------- Windows apagado del todo (sin inicio rápido ni hibernación) ----------
powercfg /h off | Out-Null

# ---------- Entrar sin escribir la contraseña ----------
# Windows 11 esconde la casilla «Los usuarios deben escribir su nombre y contraseña»: se enseña y se abre la ventana
# para que la quites tú (te pedirá tu contraseña: la guarda Windows, no Apogeo)
New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device' -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device' -Name DevicePasswordLessBuildVersion -Value 0 -Type DWord

Write-Host "  Listo. Falta una cosa que tienes que hacer tú:" -ForegroundColor Green
Write-Host "  en la ventana que se abre, quita la casilla «Los usuarios deben escribir su nombre y contraseña»,"
Write-Host "  pulsa Aceptar y escribe tu contraseña de Windows. Así Windows entra solo al ir a jugar.`n"
Start-Process netplwiz -Wait
Write-Host "  Ya está. Reinicia para volver a Apogeo (desde ahora, Windows se abre solo para tus juegos)." -ForegroundColor Green
Read-Host "  Pulsa Intro para cerrar"
