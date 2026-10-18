# Apogeo · Windows escondido · que Windows entre solo (sin pedir la contraseña) para ir directo al juego.
# Como Autologon de Microsoft (Sysinternals): tu contraseña se guarda cifrada en el almacén protegido del sistema (LSA,
# el secreto «DefaultPassword»), nunca en un archivo ni a la vista en el registro. Se comprueba antes de guardarla.
# Para quitarlo: desinstalar.cmd (o volver a ejecutar esto y dejar la contraseña vacía).
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
Add-Type -AssemblyName System.DirectoryServices.AccountManagement

$usuario = (Get-CimInstance Win32_ComputerSystem).UserName      # EQUIPO\nombre
$equipo, $nombre = $usuario -split '\\', 2
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

Write-Host "`n  Apogeo · que Windows entre solo para ir directo a tus juegos`n" -ForegroundColor Magenta
Write-Host "  Escribe tu contraseña de Windows (la de la cuenta $nombre). Se guarda cifrada en Windows, no en un archivo."
Write-Host "  Déjala vacía para que Windows vuelva a pedirla siempre.`n"
$contexto = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Machine')
for ($i = 0; $i -lt 3; $i++) {
    $seguro = Read-Host '  Contraseña' -AsSecureString
    $clave = [Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($seguro))
    if ($clave -eq '') {
        [ApogeoLsa]::Store('DefaultPassword', $null) | Out-Null
        Set-ItemProperty $winlogon -Name AutoAdminLogon -Value '0'
        Write-Host "`n  Hecho: Windows pedirá la contraseña al entrar." -ForegroundColor Yellow
        break
    }
    if (-not $contexto.ValidateCredentials($nombre, $clave)) {
        Write-Host '  No es esa. Prueba otra vez.' -ForegroundColor Red
        continue
    }
    $r = [ApogeoLsa]::Store('DefaultPassword', $clave)
    $clave = $null
    if ($r -ne 0) { Write-Host "  Windows no ha dejado guardarla (error $r)." -ForegroundColor Red; break }
    Set-ItemProperty $winlogon -Name AutoAdminLogon -Value '1'
    Set-ItemProperty $winlogon -Name DefaultUserName -Value $nombre
    Set-ItemProperty $winlogon -Name DefaultDomainName -Value $equipo
    Remove-ItemProperty $winlogon -Name DefaultPassword -ErrorAction SilentlyContinue   # (nunca a la vista)
    Remove-ItemProperty $winlogon -Name AutoLogonCount -ErrorAction SilentlyContinue
    Write-Host "`n  Listo: desde ahora Windows entra solo y va directo al juego." -ForegroundColor Green
    break
}
if ($MyInvocation.InvocationName -ne '.') { Read-Host "`n  Pulsa Intro para cerrar" | Out-Null }
