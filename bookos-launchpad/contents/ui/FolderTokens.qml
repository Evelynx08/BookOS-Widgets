/*
    BookOS Launchpad — FolderTokens.qml

    Única fuente de los valores de diseño de las carpetas. Copiados literalmente
    de BookOS-HIG/AI-DESIGN-SYSTEM.md para no repartir números sueltos por el
    QML: si la guía cambia, se cambia aquí y ya.

    No es un singleton a propósito: registrarlo exigiría un qmldir en el
    plasmoide y un error ahí impide que Plasma cargue el widget entero. Como
    componente normal, QML lo resuelve por estar en el mismo directorio.

    SPDX-License-Identifier: GPL-2.0+
*/
import QtQuick 2.15

QtObject {
    // ── §2.1 Color ───────────────────────────────────────────────────────
    // Claro
    readonly property color lightCard:    "#ffffff"
    readonly property color lightText:    "#000000"
    readonly property color lightAccent:  "#007aff"
    // Oscuro
    readonly property color darkCard:     "#1c1c1e"
    readonly property color darkText:     "#ffffff"
    readonly property color darkAccent:   "#0a84ff"
    // Idéntico en ambos temas — la guía lo dice explícitamente
    readonly property color text2:        "#8e8e93"

    function card(dark)   { return dark ? darkCard   : lightCard }
    function text(dark)   { return dark ? darkText   : lightText }
    function accent(dark) { return dark ? darkAccent : lightAccent }
    // --divider
    function divider(dark) {
        return dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
    }
    // borde de popover: 1px al 9% de --text
    function popoverBorder(dark) {
        return dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.09)
    }
    // --hover
    function hover(dark) {
        return dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)
    }

    // ── §2.3 Radios (tabla cerrada) ──────────────────────────────────────
    readonly property int radiusDialog:   26
    readonly property int radiusControl:  14
    readonly property int radiusPopover:  18
    readonly property int radiusPopItem:  13
    readonly property int radiusButton:   12
    readonly property int radiusSmallBtn: 10
    readonly property int radiusChip:      6
    readonly property int radiusPill:    999

    // ── §2.7 Movimiento ──────────────────────────────────────────────────
    readonly property int durHover:    120
    readonly property int durPopover:  180
    readonly property int durCard:     220
    readonly property int durModal:    250
    readonly property int durPage:     280

    // Las cuatro curvas de la guía, como bezier — no los Easing.* de Qt, que
    // no son las mismas curvas.
    readonly property var curveStandard:   [0.4,  0.0,  0.2,  1.0, 1, 1]
    readonly property var curveEaseOutSoft:[0.25, 0.46, 0.45, 0.94, 1, 1]
    readonly property var curveSpringPop:  [0.34, 1.4,  0.64, 1.0, 1, 1]
    readonly property var curvePopover:    [0.32, 1.3,  0.5,  1.0, 1, 1]

    // ── §2.6 Blur / scrim — solo en overlays temporales ──────────────────
    readonly property color scrimDialog: Qt.rgba(0, 0, 0, 0.45)
    readonly property int   blurDialog:  6

    // ── §2.5 Sombras ─────────────────────────────────────────────────────
    // En tema oscuro las tarjetas NO llevan sombra (checklist de la guía).
    readonly property color shadowPopover: Qt.rgba(0, 0, 0, 0.18)
    readonly property int   shadowPopoverBlur: 22
    readonly property int   shadowPopoverY:     6
}
