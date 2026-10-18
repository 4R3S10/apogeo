# Apogeo

Sistema operativo personal basado en Linux ([CachyOS](https://cachyos.org), Arch, con KDE Plasma), con Ágape como
navegador y un escritorio propio organizado por **pisos** (Jugar, Navegar, Estudiar).

- **Juegos:** Steam oficial con Proton, Epic (lanzador oficial con Proton y Heroic) y los juegos con anticheat de Windows
  (Valorant, EA FC…) mediante un Windows escondido: se pulsa Jugar en Apogeo, el equipo se reinicia en Windows con el
  juego y al cerrarlo vuelve a Apogeo.
- **Actualizaciones:** Apogeo es un paquete (`apogeo`) en su propio repositorio firmado; GitHub lo construye en cada
  cambio y cada día. Se actualiza con el resto del sistema (`sudo pacman -Syu` o el actualizador de CachyOS).

## Pisos

El escritorio son tres pisos, uno encima de otro: **Jugar**, **Navegar** y **Estudiar**. Se cambia con la rueda del ratón
sobre la columna de la derecha (o con un clic en su círculo) y las ventanas se deslizan como en un ascensor. Cada piso
guarda sus ventanas y tiene su fondo y su color (el mismo berenjena, más vivo en Jugar y más apagado en Estudiar).

- **Avisos:** solo en Navegar; en Jugar y Estudiar no sale ninguno (se quedan en el historial).
- **Energía:** nunca «rendimiento». Jugar y Navegar en equilibrado, Estudiar en ahorro.
- **La primera vez** que entras en un piso se abren sus apps (Jugar: la consola; Navegar: Ágape).

## Logo

La silueta de un angelito volando, como los putti de los museos, del arte y de las esculturas: rizos, mofletes, un brazo
hacia delante, las piernas dobladas y alas de plumas en abanico. Va en el rosa de Ágape sobre un disco berenjena
(«V1 · Silueta rosa»).
- Se dibuja al construir el paquete con `herramientas/logo.py`, juntando formas sencillas del mismo color.
- De ahí salen las copias del arranque, el inicio de sesión, el bloqueo, la bienvenida, el menú y la terminal.

## Aspecto

Todo con la estética de Ágape, sacada de su código (tema Berenjena oscuro):

- **Letra:** Bricolage Grotesque en todo el sistema.
- **Colores:** fondo #120d14, superficie #1e1621, texto #f1e6ea y un solo rosa, #e0a9b4, en todos los pisos.
- **Fondos:** los fondos animados de Ágape, uno por piso (Jugar «Luces», Navegar «Tinta», Estudiar «Seda»). Se
  dibujan a un tercio de la resolución y a 30 imágenes por segundo como mucho; sin gráfica (máquina virtual) se quedan
  quietos.
- **Isla y pisos («B1 · Cristal de Ágape»):** una sola isla de cristal (radio 22) y la columna de pisos como una cápsula de
  cristal. Las apps abiertas llevan un puntito rosa (la activa, una rayita). El buscador y el piso activo son la pastilla
  rosa con brillo, y todo usa los iconos de línea de Ágape. El estilo de Plasma «apogeo» se escribe en `~/.config/plasmarc`
  de cada usuario: si solo estaba en `/etc/xdg`, Plasma se quedaba con el gris por defecto.
- **Ventanas:** la barra de Ágape (título en el centro y sus botones planos; la ✕ se pone roja).
- **Menús y avisos:** las tarjetas de Ágape.
- **Inicio de sesión y bloqueo:** una tarjeta con la hora grande, tu foto y tu nombre, el piso (el control segmentado de
  Ágape) y la contraseña, sobre el fondo del piso.
- **Carpetas:** Papirus con el rosa empolvado de Ágape. Cursor berenjena, sonidos pocos y suaves y teclado EE. UU.
  internacional (ñ con AltGr+n).

## Programas de serie

Los trae el paquete `apogeo-programas` (lo pide `apogeo`):
- **Diario:** Flameshot (Impr Pant), Stacer, Spotify (`spotify-launcher`, que baja el oficial) y Discord.
- **Máquinas virtuales:** VirtualBox con sus módulos para el núcleo de CachyOS. Las cuentas que ya existen entran en
  `vboxusers`.
- **Juegos:** MangoHud, GameMode, ProtonPlus y Lutris.
- **Multimedia:** OBS Studio, VLC, EasyEffects y qBittorrent.
- **Utilidades:** LocalSend, KeePassXC, Obsidian y CoolerControl.
- **ONLYOFFICE y Stremio:** no están en los repositorios de Arch. Los instala `apogeo-flatpaks` de Flathub, donde los dos
  están verificados por sus propias empresas, para todos los usuarios, una vez y en segundo plano cuando hay internet.
- ChatGPT y Claude no van de serie (no tienen app oficial para Linux).

## Terminal

Ghostty con el estilo «T1 · Cristal con píldoras»: el cristal de Ágape (berenjena translúcido con desenfoque), la letra
JetBrains Mono y los colores de Apogeo.
- **Prompt:** Starship, con la carpeta en una píldora rosa y la rama de git en otra.
- **Al abrir:** fastfetch con el angelito (en Ghostty, la imagen de verdad; en otras terminales, en letras).
- **Dónde está:** la configuración, en `/usr/share/apogeo/terminal/`. Cada usuario la carga desde
  `~/.config/ghostty/config`, donde puede añadir lo suyo.
- **Por defecto:** es la terminal de siempre (Dolphin, Ctrl+Alt+T).

## Jugar

- **Consola:** al entrar en el piso Jugar se abre a pantalla completa con todos tus juegos juntos (Steam, Epic y GOG con
  Heroic, Hydra y los de Windows): el último en grande y el resto en fila. Teclado o mando: ← → elegir, Intro jugar,
  Q/E cambiar de tienda, Esc salir.
- **Tiendas:** Steam, Heroic (Epic y GOG), el lanzador oficial de Epic con Proton («Epic Games (oficial)», se instala la
  primera vez) e Hydra (de su GitHub oficial, sin fuentes de descarga añadidas).
- **Modo partida (Meta+Tab, «S3 · Juego y Discord a la vez»):** con un juego a pantalla completa, el juego no se toca:
  sigue a su resolución, sin minimizarse ni pararse, que es lo que da tirones y fallos con Alt+Tab.
  - A la izquierda se ve en vivo, en pequeño (una imagen de KWin); debajo va lo que suena, con sus botones.
  - A la derecha, Discord de verdad: se abre si no lo estaba.
  - Para volver, Meta+Tab otra vez o pulsar el juego.
  - Lo hace el script de KWin `apogeo-partida`. Los juegos de SDL no se minimizan al perder el foco
    (`SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0`).
  - Alt+Tab sigue siendo el cambiador de ventanas de siempre.
- **Juegos de Windows** (Valorant, EA FC…): se abrirán en el Windows escondido; la lista está en
  `~/.config/apogeo/juegos-windows.json`.

## Bienvenida

Al entrar por primera vez sale una tarjeta en el centro, como la bienvenida de Ágape, con los pasos: tu nombre y tu foto
(para el inicio de sesión y el bloqueo), instalar Ágape con tu llave, traer tu copia de Ágape (`.agape`, la contraseña
la pide Ágape), los pisos y la isla. Todo se puede saltar; si se cierra sin terminar vuelve en el siguiente inicio,
hasta acabarla o pulsar «No volver a mostrar». Se abre de nuevo desde el buscador («Bienvenida de Apogeo»).

## Ajustes

«Ajustes de Apogeo» es como «Personalizar» de Ágape: el buscador y las secciones a la izquierda y las tarjetas a la
derecha. Pisos (el fondo, los avisos, la energía y las apps de cada uno; animar los fondos; no molestar), Isla (que se
esconda sola y lo de cada piso), Salud del PC (temperatura máxima de 70 a 85 °C y FPS de los juegos: 30, 45 o 60),
Ágape (la llave, llevar o traer la copia, la bienvenida), Tu perfil y Actualizaciones. La red, el sonido, la pantalla…
abren los Ajustes de KDE. Lo que cambias se guarda en `~/.config/apogeo/ajustes.json` y `apogeo-pisos` lo aplica al
momento.

Al final de la isla está el **panel rápido**: red, bluetooth, fondo animado, no molestar, ahorro de energía del piso,
luz nocturna, volumen y brillo, tú, «Todos los ajustes» y apagar.

## Fondos

Cada piso con el suyo; el animado de siempre es el de por defecto. Se cambian en Ajustes → Fondos o con el botón derecho
en el escritorio: sale un carrusel y el fondo se ve al momento, con «Cancelar» para volver al de antes.

- **Animados de Apogeo:** los ocho de Ágape. Se dibujan a un tercio de la resolución y a 30 imágenes por segundo como
  mucho.
- **Tus fondos:** imágenes (JPG, PNG, WebP, AVIF, JPEG XL…) y vídeos (MP4, WebM, MKV, MOV) en alta calidad.
  - Las imágenes se cargan a la resolución de la pantalla, con un fundido al cambiar.
  - Los vídeos van en bucle y sin sonido, y se paran cuando una ventana maximizada o a pantalla completa los tapa.
- **Tu carpeta:** por defecto «Fondos» dentro de tu carpeta de imágenes. Lo que metas ahí aparece solo.
- **Galería de internet:** busca en las imágenes destacadas de Wikimedia Commons, que son fotos de alta calidad con
  licencia libre y no piden clave ni cuenta.
  - Solo enseña las apaisadas de 2560 px o más.
  - Al ponerla, se baja a tu carpeta, y su autor y licencia se apuntan en `~/.local/share/apogeo/fondos-creditos.json`.
- **Que cambie solo:** cada 15 minutos, cada hora, cada día o al entrar en el piso. Pasa por tus fondos y los de la
  carpeta, solo por unos u otros, o por los animados.

Lo hacen `apogeo_fondos.py` (biblioteca y galería), `apogeo-pisos` (el de cada piso y que cambie solo) y el fondo de
Plasma `org.apogeo.fondo`.

## Entrar con neuronas

En la pantalla de inicio de sesión y en la de bloqueo, en vez de escribir la contraseña («E5», pensado para que no se pueda
copiar mirando):
- Tu código son 5 neuronas de 20. Cada una se reconoce por su tipo de dendritas (estrella, axón largo, puntas en Y,
  rizos, abanico) y su núcleo (lleno, anillo, rombo, doble).
- En cada toque las 20 cambian de sitio y de cables, y no tocas la tuya: tocas una de las conectadas a ella. Quien mira
  ve toques en neuronas distintas cada vez.
- **Comprobación:** al acabar se prueban las combinaciones posibles (2-3 vecinas por toque) contra un verificador con sal
  en `/var/lib/apogeo/neuronas/USUARIO.json`. Si una cuadra, se entra con la contraseña de la cuenta. Si no, se vuelve
  a empezar sin gastar intentos de la cuenta.
- **La contraseña:** son las letras de tus neuronas. La pone `apogeo-neuronas` (con pkexec, pidiendo la de ahora) y es la
  que se escribe en sudo y en la terminal.
- **Siempre a mano:** «Escribir la contraseña» sigue disponible.
- **Dónde se elige:** en Ajustes → Tu perfil → Entrar con neuronas.

Es más cómoda que segura: la contraseña son 5 letras de 20 posibles. Para que nadie pueda sacarla del disco, conviene
tener el disco cifrado.

## Escritorios

Sin iconos de apps y con el estilo «D2 · Sin cajas»: todo escrito sobre el fondo, separado por rayas finas, con un velo
oscuro arriba y abajo para que se lea.
- **Navegar:** la hora muy grande a la izquierda con la fecha y el tiempo, y abajo una fila: lo que suena, los avisos, lo
  próximo del calendario de Ágape y tu PC.
- **Estudiar:** tu carpeta `~/Estudios` a la izquierda (cada asignatura con Temas, Trabajos y Ejercicios), el temporizador
  25/5 en el centro (el mismo que el de la isla) y, a la derecha, los exámenes con lo que falta y las tareas de hoy.

Los datos los da `apogeo-pisos` por D-Bus (`apogeo_datos.py`). El widget es `org.apogeo.escritorio`:
- Se dibuja siempre del tamaño de la pantalla, aunque Plasma lo estreche al quedarse fijas la isla o los pisos.
- Ocupar toda la pantalla lo asegura `apogeo-pisos` en cada inicio de sesión. Plasma guarda el sitio de cada widget por
  resolución y lo pisa al cerrarse, así que, cuando hace falta, lo corrige con Plasma parado un instante.

## Música

Abajo a la izquierda, una portada por cada cosa que suena (Spotify y otras apps de música, y **cada pestaña de Ágape**
por su canal privado); al pasar el ratón, la tarjeta con el progreso y los botones; la rueda del ratón encima cambia el
volumen de cada una. Solo sale mientras suena algo (lo que pausas sigue un minuto para reanudarlo). No sale con Ágape
delante (que enseña la suya) ni con algo a pantalla completa.
`sistema/usr/lib/apogeo/apogeo-musica` y `sistema/usr/share/apogeo/musica/`.

## Sin restos de CachyOS

- **Buscador:** la lupa de la isla, la tecla Meta o Alt+Espacio abren una tarjeta en el centro, como el buscador de
  Ágape, con lo que encuentran los buscadores de KDE (apps, archivos, ajustes…) y «Buscar en la web con Ágape».
- **Pantalla de apagar:** una tarjeta con tu foto y Apagar, Reiniciar, Reposo y Cerrar sesión.
- **Pantalla de carga** al entrar: la misma que al encender (el diamante, el brillo y la barra).
- **Menú de arranque:** no sale; mantén pulsada una tecla al encender para verlo (con los colores de Apogeo).
- **Apps de CachyOS** (bienvenida, tienda, núcleos, actualizador): escondidas, no quitadas. En su lugar, un aviso de
  Apogeo cuando hay actualizaciones (uno al día como mucho; en Jugar y Estudiar se guarda para luego).

## Ágape

Ágape es privado, así que no va dentro del paquete (que es público). La primera vez que se abre (o al pulsar un
enlace), Apogeo pide tu token de GitHub de solo lectura, descarga la última versión de tus releases a
`~/Applications/ARES.AppImage` (donde se actualiza sola) y la deja como navegador del sistema.

## Salud del PC

- A partir de 80 °C (procesador o gráfica) Apogeo baja poco a poco la velocidad máxima; por debajo de 72 °C la devuelve.
- Los juegos de Windows (Proton) van a 60 FPS como mucho.

## Pasar un CachyOS a Apogeo

Sobre un CachyOS recién instalado con KDE Plasma:

```bash
curl -fsSL https://raw.githubusercontent.com/4R3S10/apogeo/main/instalar.sh | sudo bash
```

Añade la clave y el repositorio de Apogeo (`[apogeo]` en `/etc/pacman.conf`), instala el paquete y, al reiniciar, ya
entras en Apogeo.

## Estructura

- `sistema/`: los archivos que instala el paquete, tal cual van en el sistema
- `herramientas/`: lo que se genera al construir (colores, letra, ventanas, estilo de Plasma, carpetas, cursor y el
  sombreador de los fondos de Ágape)
- `paquetes/apogeo/PKGBUILD`: el paquete de Apogeo (dependencias, servicios y ganchos)
- `paquetes/apogeo-hydra/PKGBUILD`: Hydra Launcher desde su GitHub oficial
- `.github/workflows/paquetes.yml`: construye, firma y publica el repositorio
- `sistema/usr/lib/apogeo/apogeo-pisos`: los pisos (fondo, color, avisos, energía, ventanas y apps de cada uno)
- `sistema/usr/lib/apogeo/apogeo-termico`: la protección de temperatura
- `sistema/usr/lib/apogeo/apogeo-bienvenida` y `sistema/usr/share/apogeo/bienvenida/`: la bienvenida
- `sistema/usr/lib/apogeo/apogeo-ajustes` y `sistema/usr/share/apogeo/ajustes/`: los ajustes (y el panel rápido,
  `org.apogeo.rapido`)
- `sistema/usr/lib/apogeo/apogeo_comun.py` y `apogeo_qt.py`: lo que comparten (tus ajustes, tu cuenta, Ágape)
- `sistema/usr/lib/qt6/qml/Apogeo/`: las piezas de Ágape en QML (botones, campos, interruptores, fondos…)
- `apogeo.asc`: la clave pública con la que se firman los paquetes
