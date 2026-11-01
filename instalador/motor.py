#!/usr/bin/python3
"""
El motor del instalador de Apogeo (lo lanza apogeo-instalador como root, en el USB). Lee lo que has elegido (JSON, por
la entrada: así tu contraseña nunca va a un archivo) y deja el disco así:

  1  EFI      4 GiB   FAT32: el arranque de Apogeo (Limine) y el de Windows, y la nota del puente (EFI/apogeo)
  2  MSR     16 MiB   la reservada que Windows quiere tener
  3  Windows  200 GiB NTFS: el Windows escondido (si «windows» está apagado, no se hacen la 2 ni la 3)
  4  Apogeo   el resto, cifrado (LUKS2) y dentro btrfs con @, @home, @root, @srv, @cache, @tmp y @log (como CachyOS)

El disco cifrado se abre solo con el chip TPM 2.0 del PC (systemd-cryptenroll, PCR 7) y, si un día no puede, con tu
contraseña de Apogeo. Los paquetes vienen de los repositorios de CachyOS (x86-64-v3 si tu procesador vale) y del de
Apogeo, firmados. Al final prepara Windows (windows.py): lo baja de Microsoft y lo deja listo para el primer arranque.

Va contando por la salida, una línea JSON por cosa: {"paso", "texto", "progreso"} (de 0 a 1), {"fin": true} o
{"error": "texto para ti"}. El detalle va a /tmp/apogeo-instalador.log (sin contraseñas).

  motor.py < eleccion.json          instala
  motor.py --discos                 los discos donde se puede instalar (JSON)
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

AQUI = os.path.dirname(os.path.abspath(__file__))
LOG = '/tmp/apogeo-instalador.log'
DESTINO = '/mnt/apogeo'
CLAVE_APOGEO = 'DF948BE0F005C7C6101BF9607CF246C5627C09B2'
ASC = os.environ.get('APOGEO_ASC', os.path.join(AQUI, 'apogeo.asc'))
REPO = 'https://github.com/4R3S10/apogeo/releases/download/repo'
GiB = 1024 ** 3
EFI_GIB = 4
APOGEO_MIN_GIB = 60

# Lo que lleva un Apogeo recién instalado: lo de un CachyOS con KDE (lo que trae su instalador) y el paquete apogeo,
# que arrastra el escritorio, las apps de serie y los juegos. Sin temas ni fondos de CachyOS (Apogeo los esconde) y
# sin el servidor SSH encendido (openssh se queda por el cliente, pero apagado).
PAQUETES = '''
base base-devel linux-cachyos linux-cachyos-headers linux-cachyos-lts linux-cachyos-lts-headers linux-firmware
amd-ucode intel-ucode sof-firmware alsa-firmware mkinitcpio limine limine-mkinitcpio-hook limine-snapper-sync
cryptsetup tpm2-tss btrfs-progs dosfstools exfatprogs ntfs-3g e2fsprogs efibootmgr snapper cachyos-snapper-support
cachyos-hooks cachyos-keyring cachyos-mirrorlist cachyos-v3-mirrorlist cachyos-v4-mirrorlist cachyos-rate-mirrors
cachyos-settings chwd hwdetect networkmanager plasma-nm iwd wpa_supplicant bluez bluez-utils bluedevil
pipewire-alsa pipewire-pulse wireplumber alsa-utils plasma-desktop plasma-pa plasma-firewall ufw kscreen powerdevil
power-profiles-daemon kde-gtk-config breeze-gtk xdg-user-dirs dolphin ark kate kcalc gwenview kdialog kio-admin
kwallet-pam ffmpegthumbs kdegraphics-thumbnailers accountsservice plymouth noto-fonts noto-fonts-cjk
noto-fonts-emoji ttf-dejavu ttf-liberation cpupower fwupd smartmontools man-db nano sudo git wget rsync unzip
openssh reflector pacman-contrib fastfetch apogeo
'''.split()

_log = open(LOG, 'a', buffering=1)


def di(**k):
    print(json.dumps(k, ensure_ascii=False), flush=True)


def log(*a):
    _log.write(time.strftime('%H:%M:%S ') + ' '.join(str(x) for x in a) + '\n')


class Fallo(Exception):
    """Algo que no ha salido: el texto es para ti."""


def run(cmd, entrada=None, secreto=False, ok=(0,), linea=None, env=None):
    """Lanza cmd; su salida va al registro (o a «linea», una a una). entrada: texto para su entrada (si es secreto, no
    se apunta). Devuelve la salida."""
    log('$', ' '.join(cmd) + (' <secreto>' if secreto else ''))
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE if entrada is not None else subprocess.DEVNULL,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace',
                         env=dict(os.environ, **(env or {})))
    if entrada is not None:
        p.stdin.write(entrada)
        p.stdin.close()
    out = []
    for l in p.stdout:
        out.append(l)
        _log.write(l)
        if linea:
            linea(l.rstrip('\n'))
    p.wait()
    if p.returncode not in ok:
        raise Fallo(f'Ha fallado «{os.path.basename(cmd[0])}» (código {p.returncode}). El detalle está en {LOG}.')
    return ''.join(out)


def chroot(*cmd, **k):
    return run(['arch-chroot', DESTINO, *cmd], **k)


# ---------- Los discos ----------

def disco_del_usb():
    """El disco desde el que se ha arrancado (el USB de Apogeo): no se ofrece."""
    try:
        src = subprocess.run(['findmnt', '-no', 'SOURCE', '/run/archiso/bootmnt'], capture_output=True,
                             text=True).stdout.strip()
        if src:
            return subprocess.run(['lsblk', '-no', 'PKNAME', src], capture_output=True, text=True).stdout.strip()
    except OSError:
        pass
    return ''


def discos():
    d = json.loads(subprocess.run(['lsblk', '-J', '-b', '-d', '-o', 'NAME,PATH,SIZE,MODEL,TRAN,TYPE,RM,RO'],
                                  capture_output=True, text=True).stdout)
    usb = disco_del_usb()
    out = []
    for b in d.get('blockdevices', []):
        if b['type'] != 'disk' or b['ro'] or b['name'] == usb or re.match(r'(zram|loop|sr)', b['name']):
            continue
        out.append({'ruta': b['path'], 'nombre': (b.get('model') or b['name']).strip(), 'tamano': int(b['size']),
                    'tipo': {'nvme': 'NVMe', 'sata': 'SATA', 'usb': 'USB'}.get(b.get('tran') or '', ''),
                    'extraible': bool(b['rm']) or b.get('tran') == 'usb'})
    return out


def particion(disco, n):
    return f'{disco}p{n}' if disco[-1].isdigit() else f'{disco}{n}'


def asentar():
    run(['udevadm', 'settle'], ok=(0, 1))
    time.sleep(1)


# ---------- Los pasos ----------

def comprobar(e):
    if os.geteuid() != 0:
        raise Fallo('El instalador tiene que ir como administrador.')
    if not os.path.isdir('/sys/firmware/efi'):
        raise Fallo('Este PC ha arrancado en modo antiguo (BIOS). Apogeo y Windows 11 necesitan UEFI: cámbialo en la '
                    'configuración del PC y vuelve a arrancar desde el USB.')
    disco = next((d for d in discos() if d['ruta'] == e['disco']), None)
    if not disco:
        raise Fallo('No se encuentra el disco elegido.')
    falta = EFI_GIB + APOGEO_MIN_GIB + (e['windowsGB'] if e['windows'] else 0)
    if disco['tamano'] < falta * GiB:
        raise Fallo(f'En ese disco no cabe: hacen falta {falta} GB.')
    if not re.fullmatch(r'[a-z_][a-z0-9_-]{0,31}', e['usuario']):
        raise Fallo('El nombre de usuario solo puede llevar minúsculas, números, «-» y «_».')


def nivel_cpu():
    """x86-64-v3 (los repositorios optimizados de CachyOS) si tu procesador lo vale."""
    try:
        out = subprocess.run(['/lib/ld-linux-x86-64.so.2', '--help'], capture_output=True, text=True).stdout
        return 'v3' if re.search(r'x86-64-v3 \(supported', out) else ''
    except OSError:
        return ''


def pacman_conf(nivel):
    v3 = ''.join(f'[{r}-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n'
                 for r in ('cachyos', 'cachyos-core', 'cachyos-extra')) if nivel == 'v3' else ''
    # (el pacman de Arch no reconoce los paquetes x86_64_v3 con «auto»: hay que decírselo)
    arq = 'x86_64 x86_64_v3' if nivel == 'v3' else 'auto'
    return f'''[options]
HoldPkg     = pacman glibc
Architecture = {arq}
Color
ILoveCandy
VerbosePkgLists
DisableDownloadTimeout
ParallelDownloads = 10
DownloadUser = alpm
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional

{v3}[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

# Apogeo (https://github.com/4R3S10/apogeo)
[apogeo]
Server = {REPO}
'''


def particionar(e):
    d = e['disco']
    di(paso='disco', texto='Preparando el disco', progreso=0.02)
    # (nada montado de ese disco: lo que haya quedado de otra prueba)
    run(['umount', '-R', DESTINO], ok=(0, 1, 32))
    run(['cryptsetup', 'close', 'apogeo'], ok=(0, 1, 4))
    run(['wipefs', '-af', d])
    run(['sgdisk', '--zap-all', d], ok=(0, 2))
    args = ['sgdisk', '-n', f'1:0:+{EFI_GIB}G', '-t', '1:ef00', '-c', '1:EFI']
    n = 2
    if e['windows']:
        args += ['-n', '2:0:+16M', '-t', '2:0c01', '-c', '2:Microsoft reserved partition',
                 '-n', f"3:0:+{e['windowsGB']}G", '-t', '3:0700', '-c', '3:Windows']
        n = 4
    args += ['-n', f'{n}:0:0', '-t', f'{n}:8309', '-c', f'{n}:Apogeo', d]
    run(args)
    run(['partprobe', d], ok=(0, 1))
    asentar()
    efi, apo = particion(d, 1), particion(d, n)
    run(['mkfs.fat', '-F', '32', '-n', 'EFI', efi])
    if e['windows']:
        run(['mkntfs', '-Q', '-L', 'Windows', particion(d, 3)])

    di(paso='disco', texto='Cifrando el disco', progreso=0.04)
    # La clave por la entrada (nunca en un archivo). argon2id, como CachyOS
    run(['cryptsetup', 'luksFormat', '--type', 'luks2', '--batch-mode', '--label', 'Apogeo', '--key-file', '-', apo],
        entrada=e['clave'], secreto=True)
    run(['cryptsetup', 'open', '--allow-discards', '--key-file', '-', apo, 'apogeo'], entrada=e['clave'],
        secreto=True)
    run(['mkfs.btrfs', '-f', '-L', 'Apogeo', '/dev/mapper/apogeo'])
    os.makedirs(DESTINO, exist_ok=True)
    run(['mount', '/dev/mapper/apogeo', DESTINO])
    subvs = ['@', '@home', '@root', '@srv', '@cache', '@tmp', '@log']
    for s in subvs:
        run(['btrfs', 'subvolume', 'create', f'{DESTINO}/{s}'])
    run(['umount', DESTINO])
    opts = 'defaults,noatime,compress=zstd'
    run(['mount', '-o', f'subvol=/@,{opts}', '/dev/mapper/apogeo', DESTINO])
    for s, sitio in (('@home', 'home'), ('@root', 'root'), ('@srv', 'srv'), ('@cache', 'var/cache'),
                     ('@tmp', 'var/tmp'), ('@log', 'var/log')):
        os.makedirs(f'{DESTINO}/{sitio}', exist_ok=True)
        run(['mount', '-o', f'subvol=/{s},{opts}', '/dev/mapper/apogeo', f'{DESTINO}/{sitio}'])
    os.makedirs(f'{DESTINO}/boot', exist_ok=True)
    run(['mount', '-o', 'umask=0077', efi, f'{DESTINO}/boot'])
    return efi, apo


def instalar_paquetes(e):
    di(paso='apogeo', texto='Preparando la descarga', progreso=0.06)
    nivel = nivel_cpu()
    conf = '/tmp/apogeo-pacman.conf'
    with open(conf, 'w') as f:
        f.write(pacman_conf(nivel))
    log('procesador:', nivel or 'x86-64')
    # Las claves: Arch y CachyOS (de sus paquetes de llaves) y la de Apogeo (su clave pública, firmada aquí)
    run(['pacman-key', '--init'])
    run(['pacman-key', '--populate'])
    run(['pacman-key', '--add', ASC])
    run(['pacman-key', '--lsign-key', CLAVE_APOGEO])
    # Los espejos más rápidos de CachyOS desde aquí (si no se puede, los de serie)
    run(['pacman', '-Sy', '--config', conf], ok=(0, 1))

    # El controlador de Vulkan de tu gráfica (como instalar.sh)
    gpus = subprocess.run(['lspci', '-nn'], capture_output=True, text=True).stdout
    gpus = '\n'.join(l for l in gpus.splitlines() if re.search(r'vga|3d|display', l, re.I))
    vulkan = []
    if '[1002:' in gpus:
        vulkan += ['vulkan-radeon', 'lib32-vulkan-radeon']
    if '[8086:' in gpus:
        vulkan += ['vulkan-intel', 'lib32-vulkan-intel']
    if '[10de:' in gpus:
        vulkan += ['vulkan-nouveau', 'lib32-vulkan-nouveau']
    vulkan = vulkan or ['vulkan-swrast', 'lib32-vulkan-swrast']

    total = [0]

    def linea(l):
        # «( 12/834) instalando …» o «(12/834) installing …»
        m = re.search(r'\(\s*(\d+)/(\d+)\)\s+(instalando|installing|descargando|downloading|comprobando|checking)?',
                      l)
        if m and m.group(3) in ('instalando', 'installing'):
            i, n = int(m.group(1)), int(m.group(2))
            di(paso='apogeo', texto='Instalando Apogeo', detalle=f'{i} de {n}', progreso=0.15 + 0.43 * i / n)
        elif re.search(r'(descargando|downloading|Total \()', l, re.I) and total[0] % 25 == 0:
            di(paso='apogeo', texto='Descargando Apogeo', progreso=0.1)
        total[0] += 1

    di(paso='apogeo', texto='Descargando Apogeo', progreso=0.08)
    run(['pacstrap', '-C', conf, DESTINO, *PAQUETES, *vulkan, '--needed', '--noconfirm'], linea=linea)
    shutil.copy(conf, f'{DESTINO}/etc/pacman.conf')


def configurar(e, efi, apo):
    di(paso='sistema', texto='Dejando Apogeo a tu gusto', progreso=0.6)
    with open(f'{DESTINO}/etc/fstab', 'a') as f:
        f.write(run(['genfstab', '-U', DESTINO]))
    # El idioma, el teclado y la hora
    with open(f'{DESTINO}/etc/locale.gen', 'a') as f:
        f.write('\nes_ES.UTF-8 UTF-8\nen_US.UTF-8 UTF-8\n')
    chroot('locale-gen')
    open(f'{DESTINO}/etc/locale.conf', 'w').write('LANG=es_ES.UTF-8\n')
    open(f'{DESTINO}/etc/vconsole.conf', 'w').write(f"KEYMAP={e.get('teclado', 'es')}\n")
    chroot('ln', '-sf', f"/usr/share/zoneinfo/{e.get('zona', 'Europe/Madrid')}", '/etc/localtime')
    chroot('hwclock', '--systohc', ok=(0, 1))
    open(f'{DESTINO}/etc/hostname', 'w').write(e.get('equipo', 'apogeo') + '\n')
    open(f'{DESTINO}/etc/hosts', 'w').write(f"127.0.0.1 localhost\n::1 localhost\n127.0.1.1 {e.get('equipo', 'apogeo')}\n")
    os.makedirs(f'{DESTINO}/etc/X11/xorg.conf.d', exist_ok=True)
    open(f'{DESTINO}/etc/X11/xorg.conf.d/00-keyboard.conf', 'w').write(
        f'Section "InputClass"\n  Identifier "teclado"\n  MatchIsKeyboard "on"\n'
        f'  Option "XkbLayout" "{e.get("teclado", "es")}"\nEndSection\n')

    # Tu cuenta (la contraseña por la entrada de chpasswd)
    chroot('useradd', '-m', '-G', 'wheel,audio,video,storage,lp,network,sys,rfkill', '-s', '/bin/bash',
           '-c', e['nombre'], e['usuario'])
    chroot('chpasswd', entrada=f"{e['usuario']}:{e['clave']}\n", secreto=True)
    open(f'{DESTINO}/etc/sudoers.d/10-wheel', 'w').write('%wheel ALL=(ALL:ALL) ALL\n')
    os.chmod(f'{DESTINO}/etc/sudoers.d/10-wheel', 0o440)

    # El arranque: el disco cifrado se abre en el arranque (Plymouth pide la contraseña si el TPM no la da)
    uuid = run(['blkid', '-s', 'UUID', '-o', 'value', apo]).strip()
    mk = f'{DESTINO}/etc/mkinitcpio.conf'
    s = open(mk).read()
    s = re.sub(r'^HOOKS=.*$', 'HOOKS=(base systemd autodetect microcode kms modconf block keyboard sd-vconsole '
               'plymouth sd-encrypt filesystems)', s, flags=re.M)
    open(mk, 'w').write(s)
    cmdline = (f'quiet nowatchdog splash rw rd.luks.name={uuid}=apogeo rd.luks.options={uuid}=tpm2-device=auto,'
               f'discard root=/dev/mapper/apogeo rootflags=subvol=/@')
    open(f'{DESTINO}/etc/default/limine', 'w').write(
        f'ESP_PATH="/boot"\nKERNEL_CMDLINE[default]+="{cmdline}"\nBOOT_ORDER="*, *lts, *fallback, Snapshots"\n')
    di(paso='sistema', texto='Preparando el arranque', progreso=0.64)
    chroot('limine-install')
    chroot('limine-mkinitcpio')

    # Los servicios (los de Apogeo los enciende su paquete)
    for s in ('NetworkManager', 'bluetooth', 'ufw', 'fstrim.timer', 'systemd-timesyncd', 'power-profiles-daemon',
              'sddm'):
        chroot('systemctl', 'enable', s, ok=(0, 1))
    chroot('systemctl', 'disable', 'sshd', ok=(0, 1))
    # Los controladores de la gráfica que haga falta (NVIDIA…), como CachyOS
    di(paso='sistema', texto='Buscando los controladores de tu PC', progreso=0.66)
    chroot('chwd', '-a', ok=(0, 1))

    # El TPM: que el disco se abra solo (si este PC lo tiene)
    if os.path.exists('/sys/class/tpm/tpm0'):
        di(paso='sistema', texto='Enlazando el disco con el chip de seguridad', progreso=0.68)
        run(['systemd-cryptenroll', '--tpm2-device=auto', '--tpm2-pcrs=7', apo],
            env={'PASSWORD': e['clave']}, ok=(0, 1))
    else:
        log('sin TPM: el disco pedirá la contraseña al encender')


def windows(e, efi):
    if not e['windows']:
        return
    import windows as w
    w.preparar(e, DESTINO, particion(e['disco'], 3), efi,
               lambda texto, p, detalle='': di(paso='windows', texto=texto, detalle=detalle,
                                               progreso=0.7 + 0.29 * p),
               run, log)


def cerrar():
    run(['sync'])
    run(['umount', '-R', DESTINO], ok=(0, 1, 32))
    run(['cryptsetup', 'close', 'apogeo'], ok=(0, 1, 4))


def main():
    if '--discos' in sys.argv:
        print(json.dumps(discos(), ensure_ascii=False))
        return 0
    e = json.loads(sys.stdin.read())
    e.setdefault('windows', True)
    e.setdefault('windowsGB', 200)
    log('instalación en', e['disco'], 'windows' if e['windows'] else 'sin windows', e.get('windowsGB'))
    try:
        comprobar(e)
        efi, apo = particionar(e)
        instalar_paquetes(e)
        configurar(e, efi, apo)
        windows(e, efi)
        cerrar()
        di(paso='listo', texto='Listo', progreso=1.0)
        di(fin=True)
        return 0
    except Fallo as x:
        log('FALLO', x)
        di(error=str(x))
    except Exception as x:   # (lo inesperado también se cuenta, con el detalle en el registro)
        import traceback
        log(traceback.format_exc())
        di(error=f'Algo ha fallado ({type(x).__name__}). El detalle está en {LOG}.')
    return 1


if __name__ == '__main__':
    sys.exit(main())
