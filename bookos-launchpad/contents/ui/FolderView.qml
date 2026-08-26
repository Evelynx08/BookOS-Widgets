/*
    BookOS Launchpad — FolderView.qml
    Overlay que muestra el contenido de una carpeta.

    Diseño según BookOS-HIG/AI-DESIGN-SYSTEM.md:
      §2.3 radios de la tabla cerrada     §2.5 sombras (ninguna en oscuro)
      §2.6 blur solo en overlay temporal  §2.7 solo transform/opacity
      §4   patrón de popover y de diálogo

    SPDX-License-Identifier: GPL-2.0+
*/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: folderView

    FolderTokens { id: tokens }

    // ── public api (sin cambios: DashboardRepresentation depende de ella) ──
    property var    folderApps: []
    property string folderName: ""
    property int    folderIdx:  -1
    property string folderColor: "#3F51B5"

    property int    iconSize:   64
    property int    cellWidth:  100
    property int    cellHeight: 120
    property bool   showLabel:  true
    property color  fgColor:    "#FFFFFF"
    property color  bgColor:    "#1A1A1AE6"
    property bool   darkTheme:  true

    // Colores sugeridos a partir del fondo de pantalla; los rellena quien nos usa.
    property var    suggestedColors: []

    // Fondo de la tarjeta: el color de la carpeta al 80% mezclado sobre el
    // fondo del tema. Mezclado, no superpuesto con opacidad: así la tarjeta
    // sigue siendo opaca y no se transparentan los iconos de detrás.
    // La tarjeta abierta lleva más color que el tile de la rejilla: al abrirla
    // se entra "dentro" de la carpeta y el color manda.
    readonly property real tintStrength: 0.70
    // folderColor es `string` (la API pública no se toca): en string no hay .r,
    // .g ni .b, así que hay que pasar por un color de verdad antes de mezclar.
    readonly property color folderColorRgb: folderColor
    // Un punto más oscura que el tile: la carpeta abierta se asienta sobre el
    // scrim y con el mismo tono se veía plana al lado del tile de la rejilla.
    readonly property real tintDarken: 0.10
    readonly property color tintedCard: {
        var c = folderColorRgb
        var base = tokens.card(darkTheme)
        var t = tintStrength
        var d = 1 - tintDarken
        return Qt.rgba((c.r * t + base.r * (1 - t)) * d,
                       (c.g * t + base.g * (1 - t)) * d,
                       (c.b * t + base.b * (1 - t)) * d, 1)
    }

    // El texto no puede seguir el tema: sobre una tarjeta oscura va blanco y
    // sobre una clara, negro. Luminancia perceptual del color YA mezclado, la
    // misma fórmula que usa el dashboard.
    readonly property real _tintLum: 0.299 * tintedCard.r
                                   + 0.587 * tintedCard.g
                                   + 0.114 * tintedCard.b
    readonly property bool tintIsDark: _tintLum < 0.55
    readonly property color onTint: tintIsDark ? "#ffffff" : "#000000"
    function onTintAlpha(a) {
        return Qt.rgba(onTint.r, onTint.g, onTint.b, a)
    }

    signal appLaunched()
    signal renamed(int folderIdx, string newName)
    signal colorChanged(int folderIdx, string newColor)
    // Arrastrando una app fuera de la tarjeta: la tarjeta se esconde, pero el
    // overlay sigue vivo para no perder el agarre del ratón.
    property bool draggingOut: false

    signal innerDragStart(int memberIdx, string appName, var iconSrc)
    signal innerDragMove(real x, real y)
    signal innerDragEnd(real x, real y)
    // El ratón se perdió a mitad de arrastre (la ventana perdió el foco, otro
    // item robó el grab…). Sin esto el fantasma se quedaba pegado en pantalla.
    signal innerDragCancel()
    signal innerReorder(int from, int to)

    property alias card: card

    function computeInnerHoverIdx(x, y) {
        if (!appGridContainer) return -1
        var p = mapToItem(appGridContainer, x, y)
        if (p.x < 0 || p.y < 0
            || p.x > appGridContainer.width
            || p.y > appGridContainer.height) return -1
        var col = Math.floor(p.x / cellWidth)
        var row = Math.floor(p.y / cellHeight)
        if (col < 0 || col >= cardCols) return -1
        var idx = row * cardCols + col
        if (idx < 0) return -1
        if (idx > folderApps.length) idx = folderApps.length
        return idx
    }

    property var appGridContainer: null

    // ── estado ────────────────────────────────────────────────────────────
    visible: false
    anchors.fill: parent
    z: 500

    // El tamaño grande vive en el tile de la rejilla (2×2), no aquí: la tarjeta
    // abierta tiene un único tamaño, derivado de su contenido.
    readonly property int baseCols: 4
    property int cardCols: Math.min(baseCols, Math.max(1, folderApps.length))
    property int cardRows: Math.max(1, Math.ceil(folderApps.length / cardCols))

    // Ancho: el mayor entre la rejilla y lo que pide la cabecera. Sin este
    // máximo, el chip de color se salía y `card { clip: true }` lo cortaba.
    property int cardW: Math.max(cardCols * cellWidth + Kirigami.Units.gridUnit * 4,
                                 headerRow.implicitWidth + Kirigami.Units.largeSpacing * 4)
    // Alto: cabecera + separador + rejilla + márgenes. Nada de holgura fija,
    // que dejaba un hueco muerto debajo de los iconos.
    property int cardH: Kirigami.Units.gridUnit * 2.5
              + 1
              + cardRows * cellHeight
              + Kirigami.Units.largeSpacing * 2
              + Kirigami.Units.largeSpacing * 4

    property real originX: width / 2
    property real originY: height / 2

    function open() {
        colorPopup.close()
        visible = true
        opacity = 0
        card.scale = 0.18
        cardOffset.x = originX - width / 2
        cardOffset.y = originY - height / 2
        openAnim.start()
    }
    function close() {
        colorPopup.close()
        draggingOut = false
        closeAnim.start()
    }

    // Esc cierra: primero el selector de color, luego la carpeta. Sin esto, el
    // selector solo se cerraba eligiendo un color — no se podía salir sin cambiarlo.
    Keys.onEscapePressed: function(event) {
        if (colorPopup.visible) colorPopup.close()
        else folderView.close()
        event.accepted = true
    }
    onVisibleChanged: if (visible) forceActiveFocus()
    focus: true

    // §2.7 aparición de modal: 250ms con la curva spring-pop de la guía.
    ParallelAnimation { id: openAnim
        NumberAnimation { target: folderView; property: "opacity"; from: 0; to: 1
                           duration: tokens.durCard
                           easing.type: Easing.Bezier; easing.bezierCurve: tokens.curveEaseOutSoft }
        NumberAnimation { target: card; property: "scale"; from: 0.18; to: 1
                           duration: tokens.durModal
                           easing.type: Easing.Bezier; easing.bezierCurve: tokens.curveSpringPop }
        NumberAnimation { target: cardOffset; property: "x"; to: 0
                           duration: tokens.durModal
                           easing.type: Easing.Bezier; easing.bezierCurve: tokens.curveEaseOutSoft }
        NumberAnimation { target: cardOffset; property: "y"; to: 0
                           duration: tokens.durModal
                           easing.type: Easing.Bezier; easing.bezierCurve: tokens.curveEaseOutSoft }
    }
    ParallelAnimation { id: closeAnim
        NumberAnimation { target: folderView; property: "opacity"; from: 1; to: 0
                           duration: tokens.durPopover
                           easing.type: Easing.Bezier; easing.bezierCurve: tokens.curveStandard }
        NumberAnimation { target: card; property: "scale"; from: 1; to: 0.18
                           duration: tokens.durPopover
                           easing.type: Easing.Bezier; easing.bezierCurve: tokens.curveStandard }
        NumberAnimation { target: cardOffset; property: "x"
                           to: folderView.originX - folderView.width / 2
                           duration: tokens.durPopover
                           easing.type: Easing.Bezier; easing.bezierCurve: tokens.curveStandard }
        NumberAnimation { target: cardOffset; property: "y"
                           to: folderView.originY - folderView.height / 2
                           duration: tokens.durPopover
                           easing.type: Easing.Bezier; easing.bezierCurve: tokens.curveStandard }
        onFinished: { folderView.visible = false; renameField.visible = false }
    }

    // ── scrim §2.6: overlay temporal, 45% + blur 6px ──────────────────────
    // Se desvanece al sacar un icono: hay que ver la rejilla para soltarlo.
    Rectangle {
        anchors.fill: parent
        color: tokens.scrimDialog
        opacity: folderView.draggingOut ? 0 : 1
        Behavior on opacity {
            NumberAnimation { duration: tokens.durPopover
                              easing.type: Easing.Bezier
                              easing.bezierCurve: tokens.curveStandard }
        }
    }
    MouseArea {
        anchors.fill: parent
        z: -1
        // Consume también el hover: si no, los HoverHandler de la rejilla de
        // fondo siguen encendiéndose y se ve el resaltado a través del scrim.
        hoverEnabled: true
        onClicked: function(mouse) {
            var p = mapToItem(card, mouse.x, mouse.y)
            if (p.x < 0 || p.y < 0 || p.x > card.width || p.y > card.height) {
                folderView.close()
            }
        }
    }

    // ── tarjeta ───────────────────────────────────────────────────────────
    Item {
        id: cardWrap
        anchors.centerIn: parent
        width:  card.width
        height: card.height
        opacity: folderView.draggingOut ? 0 : 1
        Behavior on opacity {
            NumberAnimation { duration: tokens.durPopover
                              easing.type: Easing.Bezier
                              easing.bezierCurve: tokens.curveStandard }
        }

        // Igual que en el dashboard: la tarjeta se escala al abrirse y al
        // cerrarse, y su texto no se re-rasteriza en cada fotograma si la capa
        // está activa. Solo mientras corre la animación.
        layer.enabled: openAnim.running || closeAnim.running

        Rectangle {
            id: card
            width:  folderView.cardW
            height: folderView.cardH
            // §4 popover: radio 18. Fondo opaco: al 93% se transparentaban los
            // iconos de la rejilla de detrás y la tarjeta se leía sucia.
            radius: tokens.radiusPopover
            color: folderView.tintedCard
            border.color: folderView.onTintAlpha(0.14)
            border.width: 1
            clip: true

            transform: Translate { id: cardOffset }

            ColumnLayout {
                anchors.fill:    parent
                anchors.margins: Kirigami.Units.largeSpacing * 2
                spacing:         Kirigami.Units.largeSpacing

                // ── cabecera ─────────────────────────────────────────────
                RowLayout {
                    id: headerRow
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    // Contrapeso del chip de color para que el título quede
                    // centrado respecto a la tarjeta, no al hueco que sobra.
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        width:  Kirigami.Units.gridUnit * 1.6
                        height: 1
                    }

                    Item {
                        Layout.fillWidth: true
                        // El campo de renombrar mide 12 gridUnits SIEMPRE, también
                        // oculto: contarlo aquí hacía que la fila pidiera más ancho
                        // del que tenía la tarjeta y el chip de color quedara cortado.
                        implicitWidth:  (renameField.visible ? renameField.implicitWidth
                                                             : titleLabel.implicitWidth)
                                        + Kirigami.Units.gridUnit
                        implicitHeight: Kirigami.Units.gridUnit * 2.5

                        // §2.2 título de diálogo: 17/Bold centrado
                        Text {
                            id: titleLabel
                            anchors.centerIn: parent
                            visible: !renameField.visible
                            width:   parent.width
                            text:    folderView.folderName || i18n("Folder")
                            color:   folderView.onTint
                            font.pixelSize: 17
                            font.weight:    Font.Bold
                            font.letterSpacing: -0.3
                            elide:               Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        TextField {
                            id: renameField
                            anchors.centerIn: parent
                            visible:        false
                            text:           folderView.folderName
                            color:          folderView.onTint
                            font.pixelSize: 17
                            font.weight:    Font.Bold
                            horizontalAlignment: TextInput.AlignHCenter
                            implicitWidth:  Kirigami.Units.gridUnit * 12
                            background: Rectangle {
                                color:  folderView.onTintAlpha(0.14)
                                radius: tokens.radiusControl
                                border.color: folderView.onTintAlpha(0.22)
                                border.width: 1
                            }
                            onAccepted: commit()
                            onActiveFocusChanged: if (!activeFocus) commit()
                            function commit() {
                                folderView.folderName = text
                                folderView.renamed(folderView.folderIdx, text)
                                visible = false
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onDoubleClicked: {
                                renameField.text = folderView.folderName
                                renameField.visible = true
                                renameField.forceActiveFocus()
                                renameField.selectAll()
                            }
                        }
                    }

                    // Selector de color. Ya no es un círculo del color de la
                    // carpeta: con la tarjeta pintada de ese mismo color el
                    // botón desaparecía. Ahora es un botón con icono.
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        width:  Kirigami.Units.gridUnit * 1.6
                        height: width
                        radius: tokens.radiusPill
                        color:  folderView.onTintAlpha(colorBtnMouse.containsMouse ? 0.22 : 0.14)
                        border.color: folderView.onTintAlpha(0.28)
                        border.width: 1
                        Behavior on color {
                            ColorAnimation { duration: tokens.durHover
                                             easing.type: Easing.Bezier
                                             easing.bezierCurve: tokens.curveStandard }
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width:  Kirigami.Units.iconSizes.small
                            height: width
                            source: "color-management"
                            color:  folderView.onTint
                            isMask: true
                            opacity: 0.9
                        }
                        scale: colorBtnMouse.pressed ? 0.9 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: tokens.durHover
                                              easing.type: Easing.Bezier
                                              easing.bezierCurve: tokens.curveStandard }
                        }
                        MouseArea {
                            id: colorBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: colorPopup.visible ? colorPopup.close()
                                                          : colorPopup.open()
                        }
                    }
                }

                // separador §4: 0.5px --divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin:  Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    height: 1
                    color:  folderView.onTintAlpha(0.18)
                }

                // ── rejilla de apps ──────────────────────────────────────
                Grid {
                    id: appsGrid
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: false
                    columns: folderView.cardCols
                    rowSpacing:    Kirigami.Units.smallSpacing
                    columnSpacing: Kirigami.Units.smallSpacing
                    Component.onCompleted: folderView.appGridContainer = appsGrid

                    Repeater {
                        model: folderView.folderApps.length
                        delegate: Item {
                            id: appCell
                            required property int index
                            width:  folderView.cellWidth
                            height: folderView.cellHeight

                            property var entry: folderView.folderApps[index]
                            property bool dragging: cellMouse.dragMode

                            // Realce al pasar el ratón: hace evidente que el
                            // icono se puede pulsar sin entrar en nada.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing / 2
                                radius: tokens.radiusButton
                                color:  folderView.onTintAlpha(0.14)
                                opacity: cellMouse.containsMouse && !appCell.dragging ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: tokens.durHover
                                                      easing.type: Easing.Bezier
                                                      easing.bezierCurve: tokens.curveStandard }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: Kirigami.Units.smallSpacing
                                opacity: appCell.dragging ? 0.0 : 1.0

                                Kirigami.Icon {
                                    source: appCell.entry ? (appCell.entry.icon || "") : ""
                                    fallback: "application-x-executable"
                                    width:  folderView.iconSize
                                    height: folderView.iconSize
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    roundToIconSize: false
                                    smooth: true
                                    animated: false
                                    scale: cellMouse.pressed && !cellMouse.dragMode ? 0.88 : 1.0
                                    Behavior on scale {
                                        NumberAnimation { duration: tokens.durHover
                                                          easing.type: Easing.Bezier
                                                          easing.bezierCurve: tokens.curveStandard }
                                    }
                                }
                                // §2.2 título de fila: 14/Medium
                                Text {
                                    visible: folderView.showLabel
                                    text:    appCell.entry ? appCell.entry.name : ""
                                    color:   folderView.onTint
                                    font.pixelSize: 14
                                    font.weight:    Font.Medium
                                    elide:               Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    width:               folderView.cellWidth
                                }
                            }

                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                hoverEnabled: true
                                pressAndHoldInterval: 350
                                preventStealing: true

                                property bool dragMode: false
                                property real pressX: 0
                                property real pressY: 0
                                property bool moved: false
                                readonly property real dragThreshold: Kirigami.Units.gridUnit
                                readonly property real clickSlop: Kirigami.Units.gridUnit * 0.45

                                // onReleased pone dragMode a false antes de que llegue
                                // onClicked: sin esta marca, soltar tras arrastrar
                                // lanzaba la app.
                                property bool suppressClick: false

                                function beginDrag(mx, my) {
                                    dragMode = true
                                    suppressClick = true
                                    var p = mapToItem(folderView, mx, my)
                                    folderView.innerDragStart(appCell.index,
                                        appCell.entry ? appCell.entry.name : "",
                                        appCell.entry ? appCell.entry.icon : "")
                                    folderView.innerDragMove(p.x, p.y)
                                }

                                onPressed: mouse => {
                                    pressX = mouse.x
                                    pressY = mouse.y
                                    moved  = false
                                    suppressClick = false
                                }
                                onPressAndHold: mouse => beginDrag(mouse.x, mouse.y)
                                onPositionChanged: mouse => {
                                    // Este MouseArea tiene hoverEnabled, así que aquí
                                    // llegan también los movimientos SIN botón pulsado:
                                    // sin esta guarda, pasar el ratón por encima ya
                                    // arrancaba un arrastre y los iconos desaparecían.
                                    if (!pressed) return
                                    var dx = mouse.x - pressX
                                    var dy = mouse.y - pressY
                                    var dist = Math.sqrt(dx * dx + dy * dy)
                                    if (dist > clickSlop) moved = true
                                    // Igual que en la rejilla: mover el icono arrastra,
                                    // sin tener que acertar con el pulsado largo.
                                    if (!dragMode && dist > dragThreshold) {
                                        beginDrag(mouse.x, mouse.y)
                                    }
                                    if (!dragMode) return
                                    var p = mapToItem(folderView, mouse.x, mouse.y)
                                    folderView.innerDragMove(p.x, p.y)
                                }
                                onReleased: mouse => {
                                    if (dragMode) {
                                        dragMode = false
                                        var p = mapToItem(folderView, mouse.x, mouse.y)
                                        folderView.innerDragEnd(p.x, p.y)
                                    }
                                }
                                onCanceled: {
                                    if (dragMode) {
                                        dragMode = false
                                        folderView.innerDragCancel()
                                    }
                                }
                                onClicked: mouse => {
                                    if (dragMode || suppressClick) return
                                    if (moved) return
                                    if (appCell.entry && appCell.entry.trigger) appCell.entry.trigger()
                                    folderView.close()
                                    folderView.appLaunched()
                                }
                            }
                        }
                    }
                }
            }
        }

        // Sin sombra a propósito. La guía la prohíbe en tema oscuro (§2.5 y el
        // checklist), y en claro la tarjeta ya va sobre un scrim al 45%: una
        // sombra sobre un velo tan oscuro no se distingue. Añadirla costaría un
        // MultiEffect que redibuja la tarjeta entera para nada.
    }

    // ── selector de color ─────────────────────────────────────────────────
    // Se puede cerrar SIN elegir color: pulsando fuera, con Esc, o volviendo a
    // pulsar el botón. Antes solo se cerraba eligiendo uno, así que abrirlo por
    // error obligaba a cambiar el color sí o sí.
    Item {
        id: colorPopup
        // Cuelga de cardWrap, no de card: card recorta (clip) y el selector se
        // veía cortado en cuanto sobresalía del alto de la tarjeta.
        parent: cardWrap
        x: card.x + card.width - width - Kirigami.Units.largeSpacing
        y: card.y + Kirigami.Units.gridUnit * 3.5
        width:  Kirigami.Units.gridUnit * 16
        height: popupCol.implicitHeight + Kirigami.Units.largeSpacing * 2
        visible: false
        z: 100
        opacity: visible ? 1 : 0
        scale:   visible ? 1 : 0.92
        transformOrigin: Item.TopRight
        // §2.7 aparición de popover: 180ms con la curva spring de popover
        Behavior on opacity {
            NumberAnimation { duration: tokens.durPopover
                              easing.type: Easing.Bezier
                              easing.bezierCurve: tokens.curvePopover }
        }
        Behavior on scale {
            NumberAnimation { duration: tokens.durPopover
                              easing.type: Easing.Bezier
                              easing.bezierCurve: tokens.curvePopover }
        }

        function open()  { visible = true  }
        function close() { visible = false }

        Rectangle {
            anchors.fill: parent
            radius: tokens.radiusPopover
            color: tokens.card(folderView.darkTheme)
            border.color: tokens.popoverBorder(folderView.darkTheme)
            border.width: 1
        }

        ColumnLayout {
            id: popupCol
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.largeSpacing * 2
            spacing: Kirigami.Units.smallSpacing

            // §2.2 section header: 12/Medium en --text-2
            Text {
                text: i18n("From your wallpaper")
                visible: folderView.suggestedColors.length > 0
                color: tokens.text2
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            Grid {
                Layout.alignment: Qt.AlignHCenter
                visible: folderView.suggestedColors.length > 0
                columns: 6
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: folderView.suggestedColors
                    delegate: ColorChip {
                        required property string modelData
                        chipColor: modelData
                        selected:  folderView.folderColor.toLowerCase() === modelData.toLowerCase()
                        dark:      folderView.darkTheme
                        onPicked:  folderView.applyColor(modelData)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: folderView.suggestedColors.length > 0
                height: 1
                color:  tokens.divider(folderView.darkTheme)
            }

            // Color a medida: cuadro de saturación/brillo + arcoíris.
            ColorPicker {
                id: colorPicker
                Layout.fillWidth: true
                dark:  folderView.darkTheme
                color: folderView.folderColor
                // Sin cerrar el popover: se arrastra y se ve el cambio en vivo,
                // y solo al soltar se guarda.
                onPicked:    function(c) { folderView.folderColor = c }
                onCommitted: function(c) {
                    folderView.folderColor = c
                    folderView.colorChanged(folderView.folderIdx, String(c))
                }
            }
        }
    }

    // Pulsar en cualquier otro sitio de la tarjeta cierra el selector.
    MouseArea {
        parent: card
        anchors.fill: parent
        z: 50
        enabled: colorPopup.visible
        onClicked: function(mouse) {
            var p = mapToItem(colorPopup, mouse.x, mouse.y)
            if (p.x < 0 || p.y < 0 || p.x > colorPopup.width || p.y > colorPopup.height)
                colorPopup.close()
        }
    }

    function applyColor(c) {
        folderView.folderColor = c
        folderView.colorChanged(folderView.folderIdx, c)
        colorPopup.close()
    }
}
