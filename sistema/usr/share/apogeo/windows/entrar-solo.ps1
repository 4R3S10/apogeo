# Apogeo · Windows escondido · que Windows entre solo (sin pedir la contraseña) para ir directo al juego.
# Como Autologon de Microsoft (Sysinternals): tu contraseña se guarda cifrada en el almacén protegido del sistema (LSA,
# el secreto «DefaultPassword»), nunca en un archivo ni a la vista en el registro. Se comprueba antes de guardarla.
# Con una cuenta Microsoft, Windows entra con tu correo (dominio «MicrosoftAccount», como hace netplwiz) y la contraseña
# es la de tu cuenta Microsoft, no el PIN. Y se apaga «Solo permitir Windows Hello para cuentas Microsoft»: con eso
# encendido (lo trae Windows 11 de serie) Windows no hace caso de la entrada automática y pide el PIN.
# Para quitarlo: desinstalar.cmd (o volver a ejecutar esto y dejar la contraseña vacía; o entrar-solo.ps1 -Quitar).
param([switch]$Quitar)
$ErrorActionPreference = 'Stop'

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ApogeoLsa {
    [StructLayout(LayoutKind.Sequential)] struct LSA_UNICODE_STRING { public UInt16 Length; public UInt16 MaximumLength; public IntPtr Buffer; }
    [StructLayout(LayoutKind.Sequential)] struct LSA_OBJECT_ATTRIBUTES { public int Length; public IntPtr RootDirectory; public IntPtr ObjectName; public int Attributes; public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService; }
    [DllImport("advapi32.dll")] static extern uint LsaOpenPolicy(IntPtr system, ref LSA_OBJECT_ATTRIBUTES attrs, int access, out IntPtr handle);
    [DllImport("advapi32.dll")] static extern uint LsaStorePrivateData(IntPtr handle, ref LSA_UNICODE_STRING key, IntPtr data);
    [DllImport("advapi32.dll")] static extern uint LsaClose(IntPtr handle);
    [DllImport("advapi32.dll")] static extern int LsaNtStatusToWinError(uint status);
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool LogonUser(string user, string domain, string password, int type, int provider, out IntPtr token);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    // ¿Entra esa cuenta con esa contraseña? (como al encender: sesión interactiva)
    public static bool Check(string user, string domain, string password) {
        IntPtr token;
        if (!LogonUser(user, domain, password, 2, 0, out token)) return false;
        CloseHandle(token);
        return true;
    }
    static LSA_UNICODE_STRING Str(string s) {
        var u = new LSA_UNICODE_STRING();
        u.Buffer = Marshal.StringToHGlobalUni(s);
        u.Length = (UInt16)(s.Length * 2);
        u.MaximumLength = (UInt16)(s.Length * 2 + 2);
        return u;
    }
    // valor null: borra el secreto
    public static int Store(string key, string value) {
        var attrs = new LSA_OBJECT_ATTRIBUTES();
        IntPtr policy;
        uint r = LsaOpenPolicy(IntPtr.Zero, ref attrs, 0x000F0FFF, out policy);
        if (r != 0) return LsaNtStatusToWinError(r);
        var k = Str(key);
        IntPtr data = IntPtr.Zero;
        LSA_UNICODE_STRING v = new LSA_UNICODE_STRING();
        if (value != null) { v = Str(value); data = Marshal.AllocHGlobal(Marshal.SizeOf(v)); Marshal.StructureToPtr(v, data, false); }
        r = LsaStorePrivateData(policy, ref k, data);
        LsaClose(policy);
        Marshal.FreeHGlobal(k.Buffer);
        if (value != null) { Marshal.ZeroFreeGlobalAllocUnicode(v.Buffer); Marshal.FreeHGlobal(data); }
        return LsaNtStatusToWinError(r);
    }
}
'@
$usuario = (Get-CimInstance Win32_ComputerSystem).UserName      # EQUIPO\nombre
$equipo, $nombre = $usuario -split '\\', 2
$sid = (New-Object System.Security.Principal.NTAccount($usuario)).Translate([System.Security.Principal.SecurityIdentifier]).Value
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$sinClave = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'
$Base = 'C:\Apogeo'

# ¿Cuenta Microsoft? Su correo está en la caché de identidades de Windows
$correo = $null
try {
    if ((Get-LocalUser -SID $sid -ErrorAction Stop).PrincipalSource -eq 'MicrosoftAccount') {
        $correo = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\IdentityStore\Cache\$sid\IdentityCache\$sid" -ErrorAction Stop).UserName
    }
} catch { $correo = $null }
# Las formas de entrar que se prueban (la primera que valga es la que se guarda)
$cuentas = @()
if ($correo) { $cuentas += , @($correo, 'MicrosoftAccount') }
$cuentas += , @($nombre, $equipo)

function Quitar-Entrada {
    # Windows vuelve a pedir la contraseña: sin el secreto guardado y con «Solo Windows Hello» como estaba
    [ApogeoLsa]::Store('DefaultPassword', $null) | Out-Null
    Set-ItemProperty $winlogon -Name AutoAdminLogon -Value '0'
    if (Test-Path "$Base\sin-contrasena-antes.txt") {
        Set-ItemProperty $sinClave -Name DevicePasswordLessBuildVersion -Value ([int](Get-Content "$Base\sin-contrasena-antes.txt")) -Type DWord
        Remove-Item "$Base\sin-contrasena-antes.txt"
    }
}
if ($Quitar) { Quitar-Entrada; return }

Write-Host "`n  Apogeo · que Windows entre solo para ir directo a tus juegos`n" -ForegroundColor Magenta
if ($correo) {
    Write-Host "  Escribe la contraseña de tu cuenta Microsoft ($correo): la de tu correo, no el PIN."
} else {
    Write-Host "  Escribe tu contraseña de Windows (la de la cuenta $nombre)."
}
Write-Host "  Se guarda cifrada en Windows, no en un archivo. Déjala vacía para que Windows vuelva a pedirla siempre.`n"
for ($i = 0; $i -lt 3; $i++) {
    $seguro = Read-Host '  Contraseña' -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($seguro)
    $clave = [Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
    [Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($ptr)   # (la copia sin cifrar, borrada)
    if ($clave -eq '') {
        Quitar-Entrada
        Write-Host "`n  Hecho: Windows pedirá la contraseña al entrar." -ForegroundColor Yellow
        break
    }
    $vale = $cuentas | Where-Object { [ApogeoLsa]::Check($_[0], $_[1], $clave) } | Select-Object -First 1
    if (-not $vale) {
        Write-Host '  No es esa. Prueba otra vez.' -ForegroundColor Red
        continue
    }
    $r = [ApogeoLsa]::Store('DefaultPassword', $clave)
    $clave = $null
    if ($r -ne 0) { Write-Host "  Windows no ha dejado guardarla (error $r)." -ForegroundColor Red; break }
    Set-ItemProperty $winlogon -Name AutoAdminLogon -Value '1'
    Set-ItemProperty $winlogon -Name DefaultUserName -Value $vale[0]
    Set-ItemProperty $winlogon -Name DefaultDomainName -Value $vale[1]
    # Sin «solo Windows Hello» (si estaba, se apunta para devolverlo al quitar el puente)
    $antes = (Get-ItemProperty $sinClave -Name DevicePasswordLessBuildVersion -ErrorAction SilentlyContinue).DevicePasswordLessBuildVersion
    if ($null -ne $antes -and $antes -ne 0) {
        New-Item -ItemType Directory -Force -Path $Base | Out-Null
        Set-Content -Path "$Base\sin-contrasena-antes.txt" -Value $antes
    }
    if (-not (Test-Path $sinClave)) { New-Item -Path $sinClave -Force | Out-Null }   # (-Force sobre una que ya está la vaciaría)
    Set-ItemProperty $sinClave -Name DevicePasswordLessBuildVersion -Value 0 -Type DWord
    Remove-ItemProperty $winlogon -Name DefaultPassword -ErrorAction SilentlyContinue   # (nunca a la vista)
    Remove-ItemProperty $winlogon -Name AutoLogonCount -ErrorAction SilentlyContinue
    Write-Host "`n  Listo: desde ahora Windows entra solo y va directo al juego." -ForegroundColor Green
    break
}
if ($MyInvocation.InvocationName -ne '.') { Read-Host "`n  Pulsa Intro para cerrar" | Out-Null }
