# Apogeo

Sistema operativo personal basado en Linux ([Bazzite](https://bazzite.gg), Fedora Atomic), con Ágape como navegador y un
escritorio propio organizado por **Modos** (Jugar, Navegar, Estudiar, Relax).

- **Juegos:** Steam oficial con Proton, Epic (lanzador oficial con Proton y Heroic) y los juegos con anticheat de Windows
  (Valorant, EA FC…) mediante un Windows escondido: se pulsa Jugar en Apogeo, el equipo se reinicia en Windows con el
  juego y al cerrarlo vuelve a Apogeo.
- **Actualizaciones:** GitHub construye la imagen cada día (`ghcr.io/4r3s10/apogeo`); el equipo se actualiza solo y, si
  algo falla, se arranca la versión anterior.

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
