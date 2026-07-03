import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
PlasmoidItem {
    id: root

    // ── Estado ────────────────────────────────────────────────────────────
    property int    percentage:       0
    property bool   isCharging:       false
    property bool   isPlugged:        false
    property string powerProfile:     "balanced"
    property string timeRemaining:    ""
    property real   batteryTemp:      -1
    property bool   chargeLimit:      false
    property int    batteryHealth:    -1
    property string powerManager:     "detecting"
    property bool   tlpActive:        false
    property var    btDevices:        []
    property string topProcess:       ""
    property string cpuGovernor:      ""
    property bool   hasPstate:        false
    property bool   hasLpmd:          false
    property string lpmdStatus:       ""    // "active" | "inactive" | ""
    property real   energyRate:       -1    // Vatios consumidos ahora
    property int    chargeCycles:     -1    // Ciclos de carga

    // Notificaciones — anti-repeat
    property int    lastNotifiedPct:  -1
    property bool   lastCharging:     false
    property bool   lastPlugged:      false

    // ── Colores ───────────────────────────────────────────────────────────
    readonly property color txt: Kirigami.Theme.textColor
    readonly property color bg:  Kirigami.Theme.backgroundColor
    readonly property color hi:  Kirigami.Theme.highlightColor

    readonly property color colCharging:    Qt.color(Plasmoid.configuration.chargingColor    || "#34C759")
    readonly property color colCritical:    Qt.color(Plasmoid.configuration.criticalColor    || "#FF3B30")
    readonly property color colPowerSave:   Qt.color(Plasmoid.configuration.powerSaveColor   || "#FFCC00")
    readonly property color colPerformance: Qt.color(Plasmoid.configuration.performanceColor || "#32ADE6")

    readonly property color baseTextColor: {
        let m = Plasmoid.configuration.iconTheme
        if (m === 1) return Qt.color("#000000")
        if (m === 2) return Qt.color("#FFFFFF")
        return txt
    }

    readonly property color stateColor: {
        if (isCharging || isPlugged)        return colCharging
        if (percentage <= 20)               return colCritical
        if (powerProfile === "power-saver") return colPowerSave
        if (powerProfile === "performance") return colPerformance
        return baseTextColor
    }

    readonly property color borderColor: Qt.rgba(baseTextColor.r, baseTextColor.g, baseTextColor.b, 0.48)
    property string customFont:    Plasmoid.configuration.customFont    || ""
    property int percentPosition:  Plasmoid.configuration.percentPosition || 0
    property int cfgW:             Plasmoid.configuration.iconWidth      || 23
    property int cfgH:             Plasmoid.configuration.iconHeight     || 11
    property int popW:             Plasmoid.configuration.popupWidth     || 300
    property int popH:             Plasmoid.configuration.popupHeight    || 0

    Connections {
        target: Plasmoid.configuration
        function onCustomFontChanged()      { root.customFont       = Plasmoid.configuration.customFont || "" }
        function onPercentPositionChanged() { root.percentPosition  = Plasmoid.configuration.percentPosition || 0 }
        function onIconWidthChanged()       { root.cfgW             = Plasmoid.configuration.iconWidth || 23 }
        function onIconHeightChanged()      { root.cfgH             = Plasmoid.configuration.iconHeight || 11 }
        function onPopupWidthChanged()      { root.popW             = Plasmoid.configuration.popupWidth || 300 }
        function onPopupHeightChanged()     { root.popH             = Plasmoid.configuration.popupHeight || 0 }
    }

    preferredRepresentation: Plasmoid.compactRepresentation

    // ── Animación de carga ────────────────────────────────────────────────
    property real chargePulse: 0.0
    SequentialAnimation {
        id: chargeAnim
        running: root.isCharging
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "chargePulse"; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "chargePulse"; to: 0.0; duration: 900; easing.type: Easing.InOutSine }
        onStopped: root.chargePulse = 0.0
    }

    // ── Notificaciones — usando KNotification nativo de KDE ──────────────
    // Esto es instantáneo y se integra perfectamente con el sistema
    function sendNotif(icon, title, body, urgency) {
        if (!Plasmoid.configuration.enableNotifications) return
        // Urgency: 0=low, 1=normal, 2=critical
        let u = urgency || 1
        notifySource.connectSource(
            "notify-send" +
            " -a 'Mi Batería'" +
            " -i '" + icon + "'" +
            " -u " + (u === 2 ? "critical" : u === 0 ? "low" : "normal") +
            " -t " + (u === 2 ? "8000" : "4000") +
            " '" + title + "' '" + body + "'"
        )
    }

    onIsChargingChanged: {
        // Detectar cambio real ignorando el estado inicial
        if (lastCharging === isCharging) return
        if (isCharging && !lastCharging) {
            sendNotif("battery-ac-adapter", "Cargador conectado",
                      "Cargando · " + percentage + "%" +
                      (timeRemaining !== "" ? " · completo en " + timeRemaining : ""), 0)
        } else if (!isCharging && lastCharging && !isPlugged) {
            sendNotif("battery", "Cargador desconectado",
                      percentage + "%" +
                      (timeRemaining !== "" ? " · " + timeRemaining + " restante" : ""), 1)
        }
        lastCharging = isCharging
    }

    onIsPluggedChanged: {
        // Enchufado pero no cargando (batería llena o límite)
        if (isPlugged && !isCharging && lastCharging) {
            sendNotif("battery-full", "Batería completa", "La batería está al " + percentage + "%", 0)
        }
        lastPlugged = isPlugged
    }

    onPercentageChanged: {
        if (percentage === 20 && !isCharging && lastNotifiedPct !== 20)
            sendNotif("battery-low", "Batería baja",
                      "Queda un 20%" + (timeRemaining !== "" ? " · " + timeRemaining + " restante" : " · conecta el cargador"), 1)
        if (percentage === 10 && !isCharging && lastNotifiedPct !== 10)
            sendNotif("battery-caution", "Batería crítica",
                      "Solo queda un 10% · conecta el cargador ahora", 2)
        if (percentage === 100 && isCharging && lastNotifiedPct !== 100)
            sendNotif("battery-full", "Carga completa", "La batería está al 100%", 0)
        lastNotifiedPct = percentage
    }

    // ════════════════════════════════════════════════════════════════════
    // COMPACT — icono del panel
    // ════════════════════════════════════════════════════════════════════
    compactRepresentation: Item {
        Layout.preferredWidth:  compactRow.implicitWidth  + 10
        Layout.preferredHeight: compactRow.implicitHeight + 6
        implicitWidth:  Layout.preferredWidth
        implicitHeight: Layout.preferredHeight

        PlasmaComponents.ToolTip {
            text: {
                let st = root.isCharging ? "Cargando"
                       : root.isPlugged ? "Enchufado"
                       : "Batería"
                let tr = root.timeRemaining !== ""
                       ? "\n" + root.timeRemaining + (root.isCharging ? " para carga completa" : " restante")
                       : ""
                let pr = "\nPerfil: " + profileLabel(root.powerProfile)
                let tp = root.batteryTemp > 0 ? "\nTemp: " + root.batteryTemp.toFixed(1) + " °C" : ""
                let hl = root.batteryHealth > 0 ? "\nSalud: " + root.batteryHealth + "%" : ""
                let cy = root.chargeCycles > 0 ? " · " + root.chargeCycles + " ciclos" : ""
                let wr = root.energyRate > 0 ? "\nConsumo: " + root.energyRate.toFixed(1) + " W" : ""
                return st + " · " + root.percentage + "%" + tr + pr + tp + hl + cy + wr
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: root.expanded = !root.expanded

            RowLayout {
                id: compactRow
                anchors.centerIn: parent
                spacing: 5

                // % IZQUIERDA
                PlasmaComponents.Label {
                    visible: root.percentPosition === 1
                    text: root.percentage + "%"
                    font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family
                    font.weight: Font.Medium; font.pixelSize: 12
                    color: root.baseTextColor; opacity: 0.92
                }

                // Icono batería
                Item {
                    width: root.cfgW + 3; height: root.cfgH

                    Rectangle {
                        id: batteryBody
                        width: root.cfgW; height: root.cfgH
                        radius: Math.max(2, root.cfgH / 4)
                        color: "transparent"
                        border.color: root.borderColor; border.width: 1

                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 1.5 }
                            // El radio interior debe estar limitado por el ancho para no deformarse a baja carga
                            radius: {
                                let w = Math.max(0, (root.cfgW - 3) * (root.percentage / 100))
                                let maxR = Math.max(1, root.cfgH / 8)
                                return Math.min(maxR, w / 2)
                            }
                            width: {
                                let base = Math.max(0, (root.cfgW - 3) * (root.percentage / 100))
                                if (root.isCharging) {
                                    let extra = (root.cfgW - 3) * 0.035 * root.chargePulse
                                    return Math.min(root.cfgW - 3, base + extra)
                                }
                                return base
                            }
                            color: root.stateColor
                            opacity: root.isCharging ? (0.78 + 0.22 * root.chargePulse) : 1.0
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        // Rayo — dibujado con Canvas (estilo SF Symbols, limpio)
                        Canvas {
                            visible: (root.isCharging || root.isPlugged) && root.percentPosition !== 2
                            anchors.centerIn: parent
                            width: Math.max(6, root.cfgH * 0.6)
                            height: Math.max(8, root.cfgH * 0.82)
                            opacity: root.isCharging ? (0.72 + 0.28 * root.chargePulse) : 0.90

                            property color boltColor: root.percentage > 48 ? root.bg : root.stateColor
                            onBoltColorChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.fillStyle = Qt.rgba(boltColor.r, boltColor.g, boltColor.b, 1)
                                // Bolt shape: top-right → mid-left → mid-right → bottom-left
                                var w = width, h = height
                                ctx.beginPath()
                                ctx.moveTo(w * 0.62, 0)
                                ctx.lineTo(w * 0.15, h * 0.52)
                                ctx.lineTo(w * 0.50, h * 0.48)
                                ctx.lineTo(w * 0.38, h)
                                ctx.lineTo(w * 0.85, h * 0.48)
                                ctx.lineTo(w * 0.50, h * 0.52)
                                ctx.closePath()
                                ctx.fill()
                            }
                        }

                        // % dentro
                        PlasmaComponents.Label {
                            visible: root.percentPosition === 2 && root.cfgW >= 28 && !root.isCharging
                            text: root.percentage + "%"
                            anchors.centerIn: parent
                            font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family
                            font.pixelSize: Math.max(6, root.cfgH - 4); font.weight: Font.Bold
                            color: root.percentage > 45 ? root.bg : root.baseTextColor
                        }
                    }

                    // Polo positivo
                    Rectangle {
                        anchors.left: batteryBody.right
                        anchors.verticalCenter: batteryBody.verticalCenter
                        width: 2; height: Math.max(4, root.cfgH / 2.5); radius: 1
                        color: root.borderColor
                    }
                }

                // % DERECHA
                PlasmaComponents.Label {
                    visible: root.percentPosition === 0
                    text: root.percentage + "%"
                    font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family
                    font.weight: Font.Medium; font.pixelSize: 12
                    color: root.baseTextColor; opacity: 0.92
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // FULL REPRESENTATION — popup estilo macOS
    // ════════════════════════════════════════════════════════════════════
    fullRepresentation: Item {
        // popH=0 → altura automática al contenido; >0 → fija
        Layout.minimumWidth:    root.popW
        Layout.preferredWidth:  root.popW
        Layout.maximumWidth:    root.popW
        Layout.minimumHeight:   root.popH > 0 ? root.popH : popupCol.implicitHeight + 28
        Layout.preferredHeight: root.popH > 0 ? root.popH : popupCol.implicitHeight + 28
        Layout.maximumHeight:   root.popH > 0 ? root.popH : popupCol.implicitHeight + 28

        ColumnLayout {
            id: popupCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 0

            // ── 1. Cabecera ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 2

                PlasmaComponents.Label {
                    text: "Batería"
                    font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family
                    font.weight: Font.Bold; font.pixelSize: 15; color: root.txt
                }
                Item { Layout.fillWidth: true }

                // Mini batería + porcentaje en cabecera (como macOS)
                RowLayout {
                    spacing: 5
                    Item {
                        visible: root.isCharging || root.isPlugged
                        width: 20; height: 12
                        Rectangle {
                            width: 18; height: 12; radius: 2; color: "transparent"
                            border.color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.35); border.width: 1
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 1.5 }
                                radius: 1.5
                                width: Math.min(15, 15 * (root.percentage / 100))
                                color: root.colCharging
                                opacity: root.isCharging ? (0.75 + 0.25 * root.chargePulse) : 1.0
                            }
                            Canvas {
                                anchors.centerIn: parent
                                width: 5; height: 7
                                opacity: root.isCharging ? (0.65 + 0.35 * root.chargePulse) : 0.9
                                property color boltColor: root.percentage > 60 ? root.bg : root.colCharging
                                onBoltColorChanged: requestPaint()
                                Component.onCompleted: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.fillStyle = Qt.rgba(boltColor.r, boltColor.g, boltColor.b, 1)
                                    var w = width, h = height
                                    ctx.beginPath()
                                    ctx.moveTo(w*0.62,0); ctx.lineTo(w*0.15,h*0.52)
                                    ctx.lineTo(w*0.50,h*0.48); ctx.lineTo(w*0.38,h)
                                    ctx.lineTo(w*0.85,h*0.48); ctx.lineTo(w*0.50,h*0.52)
                                    ctx.closePath(); ctx.fill()
                                }
                            }
                        }
                        Rectangle {
                            anchors.left: parent.left; anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2; height: 5; radius: 1
                            color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.35)
                        }
                    }
                    PlasmaComponents.Label {
                        text: root.percentage + "%"
                        font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family
                        font.pixelSize: 14; font.weight: Font.Medium
                        color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.55)
                    }
                }
            }

            // ── Fuente + estado detallado ──────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Layout.bottomMargin: 10

                PlasmaComponents.Label {
                    text: "Fuente: " + (root.isCharging || root.isPlugged ? "Adaptador de corriente" : "Batería")
                    font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 12
                    color: root.txt; opacity: 0.65
                }
                PlasmaComponents.Label {
                    visible: root.timeRemaining !== ""
                    text: root.isCharging
                          ? root.timeRemaining + " para carga completa"
                          : root.timeRemaining + " restante"
                    font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 12
                    color: root.txt; opacity: 0.65
                }
                PlasmaComponents.Label {
                    visible: root.isPlugged && !root.isCharging && root.percentage >= 99
                    text: "Completamente cargada"
                    font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 12
                    color: root.txt; opacity: 0.65
                }
                PlasmaComponents.Label {
                    visible: root.isPlugged && !root.isCharging && root.chargeLimit && root.percentage < 99
                    text: "Carga en espera (optimización activa)"
                    font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 12
                    color: root.txt; opacity: 0.65
                }

                // Fila de métricas: temp · vatios · salud · ciclos
                RowLayout {
                    visible: root.batteryTemp > 0 || root.batteryHealth > 0
                            || root.energyRate > 0 || root.chargeCycles > 0
                    spacing: 12; Layout.topMargin: 4

                    // Temperatura
                    RowLayout {
                        visible: root.batteryTemp > 0
                        spacing: 3
                        PlasmaComponents.Label {
                            text: "🌡️ " + root.batteryTemp.toFixed(1) + " °C"
                            font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 12
                            color: root.batteryTemp > 42 ? "#FF3B30" : Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.65)
                        }
                    }

                    // Watts
                    RowLayout {
                        visible: root.energyRate > 0 && !root.isCharging
                        spacing: 3
                        PlasmaComponents.Label {
                            text: "⚡ " + root.energyRate.toFixed(1) + " W"
                            font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 12
                            color: root.energyRate > 25 ? "#FF9500" : Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.65)
                        }
                    }

                    // Salud
                    RowLayout {
                        visible: root.batteryHealth > 0
                        spacing: 3
                        PlasmaComponents.Label {
                            text: {
                                let h = root.batteryHealth
                                let label = h >= 80 ? "🔋 Normal"
                                          : h >= 65 ? "🔋 Servicio"
                                          : "🔋 Reemplazar"
                                return label + " · " + h + "%"
                            }
                            font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 12
                            color: {
                                let h = root.batteryHealth
                                if (h < 65) return "#FF3B30"
                                if (h < 80) return "#FF9500"
                                return root.colCharging
                            }
                        }
                    }

                    // Cycles
                    RowLayout {
                        visible: root.chargeCycles > 0
                        spacing: 3
                        PlasmaComponents.Label {
                            text: "🔄 " + root.chargeCycles + " ciclos"
                            font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 12
                            color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.55)
                        }
                    }
                }

                // CPU governor + intel_pstate / intel_lpmd
                PlasmaComponents.Label {
                    visible: root.cpuGovernor !== ""
                    text: {
                        let gov = root.cpuGovernor
                        let driver = root.hasPstate ? "intel_pstate" : ""
                        let lpmd = root.hasLpmd ? (root.lpmdStatus === "active" ? " · lpmd activo" : " · lpmd inactivo") : ""
                        return "CPU: " + gov + (driver ? " · " + driver : "") + lpmd
                    }
                    font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 11
                    color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.32)
                    Layout.topMargin: 1
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.txt; opacity: 0.1; Layout.bottomMargin: 12 }

            // ── 2. Modo de energía ─────────────────────────────────────────
            PlasmaComponents.Label {
                visible: root.powerManager !== "none" && root.powerManager !== "detecting"
                text: "Modo de energía"
                font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family
                font.weight: Font.DemiBold; font.pixelSize: 13; color: root.txt
                Layout.bottomMargin: 10
            }
            PlasmaComponents.Label {
                visible: root.powerManager === "detecting"
                text: "Detectando gestor…"; font.pixelSize: 12
                color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.38); Layout.bottomMargin: 14
            }
            PlasmaComponents.Label {
                visible: root.powerManager === "none"
                text: "Sin gestor de energía"; font.pixelSize: 12
                color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.38); Layout.bottomMargin: 14
            }

            // ── TLP ───────────────────────────────────────────────────────
            Rectangle {
                visible: root.powerManager === "tlp"
                Layout.fillWidth: true; height: 50; radius: 10; Layout.bottomMargin: 14
                color: Qt.rgba(root.hi.r, root.hi.g, root.hi.b, root.tlpActive ? 0.09 : 0.03)
                border.color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, root.tlpActive ? 0.14 : 0.07)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        PlasmaComponents.Label {
                            text: "TLP"
                            font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family
                            font.weight: Font.DemiBold; font.pixelSize: 13; color: root.txt
                        }
                        PlasmaComponents.Label {
                            text: root.tlpActive ? "Activo · gestión automática" : "Inactivo · sin gestión"
                            font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 11
                            color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.50)
                        }
                    }
                    Rectangle {
                        width: 40; height: 24; radius: 12
                        color: root.tlpActive ? root.colCharging : Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.18)
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Rectangle {
                            width: 18; height: 18; radius: 9; anchors.verticalCenter: parent.verticalCenter
                            x: root.tlpActive ? parent.width - 21 : 3; color: "white"
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { actionSource.connectSource(root.tlpActive ? "pkexec tlp ac" : "pkexec tlp bat"); root.tlpActive = !root.tlpActive }
                }
            }

            // Contenedor principal para los tres modos (Segmented Control)
            Rectangle {
                visible: root.powerManager === "ppd"
                Layout.fillWidth: true; height: 62; radius: 10
                color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.07)
                border.color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.05)
                border.width: 1
                Layout.bottomMargin: 14

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 2

                    Repeater {
                        model: [
                            { id: "power-saver",  label: "Ahorro",      desc: "Máx. duración" },
                            { id: "balanced",     label: "Equilibrado", desc: "Recomendado"   },
                            { id: "performance",  label: "Rendimiento", desc: "Máx. potencia" }
                        ]
                        delegate: Item {
                            Layout.fillWidth: true; Layout.fillHeight: true

                            readonly property bool isActive: root.powerProfile === modelData.id
                            readonly property bool isHov: cm.containsMouse

                            // Sombra sutil debajo del segmento activo
                            Rectangle {
                                anchors { fill: parent; topMargin: 1 }
                                radius: 8
                                visible: isActive
                                color: Qt.rgba(0, 0, 0, 0.12)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            // Fondo del segmento
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: isActive
                                    ? Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.18)
                                    : isHov
                                        ? Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.06)
                                        : "transparent"
                                border.color: isActive ? Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.12) : "transparent"
                                border.width: isActive ? 1 : 0
                                Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: 1

                                    PlasmaComponents.Label {
                                        text: modelData.label
                                        font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family
                                        font.pixelSize: 12
                                        font.weight: isActive ? Font.DemiBold : Font.Normal
                                        color: isActive
                                            ? root.txt
                                            : Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.55)
                                        Layout.alignment: Qt.AlignHCenter
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                    PlasmaComponents.Label {
                                        text: modelData.desc
                                        font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family
                                        font.pixelSize: 10
                                        color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, isActive ? 0.55 : 0.35)
                                        Layout.alignment: Qt.AlignHCenter
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                }
                            }
                            MouseArea {
                                id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.powerProfile = modelData.id
                                    profileSetSource.connectSource("powerprofilesctl set " + modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.txt; opacity: 0.1; Layout.bottomMargin: 8 }

            // ── 3. Dispositivos Bluetooth ─────────────────────────────────
            ColumnLayout {
                visible: root.btDevices.length > 0
                Layout.fillWidth: true; spacing: 2; Layout.bottomMargin: 4

                Repeater {
                    model: root.btDevices
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 32; radius: 6; color: "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 4; anchors.rightMargin: 8
                            spacing: 8
                            PlasmaComponents.Label { text: modelData.icon || "📡"; font.pixelSize: 14 }
                            PlasmaComponents.Label {
                                text: modelData.name
                                font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 13; color: root.txt
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            PlasmaComponents.Label {
                                visible: modelData.pct > 0; text: modelData.pct + "%"
                                font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 12
                                color: modelData.pct <= 20
                                       ? root.colCritical
                                       : Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.55)
                            }
                            Item { visible: modelData.pct > 0; width: 22; height: 11
                                Rectangle { width: 20; height: 11; radius: 2; color: "transparent"
                                    border.color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.35); border.width: 1
                                    Rectangle {
                                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 1.5 }
                                        radius: 1
                                        width: Math.max(0, (20 - 3) * (modelData.pct / 100))
                                        color: modelData.pct <= 20 ? root.colCritical : Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.65)
                                    }
                                }
                                Rectangle {
                                    anchors.left: parent.left; anchors.leftMargin: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 2; height: 5; radius: 1
                                    color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.35)
                                }
                            }
                        }
                    }
                }
            }
            Rectangle { visible: root.btDevices.length > 0; Layout.fillWidth: true; height: 1; color: root.txt; opacity: 0.1; Layout.bottomMargin: 6 }

            // ── 4. App consumidora ────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4; Layout.topMargin: 8; Layout.bottomMargin: 12
                PlasmaComponents.Label {
                    visible: root.topProcess !== "" && !root.topProcess.startsWith("Sin") && !root.topProcess.includes("0% CPU")
                    text: "Usando energía significativa"
                    font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family
                    font.weight: Font.DemiBold; font.pixelSize: 13; color: root.txt
                }
                
                RowLayout {
                    visible: root.topProcess !== "" && !root.topProcess.startsWith("Sin") && !root.topProcess.includes("0% CPU")
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8
                    
                    PlasmaComponents.Label { text: "⚠️"; font.pixelSize: 16 }
                    
                    PlasmaComponents.Label {
                        text: {
                            if (root.topProcess === "" || root.topProcess.startsWith("Sin")) return "";
                            let parts = root.topProcess.split(" (");
                            if (parts.length > 1) {
                                return "<b>" + parts[0] + "</b> (" + parts[1];
                            }
                            return root.topProcess;
                        }
                        textFormat: Text.RichText
                        font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 13
                        color: root.txt
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                    }
                }
                
                PlasmaComponents.Label {
                    visible: root.topProcess === "" || root.topProcess.startsWith("Sin") || root.topProcess.includes("0% CPU")
                    text: "Sin apps usando energía significativa"
                    font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family; font.pixelSize: 12
                    color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.42)
                    Layout.fillWidth: true
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.txt; opacity: 0.1; Layout.bottomMargin: 4 }

            // ── 5. Preferencias ───────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 36; radius: 8
                color: prefMouse.containsMouse
                    ? Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.08)
                    : "transparent"
                Layout.bottomMargin: 4
                Behavior on color { ColorAnimation { duration: 100 } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 12
                    PlasmaComponents.Label {
                        text: "Preferencias de Batería…"
                        font.family: root.customFont !== "" ? root.customFont : Kirigami.Theme.defaultFont.family
                        font.pixelSize: 13; font.weight: Font.Medium; color: root.txt
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: "›"
                        font.pixelSize: 16
                        color: Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.28)
                    }
                }
                MouseArea {
                    id: prefMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.expanded = false; actionSource.connectSource("kcmshell6 powerdevilprofilesconfig") }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // HELPERS
    // ════════════════════════════════════════════════════════════════════
    function profileLabel(p) {
        if (p === "power-saver") return "Ahorro de energía"
        if (p === "performance") return "Rendimiento"
        return "Equilibrado"
    }

    function resolveManager(detected) {
        let f = Plasmoid.configuration.forceManager || 0
        if (f === 1) return "ppd"; if (f === 2) return "tlp"; if (f === 3) return "none"
        return detected
    }

    function btIcon(name) {
        let n = name.toLowerCase()
        if (n.includes("buds") || n.includes("galaxy buds"))    return "🎧"
        if (n.includes("galaxy") || n.includes("samsung"))      return "📱"
        if (n.includes("mouse"))                                 return "🖱️"
        if (n.includes("keyboard") || n.includes("teclado"))    return "⌨️"
        if (n.includes("airpod") || n.includes("headphone") || n.includes("auricular")) return "🎧"
        if (n.includes("speaker") || n.includes("altavoz"))     return "🔊"
        if (n.includes("iphone") || n.includes("android") || n.includes("phone"))       return "📱"
        if (n.includes("watch") || n.includes("band"))          return "⌚"
        if (n.includes("gamepad") || n.includes("controller") || n.includes("dual"))    return "🎮"
        if (n.includes("tablet") || n.includes("ipad"))         return "📟"
        return "📡"
    }

    // ════════════════════════════════════════════════════════════════════
    // FUENTES DE DATOS
    // ════════════════════════════════════════════════════════════════════

    // ── 1. Estado rápido (1.5s) — %, charging, AC online ────────────────
    Plasma5Support.DataSource {
        id: statusSource; engine: "executable"
        connectedSources: [
            "sh -c '" +
            "c=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1); echo ${c:--1}; " +
            "s=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1); echo ${s:-Unknown}; " +
            "o=$(cat /sys/class/power_supply/AC*/online 2>/dev/null | head -n1 || cat /sys/class/power_supply/ADP*/online 2>/dev/null | head -n1); echo ${o:--1}'"
        ]
        interval: 1500
        onNewData: (sourceName, data) => {
            if (!data["stdout"]) return
            let lines = data["stdout"].trim().split('\n')
            if (lines.length >= 1 && !isNaN(parseInt(lines[0])))
                root.percentage = parseInt(lines[0])
            if (lines.length >= 2) {
                let status = lines[1].trim()
                root.isCharging = (status === "Charging")
                root.isPlugged  = (status === "Full" || status === "Not charging" || status === "Charging")
            }
            if (lines.length >= 3 && lines[2].trim() === "1")
                root.isPlugged = true
        }
    }

    // ── 2. Datos de batería lentos (15s) — temp, salud, ciclos, vatios ──
    Plasma5Support.DataSource {
        id: batterySource; engine: "executable"
        connectedSources: [
            "sh -c '" +
            // Temperatura
            "t=$(cat /sys/class/power_supply/BAT*/temp 2>/dev/null | head -n1); echo ${t:--1}; " +
            // Límite de carga
            "l=$(cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -n1); echo ${l:--1}; " +
            // Salud + ciclos + vatios via upower (más preciso)
            "bat=$(upower -e 2>/dev/null | grep -iE \"/battery_\" | head -n1); " +
            "if [ -n \"$bat\" ]; then " +
            "  energy=$(upower -i \"$bat\" 2>/dev/null | grep -i \"energy-full:\" | grep -v design | awk \"{printf \\\"%.4f\\\", \\$2}\"); " +
            "  design=$(upower -i \"$bat\" 2>/dev/null | grep -i \"energy-full-design:\" | awk \"{printf \\\"%.4f\\\", \\$2}\"); " +
            "  rate=$(upower -i \"$bat\" 2>/dev/null | grep -i \"energy-rate:\" | awk \"{printf \\\"%.2f\\\", \\$2}\"); " +
            "  cycles=$(upower -i \"$bat\" 2>/dev/null | grep -i \"charge-cycles:\" | awk \"{print \\$2}\"); " +
            "  [ -n \"$energy\" ] && [ -n \"$design\" ] && awk \"BEGIN{h=int($energy/$design*100+0.5); if(h>100)h=100; print h}\" || echo -1; " +
            "  echo ${rate:--1}; " +
            "  echo ${cycles:--1}; " +
            "else echo -1; echo -1; echo -1; fi'"
        ]
        interval: 15000
        onNewData: (sourceName, data) => {
            if (!data["stdout"]) return
            let lines = data["stdout"].trim().split('\n')
            if (lines.length >= 1 && !isNaN(parseInt(lines[0])) && parseInt(lines[0]) > 0)
                root.batteryTemp = parseInt(lines[0]) / 10.0
            if (lines.length >= 2 && !isNaN(parseInt(lines[1])))
                root.chargeLimit = parseInt(lines[1]) > 0 && parseInt(lines[1]) <= 85
            if (lines.length >= 3 && !isNaN(parseInt(lines[2])) && parseInt(lines[2]) > 0)
                root.batteryHealth = Math.min(100, parseInt(lines[2]))
            if (lines.length >= 4 && !isNaN(parseFloat(lines[3])) && parseFloat(lines[3]) > 0)
                root.energyRate = parseFloat(lines[3])
            if (lines.length >= 5 && !isNaN(parseInt(lines[4])) && parseInt(lines[4]) > 0)
                root.chargeCycles = parseInt(lines[4])
        }
    }

    // ── 3. Gestor de energía (30s) ───────────────────────────────────────
    Plasma5Support.DataSource {
        id: managerDetectSource; engine: "executable"
        connectedSources: [
            "sh -c 'if systemctl is-active --quiet power-profiles-daemon 2>/dev/null; then echo ppd; " +
            "elif systemctl is-active --quiet tlp 2>/dev/null; then echo tlp; " +
            "elif command -v tlp >/dev/null 2>&1; then echo tlp; " +
            "else echo none; fi'"
        ]
        interval: 30000
        onNewData: (sourceName, data) => {
            if (data["stdout"]) root.powerManager = root.resolveManager(data["stdout"].trim() || "none")
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onForceManagerChanged() {
            let f = Plasmoid.configuration.forceManager || 0
            if      (f === 1) root.powerManager = "ppd"
            else if (f === 2) root.powerManager = "tlp"
            else if (f === 3) root.powerManager = "none"
            else {
                managerDetectSource.connectedSources = []
                managerDetectSource.connectedSources = [
                    "sh -c 'if systemctl is-active --quiet power-profiles-daemon 2>/dev/null; then echo ppd; elif systemctl is-active --quiet tlp 2>/dev/null; then echo tlp; elif command -v tlp >/dev/null 2>&1; then echo tlp; else echo none; fi'"
                ]
            }
        }
    }

    // ── 4. Estado TLP (5s) ───────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: tlpStateSource; engine: "executable"
        connectedSources: root.powerManager === "tlp"
            ? ["sh -c 'tlp-stat -s 2>/dev/null | grep -i \"power source\" | grep -qi \"battery\" && echo bat || echo ac'"]
            : []
        interval: 5000
        onNewData: (sourceName, data) => { if (data["stdout"]) root.tlpActive = data["stdout"].trim() === "bat" }
    }

    // ── 5. Perfil PPD (4s) ───────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: profileSource; engine: "executable"
        connectedSources: root.powerManager === "ppd" ? ["powerprofilesctl get"] : []
        interval: 4000
        onNewData: (sourceName, data) => {
            if (data["stdout"]) { let p = data["stdout"].trim(); if (p !== "") root.powerProfile = p }
        }
    }

    // ── 6. Tiempo restante (30s) ─────────────────────────────────────────
    Plasma5Support.DataSource {
        id: timeSource; engine: "executable"
        connectedSources: [
            "sh -c 'bat=$(upower -e 2>/dev/null | grep -iE \"/battery_\" | head -n1); " +
            "[ -n \"$bat\" ] && upower -i \"$bat\" 2>/dev/null | " +
            "grep -E \"time to (empty|full)\" | head -n1 | awk -F\": \" \"{print \\$2}\"'"
        ]
        interval: 30000
        onNewData: (sourceName, data) => {
            if (data["stdout"]) {
                let t = data["stdout"].trim()
                if (t !== "" && t !== "0 seconds") {
                    t = t.replace("hours", "horas").replace("minutes", "minutos").replace("seconds", "segundos").replace("hour", "hora").replace("minute", "minuto").replace("second", "segundo");
                    root.timeRemaining = t;
                } else {
                    root.timeRemaining = "";
                }
            }
        }
    }

    // ── 7. Top proceso (10s) ─────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: topSource; engine: "executable"
        connectedSources: ["sh -c 'ps -eo comm,pcpu --sort=-pcpu 2>/dev/null | awk \"NR==2 && \\$2+0 > 8 {printf \\\"%s (%.0f%% CPU)\\\", \\$1, \\$2}\"'"]
        interval: 10000
        onNewData: (sourceName, data) => { root.topProcess = data["stdout"] ? data["stdout"].trim() : "" }
    }

    // ── 8. Dispositivos Bluetooth (20s) ──────────────────────────────────
    // Usa bluetoothctl para obtener nombres reales + upower para batería
    // Detecta Galaxy Buds, Galaxy phone, Magic Mouse, etc.
    Plasma5Support.DataSource {
        id: btSource; engine: "executable"
        connectedSources: [
            "sh -c '" +
            // Obtener MACs de dispositivos conectados via bluetoothctl
            "bluetoothctl devices Connected 2>/dev/null | awk \"{print \\$2, \\$3, \\$4, \\$5, \\$6}\" | while read mac rest; do " +
            // Nombre amigable desde bluetoothctl
            "  friendly=$(bluetoothctl info \"$mac\" 2>/dev/null | grep -i \"Name:\" | head -n1 | sed \"s/.*Name: //\"); " +
            // Batería via UPower buscando por MAC
            "  mac_under=$(echo \"$mac\" | tr \":\" \"_\"); " +
            "  dev=$(upower -e 2>/dev/null | grep -i \"$mac_under\" | head -n1); " +
            "  if [ -n \"$dev\" ]; then " +
            "    pct=$(upower -i \"$dev\" 2>/dev/null | grep -i \"percentage:\" | awk \"{print \\$2}\" | tr -d \"%\"); " +
            "  else " +
            // Fallback: buscar por nombre en upower
            "    pct=$(upower -e 2>/dev/null | grep -v BAT | grep -v line_power | while read d; do " +
            "      n=$(upower -i \"$d\" 2>/dev/null | grep -i \"model:\" | awk -F\": \" \"{print \\$2}\" | xargs); " +
            "      [ -n \"$friendly\" ] && echo \"$n\" | grep -qi \"$(echo $friendly | cut -c1-4)\" && " +
            "      upower -i \"$d\" 2>/dev/null | grep -i \"percentage:\" | awk \"{print \\$2}\" | tr -d \"%\" && break; " +
            "    done); " +
            "  fi; " +
            "  [ -n \"$friendly\" ] && echo \"${friendly}|${pct:-0}\"; " +
            "done | sort -u'"
        ]
        interval: 20000
        onNewData: (sourceName, data) => {
            if (!data["stdout"]) { root.btDevices = []; return }
            let lines = data["stdout"].trim().split('\n').filter(l => l.includes("|"))
            root.btDevices = lines.map(l => {
                let p = l.split("|")
                let name = p[0].trim()
                let pct  = parseInt(p[1].trim()) || 0
                return { name: name, pct: pct, icon: root.btIcon(name) }
            }).filter(d => d.name !== "")
        }
    }

    // ── 9. CPU governor + intel_pstate + intel_lpmd (10s) ────────────────
    Plasma5Support.DataSource {
        id: cpuSource; engine: "executable"
        connectedSources: [
            "sh -c '" +
            "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo; " +
            "[ -d /sys/devices/system/cpu/intel_pstate ] && echo pstate || echo nopstate; " +
            // intel_lpmd: Low Power Mode Daemon de Intel (diferente a pstate)
            "if systemctl is-active --quiet intel-lpmd 2>/dev/null || systemctl is-active --quiet intel_lpmd 2>/dev/null; then echo active; else echo inactive; fi'"
        ]
        interval: 10000
        onNewData: (sourceName, data) => {
            if (!data["stdout"]) return
            let lines = data["stdout"].trim().split('\n')
            root.cpuGovernor = lines[0] || ""
            root.hasPstate = lines.length > 1 && lines[1].trim() === "pstate"
            if (lines.length > 2) {
                let lpmd = lines[2].trim()
                root.hasLpmd = (lpmd === "active" || lpmd === "inactive")
                root.lpmdStatus = lpmd
            }
        }
    }

    // ── Ejecutores ───────────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: profileSetSource; engine: "executable"; connectedSources: []
        onNewData: (s, d) => { disconnectSource(s) }
    }
    Plasma5Support.DataSource {
        id: actionSource; engine: "executable"; connectedSources: []
        onNewData: (s, d) => { disconnectSource(s) }
    }
    Plasma5Support.DataSource {
        id: notifySource; engine: "executable"; connectedSources: []
        onNewData: (s, d) => { disconnectSource(s) }
    }
}
