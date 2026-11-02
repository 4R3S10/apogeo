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
