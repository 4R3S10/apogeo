# Apogeo

Sistema operativo personal basado en Linux ([Bazzite](https://bazzite.gg), Fedora Atomic), con Ágape como navegador y un
escritorio propio organizado por **Modos** (Jugar, Navegar, Estudiar, Relax).

- **Juegos:** Steam oficial con Proton, Epic (lanzador oficial con Proton y Heroic) y los juegos con anticheat de Windows
  (Valorant, EA FC…) mediante un Windows escondido: se pulsa Jugar en Apogeo, el equipo se reinicia en Windows con el
  juego y al cerrarlo vuelve a Apogeo.
- **Actualizaciones:** GitHub construye la imagen cada día (`ghcr.io/4r3s10/apogeo`); el equipo se actualiza solo y, si
  algo falla, se arranca la versión anterior.

## Pisos

El escritorio son tres pisos, uno encima de otro: **Jugar**, **Navegar** y **Estudiar**. Se cambia con la rueda del ratón
sobre la columna de la derecha (o con un clic en su círculo) y las ventanas se deslizan como en un ascensor. Cada piso
guarda sus ventanas y tiene su fondo y su color (el mismo berenjena, más vivo en Jugar y más apagado en Estudiar).

- **Avisos:** solo en Navegar; en Jugar y Estudiar no sale ninguno (se quedan en el historial).
- **Energía:** nunca «rendimiento». Jugar y Navegar en equilibrado, Estudiar en ahorro.
- **La primera vez** que entras en un piso se abren sus apps (Jugar: Steam; Navegar: Ágape o Firefox).

## Aspecto

- **Arranque:** el diamante de Apogeo sobre un brillo berenjena y una barra finita de progreso.
- **Inicio de sesión:** una tarjeta con tu nombre, el piso en el que empiezas y la contraseña (SDDM, tema propio).
- **Isla:** abajo, centrada, se esconde sola y cambia en cada piso (Jugar: temperatura, FPS y escritorio; Navegar:
  ventanas y música; Estudiar: temporizador 25/5 y lo estudiado hoy). El corazón abre el buscador.
- **Ventanas sin barra de título:** al tocar el borde de arriba de una ventana salen, encima de ella, sus botones.
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

Ágape es privado, así que no va dentro de la imagen (que es pública). La primera vez que se abre (o al pulsar un
enlace), Apogeo pide tu token de GitHub de solo lectura, descarga la última versión de tus releases a
`~/Applications/ARES.AppImage` (donde se actualiza sola) y la deja como navegador del sistema.

## Salud del PC

- A partir de 80 °C (procesador o gráfica) Apogeo baja poco a poco la velocidad máxima; por debajo de 72 °C la devuelve.
- Los juegos de Windows (Proton) van a 60 FPS como mucho.

## Pasar un equipo con Bazzite a Apogeo

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/4r3s10/apogeo:latest
systemctl reboot
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/4r3s10/apogeo:latest
systemctl reboot
```

## Estructura

- `recipes/recipe.yml`: la receta (qué se añade sobre Bazzite)
- `files/system/`: archivos que se copian al sistema
- `files/scripts/`: pasos que se ejecutan al construir
- `files/system/usr/libexec/apogeo-pisos`: los pisos (fondo, color, avisos, energía y apps de cada uno)
- `files/system/usr/share/plasma/plasmoids/org.apogeo.pisos`: la columna de pisos
- `files/system/usr/libexec/apogeo-termico`: la protección de temperatura
