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

**Rejilla de ventanas** («V2 · Huecos en toda la pantalla»): lleva una ventana hasta arriba y la pantalla enseña sus
huecos en rosa; arriba, una pastilla para cambiar de esquema (mitades, tercios, ⅔ + ⅓, cuartos o «Suelta»). Al soltar,
la ventana va al hueco iluminado; si la sueltas luego fuera, vuelve a su tamaño (`apogeo-ventanas`, `Rejilla.qml`).

- **Avisos:** solo en Navegar; en Jugar y Estudiar no sale ninguno (se quedan en el historial). Al volver a un piso
  con avisos sale el **resumen** («H3»): una tarjeta encima de la isla con lo que llegó («Has jugado 1 h 20 min»), lo
  importante delante, «Ver todos» y un clic en un aviso abre su app. Se va sola al medio minuto
  (`apogeo-resumen`, `sistema/usr/share/apogeo/resumen/`).
- **Luz cálida en Estudiar por la noche:** la luz nocturna de KWin, solo en Estudiar: al anochecer en tu zona entra poco
  a poco (Suave 4500 K de serie; Media y Fuerte en Ajustes → Pisos) y al amanecer se va. Tu zona sale de tu zona horaria,
  sin preguntar a internet.
- **Energía:** nunca «rendimiento». Jugar y Navegar en equilibrado, Estudiar en ahorro.
- **La primera vez** que entras en un piso se abren sus apps (Jugar: la consola; en Navegar y Estudiar, ninguna de serie: se eligen en Ajustes → Pisos).

## Logo

Un búho de frente batiendo las alas, realista pero sencillo («R4 · Batiendo»): plumas por capas (primarias, secundarias y
coberteras) separadas por líneas finas, la cara en corazón, el pecho con sus uves y la cola en abanico. Va en el rosa de
Ágape sobre un disco berenjena. Es un diseño propio.
- Se dibuja al construir el paquete con `herramientas/logo.py` (también los fotogramas del aleteo para el arranque).
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
- **Carpetas:** Papirus con el rosa empolvado de Ágape. Cursor berenjena y teclado EE. UU. internacional (ñ con AltGr+n).
- **Sonidos:** propios y suaves (marimba de madera con un poco de sala) para avisos, errores, USB, volumen, capturas y lo
  hecho; al entrar, el «uu-uu» del búho sobre un acorde cálido. Se sintetizan al construir el paquete
  (`herramientas/sonidos.py`).
- **Arranque y apagado:** el búho batiendo las alas (Plymouth y la pantalla de carga al entrar).

### Tu aspecto (Ajustes → Aspecto, «K2 con vista previa»)

**De serie, los colores salen del fondo («Del fondo»)**: cada piso coge los de su foto o su vídeo (`apogeo_paleta`: el
tono que más se ve, con su viveza, y con él el acento, el fondo y la superficie oscuros, el texto y los colores de los
animados, como Material You pero con la forma de Ágape). A los fondos animados de Apogeo les das tú el color (Ajustes →
Fondos → «Color de los animados»; sin elegir, el rosa de siempre). Al cambiar de piso o de fondo cambia todo: lo de
Apogeo en QML al momento y los temas de KDE un momento después (al acabar la animación). La ventana activa lleva un
borde del color del piso (el efecto de esquinas redondeadas). Las apps de KDE ya abiertas se quedan con el color con el
que se abrieron (Kvantum no cambia en vivo); las que abras cogen el del piso.
- Los temas de KDE de cada piso se hacen una vez por colores (`ApogeoTuAspecto-<huella>`, en segundo plano) y al cambiar
  de piso solo se ponen. Las carpetas usan el más parecido de los colores de los animados (hacer un tema de iconos
  tarda).
- `aspecto.json` lleva las fichas del piso en el que estás y, en `pisos`, las de los tres: el fondo de Plasma dice a
  Tema en qué piso estás y todo lo de Plasma cambia sin esperar.

Con «Como Ágape», lo que elijas en Ágape → Personalizar (sus colores, claro u oscuro, los colores del fondo, la letra, las
esquinas, el cristal y la velocidad de las animaciones) cambia también Apogeo, al momento (`apogeo-pisos` vigila los
ajustes de Ágape y solo los lee). En Ajustes → Aspecto también hay estilos propios de un clic (Apogeo, Medianoche, Bosque,
Arena y Papel) y cada detalle a mano: el color, claro u oscuro (o según la hora: claro de 8:00 a 20:00), la letra, las esquinas
(rectas, suaves o redondas), el cristal, el tamaño (letra e isla), las animaciones y dónde van la isla y la columna
(abajo y a la derecha, abajo y a la izquierda, o arriba y a la derecha), con una vista en pequeño de cómo queda.
- Las carpetas van del color de tu estilo (un tema de iconos por color, `ApogeoCarpetas-<color>`, que hereda de Papirus).
- Con lo de serie se usan los temas del paquete. Con otra cosa, `apogeo_aspecto` genera tus temas (colores de KDE,
  Kvantum, Plasma y barra de ventana, con los mismos generadores de `herramientas/`, instalados en
  `/usr/lib/apogeo/temas`) y los pone; «Volver a lo de serie» los quita.
- Lo de Apogeo hecho en QML (Tema) lee `~/.config/apogeo/aspecto.json` y cambia solo, también los fondos animados.

### La isla («I1 · Una sola isla»)

Todo en el mismo cristal: el botón rosa de las apps, **tus apps del piso** (las fijadas, aunque estén cerradas, y las
abiertas; clic derecho para fijar o dejar de fijar, en cada piso las suyas), lo de cada piso (Jugar: temperatura y FPS;
Navegar: la música; Estudiar: el temporizador) y, al final, la red, el sonido, la campana con los avisos sin leer y la
hora. Al pasar por una app abierta, su vista en vivo (y ✕ para cerrarla). En la bandeja de KDE solo quedan los iconos de
tus apps (Discord, Steam…).
- **La tarjeta de la hora** (al pulsar la hora): el mes (puntos en los días con algo), el tiempo de tu ciudad (ahora,
  las próximas horas y 3 días; la ciudad se elige ahí) y lo del día elegido: tus planes de Ágape, **recordatorios** y
  **temporizadores**. Al llegar la hora suena y sale un aviso con «Posponer 10 min» (también en Jugar y Estudiar).
- **Panel rápido** (al pulsar los iconos de al lado): la hora y el día, red, bluetooth, fondo animado, no molestar, ahorro, luz
  nocturna, volumen, brillo, **tus avisos** (abrirlos o quitarlos), tú, «Todos los ajustes» y apagar.
- **Avisos en pantalla:** los de Apogeo, abajo a la derecha, apilados, con sus botones y una rayita rosa con el tiempo
  que les queda (se paran con el ratón encima). Respetan No molestar y los pisos sin avisos (salvo los urgentes).
- **Columna de pisos:** cada piso con cuántas ventanas tiene; al pasar, la vista del piso (sus ventanas en su sitio).
  Una ventana soltada encima de un piso se va a ese piso (script de KWin `apogeo-ventanas`, que también cuenta las
  ventanas a `apogeo-pisos`).

## Programas de serie

Los trae el paquete `apogeo-programas` (lo pide `apogeo`):
- **Diario:** Spotify (`spotify-launcher`, que baja el oficial) y Discord (las capturas son de Apogeo: Impr Pant).
- **Juegos:** MangoHud, GameMode y ProtonPlus.
- **Multimedia:** OBS Studio, VLC, EasyEffects y qBittorrent.
- **Utilidades:** LocalSend, KeePassXC, Obsidian y CoolerControl.
- **Estudiar:** Okular (leer y subrayar PDFs), Anki (tarjetas de memoria) y Xournal++ (escribir a mano sobre apuntes).
- **Sistema:** Mission Center (qué gasta el PC). Los demás programas, desde la tienda de Apogeo.
- **ONLYOFFICE y Stremio:** no están en los repositorios de Arch. Los instala `apogeo-flatpaks` de Flathub, donde los dos
  están verificados por sus propias empresas, para todos los usuarios, una vez y en segundo plano cuando hay internet.
- ChatGPT y Claude no van de serie (no tienen app oficial para Linux).
- **ArtCraft Launcher:** su AppImage oficial ([storytold/craft-launcher](https://github.com/storytold/craft-launcher)).
  La primera vez que lo abres, `apogeo-artcraft` lo baja de su última versión, comprueba su SHA-256 publicado y lo deja
  en `~/Applications/ArtCraft-Launcher.AppImage`, donde se actualiza solo. Desde él se instalan los programas Craft
  (PhotoCraft, FilmCraft, VectorCraft…).

## Tienda de Apogeo

La tienda de programas (sustituye a Warehouse), con el aspecto de Ágape y la idea de appPoint: a la izquierda Inicio,
Jugar, Estudiar, Internet, Crear y Sistema, Instalados y Actualizaciones; arriba, el buscador.
- **Inicio:** destacados, lo más usado (las descargas de Flathub del último mes) y unos cuantos de cada grupo.
- **De dónde:** del sistema (los repositorios de Arch y CachyOS, con pacman; se pone al día con Apogeo y pide tu
  contraseña) o de Flathub (sin contraseña). Si un programa está en los dos, se elige en su ficha.
- **Ficha:** capturas, descripción, licencia, su web, instalar, abrir y quitar.
- **Lo que no deja:** quitar lo que Apogeo necesita (el sistema, el escritorio, el núcleo y Apogeo) ni actualizar a
  medias (nunca `pacman -Sy`): las actualizaciones van por Ajustes → Actualizaciones.

Lo hacen `apogeo-tienda` (el catálogo de AppStream: `archlinux-appstream-data` y Flathub), `apogeo-tienda-root` (pacman,
con pkexec y la regla de polkit `org.apogeo.tienda`) y `/usr/share/apogeo/tienda/Tienda.qml`.

## Terminal

Ghostty con el estilo «T1 · Cristal con píldoras»: el cristal de Ágape (berenjena translúcido con desenfoque), la letra
JetBrains Mono y los colores de Apogeo.
- **Prompt:** Starship, con la carpeta en una píldora rosa y la rama de git en otra.
- **Al abrir:** fastfetch con el búho (en Ghostty, la imagen de verdad; en otras terminales, en letras).
- **Dónde está:** la configuración, en `/usr/share/apogeo/terminal/`. Cada usuario la carga desde
  `~/.config/ghostty/config`, donde puede añadir lo suyo.
- **Por defecto:** es la terminal de siempre (Dolphin, Ctrl+Alt+T).

## Jugar

- **Consola («C8 · Cinta panorámica»):** al entrar en el piso Jugar se abre a pantalla completa. Abajo, una cinta con las
  portadas de tus juegos descargados (el último jugado primero); el elegido se agranda y pinta la pantalla con su arte,
  con cuándo jugaste y **cuántas horas llevas** (las de Steam y Heroic; en emuladores y PS5 las cuenta Apogeo).
  Arriba, **Inicio** y una pestaña por tienda o plataforma con toda tu biblioteca para **descargar y quitar**:
  - **Steam:** los descargados y el resto de tu biblioteca (descargar y quitar los hace Steam).
  - **Epic:** tu biblioteca de Heroic; descargar (con su progreso) y quitar con legendary, el de Heroic.
  - **Emuladores:** tus copias de tus juegos en `~/Juegos/<sistema>/` (NES, SNES, N64, GB, GBC, GBA, Mega Drive, PS1, PSP,
    PS2, PS3, GameCube, Wii, Wii U, DS, 3DS y Switch), con su portada de libretro-thumbnails. Emuladores de Flathub:
    RetroArch, PCSX2, RPCS3, Dolphin, Cemu, melonDS, Azahar y Ryujinx. La BIOS va en `~/Juegos/BIOS`. Apogeo no trae ni
    busca juegos: cada uno pone los suyos (`~/Juegos/LEEME.txt`).
  - **PS5 (AnyPS5, experimental):** tus juegos volcados de tu PS5 en `~/Juegos/PS5/<juego>/` se convierten con AnyPS5 en
    programas de Linux (sin emular). Por ahora van muy pocos; cada versión nueva de AnyPS5 los vuelve a probar sola.
  - **Windows:** los que solo van en el Windows escondido (`~/.config/apogeo/juegos-windows.json`). De serie, ninguno: la
    pestaña sale cuando añadas uno.
  - Con el mando (lo lee la consola, sin Steam por medio) o el teclado: ← → elegir, ✕/Intro jugar o descargar, □/Supr
    quitar, L1 R1/Q E pestaña, ○/Esc atrás, ↓ bajar a Navegar. El botón PS trae la consola desde cualquier sitio. Los
    botones salen como en tu mando (PlayStation de serie; A B X Y LB RB con uno de Xbox).
- **Al día solo (`apogeo-al-dia`), sin jugar:** cada 2 horas, si no estás jugando, se ponen al día los emuladores (Flatpak),
  GE-Proton, AnyPS5, los núcleos de RetroArch y Heroic pone al día tus juegos de Epic. Steam lo hace él (y no descarga
  mientras juegas).
- **Tiendas:** Steam, Heroic (Epic), el lanzador oficial de Epic con Proton («Epic Games (oficial)») e Hydra (de su GitHub
  oficial, sin fuentes de descarga añadidas).
- **Modo partida (Meta+Tab, «S3 · Juego y Discord a la vez»):** con un juego a pantalla completa, el juego no se toca:
  sigue a su resolución, sin minimizarse ni pararse, que es lo que da tirones y fallos con Alt+Tab.
  - A la izquierda se ve en vivo, en pequeño (una imagen de KWin); debajo va lo que suena, con sus botones.
  - A la derecha, Discord de verdad: se abre si no lo estaba.
  - Para volver, Meta+Tab otra vez o pulsar el juego.
  - Lo hace el script de KWin `apogeo-partida`. Los juegos de SDL no se minimizan al perder el foco
    (`SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0`).
  - Alt+Tab sigue siendo el cambiador de ventanas de siempre.
- **Windows escondido** (solo para los juegos que no van en Apogeo por su antitrampas: Valorant, EA FC…):
  - En la consola, pestaña Windows (sale cuando hay un Windows en el PC), eliges el juego: «W1 · Cuenta atrás» de 10 s
    (✕ ya, ○ cancelar) y Apogeo se reinicia en Windows una sola vez (BootNext) con una nota en el arranque de Windows
    (`EFI/apogeo/puente.json`). Lo hace `apogeo-windows` (pkexec, sin contraseña para quien está delante).
  - En Windows («V1 · Solo el juego»): sin escritorio, la pantalla de carga de Apogeo, el juego y, al cerrarlo, de vuelta
    a Apogeo solo. Si el juego no aparece, deja elegir escritorio o volver.
  - Para instalar juegos: «Ir a Windows a instalar» → el escritorio de siempre con «Volver a Apogeo». Al volver, Windows
    apunta tus juegos (Riot, Epic, EA app, Steam) en `EFI/apogeo/juegos.json` y Apogeo los enseña en la consola.
  - En Windows lo pone `instalar.cmd` (de `/usr/share/apogeo/windows`, una vez): la tarea «Apogeo-Arranque» (como
    SISTEMA), el puente como escritorio de tu cuenta, sin inicio rápido y entrar sin contraseña (lo eliges tú).
  - Allí no hay Meta+Tab (Apogeo no está en marcha): el overlay de Discord y la Xbox Game Bar para Spotify.
  - Valorant y EA FC piden Secure Boot y TPM 2.0: en el PC de verdad, Apogeo arrancará con Secure Boot (firmado con
    claves propias). Nunca se salta ningún antitrampas.

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

Cada piso con el suyo; el animado de siempre es el de por defecto. Se cambian en Ajustes → Fondos, con Aura o con el botón
derecho en el escritorio: sale un carrusel y el fondo se ve al momento, con «Cancelar» para volver al de antes y «Aura…»
para buscar más.

- **Animados de Apogeo:** los ocho de Ágape. Se dibujan a un tercio de la resolución y a 30 imágenes por segundo como
  mucho.
- **Con Aura:** [Aura](https://github.com/antwny/aura) (de antwny, GPL-3) busca y baja fondos de Wallhaven, vídeos de
  MotionBGS y la imagen del día de Bing, y lleva tu biblioteca. Va en el paquete `apogeo-aura`, construido desde su
  código (revisado) con un parche pequeño (`paquetes/apogeo-aura/aura-apogeo.patch`):
  - Lo que eliges en ella va solo al piso en el que estás (`/usr/lib/apogeo/apogeo-fondo`), con el reproductor de fondos
    de Apogeo; sin plugins de fuera. En ese piso se apaga «que cambie solo», porque es una elección tuya.
  - No se actualiza sola: se pone al día con Apogeo.
  - Ajustes → Fondos: lo que tiene el piso ahora y «Elegir con Aura» (te lleva a ese piso y la abre).
- **Tu biblioteca:** lo que bajas con Aura (Imágenes/Wallpapers/Aura) y las carpetas que mira ella (de serie, Wallpapers,
  Wallpaper y Fondos en Imágenes y en Vídeos), más los fondos que añadiste antes de Aura. Se pone en cualquier piso desde
  Ajustes → Fondos o el carrusel.
  - Imágenes (JPG, PNG, WebP, AVIF, JPEG XL…) a la resolución de la pantalla, con un fundido al cambiar.
  - Vídeos (MP4, WebM, MKV, MOV, AVI) en bucle y sin sonido; se paran cuando una ventana maximizada o a pantalla
    completa los tapa. Su miniatura (un fotograma) va en `~/.cache/apogeo/miniaturas`.
- **Que cambie solo:** cada 15 minutos, cada hora, cada día o al entrar en el piso. Pasa por tu biblioteca, por los
  animados o por los dos.

Lo hacen `apogeo_fondos.py` (la biblioteca), `apogeo-pisos` (el de cada piso y que cambie solo) y el fondo de
Plasma `org.apogeo.fondo`.

## Ventanas en carrusel (como niri)

En Ajustes → Pisos, por piso: las ventanas en columnas que se deslizan de lado, como en niri, con
[Karousel](https://github.com/peterfajdiga/karousel) (de Peter Fajdiga, GPL-3; paquete `apogeo-karousel`, su versión
publicada tal cual). Apagado de serie.
- **Atajos:** Meta+Alt+← → (la columna de al lado), Meta+Alt+⇧+← → (mover la ventana), Meta+Alt+R (cambiar el ancho),
  Meta+Alt+Espacio (soltarla o volver) y Meta+Alt+Intro (centrarla). Los demás de Karousel, sin tecla, para no chocar
  con los de Apogeo. Mientras algún piso tiene el carrusel, Meta+Alt+flechas son suyas (en KWin eran «ir a la ventana de
  al lado»). La guía de atajos los enseña en esos pisos.
- **Huecos** (sin, 4, 8 o 16 px) y **anchos** que recorre Meta+Alt+R (½, ⅔, entera): iguales en todos los pisos con
  carrusel.

Lo pone `apogeo-pisos` (`carousel()`): Karousel solo trabaja en los escritorios con el nombre de esos pisos
(`tiledDesktops`).

## Escritorios

Sin iconos de apps y con el estilo «D2 · Sin cajas»: todo escrito sobre el fondo, separado por rayas finas, con un velo
oscuro arriba y abajo para que se lea.
- **Navegar:** la hora muy grande a la izquierda con la fecha y el tiempo, y abajo una fila: lo que suena, los avisos, lo
  próximo del calendario de Ágape y tu PC.
- **Estudiar:** tu carpeta `~/Estudios` a la izquierda (cada asignatura con Temas, Trabajos y Ejercicios), el temporizador
  25/5 en el centro (el mismo que el de la isla) y, a la derecha, los exámenes con lo que falta y las tareas de hoy.
- **Notas** («R1 · Post-its de colores»), en cada piso: el «+» de arriba a la derecha pone una (en un hueco libre y de
  un color que no esté); un clic la escribe, se arrastran, las líneas con ☐ son una lista (Intro la sigue) y arriba de
  cada una, lista, color y quitar. Se guardan en `~/.config/apogeo/notas.json` (`Notas.qml`).

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
- **Guía de atajos (mantener Meta o Meta+/, «G1 + G3»):** una tarjeta grande en el centro con los atajos de Apogeo
  (pisos, ventanas, buscar y copiar, pantalla) y, arriba y resaltados, los del piso en el que estás (Jugar: modo
  partida y HUD; Navegar: los de Ágape; Estudiar: apuntes lado a lado y sacar texto). Manteniendo Meta 0,6 s sale sin
  quitarle el teclado ni el ratón a nada (capa de encima de todo, layer-shell: también sobre un juego) y al soltar se va
  sin abrir el buscador; con Meta+/ se cierra con Esc o un clic. La enseña `apogeo-buscador` (`Atajos.qml`); lo de
  mantener Meta lo avisa `apogeo-meta`, un servicio del sistema sin root (usuario dinámico con el grupo `input`, sin
  red) que lee los teclados y solo dice «Mantenida» y «Soltada» por el bus del sistema: ni qué otras teclas pulsas ni
  cuándo.
- **Portapapeles (Meta+V, «P1 · Junto al cursor»):** una lista pequeña donde está el ratón con lo último que has
  copiado (textos e imágenes); escribir filtra, flechas eligen, Intro lo pega donde estabas (Ctrl+V, o Ctrl+Mayús+V en
  un terminal), Ctrl+P lo fija (📌) y Supr lo quita. Vive en la memoria y en `/run/user` (se borra al apagar, menos lo
  fijado) y nunca guarda contraseñas de KeePassXC (`x-kde-passwordManagerHint`). Sustituye al de Plasma (Klipper).
- **Emojis (Meta+., «E1 · Junto al cursor»):** una tarjetita con buscador en español («corazon», «gato») y pestañas por
  tipo; los que más usas salen primero. Se pega donde escribías y luego vuelve al portapapeles lo que tenías.
  Los dos son `apogeo-portapapeles` (servicio de cada sesión) y `sistema/usr/share/apogeo/portapapeles/`; hablan con
  KWin por Wayland sin librerías (`apogeo_wayland.py`: ext-data-control para el portapapeles y fake-input para pegar).
- **Capturas (Meta+Mayús+S o Impr Pant, «C1 + C3»):** la pantalla se congela y se oscurece; arriba eliges Zona
  (arrastrar), Ventana (pulsar una), Pantalla o ⏱ 3 s (←/→ también cambian; Intro sin elegir nada: toda la pantalla, o
  la ventana de delante). Debajo de lo elegido salen sus botones: Copiar (Intro), Guardar como…, Dibujar (flecha,
  recuadro, a mano y tapar, en cuatro colores, Ctrl+Z deshace) y Sacar texto (tesseract, español e inglés: lo copia).
  Al acabar se copia sola (y queda en lo copiado de Meta+V), se guarda en Imágenes/Capturas y sale una miniatura abajo
  a la derecha unos segundos: Editar, la carpeta o arrastrarla a un chat. La foto la da KWin
  (`org.kde.KWin.ScreenShot2`) al pulsar, antes de cargar nada. `apogeo-captura` y `sistema/usr/share/apogeo/captura/`.
- **Pantalla de apagar («A1 · La isla se abre»):** la isla de abajo crece y se convierte en el menú: tu foto, desde
  cuándo está encendido, Apagar, Reiniciar, Reposo, Ir a Windows (si hay Windows escondido), Salir y Bloquear; cuántas
  apps se cierran (Ágape guarda sus pestañas) y **«Actualizar al apagar»** si hay actualizaciones (las instala el
  servicio `apogeo-actualizar-al-apagar` antes de apagarse, con su aviso en la pantalla del búho; si algo falla no
  toca nada y avisa al volver). Desde Plasma 6.8 vive en el escritorio de Plasma: `apogeo-bloqueo` la pone, como la de
  bloqueo.
- **Pantalla de carga** al entrar: la misma que al encender (el búho batiendo las alas, el brillo y la barra).
- **Menú de arranque:** no sale; mantén pulsada una tecla al encender para verlo (con los colores de Apogeo).
- **Programas repetidos y apps de CachyOS, fuera** (una vez, después de actualizar: `apogeo-limpieza`): la bienvenida,
  el instalador de paquetes, el gestor de núcleos, scx-manager, el actualizador y Shelly; Konsole y Alacritty (se queda
  Ghostty), Spectacle y Flameshot (las capturas de Apogeo), Haruna y mpv (VLC), Firefox (Ágape), btop, el Monitor del sistema y Filelight
  (Mission Center), vim, micro y la zsh de CachyOS (Kate y fish; zsh se queda si alguna cuenta entra con ella).
  Si luego instalas alguno a mano, se queda. En una segunda tanda, KDE Connect (gastaba memoria y red sin usarse); en una tercera, Stacer (lo hace
  Mission Center) y VirtualBox (no hace falta en el PC y su módulo frenaba las actualizaciones del núcleo); en una
  quinta, Flameshot. Lo que no son apps (herramientas de Qt, Avahi, cámaras…) va fuera del menú.
  En lugar del actualizador, un aviso de Apogeo cuando hay actualizaciones (uno al día como mucho; en Jugar y Estudiar
  se guarda para luego).

## Deshacer una actualización

Antes de cada actualización CachyOS guarda cómo estaba el sistema (snap-pac + Snapper en Btrfs; `/home` no se toca) y
lo pone en el menú de arranque (limine-snapper-sync). En Ajustes → Actualizaciones, «Reiniciar y elegir…» hace que el
próximo arranque enseñe el menú una vez (`apogeo-volver menu` → `apogeo-menu-arranque una-vez`; al encender se vuelve a
esconder) para entrar en «Snapshots» y elegir la de antes. Dentro de una instantánea, Apogeo pregunta: «Quedarme así»
(la herramienta de CachyOS, `limine-snapper-restore`, en una terminal) o «Volver a lo de ahora» (reinicia). Los avisos
de Limine y Snapper de CachyOS al arrancar, fuera (los sustituye este).

## Bloqueo: tu símbolo

En Ajustes → Bloqueo dibujas tu símbolo tres veces (de un solo trazo) y, en la pantalla de bloqueo, lo dibujas con el
ratón en cualquier parte y entras. Se reconoce la forma y el sentido (no el sitio ni el tamaño). La contraseña sigue
igual y siempre sirve: al encender y al iniciar sesión se pide ella.
- El dibujo va por el mismo camino que la contraseña, con «apogeo-simbolo:» delante: `/etc/pam.d/kde` lo pasa primero
  por `apogeo-simbolo` (pam_exec). Si no es tu símbolo, se para ahí: no cuenta como contraseña equivocada ni bloquea la
  cuenta. Tras 5 dibujos que no son, solo vale la contraseña durante 10 minutos.
- Lo guardado está en `/var/lib/apogeo/simbolo/<tú>.json` (solo lo lees tú; cambiarlo pide tu contraseña).

## Optimización

- **Planificador de CachyOS para escritorio y juegos** (sched_ext `scx_lavd` en modo Auto, con `scx_loader`): responde
  antes y ahorra energía en reposo; si falla, vuelve solo al de siempre.
- **Caché de paquetes** limpia cada semana (`paccache`: las 2 últimas versiones).
- **El índice de los manuales** (man-db) con la prioridad más baja: ya no compite con el escritorio al arrancar.
- **Fuera de en medio** el menú global y el ayudante de accesibilidad (no se usan) y KDE Connect (se quita).
- **La consola de Jugar duerme** sin estar delante: deja de mirar tus juegos cada 20 segundos y suelta las imágenes; el
  arte se carga al tamaño de la pantalla. Tras media hora dormida fuera de Jugar se cierra (devuelve su memoria) y
  `apogeo-pisos` la abre al volver a Jugar.
- **MangoHud en los juegos** (Vulkan, también Proton), escondido y con los colores de Apogeo: el botón «HUD» de la isla
  en Jugar y del modo partida (Meta+Tab) lo enseña o esconde (`mangohudctl`; también Mayús derecha+F12). El límite de
  FPS de Salud del PC va con MangoHud (vale en todos los juegos) y cada juego de Steam o Epic puede tener el suyo (30,
  45 o 60) desde la consola. Ágape, Discord, Steam y Spotify quedan fuera.
- Sin gráfica de verdad (máquina virtual), sin desenfoque; los fondos animados solo se mueven a la vista.

## Copia de Apogeo

Ajustes → Copia: tus ajustes y pisos, tus fondos, `~/Estudios`, tus tareas y exámenes (y, si quieres, Documentos) en un
archivo `.apogeo` cerrado con contraseña, en un USB, un disco o una carpeta de otro disco. Se hace **sola** al conectar
ese USB si la última tiene una semana o más (lo monta, la guarda, lo desmonta y avisa) y con «Hacer copia ahora»; se
guardan las 4 últimas. «Recuperar…» la abre con su contraseña y lo pone todo en su sitio.
Va cerrada con GnuPG sin guardar la contraseña: la llave pública cierra las copias (por eso puede hacerse sola) y la
privada, protegida con tu contraseña, va dentro de cada copia. Ágape tiene su propia copia (Personalizar → Avanzado).
`sistema/usr/lib/apogeo/apogeo-copia` y `sistema/usr/share/apogeo/ajustes/CopiaSeccion.qml`.

## Revisión después de actualizar

Al acabar cada actualización, Apogeo se revisa y arregla lo que pueda (`apogeo-revision`): los servicios, el inicio de
sesión, que no falten archivos y, en tu sesión, los pisos, la isla, la columna de pisos, el fondo, los scripts de KWin,
el estilo y la música. Solo avisa si ha arreglado algo o si algo no ha podido arreglarlo.

## Instalador (ISO) — decidido para cuando se haga

- **Disco cifrado** (LUKS) de serie, que se abre solo con el chip de seguridad del PC (TPM 2.0, `systemd-cryptenroll`):
  al encender no hay que escribir dos contraseñas, solo la de tu cuenta. La contraseña del disco se guarda de reserva
  (por si cambias de placa o el TPM no la da) y se pide solo entonces.
- **Windows 11 Home** en el Windows escondido (la clave ya viene en el PC y se activa sola).
- **Sin acceso remoto:** SSH apagado (en la máquina virtual se encendió solo para probar).
- Particiones, Apogeo y Windows (descargado de Microsoft e instalado sin preguntas, con el puente) en un solo paso.

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
