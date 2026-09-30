#!/usr/bin/python3
"""
Tema de Kvantum «Apogeo»: las apps (Dolphin, Ajustes, Konsole…) con las formas de Ágape. Botones y campos con el
fondo suave y radio 12-14 (como sus .icon-btn y su barra de direcciones), la selección como la pastilla rosa con el
texto oscuro, pestañas como las suyas, menús y bocadillos como sus tarjetas, casillas e interruptores redondeados en
rosa y barras de desplazamiento finas.

Cada control es un marco de 9 trozos por estado (normal, focused = ratón encima, pressed, toggled, disabled). Los trozos
se dibujan pequeños (F px) y Kvantum los agranda con «frame.expansion» para las esquinas redondeadas.

  kvantum.py [destino]    por defecto /usr/share/Kvantum
"""
import os
import sys

DST = sys.argv[1] if len(sys.argv) > 1 else '/usr/share/Kvantum'
THEME = 'Apogeo'

BG, SURFACE, TEXT, ACCENT, ACCENT_TEXT = '#120d14', '#1e1621', '#f1e6ea', '#e0a9b4', '#2a1c26'


def mix(a, b, t):
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return '#' + ''.join(f'{round(x + (y - x) * t):02x}' for x, y in zip(ca, cb))


CHROME = mix(SURFACE, TEXT, 0.03)
VIEW = mix(BG, SURFACE, 0.55)
HOVER = mix(SURFACE, TEXT, 0.07)
HOVER2 = mix(SURFACE, TEXT, 0.10)
PRESS = mix(SURFACE, TEXT, 0.13)
BORDER = mix(SURFACE, TEXT, 0.10)
MUTED = mix(SURFACE, TEXT, 0.62)
FAINT = mix(SURFACE, TEXT, 0.38)
ACCENT_HI = mix(ACCENT, '#ffffff', 0.28)
DISABLED = mix(SURFACE, TEXT, 0.04)

NONE = None  # sin relleno


class Canvas:
    def __init__(self):
        self.parts = []
        self.x = 0
        self.y = 0
        self.row_h = 0

    def place(self, w, h):
        """Sitio libre en el lienzo (en filas de 1000 px)."""
        if self.x + w > 1000:
            self.x, self.y, self.row_h = 0, self.y + self.row_h + 6, 0
        x, y = self.x, self.y
        self.x += w + 6
        self.row_h = max(self.row_h, h)
        return x, y

    def frame(self, name, F, fill, border=None, border_w=1):
        """El marco de 9 trozos «name-*» (esquinas de radio F) y su interior «name»."""
        x0, y0 = self.place(3 * F + 4, 3 * F + 4)
        R = F
        fa = f'fill="{fill}"' if fill else 'fill="#000" fill-opacity="0"'
        cells = {
            'topleft': (0, 0), 'top': (F + 2, 0), 'topright': (2 * F + 4, 0),
            'left': (0, F + 2), 'right': (2 * F + 4, F + 2),
            'bottomleft': (0, 2 * F + 4), 'bottom': (F + 2, 2 * F + 4), 'bottomright': (2 * F + 4, 2 * F + 4),
        }
        for part, (dx, dy) in cells.items():
            x, y = x0 + dx, y0 + dy
            g = [f'<rect x="{x}" y="{y}" width="{F}" height="{F}" fill="#000" fill-opacity="0"/>']
            if part in ('topleft', 'topright', 'bottomleft', 'bottomright'):
                sx = -1 if 'left' in part else 1
                sy = -1 if 'top' in part else 1
                cx, cy = (x + F if sx < 0 else x), (y + F if sy < 0 else y)   # centro del arco
                sweep = 1 if sx * sy > 0 else 0
                p1 = (cx + sx * R, cy)
                p2 = (cx, cy + sy * R)
                if fill:
                    g.append(f'<path d="M{cx} {cy} L{p1[0]} {p1[1]} A{R} {R} 0 0 {sweep} {p2[0]} {p2[1]} Z" {fa}/>')
                if border:
                    r2 = R - border_w
                    q1 = (cx + sx * r2, cy)
                    q2 = (cx, cy + sy * r2)
                    g.append(f'<path d="M{p1[0]} {p1[1]} A{R} {R} 0 0 {sweep} {p2[0]} {p2[1]} L{q2[0]} {q2[1]} '
                             f'A{r2} {r2} 0 0 {1 - sweep} {q1[0]} {q1[1]} Z" fill="{border}"/>')
            else:
                if fill:
                    g.append(f'<rect x="{x}" y="{y}" width="{F}" height="{F}" {fa}/>')
                if border:
                    bx, by, bw, bh = {
                        'top': (x, y, F, border_w), 'bottom': (x, y + F - border_w, F, border_w),
                        'left': (x, y, border_w, F), 'right': (x + F - border_w, y, border_w, F),
                    }[part]
                    g.append(f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" fill="{border}"/>')
            self.parts.append(f'<g id="{name}-{part}">{"".join(g)}</g>')
        # Interior
        self.parts.append(f'<rect id="{name}" x="{x0 + F + 2}" y="{y0 + F + 2}" width="{F}" height="{F}" {fa}/>')

    def icon(self, name, size, body, color, stroke=1.8, fill='none'):
        x, y = self.place(size, size)
        s = size / 24
        self.parts.append(
            f'<g id="{name}"><rect x="{x}" y="{y}" width="{size}" height="{size}" fill="#000" fill-opacity="0"/>'
            f'<g transform="translate({x} {y}) scale({s})" fill="{fill}" stroke="{color}" stroke-width="{stroke}" '
            f'stroke-linecap="round" stroke-linejoin="round">{body}</g></g>')

    def raw(self, name, w, h, body):
        x, y = self.place(w, h)
        self.parts.append(f'<g id="{name}"><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#000" '
                          f'fill-opacity="0"/><g transform="translate({x} {y})">{body}</g></g>')

    def svg(self):
        h = self.y + self.row_h + 10
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="{h}" viewBox="0 0 1000 {h}">\n'
                + '\n'.join(self.parts) + '\n</svg>\n')


def build_svg():
    c = Canvas()
    F = 4
    # Botones: fondo suave (como los botones de Ágape); activo = la pastilla rosa
    for state, fill in (('normal', HOVER), ('focused', HOVER2), ('pressed', PRESS), ('toggled', ACCENT),
                        ('disabled', DISABLED)):
        c.frame(f'button-{state}', F, fill)
    c.frame('button-toggled-inactive', F, mix(ACCENT, SURFACE, 0.6))
    c.raw('button-default-indicator', 4, 4, '')
    # Botones de herramientas (barras): sin fondo, como los .icon-btn de Ágape
    for state, fill in (('normal', NONE), ('focused', HOVER), ('pressed', PRESS), ('toggled', PRESS),
                        ('disabled', NONE)):
        c.frame(f'tbutton-{state}', F, fill)
    # Campos de texto: como la barra de direcciones de Ágape (fondo suave; al escribir, el borde rosa)
    c.frame('lineedit-normal', F, HOVER)
    c.frame('lineedit-focused', F, HOVER, border=ACCENT, border_w=F / 14)  # se agranda ×3,5 (frame.expansion 28)
    c.frame('lineedit-disabled', F, DISABLED)
    # Listas: al pasar el ratón, el fondo suave; lo elegido, la pastilla rosa
    c.frame('itemview-normal', F, NONE)
    c.frame('itemview-focused', F, HOVER)
    # Elegido con el foco: rosa oscuro con el borde rosa (las carpetas también son rosas y no se pierden)
    c.frame('itemview-pressed', F, mix(ACCENT, SURFACE, 0.62), border=ACCENT, border_w=F / 10)  # ×2,5
    # Elegido pero sin el foco (p. ej. el panel de Lugares): rosa atenuado con el texto claro
    c.frame('itemview-toggled', F, mix(ACCENT, SURFACE, 0.55))
    c.frame('itemview-pressed-inactive', F, mix(ACCENT, SURFACE, 0.6))
    c.frame('itemview-toggled-inactive', F, mix(ACCENT, SURFACE, 0.6))
    # Menús: la tarjeta de Ágape; el elemento bajo el ratón, el fondo suave
    c.frame('menu-normal', 6, CHROME, border=BORDER)
    for state in ('normal',):
        c.frame(f'menuitem-{state}', F, NONE)
    for state in ('focused', 'pressed', 'toggled'):
        c.frame(f'menuitem-{state}', F, HOVER2)
    c.frame('menubar-normal', F, NONE)
    c.frame('menubaritem-normal', F, NONE)
    for state in ('focused', 'pressed', 'toggled'):
        c.frame(f'menubaritem-{state}', F, HOVER)
    # Bocadillos
    c.frame('tooltip-normal', 8, CHROME, border=BORDER)
    # Pestañas: como las de Ágape (la activa, el bloque rosa)
    c.frame('tab-normal', F, NONE)
    c.frame('tab-focused', F, HOVER)
    c.frame('tab-toggled', F, ACCENT)
    c.frame('tab-toggled-inactive', F, mix(ACCENT, SURFACE, 0.6))
    c.frame('tabframe-normal', 8, SURFACE, border=BORDER)
    c.frame('tframe-normal', 8, SURFACE, border=BORDER)
    # Marcos (vistas, grupos)
    c.frame('common-normal', F, NONE, border=BORDER)
    c.frame('group-normal', 8, NONE, border=BORDER)
    c.frame('dock-normal', F, SURFACE)
    c.frame('focus', F, NONE, border=mix(ACCENT, SURFACE, 0.3), border_w=F / 12)  # ×12 (frame 1, expansión 24)
    # Barras de progreso y deslizadores: pastillas; lo lleno, rosa
    c.frame('progress-normal', 3, HOVER2)
    c.frame('progress-pattern-normal', 3, ACCENT)
    c.frame('progress-pattern-normal-inactive', 3, mix(ACCENT, SURFACE, 0.6))
    c.frame('progress-pattern-disabled', 3, FAINT)
    c.frame('slider-normal', 2, HOVER2)
    c.frame('slider-toggled', 2, ACCENT)
    c.frame('slider-disabled', 2, DISABLED)
    for state, fill in (('normal', ACCENT), ('focused', ACCENT_HI), ('pressed', ACCENT_HI), ('disabled', FAINT)):
        c.raw(f'slidercursor-{state}', 18, 18,
              f'<circle cx="9" cy="9" r="8" fill="{fill}"/><circle cx="9" cy="9" r="3" fill="{ACCENT_TEXT}" '
              f'fill-opacity="0.35"/>')
    # Barras de desplazamiento finas (el pulgar de Ágape: 13 %; al pasar, 38 %)
    for state, fill in (('normal', PRESS), ('focused', FAINT), ('pressed', MUTED)):
        c.frame(f'scrollbarslider-{state}', F, fill)
    # Casillas y botones de opción redondeados (marcados, en rosa)
    check = '<path d="M5 12.5l4.5 4.5L19 7.5"/>'
    for kind, rr in (('checkbox', 5), ('radio', 8)):
        for state, edge, fillc in (('normal', FAINT, NONE), ('focused', MUTED, NONE), ('pressed', MUTED, HOVER),
                                   ('disabled', DISABLED, NONE)):
            c.raw(f'{kind}-{state}', 16, 16,
                  f'<rect x="0.75" y="0.75" width="14.5" height="14.5" rx="{rr - 0.75}" '
                  f'fill="{fillc or "none"}" stroke="{edge}" stroke-width="1.5"/>')
        for state, fillc in (('normal', ACCENT), ('focused', ACCENT_HI), ('pressed', ACCENT_HI), ('disabled', FAINT)):
            mark = (f'<g transform="scale({16 / 24})" fill="none" stroke="{ACCENT_TEXT}" stroke-width="2.6" '
                    f'stroke-linecap="round" stroke-linejoin="round">{check}</g>' if kind == 'checkbox'
                    else f'<circle cx="8" cy="8" r="3" fill="{ACCENT_TEXT}"/>')
            c.raw(f'{kind}-checked-{state}', 16, 16,
                  f'<rect x="0" y="0" width="16" height="16" rx="{rr}" fill="{fillc}"/>{mark}')
            if kind == 'checkbox':
                c.raw(f'checkbox-tristate-{state}', 16, 16,
                      f'<rect x="0" y="0" width="16" height="16" rx="{rr}" fill="{fillc}"/>'
                      f'<path d="M4.5 8h7" stroke="{ACCENT_TEXT}" stroke-width="1.8" stroke-linecap="round"/>')
    # Flechas (las de Ágape: chevrons de línea)
    chevrons = {'down': '<path d="M6 9l6 6 6-6"/>', 'up': '<path d="M6 15l6-6 6 6"/>',
                'left': '<path d="M15 18l-6-6 6-6"/>', 'right': '<path d="M9 18l6-6-6-6"/>',
                'plus': '<path d="M12 5v14M5 12h14"/>', 'minus': '<path d="M5 12h14"/>'}
    for d, body in chevrons.items():
        for state, color in (('normal', MUTED), ('focused', TEXT), ('pressed', TEXT), ('toggled', ACCENT_TEXT),
                             ('disabled', FAINT)):
            c.icon(f'arrow-{d}-{state}', 16, body, color, stroke=2)
    # Cerrar pestaña
    for state, color in (('normal', MUTED), ('focused', TEXT), ('pressed', TEXT), ('disabled', FAINT)):
        c.icon(f'tab-close-{state}', 16, '<path d="M17 7L7 17M7 7l10 10"/>', color, stroke=2)
    # Divisores y asas: casi invisibles
    for state in ('normal', 'focused', 'pressed'):
        c.raw(f'splitter-grip-{state}', 2, 24, '')
    c.raw('toolbar-handle', 4, 16, '')
    c.frame('toolbar-normal', F, NONE)
    c.frame('header-normal', F, NONE)
    c.raw('header-separator', 2, 12, f'<rect x="0.5" y="0" width="1" height="12" fill="{BORDER}"/>')
    # Ventana (Kvantum la pinta con window.color)
    c.raw('window-normal', 8, 8, f'<rect width="8" height="8" fill="{SURFACE}"/>')
    c.raw('dialog-normal', 8, 8, f'<rect width="8" height="8" fill="{SURFACE}"/>')
    return c.svg()


KVCONFIG = f"""[%General]
author=Ares
comment=Las apps con la estética de Ágape (Apogeo)
x11drag=menubar_and_primary_toolbar
alt_mnemonic=true
left_tabs=false
attach_active_tab=false
embedded_tabs=false
mirror_doc_tabs=false
group_toolbar_buttons=false
spread_progressbar=true
composite=true
menu_shadow_depth=0
tooltip_shadow_depth=0
spread_menuitems=true
scroll_width=8
splitter_width=1
scroll_arrows=false
scroll_min_extent=48
transient_scrollbar=true
transient_groove=true
slider_width=4
slider_handle_width=18
slider_handle_length=18
check_size=16
textless_progressbar=false
progressbar_thickness=6
menubar_mouse_tracking=true
toolbutton_style=0
click_behavior=0
translucent_windows=false
blurring=false
popup_blurring=false
vertical_spin_indicators=false
fill_rubberband=false
merge_menubar_with_toolbar=true
small_icon_size=16
large_icon_size=32
button_icon_size=16
toolbar_icon_size=18
combo_as_lineedit=false
combo_menu=true
combo_focus_rect=false
groupbox_top_label=true
inline_spin_indicators=true
remove_extra_frames=true
joined_inactive_tabs=false
layout_spacing=4
layout_margin=6
submenu_overlap=0
tooltip_delay=-1
animate_states=true
no_inactiveness=false
no_window_pattern=true
respect_DE=true
scrollable_menu=true
menu_separator_height=7
spin_button_width=24
tree_branch_line=false
dark_titlebar=true
contrasted_icons=false

[GeneralColors]
window.color={SURFACE}
base.color={VIEW}
alt.base.color={mix(VIEW, TEXT, 0.03)}
button.color={HOVER}
light.color={PRESS}
mid.light.color={HOVER2}
dark.color={BG}
mid.color={BORDER}
highlight.color={ACCENT}
inactive.highlight.color={mix(ACCENT, SURFACE, 0.6)}
text.color={TEXT}
window.text.color={TEXT}
button.text.color={TEXT}
disabled.text.color={FAINT}
tooltip.base.color={CHROME}
tooltip.text.color={TEXT}
highlight.text.color={ACCENT_TEXT}
inactive.highlight.text.color={ACCENT_TEXT}
link.color={ACCENT}
link.visited.color={mix(ACCENT, '#9b59b6', 0.5)}
progress.indicator.text.color={ACCENT_TEXT}

[Hacks]
transparent_ktitle_label=true
transparent_dolphin_view=false
transparent_pcmanfm_sidepane=true
transparent_menutitle=true
respect_darkness=true
force_size_grip=false
iconless_pushbutton=false
iconless_menu=false
disabled_icon_opacity=45
normal_default_pushbutton=true
single_top_toolbar=true
tint_on_mouseover=0
transparent_arrow_button=true
no_selection_tint=true
centered_forms=false
kcapacitybar_as_progressbar=true
blur_konsole=false
middle_click_scroll=false
style_vertical_toolbars=false

[PanelButtonCommand]
frame=true
frame.element=button
frame.top=4
frame.bottom=4
frame.left=4
frame.right=4
frame.expansion=24
interior=true
interior.element=button
indicator.size=12
indicator.element=arrow
text.normal.color={TEXT}
text.focus.color={TEXT}
text.press.color={TEXT}
text.toggle.color={ACCENT_TEXT}
text.shadow=0
text.margin=1
text.iconspacing=6
text.margin.top=3
text.margin.bottom=3
text.margin.left=8
text.margin.right=8

[PanelButtonTool]
inherits=PanelButtonCommand
frame.element=tbutton
interior.element=tbutton
text.toggle.color={TEXT}
text.margin.left=6
text.margin.right=6

[ToolbarButton]
inherits=PanelButtonTool

[DockTitle]
inherits=PanelButtonCommand
frame=false
interior=false
text.bold=true

[Dock]
inherits=PanelButtonCommand
frame.element=dock
interior.element=dock
frame.expansion=0

[IndicatorSpinBox]
inherits=PanelButtonTool
indicator.element=arrow
indicator.size=12

[RadioButton]
inherits=PanelButtonCommand
frame=false
interior.element=radio
text.toggle.color={TEXT}

[CheckBox]
inherits=PanelButtonCommand
frame=false
interior.element=checkbox
text.toggle.color={TEXT}

[Focus]
inherits=PanelButtonCommand
frame=true
frame.element=focus
interior=false
frame.top=1
frame.bottom=1
frame.left=1
frame.right=1
frame.expansion=24

[GenericFrame]
inherits=PanelButtonCommand
frame=true
interior=false
frame.element=common
interior.element=common
frame.top=1
frame.bottom=1
frame.left=1
frame.right=1
frame.expansion=0

[LineEdit]
inherits=PanelButtonCommand
frame.element=lineedit
interior.element=lineedit
frame.expansion=28
text.margin.left=8
text.margin.right=8

[DropDownButton]
inherits=PanelButtonCommand
indicator.element=arrow-down

[IndicatorArrow]
indicator.element=arrow
indicator.size=12

[ToolboxTab]
inherits=PanelButtonCommand

[Tab]
inherits=PanelButtonCommand
frame.element=tab
interior.element=tab
frame.expansion=22
text.margin.left=12
text.margin.right=12
text.margin.top=5
text.margin.bottom=5
indicator.element=tab
indicator.size=14
text.toggle.color={ACCENT_TEXT}
text.toggle.bold=true
focusFrame=false

[TabFrame]
inherits=PanelButtonCommand
frame.element=tframe
interior=false
frame.top=8
frame.bottom=8
frame.left=8
frame.right=8
frame.expansion=0

[TabBarFrame]
inherits=GenericFrame
frame=false
interior=false

[TreeExpander]
inherits=PanelButtonCommand
frame=false
interior=false
indicator.size=12
indicator.element=arrow

[HeaderSection]
inherits=PanelButtonCommand
frame.element=header
interior.element=header
frame.expansion=0
text.normal.color={MUTED}
text.focus.color={TEXT}
text.press.color={TEXT}
text.toggle.color={TEXT}
text.margin.left=8
text.margin.right=8

[SizeGrip]
indicator.element=resize-grip

[Toolbar]
inherits=PanelButtonCommand
frame=false
interior=false
frame.element=toolbar
interior.element=toolbar
indicator.element=toolbar
indicator.size=4
text.margin=0
frame.expansion=0

[Slider]
inherits=PanelButtonCommand
frame.element=slider
interior.element=slider
frame.top=2
frame.bottom=2
frame.left=2
frame.right=2
frame.expansion=100

[SliderCursor]
inherits=PanelButtonCommand
frame=false
interior.element=slidercursor

[Progressbar]
inherits=PanelButtonCommand
frame.element=progress
interior.element=progress
frame.top=3
frame.bottom=3
frame.left=3
frame.right=3
frame.expansion=100
text.margin=0
text.bold=true

[ProgressbarContents]
inherits=PanelButtonCommand
frame=true
frame.element=progress-pattern
interior.element=progress-pattern
frame.top=3
frame.bottom=3
frame.left=3
frame.right=3
frame.expansion=100

[ItemView]
inherits=PanelButtonCommand
frame.element=itemview
interior.element=itemview
frame.expansion=20
text.margin.top=1
text.margin.bottom=1
text.margin.left=2
text.margin.right=2
text.normal.color={TEXT}
text.focus.color={TEXT}
text.press.color={TEXT}
text.toggle.color={TEXT}
text.normal.inactive.color={TEXT}
text.toggle.inactive.color={TEXT}
text.press.inactive.color={TEXT}

[Splitter]
indicator.size=2

[Scrollbar]
inherits=PanelButtonCommand
indicator.element=arrow
indicator.size=10

[ScrollbarSlider]
inherits=PanelButtonCommand
frame.element=scrollbarslider
interior=false
frame.top=4
frame.bottom=4
frame.left=4
frame.right=4
frame.expansion=100

[ScrollbarGroove]
inherits=PanelButtonCommand
frame=false
interior=false

[MenuItem]
inherits=PanelButtonCommand
frame.element=menuitem
interior.element=menuitem
indicator.element=arrow
frame.expansion=20
text.normal.color={TEXT}
text.focus.color={TEXT}
text.press.color={TEXT}
text.toggle.color={TEXT}
text.margin.top=2
text.margin.bottom=2
text.margin.left=4
text.margin.right=4
text.iconspacing=8

[MenuBar]
inherits=PanelButtonCommand
frame=false
interior=false
frame.element=menubar
interior.element=menubar
frame.expansion=0

[MenuBarItem]
inherits=PanelButtonCommand
interior=false
frame.element=menubaritem
frame.expansion=20
text.margin.left=8
text.margin.right=8

[TitleBar]
inherits=PanelButtonCommand
frame=false
interior=false
text.bold=true

[ComboBox]
inherits=PanelButtonCommand
indicator.element=arrow-down

[Menu]
inherits=PanelButtonCommand
frame.element=menu
interior.element=menu
frame.top=6
frame.bottom=6
frame.left=6
frame.right=6
frame.expansion=0
text.normal.color={TEXT}

[GroupBox]
inherits=GenericFrame
frame=true
frame.element=group
frame.top=8
frame.bottom=8
frame.left=8
frame.right=8
text.bold=true
text.normal.color={MUTED}

[ToolTip]
inherits=GenericFrame
frame.element=tooltip
interior=true
interior.element=tooltip
frame.top=8
frame.bottom=8
frame.left=8
frame.right=8
text.normal.color={TEXT}

[StatusBar]
inherits=GenericFrame
frame=false
interior=false

[Window]
interior=false
"""


def main():
    d = os.path.join(DST, THEME)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, f'{THEME}.kvconfig'), 'w') as f:
        f.write(KVCONFIG)
    with open(os.path.join(d, f'{THEME}.svg'), 'w') as f:
        f.write(build_svg())
    print('Kvantum: tema', THEME)


if __name__ == '__main__':
    main()
