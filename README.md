# Apogeo

Sistema operativo personal basado en Linux ([CachyOS](https://cachyos.org), Arch, con KDE Plasma), con Ágape como
navegador y con una identidad propia —**Órbita**: grafito, Geist y un acento por modo— sobre un escritorio organizado en
tres **modos**: Jugar, Navegar y Estudiar.

- **Juegos:** Steam oficial con Proton, Epic (lanzador oficial con Proton y Heroic) y los juegos con anticheat de Windows
  (Valorant, EA FC…) mediante un Windows escondido: se pulsa Jugar en Apogeo, el equipo se reinicia en Windows con el
  juego y al cerrarlo vuelve a Apogeo.
- **Actualizaciones:** Apogeo es un paquete (`apogeo`) en su propio repositorio firmado; GitHub lo construye en cada
  cambio y cada día. Se actualiza con el resto del sistema (`sudo pacman -Syu` o el actualizador de CachyOS).

## Los tres modos

El escritorio son tres modos, uno encima de otro: **Jugar**, **Navegar** y **Estudiar**. Se cambia con Meta+F1/F2/F3, con
la pastilla de los modos (Meta+N), desde la consola y en la pantalla de inicio de sesión (cada modo es una sesión); las
ventanas se deslizan como en un ascensor. Cada modo guarda sus ventanas, su fondo y su acento: **violeta `#B79CFF` en
Jugar, cian `#45D6FF` en Navegar y ámbar `#FFB35C` en Estudiar**, sobre el grafito de Órbita (Estudiar va, además, en
papel cálido de serie).

- **El modo es estado de verdad**, no un truco visual: `apogeo-pisos` lo escribe en `~/.config/apogeo/modo.json`, lo
  publica en la sesión D-Bus `org.apogeo.Modos1` (`/Modos`: `Actual`, `Piso`, `Cambiar`, `Siguiente`, `Anterior` y la
  señal `Cambiado`) y lo leen Tema (los colores de todo el QML), la consola, los scripts y las apps.
- **Lo que se abre la primera vez en cada modo** (Ajustes → Modos → «Apps al llegar»): en Jugar, la consola (tiendas,
  emuladores, PS5 y Windows están dentro); en Navegar y Estudiar, nada de serie (ahí eliges tú). **Todas las apps siguen
  disponibles en los tres modos**, en el menú y en el buscador: el modo cambia color, fondo, energía y avisos, nunca tus
  programas.

**Rejilla de ventanas** («V2 · Huecos en toda la pantalla»): lleva una ventana hasta arriba y la pantalla enseña sus
huecos en el color del modo; arriba, una pastilla para cambiar de esquema (mitades, tercios, ⅔ + ⅓, cuartos o «Suelta»). Al soltar,
la ventana va al hueco iluminado; si la sueltas luego fuera, vuelve a su tamaño (`apogeo-ventanas`, `Rejilla.qml`).

- **Avisos:** solo en Navegar; en Jugar y Estudiar no sale ninguno (se quedan en el historial). Al volver a un modo
  con avisos sale el **resumen** («H3»): una tarjeta encima de la isla con lo que llegó («Has jugado 1 h 20 min»), lo
  importante delante, «Ver todos» y un clic en un aviso abre su app. Se va sola al medio minuto
  (`apogeo-resumen`, `sistema/usr/share/apogeo/resumen/`).
- **Luz cálida en Estudiar por la noche:** la luz nocturna de KWin, solo en Estudiar: al anochecer en tu zona entra poco
  a poco (Suave 4500 K de serie; Media y Fuerte en Ajustes → Modos) y al amanecer se va. Tu zona sale de tu zona horaria,
  sin preguntar a internet.
- **Energía:** nunca «rendimiento». Jugar y Navegar en equilibrado, Estudiar en ahorro.

## Logo

**Núcleo**, la marca de Órbita: un punto sólido y tres órbitas abiertas (cian, violeta y ámbar), cada una con su nodo
al final. Se dibuja vectorial, así que sale nítido a cualquier tamaño y puede girar sin pixelarse. Es un diseño propio.
- Se dibuja al construir el paquete con `herramientas/logo.py` (también los 24 fotogramas del giro para el arranque).
- De ahí salen las copias del arranque, el inicio de sesión, el bloqueo, la bienvenida, el menú, la terminal y el
  `fastfetch` de la terminal (imagen de verdad, y en letras el Núcleo dibujado). El búho antiguo se queda en
  `herramientas/logo-clasico.py` por si algún día hace falta.

## Identidad: Órbita

La piel de serie de todo el sistema (Ajustes → Identidad):

- **Letra:** **Geist** en todo el sistema y **Geist Mono** para datos, rutas, compatibilidad y la consola (las dos,
  con licencia OFL, se instalan con el paquete). Bricolage Grotesque sigue instalada para la identidad «Clásico».
- **Colores:** fondo `#080A0F`, superficie `#0F131A`, texto `#E9EDF5` y un acento por modo (cian en Navegar, ámbar en
  Estudiar, violeta en Jugar), los tres sobre grafito (Estudiar ya no va en papel de día). La identidad antigua (berenjena y rosa de Ágape) es
  el estilo «Clásico» y sigue ahí, a un clic.
- **Fondos:** los fondos animados de Órbita, uno por modo y con sus tres colores: Navegar «Órbitas» (abajo en el
  centro, donde está el orbe, sus órbitas abiertas girando despacio, cada una con su nodo, y unas estrellas), Jugar
  «Nebulosa» (una nube violeta que se deforma despacio y ondas que salen del orbe) y Estudiar «Aurora» (cortinas de luz
  ámbar que se mecen; de día, sobre papel y casi sin color). Siguen los de antes (Tinta, Humo, Seda, Mármol, Relieve,
  Remolino, Dunas, Luces) para elegir. Se dibujan a un tercio de la resolución y a 30 imágenes por segundo como mucho; sin gráfica (máquina virtual) se quedan
  quietos.
- **Isla («B1 · Cristal»):** una sola isla de cristal (radio 22). Las apps abiertas llevan un puntito con el color del
  modo (la activa, una rayita). El buscador y el modo activo son la pastilla de su acento con brillo, y todo usa los
  iconos de línea de Papirus. El estilo de Plasma «apogeo» se escribe en `~/.config/plasmarc`
  de cada usuario: si solo estaba en `/etc/xdg`, Plasma se quedaba con el gris por defecto.
- **Ventanas:** la barra de ventanas con el título en el centro y sus botones planos (la ✕ se pone roja), del color
  del modo.
- **Menús y avisos:** tarjetas de cristal del modo.
- **Inicio de sesión** («8 · Inicio de sesión», con el orbe): arriba la hora grande y la fecha; en el centro una
  tarjeta de cristal con tu foto, «Hola, …», en qué modo entras y la contraseña. El modo se elige con el orbe, como en
  el escritorio: el elegido en el centro, con su color, y los otros dos en bolitas a sus lados (← → o un clic). Detrás, el fondo animado de ese modo moviéndose, con sus
  colores (con «Del fondo», los de cada modo): al elegir otro modo, cambia. Esa pantalla no puede leer tus ajustes, así
  que `apogeo-aspecto-login` le deja en `/var/lib/apogeo/aspecto-login.json` solo los colores (también por modo) y qué
  fondo animado lleva cada uno. El bloqueo: tu símbolo (ver abajo).
- **Carpetas:** Papirus con las carpetas del acento (un tema de iconos por color que hereda de Papirus). Cursor
  grafito con borde cian y teclado EE. UU. internacional (ñ con AltGr+n).
- **Sonidos:** propios y suaves (marimba de madera con un poco de sala) para avisos, errores, USB, volumen, capturas y lo
  hecho; al entrar, dos notas suaves que bajan un poco, sobre un acorde cálido. Se sintetizan al construir el paquete
  (`herramientas/sonidos.py`).
- **Fondos de serie (de Aura, Wallhaven):** Navegar una nebulosa azul (`4ddk8g`), Estudiar un atardecer mínimo oscuro
  (`mdjrqy`) y Jugar nubes violeta (`k88m2m`). No van en el paquete (son de sus autores): `apogeo_fondos.bajar_de_serie`
  los baja una vez al entrar a `Imágenes/Wallpapers/Aura` y los pone donde seguía el animado de serie; si no hay
  internet, siguen los animados.
- **Arranque y apagado:** el Núcleo sobre **la Tierra vista desde la Luna** (Wallhaven `k7zv97`, oscurecida; la baja
  `apogeo-tierra.service` la primera vez que hay internet, y mientras tanto va el grafito). Al encender la Tierra
  aparece poco a poco y el orbe se forma (90 fotogramas `forma-*.png`, uno por refresco); luego las órbitas giran
  enteras (Plymouth gira `orbitas.png` en cada refresco, a 50 por segundo, sin fotogramas sueltos) y el punto respira
  (`halo.png`). Debajo, una barra fina cian. La pantalla de carga al entrar es la misma (en QML). Se dibujan con
  `herramientas/arranque.py` y `herramientas/logo.py`.

### Tu identidad (Ajustes → Identidad, «K2 con vista previa»)

**De serie es Órbita**: grafito con el acento de cada modo. Con «Del fondo», en cambio,
cada modo coge los colores de su foto o su vídeo (`apogeo_paleta`: el
tono que más se ve, con su viveza, y con él el acento, el fondo y la superficie oscuros, el texto y los colores de los
animados, como Material You pero con la forma de las tarjetas de Órbita). A los fondos animados de Apogeo les das tú el color (Ajustes →
Fondos → «Color de los animados»; sin elegir, el del modo). Al cambiar de modo o de fondo cambia todo: lo de
Apogeo en QML al momento y los temas de KDE un momento después (al acabar la animación). La ventana activa lleva un
borde del color del modo (el efecto de esquinas redondeadas). Las apps de KDE ya abiertas se quedan con el color con el
que se abrieron (Kvantum no cambia en vivo); las que abras cogen el del modo.
- Los temas de KDE de cada modo se hacen una vez por colores (`ApogeoTuAspecto-<huella>`, en segundo plano) y al cambiar
  de modo solo se ponen. Las carpetas usan el más parecido de los colores de los animados (hacer un tema de iconos
  tarda).
- `aspecto.json` lleva las fichas del modo en el que estás y, en `pisos`, las de los tres: el fondo de Plasma dice a
  Tema en qué modo estás y todo lo de Plasma cambia sin esperar.

Con «Como Ágape», lo que elijas en Ágape → Personalizar (sus colores, claro u oscuro, los colores del fondo, la letra, las
esquinas, el cristal y la velocidad de las animaciones) cambia también Apogeo, al momento (`apogeo-pisos` vigila los
ajustes de Ágape y solo los lee). En Ajustes → Identidad también hay estilos de un clic (Órbita es el de serie; Clásico,
Medianoche, Bosque, Arena y Papel) y cada detalle a mano: el color, claro u oscuro (o por modo, que es lo de serie, o
según la hora: claro de 8:00 a 20:00), la letra, las esquinas
(rectas, suaves o redondas), el cristal, el tamaño (letra e isla), las animaciones y dónde va la isla (abajo o
arriba), con una vista en pequeño de cómo queda.
- Las carpetas van del color de tu estilo (un tema de iconos por color, `ApogeoCarpetas-<color>`, que hereda de Papirus).
- Con lo de serie se usan los temas del paquete. Con otra cosa, `apogeo_aspecto` genera tus temas (colores de KDE,
  Kvantum, Plasma y barra de ventana, con los mismos generadores de `herramientas/`, instalados en
  `/usr/lib/apogeo/temas`) y los pone; «Volver a lo de serie» los quita.
- Lo de Apogeo hecho en QML (Tema) lee `~/.config/apogeo/aspecto.json` y cambia solo, también los fondos animados.

### El escritorio de Órbita («C · Orbe central»)

Casi vacío, como en la bienvenida de una consola:
- **Arriba, una barra fina sin fondo:** a la izquierda el modo en el que estás, pequeño y en su color
  (`org.apogeo.modo`; un clic abre la Órbita); **en el centro, tus ventanas abiertas** en el modo, solo sus iconos y
  un punto bajo la activa (`org.apogeo.ventanas`: clic ir o minimizar, clic central otra, clic derecho cerrar); al
  cambiar el volumen o el brillo, su barrita sale ahí un momento. A la derecha la hora, los iconos de tus apps
  (bandeja), la red, el sonido y la campana (el panel rápido: un clic abre el de la derecha).
- **Abajo, el orbe** (la isla, sin cristal detrás): el del modo en el que estás en el centro y, a sus lados, los otros
  dos en bolitas con su nombre (Jugar violeta, Navegar cian, Estudiar ámbar; un clic te lleva y el tuyo siempre queda
  en el centro). Nada encima ni a los lados: tus ventanas van arriba. Se aparta de las ventanas (con el escritorio a
  la vista, se ve) y sale al acercar el ratón al borde.
- **Jugar es solo la consola:** en Jugar no hay barra ni orbe (sus widgets no se pintan y `apogeo-pisos` esconde sus
  paneles sin guardar sitio); al salir de Jugar, vuelven.
- **La Órbita abierta** («G3 · Constelación»; clic en el orbe o Meta; sustituye al buscador, `apogeo-buscador`):
  todo a la vista nada más entrar, sin pestañas. En el centro, unida al orbe por un haz de luz, la cubierta con **tus
  apps del modo** (las que fijas tú, `~/.config/apogeo/fijadas.json`: Navegar empieza vacío; Estudiar con Obsidian,
  Okular, Xournal++, Anki, ONLYOFFICE, Ágape y Spotify) y el buscador. Las demás apps solo se encuentran buscando: su
  chincheta (o Ctrl+Intro) las fija; en la cubierta, su chincheta o el clic derecho las quitan. Alrededor, unidos al
  orbe por hilos de luz con una chispa que viaja, los **satélites**: lo que suena (su portada, sus colores en el
  cristal y las barritas, y sus botones), tus **avisos** (los últimos 12 los apunta `apogeo-pisos` en
  `$XDG_RUNTIME_DIR/apogeo-avisos.json`; «Abrir» su app o «Quitar»; arriba lo que se baja), **tu nota** (la primera
  del modo; las líneas `- [ ]` son casillas que se marcan ahí), lo que queda **hoy** en tu calendario y lo próximo y,
  en Estudiar, **tu estudio** (el 25/5 con su botón). Un clic en la nota, el calendario o el estudio los abre enteros
  (tus **notas**, la **agenda** con el mes, el tiempo y tu ciudad, recordatorios y temporizadores, y **Estudios**: el
  25/5, los exámenes, las tareas de hoy y tus asignaturas); Esc vuelve. Al escribir, encima del campo: tus apps, la
  cuenta, las **órdenes** (Jugar, Navegar, Estudiar, apagar, reiniciar, suspender, bloquear, cerrar sesión, ajustes,
  atajos), lo de KDE (sin repetir las apps), tus archivos y la web con Ágape. A los lados del orbe, los otros modos.
- Las barras y el orbe sin fondo son del estilo de Plasma de Órbita (`herramientas/plasma.py`: los trozos «north-…» y
  «south-…» de `panel-background`, vacíos, y sin sombra de panel). Con Clásico, la isla de cristal de siempre.

### La isla («I1 · Una sola isla», Clásico)

Todo en el mismo cristal: el botón de las apps, **tus apps del modo** (las fijadas, aunque estén cerradas, y las
abiertas; clic derecho para fijar o dejar de fijar, en cada modo las suyas), lo de cada modo (Jugar: temperatura y FPS;
Navegar: la música; Estudiar: el temporizador) y, al final, la red, el sonido, la campana con los avisos sin leer y la
hora. Al pasar por una app abierta, su vista en vivo (y ✕ para cerrarla). En la bandeja de KDE solo quedan los iconos de
tus apps (Discord, Steam…).
- **La red, el sonido, los avisos y la hora:** al pulsarlos sale el panel rápido de la derecha (ver «Paneles»).
- **Isla dinámica** (cristal como los paneles): sale sola y crece cuando tiene algo que enseñar, y se esconde al
  acabar (llama a los atajos sin tecla `apogeo-isla-mostrar`/`apogeo-isla-soltar` del script `apogeo-bordes`). Por
  orden: el **volumen y el brillo** (en vez de la ventanita de KDE para el volumen; la del brillo la lleva Plasma
  dentro y no se puede quitar), un **aviso** nuevo unos segundos (con sus botones; Responder abre el panel rápido;
  luego queda en el historial), una **descarga** o copia (los avisos de trabajos de KDE y las apps que lo cuentan con
  `LauncherEntry`), el **temporizador** de estudio (clic: pausa; derecho: otra vez) y **lo que suena** (portada, los
  colores de la portada, avanzar y, con el ratón encima, los botones).
- **Números en los iconos:** los avisos sin leer de cada app (y los que la app cuenta, con su barra de progreso).
- **Avisos en pantalla:** los normales salen en la isla; los urgentes, abajo a la derecha, apilados, con sus botones y
  una rayita con el color del modo y el tiempo que les queda (se paran con el ratón encima). Respetan No molestar y los modos sin
  avisos (salvo los urgentes).

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

La tienda de programas (sustituye a Warehouse), con el aspecto de Órbita y la idea de appPoint: a la izquierda Inicio,
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

Ghostty con el estilo «T1 · Cristal con píldoras»: el cristal grafito translúcido con desenfoque, **Geist Mono** como
letra de datos (con JetBrains Mono Nerd Font de respaldo, para los símbolos del prompt) y el cian de Navegar.
- **Prompt:** Starship, con la carpeta en una píldora cian y la rama de git en otra grafito.
- **Al abrir:** fastfetch con el Núcleo (en Ghostty, la imagen de verdad; en otras terminales, en letras).
- **Dónde está:** la configuración, en `/usr/share/apogeo/terminal/`. Cada usuario la carga desde
  `~/.config/ghostty/config`, donde puede añadir lo suyo.
- **Por defecto:** es la terminal de siempre (Dolphin, Ctrl+Alt+T).

## Jugar

- **Consola («C8 · Cinta panorámica»):** al entrar en el modo Jugar se abre a pantalla completa. Abajo, una cinta con las
  portadas de tus juegos descargados (el último jugado primero); el elegido se agranda y pinta la pantalla con su arte
  (un **fondo vivo**: se acerca y se aleja muy despacio, se queda un poco atrás al pasar de un juego a otro, y sus
  colores, mezclados con el violeta, tiñen el grafito), con cuándo jugaste y **cuántas horas llevas** (las de Steam y Heroic; en emuladores y PS5 las cuenta Apogeo).
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
  - **Antes de ir a Windows** (`apogeo-windows revisar`, sin permisos y solo leyendo): la pestaña Windows de la consola
    avisa si Secure Boot está apagado (y si el firmware está en modo de configuración, listo para las claves propias),
    si no se ve el TPM, si Windows tiene BitLocker (ten a mano la clave de recuperación) y si queda poco sitio en su
    partición de arranque (menos de 20 MB; lo mide `apogeo-windows sync` al encender). Nunca toca las claves por su
    cuenta.

## Bienvenida

Al entrar por primera vez sale una tarjeta en el centro, como la bienvenida de Ágape, con los pasos: tu nombre y tu foto
(para el inicio de sesión y el bloqueo), instalar Ágape con tu llave, traer tu copia de Ágape (`.agape`, la contraseña
la pide Ágape), los modos y la isla. Todo se puede saltar; si se cierra sin terminar vuelve en el siguiente inicio,
hasta acabarla o pulsar «No volver a mostrar». Se abre de nuevo desde el buscador («Bienvenida de Apogeo»).

## Ajustes

«Ajustes de Apogeo» es como «Personalizar» de Ágape: el buscador y las secciones a la izquierda y las tarjetas a la
derecha. Modos (el fondo, los avisos, la energía y las apps de cada uno; animar los fondos; no molestar), Isla (que se
esconda sola y lo de cada modo), Salud del PC (temperatura máxima de 70 a 85 °C y FPS de los juegos: 30, 45 o 60),
Ágape (la llave, llevar o traer la copia, la bienvenida), Tu perfil y Actualizaciones. La red, el sonido, la pantalla…
abren los Ajustes de KDE. Lo que cambias se guarda en `~/.config/apogeo/ajustes.json` y `apogeo-pisos` lo aplica al
momento.

Lo de todos los días (red, bluetooth, fondo animado, no molestar, ahorro de energía del modo, luz nocturna, volumen y
brillo) está en el **panel rápido** de la derecha (Meta+N).

## Fondos

Cada modo con el suyo; el animado de siempre es el de por defecto. Se cambian en Ajustes → Fondos, con Aura o con el botón
derecho en el escritorio: sale un carrusel y el fondo se ve al momento, con «Cancelar» para volver al de antes y «Aura…»
para buscar más.

- **Animados de Apogeo:** los ocho de siempre (Tinta, Humo, Seda…). Se dibujan a un tercio de la resolución y a 30 imágenes por segundo como
  mucho.
- **Con Aura:** [Aura](https://github.com/antwny/aura) (de antwny, GPL-3) busca y baja fondos de Wallhaven, vídeos de
  MotionBGS y la imagen del día de Bing, y lleva tu biblioteca. Va en el paquete `apogeo-aura`, construido desde su
  código (revisado) con un parche pequeño (`paquetes/apogeo-aura/aura-apogeo.patch`):
  - Lo que eliges en ella va solo al modo en el que estás (`/usr/lib/apogeo/apogeo-fondo`), con el reproductor de fondos
    de Apogeo; sin plugins de fuera. En ese modo se apaga «que cambie solo», porque es una elección tuya.
  - No se actualiza sola: se pone al día con Apogeo.
  - Ajustes → Fondos: lo que tiene el modo ahora y «Elegir con Aura» (te lleva a ese modo y la abre).
- **Tu biblioteca:** lo que bajas con Aura (Imágenes/Wallpapers/Aura) y las carpetas que mira ella (de serie, Wallpapers,
  Wallpaper y Fondos en Imágenes y en Vídeos), más los fondos que añadiste antes de Aura. Se pone en cualquier modo desde
  Ajustes → Fondos o el carrusel.
  - Imágenes (JPG, PNG, WebP, AVIF, JPEG XL…) a la resolución de la pantalla, con un fundido al cambiar.
  - Vídeos (MP4, WebM, MKV, MOV, AVI) en bucle y sin sonido; se paran cuando una ventana maximizada o a pantalla
    completa los tapa. Su miniatura (un fotograma) va en `~/.cache/apogeo/miniaturas`.
- **Que cambie solo:** cada 15 minutos, cada hora, cada día o al entrar en el modo. Pasa por tu biblioteca, por los
  animados o por los dos.

Lo hacen `apogeo_fondos.py` (la biblioteca), `apogeo-pisos` (el de cada modo y que cambie solo) y el fondo de
Plasma `org.apogeo.fondo`.

## Alt+Tab y animaciones de las ventanas

- **Alt+Tab de cristal** («6»): el cambiador de ventanas `apogeo` (`/usr/share/kwin/tabbox/apogeo`), con tus ventanas
  en grande y en vivo en una tarjeta de cristal, el nombre debajo, ✕ al pasar el ratón y las flechas para moverte.
  Hasta ahora Alt+Tab no hacía nada: `apogeo-pisos` lo guardaba mal en kglobalaccel («Alt+\x01»); se arregla solo.
- **Animaciones con vida** («7»): el efecto de KWin `apogeo-vida` abre las ventanas con un saltito y las cierra
  encogiéndose; al minimizar, la lámpara mágica de KWin las lleva a su icono de la isla. KWin no anima nada sin
  tarjeta gráfica (en una máquina virtual sin aceleración, por ejemplo).

## Ventanas en carrusel (como niri)

En Ajustes → Modos, por modo: las ventanas en columnas que se deslizan de lado, como en niri, con
[Karousel](https://github.com/peterfajdiga/karousel) (de Peter Fajdiga, GPL-3; paquete `apogeo-karousel`, su versión
publicada tal cual). Apagado de serie.
- **Atajos:** Meta+Alt+← → (la columna de al lado), Meta+Alt+⇧+← → (mover la ventana), Meta+Alt+R (cambiar el ancho),
  Meta+Alt+Espacio (soltarla o volver) y Meta+Alt+Intro (centrarla). Los demás de Karousel, sin tecla, para no chocar
  con los de Apogeo. Mientras algún modo tiene el carrusel, Meta+Alt+flechas son suyas (en KWin eran «ir a la ventana de
  al lado»). La guía de atajos los enseña en esos modos.
- **Huecos** (sin, 4, 8 o 16 px) y **anchos** que recorre Meta+Alt+R (½, ⅔, entera): iguales en todos los modos con
  carrusel.

Lo pone `apogeo-pisos` (`carousel()`): Karousel solo trabaja en los escritorios con el nombre de esos modos
(`tiledDesktops`).

## El panel rápido

El escritorio está limpio: solo el fondo (con el botón derecho, el carrusel de fondos). A la derecha, un panel alto
**de cristal** («1 · Cristal con tu fondo»: detrás, tu fondo difuminado y oscurecido, con un brillo del color del modo
arriba; lo hace `apogeo_fondos.glass`, una vez por fondo, y los animados se dibujan en vivo). Sale con Meta+N, desde la
barra de arriba o empujando el ratón contra el borde, **hace sitio** (las ventanas se estrechan y vuelven al cerrarlo) y
se queda hasta que vuelves a pulsar la tecla. El panel de widgets de la izquierda ya no está: la agenda (con el tiempo y
tu ciudad, recordatorios y temporizadores), tus notas y Estudios van en la Órbita abierta, como satélites.
En Órbita, el panel es de **«cristal grafito» (W1)**: neutro, sin el brillo del modo, y lo encendido en blanco.
- **Panel rápido** (derecha, Meta+N o pulsando la red, el sonido o la hora de la isla; `org.apogeo.derecho`): cuánto
  lleva encendido el PC con Identidad, Todos los ajustes y apagar; **los modos**; la red, el sonido y el micro en
  pastillas; bluetooth, fondo animado, no molestar, ahorro del modo y luz nocturna en botones redondos; volumen y brillo;
  **tus avisos** agrupados por app («Ver todos»), con sus botones y **Responder** ahí mismo (quitarlos o «Borrar
  todo») y abajo el tiempo de las próximas horas (en barras) y días.
  Al abrirlo, los avisos cuentan como vistos.

Lo abre el script de KWin `apogeo-bordes` (cambia el panel de «se esconde» a «siempre visible», que es lo que hace sitio,
y le dice si está abierto: cerrado no pide nada). Los datos los da `apogeo-pisos` por D-Bus (`apogeo_datos.py`). En el
tema de Plasma, la raya del foco no sale en los paneles de los lados (cruzaba el panel junto a lo que escribías).

El widget del escritorio es `org.apogeo.escritorio`:
- Se dibuja siempre del tamaño de la pantalla, aunque Plasma lo estreche al quedarse fijos la isla o un panel.
- Ocupar toda la pantalla lo asegura `apogeo-pisos` en cada inicio de sesión. Plasma guarda el sitio de cada widget por
  resolución y lo pisa al cerrarse, así que, cuando hace falta, lo corrige con Plasma parado un instante.

## Música

Abajo a la izquierda, una portada por cada cosa que suena (Spotify y otras apps de música, y **cada pestaña de Ágape**
por su canal privado); al pasar el ratón, la tarjeta con el progreso y los botones; la rueda del ratón encima cambia el
volumen de cada una. Solo sale mientras suena algo (lo que pausas sigue un minuto para reanudarlo). No sale con Ágape
delante (que enseña la suya) ni con algo a pantalla completa.
`sistema/usr/lib/apogeo/apogeo-musica` y `sistema/usr/share/apogeo/musica/`.

## Sin restos de CachyOS

- **Buscador:** la Órbita abierta (el orbe, la tecla Meta o Alt+Espacio): ver «El escritorio de Órbita».
- **Guía de atajos (mantener Meta o Meta+/, «G1 + G3»):** una tarjeta grande en el centro con los atajos de Apogeo
  (modos, ventanas, buscar y copiar, pantalla) y, arriba y resaltados, los del modo en el que estás (Jugar: modo
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
  servicio `apogeo-actualizar-al-apagar` antes de apagarse, con su aviso en la pantalla de arranque; si algo falla no
  toca nada y avisa al volver). Desde Plasma 6.8 vive en el escritorio de Plasma: `apogeo-bloqueo` la pone, como la de
  bloqueo.
- **Pantalla de carga** al entrar: la misma que al encender (el Núcleo girando sobre la Tierra y la barra cian).
- **Menú de arranque:** no sale; mantén pulsada una tecla al encender para verlo (con los colores de Apogeo).
- **Nada se quita solo: `apogeo-limpieza` solo sugiere.** Después de cada actualización mira qué programas repetidos o
  restos de CachyOS siguen ahí y escribe la lista en `/var/lib/apogeo/limpieza.json` (con su porqué) y en
  `/var/lib/apogeo/limpieza.txt` (para leerla a gusto); `apogeo-revision` te avisa solo si la lista cambia. No ejecuta
  `pacman -Rns`, no borra archivos y no toca el candado de pacman: **todas las apps se quedan donde estaban**, y solo
  tú decides si correr `sudo pacman -Rns <paquete>`. Lo que sí se hace solo es esconder del menú lo que no es una app
  (herramientas de Qt, de Avahi, de cámaras…): sigue instalado y se abre desde una terminal; las apps de verdad —las de
  CachyOS incluidas— están en el menú y en el buscador en los tres modos.
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

La pantalla («N2 · Hora recortada»): la hora enorme y recortada, con tu fondo nítido dentro de sus números y
desenfocado fuera, con un brillo del color del modo; debajo, la fecha. Arriba a la izquierda los tres modos (el tuyo
en su color; un clic o ↑↓ eligen en cuál entras) y abajo la contraseña, una línea fina con el cursor del modo.
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
- **Fuera de en medio** el menú global y el ayudante de accesibilidad (no se usan). KDE Connect se queda instalado
  (solo lo puede quitar tú).
- **La consola de Jugar duerme** sin estar delante: deja de mirar tus juegos cada 20 segundos y suelta las imágenes; el
  arte se carga al tamaño de la pantalla. Tras media hora dormida fuera de Jugar se cierra (devuelve su memoria) y
  `apogeo-pisos` la abre al volver a Jugar.
- **MangoHud en los juegos** (Vulkan, también Proton), siempre a la vista y sin estorbar («H2»): solo los FPS,
  pequeños, arriba a la izquierda (Geist Mono 12, sin fondo). La temperatura sale arriba a la derecha, en rojo, solo
  cuando llega al límite de Salud del PC (desde ahí Apogeo lo enfría); las temperaturas y los ventiladores, siempre, en
  el centro de control. Mayús derecha+F12 o el botón «HUD» del modo partida (Meta+Tab) lo esconden (`mangohudctl`). El
  límite de FPS de Salud del PC va con MangoHud (vale en todos los juegos) y cada juego de Steam o Epic puede tener el
  suyo (30, 45 o 60) desde la consola. Ágape, Discord, Steam y Spotify quedan fuera.
- **Centro de control de Jugar** (como en la PS5): el botón PS o Xbox, pulsado y soltado en una partida, saca abajo
  una banda de lado a lado encima del juego (layer-shell, sin pararlo): arriba la hora, el juego, las temperaturas y
  los ventiladores; debajo, lo que suena (⏮ ⏯ ⏭; sin nada, «Abrir Spotify»), Discord (tu micro, el del sistema, y
  abrirlo al lado del juego con el modo partida), los avisos que han llegado en la partida (los guarda `apogeo-pisos`:
  `org.apogeo.Modos1.Avisos`), el volumen y volver a la consola. Mientras está abierto, el mando es solo suyo (evdev
  con *grab*). Con el botón mantenido: → ← canción, ↑ ↓ volumen (con un aviso pequeño arriba a la derecha); mantenido
  0,7 s sin más, la consola. Si Steam también usa el botón (su menú), en Steam → Ajustes → Mando se puede quitar.
- **Jugar es la consola:** si se cierra estando en Jugar, `apogeo-pisos` la vuelve a abrir.
- Sin gráfica de verdad (máquina virtual), sin desenfoque; los fondos animados solo se mueven a la vista.

## Copia de Apogeo

Ajustes → Copia: tus ajustes y modos, tus fondos, `~/Estudios`, tus tareas y exámenes (y, si quieres, Documentos) en un
archivo `.apogeo` cerrado con contraseña, en un USB, un disco o una carpeta de otro disco. Se hace **sola** al conectar
ese USB si la última tiene una semana o más (lo monta, la guarda, lo desmonta y avisa) y con «Hacer copia ahora»; se
guardan las 4 últimas. «Recuperar…» la abre con su contraseña y lo pone todo en su sitio.
Va cerrada con GnuPG sin guardar la contraseña: la llave pública cierra las copias (por eso puede hacerse sola) y la
privada, protegida con tu contraseña, va dentro de cada copia. Ágape tiene su propia copia (Personalizar → Avanzado).
`sistema/usr/lib/apogeo/apogeo-copia` y `sistema/usr/share/apogeo/ajustes/CopiaSeccion.qml`.

## Revisión después de actualizar

Al acabar cada actualización, Apogeo se revisa y arregla lo que pueda (`apogeo-revision`): los servicios, el inicio de
sesión, que no falten archivos y, en tu sesión, los modos, la isla, los paneles de los lados, el fondo, los scripts de KWin,
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
  sombreador de los fondos animados)
- `paquetes/apogeo/PKGBUILD`: el paquete de Apogeo (dependencias, servicios y ganchos)
- `paquetes/apogeo-hydra/PKGBUILD`: Hydra Launcher desde su GitHub oficial
- `.github/workflows/paquetes.yml`: construye, firma y publica el repositorio
- `sistema/usr/lib/apogeo/apogeo-pisos`: los modos (fondo, color, avisos, energía, ventanas y apps de cada uno; el
  estado del modo en `~/.config/apogeo/modo.json` y en D-Bus `org.apogeo.Modos1`)
- `sistema/usr/lib/apogeo/apogeo-termico`: la protección de temperatura
- `sistema/usr/lib/apogeo/apogeo-bienvenida` y `sistema/usr/share/apogeo/bienvenida/`: la bienvenida
- `sistema/usr/lib/apogeo/apogeo-ajustes` y `sistema/usr/share/apogeo/ajustes/`: los ajustes (y lo del panel rápido,
  `org.apogeo.derecho`)
- `sistema/usr/lib/apogeo/apogeo_comun.py` y `apogeo_qt.py`: lo que comparten (tus ajustes, tu cuenta, Ágape)
- `sistema/usr/lib/qt6/qml/Apogeo/`: las piezas comunes en QML (botones, campos, interruptores, fondos, el Núcleo…)
- `apogeo.asc`: la clave pública con la que se firman los paquetes
