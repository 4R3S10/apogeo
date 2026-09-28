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
