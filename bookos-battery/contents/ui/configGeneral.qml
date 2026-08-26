import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page

    // ─── Bindings de configuración ──────────────────────────────────────
    property alias cfg_iconTheme:           iconThemeCombo.currentIndex
    property alias cfg_iconWidth:           widthSpinBox.value
    property alias cfg_iconHeight:          heightSpinBox.value
    property alias cfg_percentPosition:     percentPosCombo.currentIndex
    property alias cfg_forceManager:        managerCombo.currentIndex
    property alias cfg_popupWidth:          popupWidthBox.value
    property alias cfg_popupHeight:         popupHeightBox.value
    property alias cfg_popupStyle:          popupStyleCombo.currentIndex
    property alias cfg_enableNotifications: notifCheck.checked
    property string cfg_customFont:         ""

    // Colores
    property alias cfg_chargingColor:       _hiddenCharging.text
    property alias cfg_criticalColor:       _hiddenCritical.text
    property alias cfg_powerSaveColor:      _hiddenPower.text
    property alias cfg_performanceColor:    _hiddenPerformance.text

    // Perfiles
    property alias cfg_profile1Label: p1Label.text
    property alias cfg_profile1Desc:  p1Desc.text
    property alias cfg_profile1Cmd:   p1Cmd.text
    property alias cfg_profile2Label: p2Label.text
    property alias cfg_profile2Desc:  p2Desc.text
    property alias cfg_profile2Cmd:   p2Cmd.text
    property alias cfg_profile3Label: p3Label.text
    property alias cfg_profile3Desc:  p3Desc.text
    property alias cfg_profile3Cmd:   p3Cmd.text

    // Campos ocultos
    CheckBox  { id: _hiddenCheck;       visible: false; checked: true }
    TextField { id: _hiddenCharging;    visible: false }
    TextField { id: _hiddenCritical;    visible: false }
    TextField { id: _hiddenPower;       visible: false }
    TextField { id: _hiddenPerformance; visible: false }

    // Campos de perfil ocultos (alias bind)
    TextField { id: p1Label; visible: false }
    TextField { id: p1Desc;  visible: false }
    TextField { id: p1Cmd;   visible: false }
    TextField { id: p2Label; visible: false }
    TextField { id: p2Desc;  visible: false }
    TextField { id: p2Cmd;   visible: false }
    TextField { id: p3Label; visible: false }
    TextField { id: p3Desc;  visible: false }
    TextField { id: p3Cmd;   visible: false }

    property var fontList: {
        var list = ["Por defecto (sistema)"]
        var families = Qt.fontFamilies()
        for (var i = 0; i < families.length; i++) list.push(families[i])
        return list
    }

    Kirigami.FormLayout {

        // ════════════════════════════════════════════════════════════════
        // SECCIÓN: ICONO DEL PANEL
        // ════════════════════════════════════════════════════════════════
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Icono del panel" }

        ComboBox {
            id: iconThemeCombo
            Kirigami.FormData.label: "Color del texto:"
            model: ["Automático (sigue Plasma)", "Forzar claro", "Forzar oscuro"]
        }

        ComboBox {
            id: percentPosCombo
            Kirigami.FormData.label: "Posición del %:"
            model: ["Derecha del icono", "Izquierda del icono", "Dentro del icono", "Oculto"]
        }

        SpinBox {
            id: widthSpinBox
            Kirigami.FormData.label: "Ancho del icono:"
            from: 15; to: 60
        }

        SpinBox {
            id: heightSpinBox
            Kirigami.FormData.label: "Alto del icono:"
            from: 8; to: 40
        }

        // ════════════════════════════════════════════════════════════════
        // SECCIÓN: MENÚ EMERGENTE
        // ════════════════════════════════════════════════════════════════
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Menú emergente" }

        SpinBox {
            id: popupWidthBox
            Kirigami.FormData.label: "Ancho del menú:"
            from: 240; to: 500
        }

        SpinBox {
            id: popupHeightBox
            Kirigami.FormData.label: "Alto (0 = auto):"
            from: 0; to: 800; stepSize: 10
        }

        // ════════════════════════════════════════════════════════════════
        // SECCIÓN: APARIENCIA VISUAL
        // ════════════════════════════════════════════════════════════════
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Apariencia visual" }

        ComboBox {
            id: popupStyleCombo
            Kirigami.FormData.label: "Estilo del popup:"
            model: ["Estándar (fondo sólido)", "Seguir paleta del tema", "Blur / translúcido"]
        }

        Label {
            Kirigami.FormData.label: ""
            text: "• Estándar: fondo del tema sin modificar\n• Paleta: usa los colores de acento de tu tema\n• Blur: fondo translúcido (requiere efectos de compositor)"
            font.pixelSize: 11; opacity: 0.6; wrapMode: Text.WordWrap
            Layout.maximumWidth: 320
        }

        // ════════════════════════════════════════════════════════════════
        // SECCIÓN: TIPOGRAFÍA
        // ════════════════════════════════════════════════════════════════
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Tipografía" }

        ComboBox {
            id: fontCombo
            Kirigami.FormData.label: "Fuente:"
            model: page.fontList
            implicitWidth: 260
            font.family: currentIndex === 0 ? Kirigami.Theme.defaultFont.family : currentText
            font.pixelSize: 13

            delegate: ItemDelegate {
                width: fontCombo.width
                contentItem: Text {
                    text: modelData
                    font.family: index === 0 ? Kirigami.Theme.defaultFont.family : modelData
                    font.pixelSize: 13
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                }
                highlighted: fontCombo.highlightedIndex === index
            }

            Component.onCompleted: {
                if (cfg_customFont === "" || cfg_customFont === undefined) {
                    currentIndex = 0
                } else {
                    var idx = page.fontList.indexOf(cfg_customFont)
                    currentIndex = idx >= 0 ? idx : 0
                }
            }

            onActivated: { cfg_customFont = currentIndex === 0 ? "" : currentText }
        }

        // ════════════════════════════════════════════════════════════════
        // SECCIÓN: GESTOR DE ENERGÍA
        // ════════════════════════════════════════════════════════════════
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Gestor de energía" }

        ComboBox {
            id: managerCombo
            Kirigami.FormData.label: "Gestor a usar:"
            model: ["Automático (detectar)", "Forzar PPD (perfiles)", "Forzar TLP", "Ninguno"]
        }

        // ════════════════════════════════════════════════════════════════
        // SECCIÓN: PERFILES DE ENERGÍA PERSONALIZADOS
        // ════════════════════════════════════════════════════════════════
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Perfiles de energía" }

        Label {
            Kirigami.FormData.label: ""
            text: "Personaliza el nombre, descripción y comandos extra de cada perfil.\nLos comandos se ejecutan justo después de cambiar el perfil con PPD.\nÚsalos para ajustes del portátil (Samsung, ThinkPad, etc.)."
            font.pixelSize: 11; opacity: 0.6; wrapMode: Text.WordWrap
            Layout.maximumWidth: 340
        }

        // ── Perfil 1: Ahorro ──────────────────────────────────────────
        Label {
            Kirigami.FormData.label: ""
            text: "— Perfil 1: Ahorro (power-saver) —"
            font.pixelSize: 12; font.weight: Font.DemiBold; opacity: 0.8
        }

        TextField {
            id: p1LabelField
            Kirigami.FormData.label: "Nombre:"
            placeholderText: "Ahorro"
            implicitWidth: 220
            text: cfg_profile1Label
            onTextChanged: cfg_profile1Label = text
        }

        TextField {
            id: p1DescField
            Kirigami.FormData.label: "Descripción:"
            placeholderText: "Máx. duración de batería"
            implicitWidth: 280
            text: cfg_profile1Desc
            onTextChanged: cfg_profile1Desc = text
        }

        TextField {
            id: p1CmdField
            Kirigami.FormData.label: "Comando extra:"
            placeholderText: "Ej: samsung-galaxybook-extras --fan-mode=silent"
            implicitWidth: 340
            text: cfg_profile1Cmd
            onTextChanged: cfg_profile1Cmd = text
        }

        // ── Perfil 2: Equilibrado ────────────────────────────────────
        Label {
            Kirigami.FormData.label: ""
            text: "— Perfil 2: Equilibrado (balanced) —"
            font.pixelSize: 12; font.weight: Font.DemiBold; opacity: 0.8
        }

        TextField {
            id: p2LabelField
            Kirigami.FormData.label: "Nombre:"
            placeholderText: "Equilibrado"
            implicitWidth: 220
            text: cfg_profile2Label
            onTextChanged: cfg_profile2Label = text
        }

        TextField {
            id: p2DescField
            Kirigami.FormData.label: "Descripción:"
            placeholderText: "Rendimiento recomendado"
            implicitWidth: 280
            text: cfg_profile2Desc
            onTextChanged: cfg_profile2Desc = text
        }

        TextField {
            id: p2CmdField
            Kirigami.FormData.label: "Comando extra:"
            placeholderText: "Ej: samsung-galaxybook-extras --fan-mode=auto"
            implicitWidth: 340
            text: cfg_profile2Cmd
            onTextChanged: cfg_profile2Cmd = text
        }

        // ── Perfil 3: Rendimiento ────────────────────────────────────
        Label {
            Kirigami.FormData.label: ""
            text: "— Perfil 3: Alto rendimiento (performance) —"
            font.pixelSize: 12; font.weight: Font.DemiBold; opacity: 0.8
        }

        TextField {
            id: p3LabelField
            Kirigami.FormData.label: "Nombre:"
            placeholderText: "Alto rendimiento"
            implicitWidth: 220
            text: cfg_profile3Label
            onTextChanged: cfg_profile3Label = text
        }

        TextField {
            id: p3DescField
            Kirigami.FormData.label: "Descripción:"
            placeholderText: "Máx. potencia del sistema"
            implicitWidth: 280
            text: cfg_profile3Desc
            onTextChanged: cfg_profile3Desc = text
        }

        TextField {
            id: p3CmdField
            Kirigami.FormData.label: "Comando extra:"
            placeholderText: "Ej: samsung-galaxybook-extras --fan-mode=turbo"
            implicitWidth: 340
            text: cfg_profile3Cmd
            onTextChanged: cfg_profile3Cmd = text
        }

        Label {
            Kirigami.FormData.label: ""
            text: "💡 Galaxy Book 5 Pro 14: instala samsung-galaxybook en AUR\nAhorro → --fan-mode=silent  |  Equilibrado → --fan-mode=auto\nRendimiento → --fan-mode=turbo"
            font.pixelSize: 11; opacity: 0.55; wrapMode: Text.WordWrap
            Layout.maximumWidth: 340
        }

        // ════════════════════════════════════════════════════════════════
        // SECCIÓN: NOTIFICACIONES
        // ════════════════════════════════════════════════════════════════
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Notificaciones" }

        CheckBox {
            id: notifCheck
            Kirigami.FormData.label: "Notificaciones automáticas:"
        }

        Label {
            Kirigami.FormData.label: ""
            text: "Avisa al 20%, 10%, al conectar/desconectar\nel cargador y al llegar al 100%."
            font.pixelSize: 11; opacity: 0.6; wrapMode: Text.WordWrap
        }

        // ════════════════════════════════════════════════════════════════
        // SECCIÓN: COLORES DE ESTADO
        // ════════════════════════════════════════════════════════════════
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Colores de estado" }

        RowLayout {
            Kirigami.FormData.label: "Cargando:"
            Rectangle {
                width: 22; height: 22; radius: 5
                color: cfg_chargingColor || "#30D158"
                border.color: Qt.darker(color, 1.4); border.width: 1
                MouseArea { anchors.fill: parent; onClicked: dlgCharging.open() }
            }
            Label { text: cfg_chargingColor || "#30D158"; opacity: 0.6; font.pixelSize: 12 }
        }

        RowLayout {
            Kirigami.FormData.label: "Crítico (≤20%):"
            Rectangle {
                width: 22; height: 22; radius: 5
                color: cfg_criticalColor || "#FF453A"
                border.color: Qt.darker(color, 1.4); border.width: 1
                MouseArea { anchors.fill: parent; onClicked: dlgCritical.open() }
            }
            Label { text: cfg_criticalColor || "#FF453A"; opacity: 0.6; font.pixelSize: 12 }
        }

        RowLayout {
            Kirigami.FormData.label: "Ahorro energía:"
            Rectangle {
                width: 22; height: 22; radius: 5
                color: cfg_powerSaveColor || "#FFD60A"
                border.color: Qt.darker(color, 1.4); border.width: 1
                MouseArea { anchors.fill: parent; onClicked: dlgPowerSave.open() }
            }
            Label { text: cfg_powerSaveColor || "#FFD60A"; opacity: 0.6; font.pixelSize: 12 }
        }

        RowLayout {
            Kirigami.FormData.label: "Rendimiento:"
            Rectangle {
                width: 22; height: 22; radius: 5
                color: cfg_performanceColor || "#0A84FF"
                border.color: Qt.darker(color, 1.4); border.width: 1
                MouseArea { anchors.fill: parent; onClicked: dlgPerformance.open() }
            }
            Label { text: cfg_performanceColor || "#0A84FF"; opacity: 0.6; font.pixelSize: 12 }
        }
    }

    // ── Diálogos de color ───────────────────────────────────────────────
    Dialog {
        id: dlgCharging; title: "Color al cargar"; standardButtons: Dialog.Ok | Dialog.Cancel
        TextField { id: fldCharging; placeholderText: "#30D158" }
        onOpened:   fldCharging.text  = cfg_chargingColor  || "#30D158"
        onAccepted: cfg_chargingColor = fldCharging.text
    }
    Dialog {
        id: dlgCritical; title: "Color crítico"; standardButtons: Dialog.Ok | Dialog.Cancel
        TextField { id: fldCritical; placeholderText: "#FF453A" }
        onOpened:   fldCritical.text  = cfg_criticalColor  || "#FF453A"
        onAccepted: cfg_criticalColor = fldCritical.text
    }
    Dialog {
        id: dlgPowerSave; title: "Color ahorro"; standardButtons: Dialog.Ok | Dialog.Cancel
        TextField { id: fldPowerSave; placeholderText: "#FFD60A" }
        onOpened:   fldPowerSave.text  = cfg_powerSaveColor  || "#FFD60A"
        onAccepted: cfg_powerSaveColor = fldPowerSave.text
    }
    Dialog {
        id: dlgPerformance; title: "Color rendimiento"; standardButtons: Dialog.Ok | Dialog.Cancel
        TextField { id: fldPerformance; placeholderText: "#0A84FF" }
        onOpened:   fldPerformance.text  = cfg_performanceColor  || "#0A84FF"
        onAccepted: cfg_performanceColor = fldPerformance.text
    }
}
