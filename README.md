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
Meta+Ctrl+↑ ↓, en la Órbita, desde la consola y en la pantalla de inicio de sesión (cada modo es una sesión); las
ventanas se deslizan como en un ascensor. **Al cambiar, el orbe se expande** (`Transicion.qml`, en `apogeo-buscador`): el orbe del modo nuevo
crece desde el de la isla hasta llenar la pantalla con su color y su nombre; debajo, KWin cambia de escritorio, y luego
se abre como un iris desde el mismo sitio (unos 800 ms). Lo pide `apogeo-escritorios` por D-Bus (`Transicion`) y cambia
de escritorio cuando ya está tapado; sin el buscador, cambia igual. Se quita con `transicion=false` en
`[Script-apogeo-escritorios]` de kwinrc. Cada modo guarda sus ventanas, su fondo y su acento: **violeta `#B79CFF` en
Jugar, cian `#45D6FF` en Navegar y ámbar `#FFB35C` en Estudiar**, sobre el grafito de Órbita (Estudiar va, además, en
papel cálido de serie).

- **El modo es estado de verdad**, no un truco visual: `apogeo-pisos` lo escribe en `~/.config/apogeo/modo.json`, lo
  publica en la sesión D-Bus `org.apogeo.Modos1` (`/Modos`: `Actual`, `Piso`, `Cambiar`, `Siguiente`, `Anterior` y la
  señal `Cambiado`) y lo leen Tema (los colores de todo el QML), la consola, los scripts y las apps.
- **Lo que se abre la primera vez en cada modo** (Ajustes → Modos → «Apps al llegar»): en Jugar, la consola (tiendas,
  emuladores, PS5 y Windows están dentro); en Navegar y Estudiar, nada de serie (ahí eliges tú). **Todas las apps siguen
  disponibles en los tres modos**, en el menú y en el buscador: el modo cambia color, fondo, energía y avisos, nunca tus
  programas.
- **Escritorios en cada modo** (`apogeo-escritorios`, script de KWin): en Navegar y Estudiar puedes tener hasta 4.
  Ctrl+Alt+← → pasa al de al lado; en el último, Ctrl+Alt+→ abre uno nuevo («Navegar 2»…; si estás en uno nuevo vacío,
  no abre otro). Cada app se queda en el escritorio en el que la abriste, y un escritorio que dejas vacío se cierra al
  irte. Con Mayús te llevas la ventana (Ctrl+Alt+Mayús+← →, y Meta+Ctrl+Mayús+↑ ↓ a otro modo). Al cambiar de modo
  vuelves al escritorio en el que estabas en él. En la barra de arriba, junto al modo, un punto por escritorio (solo si
  tienes más de uno; el tuyo encendido, un clic te lleva). Jugar no tiene: es la consola.
  Por dentro, los escritorios virtuales de KWin son una rejilla: una fila por modo y una columna por escritorio, así el
  efecto Deslizar sube o baja al cambiar de modo y va de lado al cambiar de escritorio, con el fondo quieto. Las
  columnas se crean al abrir y se quitan cuando ningún modo las usa. KWin no cambia de escritorio al activar una
  ventana (`ActivationDesktopPolicy=DoNothing`): lo decide el script (en este modo vas a ella; si es de otro, se viene
  aquí). `apogeo-pisos` le da las teclas y quita las de KWin para ir a un escritorio por número.

**Rejilla de ventanas** («V2 · Huecos en toda la pantalla»): lleva una ventana hasta arriba y la pantalla enseña sus
huecos en el color del modo; arriba, una pastilla para cambiar de esquema (mitades, tercios, ⅔ + ⅓, cuartos o «Suelta»). Al soltar,
la ventana va al hueco iluminado; si la sueltas luego fuera, vuelve a su tamaño (`apogeo-ventanas`, `Rejilla.qml`).

- **Avisos:** solo en Navegar; en Jugar y Estudiar no sale ninguno (se quedan en el historial). Al volver a un modo
  con avisos sale el **resumen** («H3»): una tarjeta abajo en el centro con lo que llegó («Has jugado 1 h 20 min»), lo
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
  `fastfetch` de la terminal (imagen de verdad, y en letras el Núcleo dibujado).

## Identidad: Órbita

La piel de todo el sistema, la única (Ajustes → Identidad): la estética de antes (Clásico, los otros estilos, «Como
Ágape», «Del fondo», la isla, Bricolage, el búho, la marimba y los animados de antes) ya no está. Ágape sigue como es.

- **Letra:** **Geist** en todo el sistema y **Geist Mono** para datos, rutas, compatibilidad y la consola (las dos,
  con licencia OFL, se instalan con el paquete).
- **Colores:** fondo `#080A0F`, superficie `#0F131A`, texto `#E9EDF5` y un acento por modo (cian en Navegar, ámbar en
  Estudiar, violeta en Jugar), los tres sobre grafito.
- **Fondos:** los fondos animados de Órbita, uno por modo y con sus tres colores: Navegar «Órbitas» (abajo en el
  centro, donde está el orbe, sus órbitas abiertas girando despacio, cada una con su nodo, y unas estrellas), Jugar
  «Nebulosa» (una nube violeta que se deforma despacio y ondas que salen del orbe) y Estudiar «Aurora» (cortinas de luz
  ámbar que se mecen; de día, sobre papel y casi sin color). Son los únicos animados (quien tenía uno de los de antes
  pasa al de su modo). Se dibujan a un tercio de la resolución y a 30 imágenes por segundo como mucho; sin gráfica
  (máquina virtual) se quedan quietos.
- **Iconos y estilo de Plasma:** los iconos de línea de Papirus. El estilo de Plasma «apogeo» se escribe en
  `~/.config/plasmarc` de cada usuario: si solo estaba en `/etc/xdg`, Plasma se quedaba con el gris por defecto.
- **Ventanas:** la barra de ventanas con el título en el centro y sus botones planos (la ✕ se pone roja), del color
  del modo.
- **Menús y avisos:** tarjetas de cristal del modo.
- **Inicio de sesión** («N2 · Hora recortada», como el bloqueo): detrás, la Tierra vista desde el espacio (la del
  arranque, `tierra.png`), desenfocada y oscura; la hora gigante recortada en ella (dentro de los números se ve
  nítida), la fecha debajo y una línea fina para la contraseña, con el cursor del color del modo. Arriba a la izquierda,
  los modos: en el que entras, en su color (clic, ← → o ↑ ↓). Con más de una cuenta, su nombre encima de la contraseña
  (clic: la siguiente). Sin la foto de la Tierra (aún no se ha bajado), el fondo animado del modo y la hora en blanco.
  Esa pantalla no puede leer tus ajustes, así
  que `apogeo-aspecto-login` le deja en `/var/lib/apogeo/aspecto-login.json` solo los colores (también por modo) y qué
  fondo animado lleva cada uno. El bloqueo: tu símbolo (ver abajo).
- **Carpetas:** Papirus con las carpetas del acento (un tema de iconos por color que hereda de Papirus). Cursor
  grafito con borde cian y teclado EE. UU. internacional (ñ con AltGr+n).
- **Sonidos:** propios, limpios y espaciales (tonos puros con un brillo suave, un poco abiertos a los lados, ecos que
  van de un lado al otro y una sala grande) para avisos, errores, USB, volumen, capturas y lo hecho; al entrar, un
  acorde que se abre y cuatro notas que suben dando la vuelta de lado a lado, como algo que entra en órbita (al salir,
  hacia abajo). Se sintetizan al construir el paquete (`herramientas/sonidos.py`).
- **Fondos de serie (de Aura, Wallhaven), todos del espacio:** Navegar una nebulosa azul (`4ddk8g`), Estudiar una
  nebulosa ámbar (`2eqjpm`, antes el atardecer `mdjrqy`, que se cambia solo si seguía puesto) y Jugar nubes violeta
  (`k88m2m`). No van en el paquete (son de sus autores): `apogeo_fondos.bajar_de_serie`
  los baja una vez al entrar a `Imágenes/Wallpapers/Aura` y los pone donde seguía el animado de serie; si no hay
  internet, siguen los animados.
- **Arranque y apagado:** el Núcleo sobre **la Tierra vista desde la Luna** (Wallhaven `k7zv97`, oscurecida; la baja
  `apogeo-tierra.service` la primera vez que hay internet, y mientras tanto va el grafito). Al encender la Tierra
  aparece poco a poco y el orbe se forma (90 fotogramas `forma-*.png`, uno por refresco); luego las órbitas giran
  enteras (Plymouth gira `orbitas.png` en cada refresco, a 50 por segundo, sin fotogramas sueltos) y el punto respira
  (`halo.png`). Debajo, una barra fina cian. La pantalla de carga al entrar es la misma (en QML). Se dibujan con
  `herramientas/arranque.py` y `herramientas/logo.py`.

### Tu identidad (Ajustes → Identidad)

**El color de cada modo sale de su fondo de pantalla** («Del fondo», lo de serie, como en COSMIC): cada modo coge el
tono que más pesa entre los colores vivos de su fondo (`apogeo_color.py`: el fondo a 48 × 48 con ffmpeg, también el
primer fotograma de un vídeo; redondeado a pasos de 10°) y con él el acento, el grafito (un poco teñido), la barra, el
orbe, la Órbita, la transición, los menús y la pantalla de bloqueo. Un fondo en blanco y negro da un acento gris claro; un
fondo animado de Apogeo se queda con el color de su modo. Con «que cambie solo», el del fondo que se ve. «Del modo»
vuelve al violeta, cian y ámbar de siempre; un acento elegido a mano manda sobre los dos. En QML, `Tema.acentoDe(modo)`.

Órbita: grafito con el acento de cada modo. Arriba, una vista en pequeño de cómo queda; debajo, cada detalle a mano: el
color (el de cada modo, que es lo de serie, o uno tuyo para los tres), claro u oscuro (por modo, que es lo de serie, o
según la hora: claro de 8:00 a 20:00), las esquinas (rectas, suaves o redondas), el cristal, el tamaño (letra y orbe) y
las animaciones. Al cambiar de modo cambia el acento en todo: lo de Apogeo en QML al momento y los temas de KDE un
momento después (al acabar la animación). La ventana activa lleva un borde del color del modo (el efecto de esquinas
redondeadas: `apogeo-esquinas`, KDE-Rounded-Corners compilado cada día para la KWin de ese día, porque el efecto solo
carga con la versión exacta de KWin para la que se compiló). Las apps de KDE ya abiertas se quedan con el color con el
que se abrieron (Kvantum no cambia en vivo); las que abras cogen el del modo.
- Los temas de KDE de cada modo se hacen una vez por colores (`ApogeoTuAspecto-<huella>`, en segundo plano) y al cambiar
  de modo solo se ponen. Las carpetas van del acento (un tema de iconos por color, `ApogeoCarpetas-<color>`, que
  hereda de Papirus).
- `aspecto.json` lleva las fichas del modo en el que estás y, en `pisos`, las de los tres: el fondo de Plasma dice a
  Tema en qué modo estás y todo lo de Plasma cambia sin esperar.
- Con lo de serie se usan los temas del paquete. Con otra cosa, `apogeo_aspecto` genera tus temas (colores de KDE,
  Kvantum, Plasma y barra de ventana, con los mismos generadores de `herramientas/`, instalados en
  `/usr/lib/apogeo/temas`) y los pone; «Volver a lo de serie» los quita.
- Lo de Apogeo hecho en QML (Tema) lee `~/.config/apogeo/aspecto.json` y cambia solo, también los fondos animados.

### El escritorio de Órbita («C · Orbe central»)

Casi vacío, como en la bienvenida de una consola:
- **Arriba, una barra fina sin fondo, suelta sobre el fondo de pantalla:** no guarda sitio (las ventanas maximizadas
  llegan arriba del todo); se aparta cuando una ventana la tapa y sale al tocar el borde de arriba (Plasma: «Esquivar
  ventanas»). A la izquierda el modo en el que estás, pequeño y en su color
  (`org.apogeo.modo`; un clic abre la Órbita); **en el centro, tus ventanas abiertas** en el modo, solo sus iconos y
  un punto bajo la activa (`org.apogeo.ventanas`: clic ir o minimizar, clic central otra, clic derecho cerrar); al
  cambiar el volumen o el brillo, su barrita sale ahí un momento. A la derecha la hora, los iconos de tus apps
  (bandeja), la red, el sonido y la campana (un clic, o Meta+N, abre la tarjeta rápida: ver «La tarjeta rápida»).
- **Abajo, el orbe** (`org.apogeo.isla`, sin cristal detrás): el del modo en el que estás en el centro y, a sus lados,
  los otros dos en bolitas con su nombre (Jugar violeta, Navegar cian, Estudiar ámbar; un clic te lleva y el tuyo
  siempre queda en el centro). Nada encima ni a los lados: tus ventanas van arriba. Está escondido (abajo no se ve
  nada) y solo sale al **tocar** el borde de abajo con el ratón (en el centro, donde está; no antes, al acercarse):
  sube desde abajo y se enciende (su anillo pasa del gris al color del modo con un destello y el punto de dentro
  aparece), y las bolitas le siguen un poco después. Al alejar el ratón baja y se apaga, más deprisa. Lo hace
  `apogeo-bordes`: saca la barra («las ventanas van debajo») y pone «asomado» en el orbe, que se anima solo; al bajar,
  quita «asomado» y, cuando ya ha bajado, vuelve a esconder la barra. Con una ventana a pantalla completa no sale.
- **Jugar es solo la consola:** en Jugar no hay barra ni orbe (sus widgets no se pintan y la consola, a pantalla
  completa, va encima); al salir de Jugar, vuelven. Cada modo tiene su fondo ya cargado: al cambiar, se funden sin
  pasar por el del modo anterior. Al entrar en Jugar o salir de él el fondo cambia de golpe (delante está la consola y
  el fondo de Jugar no se ve en medio), y al empezar la sesión sale el del modo en el que estás, sin otro antes.
- **Al abrir la Órbita**, el orbe no se duplica: la Órbita pinta el suyo justo encima del de abajo (el orbe le dice
  dónde está por D-Bus, `AbrirDesde`/`Orbe` de `apogeo-buscador`), se enciende y los satélites salen de él; al
  cerrarla, vuelven a él y se apaga.
- **La Órbita abierta** («C2 · Halo»; clic en el orbe o Meta; sustituye al buscador, `apogeo-buscador`):
  todo a la vista nada más entrar, sin pestañas. En el centro, unida al orbe por un haz de luz, la cubierta con **tus
  apps del modo** (las que fijas tú, `~/.config/apogeo/fijadas.json`: Navegar empieza vacío; Estudiar con Obsidian,
  Okular, Xournal++, Anki, ONLYOFFICE, Ágape y Spotify) y el buscador. Las demás apps solo se encuentran buscando: su
  chincheta (o Ctrl+Intro) las fija; en la cubierta, su chincheta las quita. **Carpetas:** con el clic derecho (o la
  tecla Menú) en una app fijada, «Nueva carpeta…», «Mover a «…»», «Sacar de «…»» o «Quitar»; en una carpeta,
  «Renombrar…» o «Deshacer carpeta» (sus apps siguen fijadas, sueltas). La carpeta enseña sus cuatro primeras apps;
  un clic la abre dentro de la cubierta y Esc vuelve (`~/.config/apogeo/carpetas.json`). Con 8 fijadas o más, arriba
  salen tus **6 más usadas** (las que más abres desde la Órbita, `~/.local/state/apogeo/usos.json`). Con muchas, la
  cubierta se desliza. Encima, en abanico
  sobre un **arco de luz** alrededor del orbe (con una chispa que lo recorre), los **satélites**, todos del mismo
  tamaño y un poco girados hacia el orbe (al abrir salen de él y se despliegan; el radio se ajusta para no tapar la
  cubierta): **tu nota** a la izquierda, lo que suena (su portada, sus colores en el
  cristal y las barritas, y sus botones), tus **avisos** (los últimos 12 los apunta `apogeo-pisos` en
  `$XDG_RUNTIME_DIR/apogeo-avisos.json`; un clic abre su app y la ✕ lo quita; arriba lo que se baja); la nota es la
  primera del modo (las líneas `- [ ]` son casillas que se marcan ahí); a la derecha lo que queda **hoy** en tu calendario y lo próximo y,
  en Estudiar, **tu estudio** (el 25/5 con su botón). Un clic en la nota, el calendario o el estudio los abre enteros
  (tus **notas**, la **agenda** con el mes, el tiempo y tu ciudad, recordatorios y temporizadores, y **Estudios**: el
  25/5, los exámenes, las tareas de hoy y tus asignaturas); Esc vuelve. Al escribir, encima del campo: tus apps, la
  cuenta, las **órdenes** (Jugar, Navegar, Estudiar, apagar, reiniciar, suspender, bloquear, cerrar sesión, ajustes,
  atajos), lo de KDE (sin repetir las apps), tus archivos y la web con Ágape. A los lados del orbe, los otros modos.
  **Escribir con el escritorio delante** también la abre, con lo escrito ya en el buscador (`Escribir` de
  `apogeo-buscador`, lo manda `org.apogeo.escritorio`): desde Plasma 6.8 eso abría KRunner sin forma de quitarlo. Las
  notas (y la nota de los satélites) van en **Source Serif 4**; para documentos, la plantilla **«Apuntes»** (Source
  Serif 4, A4) está en tus Plantillas y en las de ONLYOFFICE (la copia `apogeo-sesion` una vez; la genera
  `herramientas/plantilla.py`). La esquina de arriba a la izquierda ya no abre la Vista general de KDE, y el modo de la
  barra fina cambia a la vez que el orbe (lo lee del escritorio virtual).
- Las barras y el orbe sin fondo son del estilo de Plasma de Órbita (`herramientas/plasma.py`: los trozos «north-…» y
  «south-…» de `panel-background`, vacíos, y sin sombra de panel), también en su versión opaca
  (`solid/widgets/panel-background`, la que usa Plasma cuando una ventana toca el panel: sin ella cogía la de Breeze y
  salía un fondo oscuro). Además, las dos van en opacidad «translúcida» (`island()` de `apogeo-pisos`, en cada
  inicio): con la «adaptable» de serie, Plasma les ponía el fondo opaco al tocarlas una ventana.

### Los avisos

- **Avisos en pantalla:** los urgentes, abajo a la derecha, apilados, con sus botones y  avisos (salvo los urgentes). Los demás van directos al historial de la tarjeta rápida.

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

## apologIA (la IA en tu PC)

Habla con modelos de IA que corren en tu propio PC, sin cuentas ni nube. A la izquierda los chats (se guardan, se
renombran con doble clic y se borran con dos clics en la ×), en el centro la conversación y arriba el modelo; abajo, la
velocidad, la RAM que usa y cuánta memoria de la conversación lleva.
- **Motor:** `llama-server` de llama.cpp (paquetes `llama-cpp` y `ggml-vulkan`), solo en 127.0.0.1 y con una llave
  nueva en cada arranque (ninguna web puede usarlo desde el navegador). Reparte el modelo solo: lo que cabe en la GPU
  (Vulkan), el resto en la RAM y, si no cabe, lo lee del disco (mmap). Se apaga al cerrar apologIA.
- **Memoria de cada chat:** la caché KV se guarda en `~/.cache/apologia/memoria` al acabar cada respuesta y se recupera
  al volver a ese chat (sin volver a leer toda la conversación); de cada modelo se guardan hasta 3 GB.
- **Cambiar de modelo** a mitad de un chat no pierde el hilo: al nuevo se le pasa la conversación entera. Si ya no cabe
  en su memoria, se quitan los mensajes más antiguos (y lo avisa).
- **Modelos:** todos juntos en `~/Modelos` (o en la carpeta que elijas con «Cambiar carpeta», que pregunta si llevar
  los que ya tienes; si es otro disco, mira antes que quepan y, si algo falla a medias, deja todo donde estaba). Los
  que hubiera en la carpeta escondida del principio (`~/.local/share/apologia/modelos`) pasan solos. Se buscan en Hugging Face (los GGUF más bajados) y en GitHub (sus
  versiones y los .gguf del repositorio), o se pega cualquier enlace. Solo GGUF: son datos; los .bin/.pt de PyTorch
  pueden ejecutar código al abrirse y no se aceptan. Se comprueban (que empiecen por «GGUF» y, si se sabe, su sha256) y
  se sigue donde se quedó si se corta. Un .gguf suelto de otra carpeta se añade con un enlace, sin copiarlo. Los
  diálogos para elegir son los de KDE (kdialog).
  Cada archivo dice si va bien en tu PC (según tu RAM) y si es de calidad baja (IQ1, IQ2, Q2).
- **Modificador:** tus instrucciones (o ninguna), sin límite de largo, pensar antes de responder, Preciso/Equilibrado/
  Creativo y temperatura, top-p, top-k, min-p y repetición, la memoria (4k–32k o la máxima del modelo), GPU automática o
  solo procesador, y los hilos. Cambia cómo responde, no lo que el modelo aprendió al entrenarse.
- **Hugging Face:** los modelos con licencia (Llama, Gemma…) piden tu token; se guarda en `~/.config/apologia/token-hf`
  (600) y solo se manda a huggingface.co (al saltar a su CDN se quita).
- **Colab:** para los modelos que no caben, «Colab» escribe en Descargas un cuaderno que compila llama.cpp con CUDA, baja
  ese modelo de Hugging Face y abre un chat dentro del propio cuaderno con la GPU T4 gratis (Colab gratis no deja
  usarlo desde fuera del cuaderno). Con la T4 caben unos 14B en Q4.

Lo hacen `apogeo-apologia` (la ventana), `apogeo_apologia.py` (motor, modelos, chats, descargas y Colab) y
`/usr/share/apogeo/apologia/` (`Apologia.qml` y `Marca.qml`, la A de nodos).

## Terminal

Ghostty con el estilo «T1 · Cristal con píldoras»: el cristal grafito translúcido con desenfoque, **Geist Mono** como
letra de datos (con JetBrains Mono Nerd Font de respaldo, para los símbolos del prompt) y el cian de Navegar.
- **Prompt:** Starship, con la carpeta en una píldora cian y la rama de git en otra grafito.
- **Al abrir:** fastfetch con el Núcleo (en Ghostty, la imagen de verdad; en otras terminales, en letras).
- **Dónde está:** la configuración, en `/usr/share/apogeo/terminal/`. Cada usuario la carga desde
  `~/.config/ghostty/config`, donde puede añadir lo suyo.
- **Por defecto:** es la terminal de siempre (Dolphin, Ctrl+Alt+T).

## Jugar

- **Consola («C8 · Cinta panorámica»):** al entrar en el modo Jugar sale al instante, a pantalla completa (`apogeo-pisos`
  la abre al entrar en la sesión, en Jugar, y ya no se cierra). Abajo, una cinta con las
  portadas de tus juegos descargados (el último jugado primero); el elegido se agranda y pinta la pantalla con su arte
  (un **fondo vivo**: se acerca y se aleja muy despacio, se queda un poco atrás al pasar de un juego a otro, y sus
  colores, mezclados con el violeta, tiñen el grafito), con cuándo jugaste y **cuántas horas llevas** (las de Steam y Heroic; en emuladores y PS5 las cuenta Apogeo).
  Arriba, **Inicio** y una pestaña por tienda o plataforma con toda tu biblioteca para **descargar y quitar**.
  - **Inicio con estantes** (↑ ↓): Recientes, Más jugados, Sin empezar y cada una de **tus colecciones** (◆). Al cambiar de
    pestaña o de estante, la cinta y el elegido entran deslizándose.
  - **La ficha de cada juego** (△ / Y, la I o el clic derecho): su arte, lo que llevas jugado (y en las últimas dos semanas,
    con Steam), la última vez, lo que ocupa, **tus capturas** (las de Steam), en qué colecciones está y lo que se puede
    hacer: jugar o descargar, **colecciones** (las tuyas con ✓ y, para empezar, Favoritos, Con amigos, Pendientes y
    Cortos), los FPS, abrir su carpeta, su página en la tienda y quitarlo (`~/.config/apogeo/colecciones.json`).
  - **Orden** (☰ / O): recientes, nombre, horas jugadas o tamaño. **Buscar escribiendo:** F o / y escribe (Esc lo borra).
  - **Sonidos y tacto:** sonidos cortos al moverte, cambiar de pestaña, elegir, abrir la ficha y volver
    (`apogeo-consola-*` en el tema de sonidos de Apogeo, `herramientas/sonidos.py`); el mando vibra un poco al jugar o
    descargar. Las portadas se acercan y les pasa un brillo al pasar el ratón.
  Las pestañas:
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
  - **Herramientas («H1»):** la última pestaña, con lo que se usa jugando: Discord, Spotify, OBS, Mission Center,
    CoolerControl, ProtonPlus e Hydra (las que no tengas salen apagadas) y **FPS en pantalla** (MangoHud a la vista o
    escondido: lo apunta `fpsVisibles` y añade `no_display` a su configuración).
  - **Botón PS («H2»):** en el centro rápido, la tarjeta Herramientas: FPS a la vista o escondidos, OBS y «+» (abre la
    pestaña Herramientas).
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

Al entrar por primera vez sale una tarjeta de cristal en el centro, **sobre la Tierra vista desde la Luna («B1»**, la de la
pantalla de arranque, que se acerca muy despacio), con los pasos: tu nombre y tu foto (para el inicio de sesión y el
bloqueo), instalar Ágape con tu llave, traer tu copia de Ágape (`.agape`, la contraseña la pide Ágape), los tres modos
(cada uno con su color) y el orbe. Todo se puede saltar; si se cierra sin terminar vuelve en el
siguiente inicio, hasta acabarla o pulsar «No volver a mostrar». Se abre de nuevo desde la Órbita («Bienvenida»).

## Ajustes

«Ajustes de Apogeo» es como «Personalizar» de Ágape: el buscador y las secciones a la izquierda y las tarjetas a la
derecha. Modos (el fondo, los avisos, la energía y las apps de cada uno; animar los fondos; no molestar), Orbe (que se
esconda solo), Salud del PC (temperatura máxima de 70 a 85 °C y FPS de los juegos: 30, 45 o 60),
Ágape (la llave, llevar o traer la copia, la bienvenida), Tu perfil y Actualizaciones. La red, el sonido, la pantalla…
abren los Ajustes de KDE. Lo que cambias se guarda en `~/.config/apogeo/ajustes.json` y `apogeo-pisos` lo aplica al
momento.

Lo de un momento (Wi-Fi, bluetooth, silencio, volumen, brillo, luz nocturna, no molestar y apagar) está en la
**tarjeta rápida** de debajo de la hora (Meta+N).

## Fondos

Cada modo con el suyo; el animado de siempre es el de por defecto. Se cambian en Ajustes → Fondos, con Aura o con el botón
derecho en el escritorio: sale un carrusel y el fondo se ve al momento, con «Cancelar» para volver al de antes y «Aura…»
para buscar más.

- **Animados de Apogeo:** los tres de Órbita (Órbitas, Nebulosa y Aurora). Se dibujan a un tercio de la resolución y a 30 imágenes por segundo como
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
  encogiéndose; al minimizar, la lámpara mágica de KWin las lleva a su icono de la barra de arriba. KWin no anima nada sin
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

## La tarjeta rápida

El escritorio está limpio: solo el fondo (con el botón derecho, el carrusel de fondos). Lo de un momento va en la
**tarjeta rápida** (`org.apogeo.rapido`, `Tarjeta.qml`): un clic en la hora de la barra de arriba (o Meta+N, el atajo
de ese widget) y cuelga debajo, flotando sobre las ventanas sin moverlas. Se va al pulsar fuera, con Esc o con otro
clic. Lleva solo:
- el **Wi-Fi** (sin tarjeta de Wi-Fi, el cable; entonces abre los ajustes de la red), el **bluetooth** y el
  **silencio**, en botones redondos con su nombre;
- el **volumen** y el **brillo** en barras que se arrastran, se pulsan o van con la rueda (el brillo, si la pantalla
  deja);
- **luz nocturna** y **no molestar**;
- abajo, **Bloquear**, **Reposo**, **Salir**, **Reiniciar** y **Apagar**: los dos primeros al momento; los otros tres
  piden un segundo toque (el botón se pone rojo, «¿Seguro?», y a los 3 s se olvida). Van directos, sin la pantalla de
  apagar (`org.kde.Shutdown`: KDE cierra tus apps bien).

La música, los avisos, la agenda y el tiempo están en la Órbita. Al abrir la tarjeta, los avisos cuentan como vistos.
Es una ventana de Plasma sin marco con «Cristal con tu fondo» detrás (en Órbita, más oscuro). Lo de los botones lo lee
y lo cambia `apogeo-ajustes rapido`, solo con la tarjeta abierta. (Antes había un panel rápido a la derecha,
`org.apogeo.derecho`: `apogeo-pisos` lo quita y suelta su atajo.)

El widget del escritorio es `org.apogeo.escritorio`:
- Se dibuja siempre del tamaño de la pantalla, aunque Plasma lo estreche al quedarse fijos el orbe o un panel.
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
- **Pantalla de apagar («A1 · Tierra y botones»):** la Tierra desenfocada detrás, el Núcleo latiendo, «¿Hasta luego,
  (tu nombre)?», desde cuándo está encendido y tres botones grandes (Apagar, Reiniciar, Reposo; el elegido, en blanco);
  debajo, Ir a Windows (si hay Windows escondido), Cerrar sesión y Bloquear. Con el teclado: ← → elegir, ↑ ↓ cambiar de
  fila, Intro. Cuántas apps se cierran (Ágape guarda sus pestañas) y **«Actualizar al apagar»** si hay actualizaciones (las instala el
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

## El disco de los juegos y la IA

`sudo apogeo-disco-juegos` formatea el SSD con la etiqueta «JUEGOS» y lo deja en dos partes: **JUEGOSyIA** (ext4, el 70 %,
en `/mnt/JUEGOSyIA`: `Juegos/Steam`, `Juegos/Heroic` y `ModelosIA`) y **JUEGOSWin** (NTFS, el 30 %, en
`/mnt/JuegosWindows`: `Juegos`, para el Windows escondido). ext4 para lo de Apogeo porque los juegos de Steam con Proton
fallan en NTFS dentro de Linux; NTFS para lo que tiene que ver Windows. Se montan solos al encender (`/etc/fstab`, con la
copia de antes en `/etc/fstab.antes-de-JUEGOSyIA`). Lo conecta: apologIA guarda sus modelos en `ModelosIA` (los que
tuvieras se mueven) y Heroic instala en `Juegos/Heroic`; a Steam se le añade a mano (Almacenamiento → Añadir unidad →
Hacer predeterminada). **Borra todo lo del SSD:** solo sigue si el disco no tiene nada más que esa partición (ni el
sistema ni Windows) y después de escribir BORRAR. `--reparto` cambia el 70 %.

## Sonido

- **La mejor calidad** (`/etc/pipewire/*.conf.d/50-apogeo-calidad.conf`): si suena una sola cosa, la tarjeta se pone a su
  frecuencia (44,1 kHz la música, 48 kHz juegos y vídeos, 96 o 192 kHz lo de alta resolución) en vez de convertirlo todo
  a 48 kHz; lo que hay que convertir, con la máxima calidad (`resample.quality = 10`) en todas las apps.
- **Por tus auriculares** (`/etc/wireplumber/wireplumber.conf.d/50-apogeo-auriculares.conf`): la salida analógica (la
  clavija de 3,5 mm) va antes que la HDMI o DisplayPort de la pantalla; al enchufar los auriculares el sonido pasa a ellos
  solo, y las apps siguen a la salida que está puesta (no se quedan en la de la última vez). Una vez, al entrar
  (`audio_setup` de `apogeo-pisos`), la analógica se pone de serie por si quedó la de la pantalla.
- **Spotify** a su mejor calidad sin Premium (Alta, 160 kbps) y sin igualar el volumen (lo comprime). Se pone una vez, con
  Spotify cerrado (si está abierto, la próxima vez que entres).

## Optimización

- **Planificador de CachyOS para escritorio y juegos** (sched_ext `scx_lavd` en modo Auto, con `scx_loader`): responde
  antes y ahorra energía en reposo; si falla, vuelve solo al de siempre.
- **Caché de paquetes** limpia cada semana (`paccache`: las 2 últimas versiones).
- **El índice de los manuales** (man-db) con la prioridad más baja: ya no compite con el escritorio al arrancar.
- **Fuera de en medio** el menú global y el ayudante de accesibilidad (no se usan). KDE Connect se queda instalado
  (solo lo puede quitar tú).
- **La consola de Jugar duerme** sin estar delante: deja de mirar tus juegos cada 20 segundos y suelta las imágenes; el
  arte se carga al tamaño de la pantalla. Ya no se cierra sola (antes, tras media hora fuera de Jugar, y al volver
  tardaba en abrirse): así Jugar sale al instante.
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
sesión, que no falten archivos y, en tu sesión, los modos, el orbe, los paneles de los lados, el fondo, los scripts de KWin,
el estilo y la música. Solo avisa si ha arreglado algo o si algo no ha podido arreglarlo.

## Instalador (el USB)

El USB de Apogeo está en la versión [«iso»](https://github.com/4R3S10/apogeo/releases/tag/iso) (`apogeo.iso` y su suma
SHA-256). Se graba en un USB (Impression, Ventoy o `dd`), se arranca el PC desde él (UEFI) y se abre solo el instalador:
una tarjeta de Órbita con cuatro pasos.

1. **Hola:** comprueba internet (y te deja elegir una Wi-Fi). Hace falta: Apogeo y Windows se descargan al instalar.
2. **Tú:** tu nombre, tu usuario y tu contraseña (la de entrar y, de reserva, la del disco).
3. **Dónde va:** el disco entero (se borra; hay que confirmarlo) para Apogeo y, si lo dejas puesto, el Windows escondido
   (200 GB).
4. **Instalando:** el progreso por fases; al acabar, reiniciar.

Lo que hace por dentro (`instalador/motor.py`, como root, con lo elegido por su entrada; la contraseña no se escribe en
ningún archivo):

- **Disco:** GPT con EFI (4 GB) | Windows (200 GB, NTFS) | Apogeo cifrado (LUKS2) con btrfs (`@`, `@home`, `@root`,
  `@srv`, `@cache`, `@tmp`, `@log`).
- **Cifrado:** se abre solo con el chip de seguridad del PC (TPM 2.0, PCR 7, `systemd-cryptenroll`): solo escribes tu
  contraseña al entrar. Si el TPM no la da (cambias de placa…), pide tu contraseña de Apogeo.
- **Apogeo:** `pacstrap` desde los repositorios de CachyOS (v3 si el procesador puede) y `[apogeo]`, español, Limine,
  los controladores con `chwd`, sin SSH.
- **Windows** (`instalador/windows.py`): la imagen oficial en español se descarga de Microsoft (el catálogo de la
  herramienta de creación de medios, con su suma comprobada). La edición sale de la clave que trae el PC (la tabla MSDM
  del firmware): Home, Home Single Language o Pro, para que se active sola. Se copia con `wimlib` en su partición y un
  WinPE de un solo uso pone sus archivos de arranque (`bcdboot`) y se borra. En su primer arranque Apogeo le pone a
  Windows su entrada del firmware y reinicia en él: Windows te pide tu cuenta de Microsoft y, al entrar, vuelve a
  poner Apogeo el primero e instala el puente de Apogeo (sin cifrado de dispositivo, reloj en UTC).

Construirlo: `instalador/construir-iso.sh <paquete apogeo-*.pkg.tar.zst> [salida]` (en Arch, como root, con archiso).
Lo hace `.github/workflows/iso.yml` al cambiar el instalador o al publicarse un paquete nuevo. Para ver cómo queda sin
instalar nada: `APOGEO_PRUEBA=1 instalador/apogeo-instalador`.

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
- `sistema/usr/lib/apogeo/apogeo-ajustes` y `sistema/usr/share/apogeo/ajustes/`: los ajustes (y lo de la tarjeta
  rápida, `org.apogeo.rapido`)
- `sistema/usr/lib/apogeo/apogeo_comun.py` y `apogeo_qt.py`: lo que comparten (tus ajustes, tu cuenta, Ágape)
- `sistema/usr/lib/qt6/qml/Apogeo/`: las piezas comunes en QML (botones, campos, interruptores, fondos, el Núcleo…)
- `instalador/`: el USB (el perfil de archiso, el instalador y el motor)
- `apogeo.asc`: la clave pública con la que se firman los paquetes
