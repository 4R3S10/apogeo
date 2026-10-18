# Apogeo: en la terminal, el prompt de píldoras (Starship) y, en Ghostty, el logo de verdad (imagen) con fastfetch.
# Si tienes tu propio ~/.config/starship.toml o ~/.config/fastfetch/config.jsonc, se usan los tuyos.
status is-interactive; or return
if not set -q STARSHIP_CONFIG; and not test -e ~/.config/starship.toml
    set -gx STARSHIP_CONFIG /usr/share/apogeo/terminal/starship.toml
end
type -q starship; and starship init fish | source

function fastfetch --wraps fastfetch --description 'fastfetch con el logo de Apogeo'
    if test "$TERM" = xterm-ghostty; and not test -e ~/.config/fastfetch/config.jsonc; and not contains -- --config $argv; and not contains -- -c $argv
        command fastfetch --config /usr/share/apogeo/terminal/fastfetch-imagen.jsonc $argv
    else
        command fastfetch $argv
    end
end
