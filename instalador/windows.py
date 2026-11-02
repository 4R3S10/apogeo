"""
El Windows escondido, preparado desde el instalador de Apogeo (lo llama motor.py). Todo de Microsoft y sin preguntas:

  1. El catálogo de la herramienta oficial de Microsoft (Media Creation Tool) dice dónde está Windows 11 en español
     (un .esd en dl.delivery.mp.microsoft.com, con su suma). Se baja al disco de Apogeo y se comprueba.
  2. La edición: la de la clave que trae el PC en su firmware (tabla MSDM). La clave se descodifica aquí mismo (nunca
     se apunta ni sale del PC) y su grupo se busca en la lista de claves del propio Windows (pkeyconfig): así sale
     Home, Home Single Language o Pro, la que se activará sola. Sin clave en el PC (una máquina virtual), Home.
  3. Se aplica esa edición a la partición de Windows (wimlib, como hace DISM).
  4. Los archivos de arranque de Windows solo los sabe poner bcdboot, que es de Windows: se deja en la partición EFI un
     Windows PE (el de la misma descarga) que al arrancar una vez ejecuta bcdboot, se borra y reinicia. Desde ese PE
     bcdboot no puede crear la entrada del firmware (no abre su almacén del sistema), así que la pone Apogeo en su
     primer arranque, la primera, y reinicia: Windows termina de prepararse (OOBE: tu cuenta Microsoft) y, al entrar,
     vuelve a poner Apogeo delante e instala el puente de Apogeo (instalar.cmd: la tarea de arranque, entrar sin
     contraseña…).

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
     Apogeo otra vez el primero al arrancar y el puente de Apogeo. Tu cuenta la eliges tú en la preparación de Windows. -->
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
          <CommandLine>bcdedit /set {fwbootmgr} displayorder {bootmgr} /addlast</CommandLine>
          <Description>Apogeo: Windows ya esta preparado, Apogeo vuelve a arrancar el primero</Description>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>2</Order>
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
rem Los archivos de arranque de Windows en la particion EFI (la entrada del firmware la pone Apogeo al arrancar)
set L=%W%\\apogeo-pe.log
mountvol S: /s > %L% 2>&1
rem (el BCD del medio de instalacion, con el que arranco este PE, no vale para Windows: bcdboot crea uno nuevo)
attrib -h -s -r S:\\EFI\\Microsoft\\Boot\\BCD* >> %L% 2>&1
del /f /q S:\\EFI\\Microsoft\\Boot\\BCD* >> %L% 2>&1
dir /a S:\\EFI\\Microsoft\\Boot >> %L% 2>&1
bcdboot %W%\\Windows /l es-es /s S: /f UEFI >> %L% 2>&1
if errorlevel 1 (
  echo   No se pudo preparar el arranque de Windows. Lo que paso esta en %L%
  pause
  wpeutil reboot
  exit /b 1
)
del /q %W%\\Windows\\System32\\apogeo-destino.txt
rd /s /q S:\\sources
del /q S:\\boot\\boot.sdi
rd /s /q S:\\EFI\\apogeo-pe
wpeutil reboot
'''

# Al primer arranque de Apogeo (antes de la pantalla de entrada): quitar del firmware la entrada del PE (ya no existe),
# poner la de Windows (la primera hasta que termine de prepararse), reiniciar en él y quitarse a sí mismo
LIMPIA = 'apogeo-quitar-pe.service'
LIMPIA_UNIDAD = '''[Unit]
Description=Apogeo: quitar la entrada de arranque de un solo uso de Windows y poner la suya
ConditionPathExists=/sys/firmware/efi
# (antes que apogeo-windows, que pondría Apogeo el primero otra vez antes de reiniciar)
Before=display-manager.service apogeo-windows.service

[Service]
Type=oneshot
ExecStart=/usr/local/lib/apogeo-quitar-pe

[Install]
WantedBy=multi-user.target
'''
LIMPIA_SCRIPT = '''#!/bin/sh
# Apogeo, la primera vez que arranca: quita del firmware la entrada «Apogeo: preparar Windows» (el PE de un solo uso ya
# se borró). Si el PE dejó los archivos de arranque de Windows, le pone su entrada (con los datos con los que Windows la
# reconoce como suya, {bootmgr}: así no crea otra) la primera, porque Windows se reinicia varias veces mientras se
# prepara (tu cuenta Microsoft); cuando entras por primera vez se pone él el último (unattend.xml). Y se quita.
for n in $(efibootmgr | sed -n 's/^Boot\\([0-9A-F]\\{4\\}\\)\\*\\{0,1\\} *Apogeo: preparar Windows.*/\\1/p'); do
    efibootmgr -q -b "$n" -B
done
win=
if [ -f /boot/EFI/Microsoft/Boot/bootmgfw.efi ] && ! efibootmgr | grep -qi 'Windows Boot Manager'; then
    esp=$(findmnt -nro SOURCE /boot)
    datos=$(mktemp)
    echo 'V0lORE9XUwABAAAAiAAAAHgAAABCAEMARABPAEIASgBFAEMAVAA9AHsAOQBkAGUAYQA4ADYAMgBjAC0ANQBjAGQAZAAtADQAZQA3ADAALQBhAGMAYwAxAC0AZgAzADIAYgAzADQANABkADQANwA5ADUAfQAAAAAAAQAAABAAAAAEAAAAf/8EAA==' | base64 -d > "$datos"
    efibootmgr -q --create-only --disk "/dev/$(lsblk -nro PKNAME "$esp")" \\
        --part "$(cat "/sys/class/block/${esp##*/}/partition")" \\
        --label 'Windows Boot Manager' --loader '\\EFI\\Microsoft\\Boot\\bootmgfw.efi' --append-binary-args "$datos"
    rm -f "$datos"
    win=$(efibootmgr | sed -n 's/^Boot\\([0-9A-F]\\{4\\}\\)\\*\\{0,1\\} *Windows Boot Manager.*/\\1/p' | head -n 1)
    orden=$(efibootmgr | sed -n 's/^BootOrder: *//p')
    [ -n "$win" ] && efibootmgr -q -o "$win${orden:+,$orden}"
fi
rm -f /etc/systemd/system/multi-user.target.wants/apogeo-quitar-pe.service /etc/systemd/system/apogeo-quitar-pe.service \\
    /usr/local/lib/apogeo-quitar-pe
if [ -n "$win" ]; then
    sync
    systemctl --no-block reboot
fi
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
        for nombre in ('winpeshl.ini', 'apogeo.cmd'):   # (wimlib admite un solo --command cada vez)
            run(['wimlib-imagex', 'update', wim, '1', f'--command=add {tmp}/{nombre} /Windows/System32/{nombre}'])
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
        # y que Apogeo, la primera vez que arranque (ya con Windows preparado), quite esa entrada del firmware
        with open(f'{destino}/etc/systemd/system/{LIMPIA}', 'w') as f:
            f.write(LIMPIA_UNIDAD)
        os.makedirs(f'{destino}/usr/local/lib', exist_ok=True)
        with open(f'{destino}/usr/local/lib/apogeo-quitar-pe', 'w') as f:
            f.write(LIMPIA_SCRIPT)
        os.chmod(f'{destino}/usr/local/lib/apogeo-quitar-pe', 0o755)
        os.makedirs(f'{destino}/etc/systemd/system/multi-user.target.wants', exist_ok=True)
        os.symlink(f'/etc/systemd/system/{LIMPIA}', f'{destino}/etc/systemd/system/multi-user.target.wants/{LIMPIA}')
        avisa('Windows preparado', 1.0)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        for f in (esd, esd + '.part'):
            if os.path.exists(f):
                os.remove(f)
