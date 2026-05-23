# BookOS Widgets

Pack de widgets para KDE Plasma 6 con identidad visual BookOS.

## Contenido

| Archivo | Widget | Versión | Autor |
|---|---|---|---|
| `com.mi.widget.bateria.plasmoid` | Mi Batería Minimalista | 2.1 | Evelyn (BookOS) |
| `com.bookos.bookbar.plasmoid` | Book Bar — dynamic island | 1.0 | Evelyn (BookOS) |
| `com.bookos.launchpad.plasmoid` | BookOS Launchpad — app grid | 1.0.0 | BookOS |
| `com.bookos.win11menu.plasmoid` | BookOS Win11 Menu | 1.0.0 | BookOS |
| `KdeControlStation.plasmoid` | KDE Control Station | 2.13.0 | Eliver Lara (incluido) |
| `bateria_macx.plasmoid` | Mi Batería (v1.2 legacy) | 1.2 | Evelyn |

## Instalación

### Opción 1 — Drag & drop (recomendada)
1. Clic derecho en el escritorio → **Añadir widgets**
2. Botón **Obtener nuevos widgets** → **Instalar desde archivo local**
3. Selecciona el `.plasmoid` que quieras

### Opción 2 — CLI
```bash
kpackagetool6 -t Plasma/Applet -i nombre-del-widget.plasmoid
```
Para reinstalar uno existente, usa `-u` en vez de `-i`.

### Opción 3 — Manual
```bash
mkdir -p ~/.local/share/plasma/plasmoids/com.bookos.bookbar
unzip com.bookos.bookbar.plasmoid -d ~/.local/share/plasma/plasmoids/com.bookos.bookbar/
kquitapp6 plasmashell && kstart plasmashell
```

## Identidad visual BookOS

Todos los widgets propios siguen la paleta:

- **Dark**: `#000` bg, `#1c1c1e` card, `#fff` tx, `#8e8e93` tx2
- **Light**: `#f2f2f7` bg, `#fff` card, `#000` tx, `#8e8e93` tx2
- **Acentos**: blue `#0A84FF/#007AFF`, green `#30D158/#34C759`, red `#FF453A/#FF3B30`, yellow `#FFD60A/#FFCC00`
- Radius cards 22px · items 18px · pills full-round
- Tipografía sans-serif, headers 22-28px peso 700 letter-spacing -0.4
- Hairlines 1px rgba 0.08

## Requisitos

- KDE Plasma 6.0+
- Qt 6 (incluye QtQuick.Effects, Qt5Compat.GraphicalEffects)
- Para Book Bar: `org.kde.plasma.private.mpris` (incluido en Plasma)
- Para batería: lectura de `/sys/class/power_supply/BAT*`

## Licencias

- Widgets propios: GPL-2.0-or-later
- KdeControlStation: ver `metadata.json` del paquete (Eliver Lara)
