"""
El Windows escondido, preparado desde el instalador de Apogeo (lo llama motor.py). Todo de Microsoft y sin preguntas:

  1. El catálogo de la herramienta oficial de Microsoft (Media Creation Tool) dice dónde está Windows 11 en español
     (un .esd en dl.delivery.mp.microsoft.com, con su suma). Se baja al disco de Apogeo y se comprueba.
  2. La edición: la de la clave que trae el PC en su firmware (tabla MSDM). La clave se descodifica aquí mismo (nunca
     se apunta ni sale del PC) y su grupo se busca en la lista de claves del propio Windows (pkeyconfig): así sale
     Home, Home Single Language o Pro, la que se activará sola. Sin clave en el PC (una máquina virtual), Home.
  3. Se aplica esa edición a la partición de Windows (wimlib, como hace DISM).
  4. Los archivos de arranque de Windows solo los sabe poner bcdboot, que es de Windows: se deja en la partición EFI un
     Windows PE (el de la misma descarga) que al arrancar una vez ejecuta bcdboot, se borra y reinicia. Entonces
     Windows termina de prepararse (OOBE: tu cuenta Microsoft) y, al entrar, instala el puente de Apogeo
     (instalar.cmd: la tarea de arranque, entrar sin contraseña…).

Ajustes que van con él (unattend.xml): español, el reloj en UTC como Apogeo (si no, la hora sale mal al cambiar), y
sin cifrado de dispositivo automático (BitLocker con cuenta Microsoft: al saltar desde Apogeo pediría la clave de
recuperación).
"""
import base64
import hashlib
import os
import re
import shutil
import subprocess
import tempfile
import time
import xml.etree.ElementTree as ET

CATALOGO = 'https://go.microsoft.com/fwlink/?LinkId=2156292'   # products.xml de la Media Creation Tool de Windows 11
IDIOMA = 'es-es'
MSDM = '/sys/firmware/acpi/tables/MSDM'
ALFABETO = 'BCDFGHJKMPQRTVWXY2346789'
PKEYCONFIG = '/Windows/System32/spp/tokens/pkeyconfig/pkeyconfig.xrm-ms'

UNATTEND = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Apogeo: Windows en español, el reloj en UTC (como Apogeo), sin cifrado automático y, al entrar por primera vez,
     el puente de Apogeo. Tu cuenta la eliges tú en la preparación de Windows. -->
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>{equipo}</ComputerName>
      <TimeZone>Romance Standard Time</TimeZone>
    </component>
    <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Path>reg add HKLM\\SYSTEM\\CurrentControlSet\\Control\\TimeZoneInformation /v RealTimeIsUniversal /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Path>reg add HKLM\\SYSTEM\\CurrentControlSet\\Control\\BitLocker /v PreventDeviceEncryption /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>040a:0000040a</InputLocale>
      <SystemLocale>es-ES</SystemLocale>
      <UILanguage>es-ES</UILanguage>
      <UserLocale>es-ES</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <CommandLine>cmd /c C:\\Apogeo-instalar\\instalar.cmd</CommandLine>
          <Description>Apogeo: el puente del Windows escondido</Description>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
'''

# Lo que hace el Windows PE al arrancar (una vez): los archivos de arranque de tu Windows, borrarse y reiniciar
WINPESHL = '''[LaunchApps]
%SYSTEMROOT%\\System32\\wpeinit.exe
%SYSTEMROOT%\\System32\\cmd.exe, /c %SYSTEMROOT%\\System32\\apogeo.cmd
'''
PE_CMD = '''@echo off
rem Apogeo: termina de instalar el Windows escondido (los archivos de arranque) y reinicia
echo.
echo   Apogeo esta preparando Windows. Un momento...
echo.
set W=
for %%d in (C D E F G H I J K L M N O P Q R T U V W Y Z) do if exist %%d:\\Windows\\System32\\apogeo-destino.txt set W=%%d:
if not defined W (
  echo   No se encuentra la particion de Windows.
  pause
  exit /b 1
)
bcdboot %W%\\Windows /l es-es /f UEFI
del /q %W%\\Windows\\System32\\apogeo-destino.txt
mountvol S: /s
rd /s /q S:\\sources
del /q S:\\boot\\boot.sdi
rd /s /q S:\\EFI\\apogeo-pe
wpeutil reboot
'''


def _texto(f, k):
    return (f.findtext(k) or '').strip()


def catalogo(run, tmp):
    """El .esd de Windows 11 en español (x64, el de consumo) del catálogo de Microsoft: {url, sha1, tamano, nombre}."""
    cab = os.path.join(tmp, 'products.cab')
    run(['curl', '-fsSL', '--retry', '5', '-o', cab, CATALOGO])
    run(['bsdtar', '-xf', cab, '-C', tmp])
    raiz = ET.parse(os.path.join(tmp, 'products.xml'))
    for f in raiz.iter('File'):
        if (_texto(f, 'LanguageCode') == IDIOMA and _texto(f, 'Architecture') == 'x64'
                and 'CLIENTCONSUMER_RET' in _texto(f, 'FileName') and _texto(f, 'Edition') == 'Core'):
            return {'url': _texto(f, 'FilePath'), 'sha1': _texto(f, 'Sha1').lower(), 'tamano': int(_texto(f, 'Size')),
                    'nombre': _texto(f, 'FileName')}
    raise RuntimeError('El catálogo de Microsoft no trae Windows 11 en español')


def bajar(d, destino, avisa, run, log):
    """Lo baja (se puede retomar) y comprueba su suma SHA-1 (la del catálogo de Microsoft)."""
    parte = destino + '.part'
    p = subprocess.Popen(['curl', '-fsSL', '--retry', '10', '--retry-delay', '5', '-C', '-', '-o', parte, d['url']],
                         stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    t0, b0 = time.time(), os.path.getsize(parte) if os.path.exists(parte) else 0
    while p.poll() is None:
        time.sleep(1)
        b = os.path.getsize(parte) if os.path.exists(parte) else 0
        vel = (b - b0) / max(1, time.time() - t0)
        quedan = (d['tamano'] - b) / vel if vel > 0 else 0
        avisa('Descargando Windows de Microsoft', b / d['tamano'],
              f'{b / 1e9:.1f} de {d["tamano"] / 1e9:.1f} GB' + (f' · quedan {int(quedan // 60) + 1} min' if vel else ''))
    if p.returncode != 0:
        log(p.stderr.read())
        raise RuntimeError('No se ha podido bajar Windows (¿se ha ido internet?)')
    avisa('Comprobando la descarga', 1.0)
    h = hashlib.sha1()
    with open(parte, 'rb') as f:
        for trozo in iter(lambda: f.read(8 << 20), b''):
            h.update(trozo)
    if h.hexdigest() != d['sha1']:
        os.remove(parte)
        raise RuntimeError('La descarga de Windows ha llegado mal (no coincide su suma); vuelve a intentarlo')
    os.replace(parte, destino)


def imagenes(esd):
    """{índice: {'nombre', 'edicion'}} de lo que lleva el .esd."""
    out = subprocess.run(['wimlib-imagex', 'info', esd], capture_output=True, text=True).stdout
    imgs, cur = {}, None
    for l in out.splitlines():
        m = re.match(r'\s*Index:\s+(\d+)', l)
        if m:
            cur = int(m.group(1))
            imgs[cur] = {'nombre': '', 'edicion': ''}
        elif cur and (m := re.match(r'\s*Name:\s+(.*)', l)):
            imgs[cur]['nombre'] = m.group(1).strip()
        elif cur and (m := re.match(r'\s*Edition ID:\s+(.*)', l)):
            imgs[cur]['edicion'] = m.group(1).strip()
    return imgs


def grupo_de_clave(clave):
    """El grupo (los 20 bits de abajo) de una clave de Windows 8 o posterior: la que lleva «N»."""
    k = clave.replace('-', '').upper()
    if len(k) != 25 or k.count('N') != 1:
        return None
    n = k.index('N')
    k = ALFABETO[n] + k[:n] + k[n + 1:]
    v = 0
    for c in k:
        if c not in ALFABETO:
            return None
        v = v * 24 + ALFABETO.index(c)
    return v & 0xFFFFF


def clave_del_pc():
    """La clave de Windows del firmware (tabla ACPI MSDM), o None. No se apunta nunca."""
    try:
        with open(MSDM, 'rb') as f:
            datos = f.read()
        clave = datos[56:56 + 29].decode('ascii')
        return clave if re.fullmatch(r'[A-Z0-9]{5}(-[A-Z0-9]{5}){4}', clave) else None
    except OSError:
        return None


def edicion_del_pc(esd, imgs, tmp, log):
    """La edición que activa la clave del PC (Core, CoreSingleLanguage, Professional…), o None si no se sabe."""
    clave = clave_del_pc()
    if not clave:
        log('windows: el PC no trae clave en el firmware')
        return None
    grupo = grupo_de_clave(clave)
    clave = None
    if grupo is None:
        log('windows: la clave del PC no es de las de ahora')
        return None
    idx = next((i for i, x in imgs.items() if x['edicion'] == 'Core'), None)
    if not idx:
        return None
    subprocess.run(['wimlib-imagex', 'extract', esd, str(idx), PKEYCONFIG, f'--dest-dir={tmp}', '--no-acls'],
                   capture_output=True)
    ruta = os.path.join(tmp, 'pkeyconfig.xrm-ms')
    if not os.path.exists(ruta):
        return None
    xrm = open(ruta, encoding='utf-8', errors='replace').read()
    m = re.search(r'<tm:infoBin name="pkeyConfigData">([^<]+)</tm:infoBin>', xrm)
    if not m:
        return None
    datos = base64.b64decode(m.group(1)).decode('utf-16', errors='replace')
    for conf in re.findall(r'<Configuration>(.*?)</Configuration>', datos, re.S):
        g = re.search(r'<RefGroupId>(\d+)</RefGroupId>', conf)
        ed = re.search(r'<EditionId>([^<]+)</EditionId>', conf)
        if g and ed and int(g.group(1)) == grupo:
            log('windows: la clave del PC es de la edición', ed.group(1))
            return ed.group(1)
    log('windows: el grupo de la clave del PC no está en la lista de este Windows')
    return None


def preparar(e, destino, part_windows, part_efi, avisa, run, log):
    tmp = tempfile.mkdtemp(prefix='apogeo-windows-', dir=f'{destino}/var/tmp')
    esd = os.path.join(f'{destino}/var/tmp', 'windows.esd')
    try:
        avisa('Buscando Windows en Microsoft', 0.0)
        d = catalogo(run, tmp)
        log('windows:', d['nombre'])
        bajar(d, esd, lambda t, p, det='': avisa(t, 0.6 * p, det), run, log)

        imgs = imagenes(esd)
        log('windows: imágenes', {i: x['edicion'] or x['nombre'] for i, x in imgs.items()})
        quiere = edicion_del_pc(esd, imgs, tmp, log) or 'Core'
        idx = next((i for i, x in imgs.items() if x['edicion'] == quiere), None)
        if not idx:
            log('windows: no está la edición', quiere, '; se pone Home')
            idx = next(i for i, x in imgs.items() if x['edicion'] == 'Core')
        pe = next(i for i, x in imgs.items() if 'Windows PE' in x['nombre'])
        media = next(i for i, x in imgs.items() if 'Setup Media' in x['nombre'])

        # Windows en su partición (como DISM /Apply-Image)
        def linea(l):
            m = re.search(r'\((\d+)%\) done', l)
            if m:
                avisa('Instalando Windows', 0.62 + 0.3 * int(m.group(1)) / 100)
        avisa('Instalando Windows', 0.62)
        run(['wimlib-imagex', 'apply', esd, str(idx), part_windows], linea=linea)

        # Lo de Apogeo dentro de Windows: la marca para el PE, la respuesta de la preparación y el puente
        win = os.path.join(tmp, 'win')
        os.makedirs(win)
        run(['ntfs-3g', part_windows, win])
        try:
            open(os.path.join(win, 'Windows/System32/apogeo-destino.txt'), 'w').write('Apogeo\r\n')
            os.makedirs(os.path.join(win, 'Windows/Panther'), exist_ok=True)
            with open(os.path.join(win, 'Windows/Panther/unattend.xml'), 'w', encoding='utf-8') as f:
                f.write(UNATTEND.replace('{equipo}', 'APOGEO-WIN'))
            shutil.copytree(f'{destino}/usr/share/apogeo/windows', os.path.join(win, 'Apogeo-instalar'),
                            dirs_exist_ok=True)
        finally:
            run(['umount', win])

        # El Windows PE de un solo uso, en la partición EFI (con el arranque del propio medio de Windows)
        avisa('Preparando el primer arranque de Windows', 0.94)
        boot = f'{destino}/boot'
        medio = os.path.join(tmp, 'medio')
        run(['wimlib-imagex', 'extract', esd, str(media), '/efi', '/boot/boot.sdi', f'--dest-dir={medio}',
             '--preserve-dir-structure', '--no-acls'])
        wim = os.path.join(tmp, 'boot.wim')
        run(['wimlib-imagex', 'export', esd, str(pe), wim, '--boot', '--compress=LZX'])
        for nombre, texto in (('winpeshl.ini', WINPESHL), ('apogeo.cmd', PE_CMD)):
            with open(os.path.join(tmp, nombre), 'w', newline='\r\n') as f:
                f.write(texto)
        run(['wimlib-imagex', 'update', wim, '1',
             f'--command=add {tmp}/winpeshl.ini /Windows/System32/winpeshl.ini',
             f'--command=add {tmp}/apogeo.cmd /Windows/System32/apogeo.cmd'])
        os.makedirs(f'{boot}/sources', exist_ok=True)
        shutil.copy(wim, f'{boot}/sources/boot.wim')
        os.makedirs(f'{boot}/boot', exist_ok=True)
        shutil.copy(f'{medio}/boot/boot.sdi', f'{boot}/boot/boot.sdi')
        shutil.copytree(f'{medio}/efi/microsoft/boot', f'{boot}/EFI/Microsoft/Boot', dirs_exist_ok=True)
        os.makedirs(f'{boot}/EFI/apogeo-pe', exist_ok=True)
        shutil.copy(f'{medio}/efi/boot/bootx64.efi', f'{boot}/EFI/apogeo-pe/bootx64.efi')

        # Que el próximo arranque (solo ese) sea el PE
        disco = re.sub(r'p?\d+$', '', part_efi)
        num = re.search(r'(\d+)$', part_efi).group(1)
        antes = set(re.findall(r'^Boot([0-9A-F]{4})', run(['efibootmgr']), re.M))
        run(['efibootmgr', '--create-only', '--disk', disco, '--part', num, '--label', 'Apogeo: preparar Windows',
             '--loader', '\\EFI\\apogeo-pe\\bootx64.efi', '--unicode'])
        nueva = set(re.findall(r'^Boot([0-9A-F]{4})', run(['efibootmgr']), re.M)) - antes
        if nueva:
            run(['efibootmgr', '--bootnext', nueva.pop()])
        avisa('Windows preparado', 1.0)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        for f in (esd, esd + '.part'):
            if os.path.exists(f):
                os.remove(f)
