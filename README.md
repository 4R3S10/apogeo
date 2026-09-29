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

## Aspecto

- **Arranque:** el diamante de Apogeo sobre un brillo berenjena y una barra finita de progreso.
- **Inicio de sesión:** una tarjeta con tu nombre, el piso en el que empiezas y la contraseña (SDDM, tema propio).
- **Isla:** abajo, centrada, se esconde sola y cambia en cada piso (Jugar: temperatura, FPS y escritorio; Navegar:
  ventanas y música; Estudiar: temporizador 25/5 y lo estudiado hoy). El corazón abre el buscador.
- **Ventanas «Fina con pastilla»:** barra ciruela de 24 px con el título en el centro y los tres botones juntos en una
  pastilla a la derecha, del color del piso (apagada en las ventanas de detrás).
- Letra Nunito, iconos Papirus con carpetas rosa, cursor berenjena, sonidos pocos y suaves y teclado EE. UU.
  internacional (ñ con AltGr+n).

## Jugar

- **Consola:** al entrar en el piso Jugar se abre a pantalla completa con todos tus juegos juntos (Steam, Epic y GOG con
  Heroic, Hydra y los de Windows): el último en grande y el resto en fila. Teclado o mando: ← → elegir, Intro jugar,
  Q/E cambiar de tienda, Esc salir.
- **Tiendas:** Steam, Heroic (Epic y GOG), el lanzador oficial de Epic con Proton («Epic Games (oficial)», se instala la
  primera vez) e Hydra (de su GitHub oficial, sin fuentes de descarga añadidas).
- **Juegos de Windows** (Valorant, EA FC…): se abrirán en el Windows escondido; la lista está en
  `~/.config/apogeo/juegos-windows.json`.

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
- `herramientas/`: lo que se genera al construir (cursor, ventanas de cada piso y carpetas rosa)
- `paquetes/apogeo/PKGBUILD`: el paquete de Apogeo (dependencias, servicios y ganchos)
- `paquetes/apogeo-hydra/PKGBUILD`: Hydra Launcher desde su GitHub oficial
- `.github/workflows/paquetes.yml`: construye, firma y publica el repositorio
- `sistema/usr/lib/apogeo/apogeo-pisos`: los pisos (fondo, color, avisos, energía, ventanas y apps de cada uno)
- `sistema/usr/lib/apogeo/apogeo-termico`: la protección de temperatura
- `apogeo.asc`: la clave pública con la que se firman los paquetes
