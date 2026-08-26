import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: root

    // ── Bindings de configuración ─────────────────────────────────────
    property alias cfg_iconTheme:        iconThemeCombo.currentIndex
    property alias cfg_iconWidth:        widthSpinBox.value
    property alias cfg_iconHeight:       heightSpinBox.value
    property alias cfg_percentPosition:  percentPosCombo.currentIndex
    property alias cfg_popupWidth:       popupWidthBox.value
    property alias cfg_popupHeight:      popupHeightBox.value
    property alias cfg_popupStyle:       popupStyleCombo.currentIndex
    property alias cfg_iconPreset:          iconPresetCombo.currentIndex
    property alias cfg_useCustomIconRadius: useCustomIconRadiusCheck.checked
    property alias cfg_customIconRadius:    customIconRadiusBox.value
    property alias cfg_boltStyle:           boltStyleCombo.currentIndex
    property real  cfg_boltScale:           1.0
    property string cfg_customFont:         ""

    // Animaciones
    property alias cfg_animFill:          animFillCheck.checked
    property alias cfg_animShimmer:       animShimmerCheck.checked
    property alias cfg_animShimmerSpeed:  animShimmerSpeedBox.value
    property alias cfg_animPulse:         animPulseCheck.checked
    property alias cfg_animPopupEntrance: animPopupCheck.checked
    property alias cfg_animProfileSpring: animSpringCheck.checked
    property alias cfg_animRainbow:       animRainbowCheck.checked
    property alias cfg_animRainbowSpeed:  animRainbowSpeedBox.value
    property alias cfg_animBounce:        animBounceCheck.checked
    property alias cfg_visualPreset:      visualPresetCombo.currentIndex

    // Colores — strings hex
    property string cfg_chargingColor:    "#30D158"
    property string cfg_pluggedFullColor: "#30D158"
    property string cfg_criticalColor:    "#FF453A"
    property string cfg_lowColor:         "#FFD60A"
    property string cfg_normalColor:      ""
    property string cfg_powerSaveColor:   "#FFD60A"
    property string cfg_balancedColor:    ""
    property string cfg_performanceColor: "#0A84FF"
    property string cfg_popupBgColorOverride: ""

    // ── Color dialog ──────────────────────────────────────────────────
    property string _editProp: ""

    function openColor(prop) {
        _editProp = prop
        colorField.text = getCurrentColor(prop)
        colorDialog.open()
    }

    function applyColor(hex) {
        if (hex === "reset") {
            resetColor(_editProp)
        } else if (hex.match(/^#[0-9a-fA-F]{6}$/)) {
            if (_editProp === "charging")    cfg_chargingColor    = hex
            if (_editProp === "pluggedFull") cfg_pluggedFullColor = hex
            if (_editProp === "critical")    cfg_criticalColor    = hex
            if (_editProp === "low")         cfg_lowColor         = hex
            if (_editProp === "normal")      cfg_normalColor      = hex
            if (_editProp === "powerSave")   cfg_powerSaveColor   = hex
            if (_editProp === "balanced")    cfg_balancedColor    = hex
            if (_editProp === "performance") cfg_performanceColor = hex
            if (_editProp === "popupBgOverride") cfg_popupBgColorOverride = hex
        }
    }

    function resetColor(prop) {
        if (prop === "charging")    cfg_chargingColor    = "#30D158"
        if (prop === "pluggedFull") cfg_pluggedFullColor = "#30D158"
        if (prop === "critical")    cfg_criticalColor    = "#FF453A"
        if (prop === "low")         cfg_lowColor         = "#FFD60A"
        if (prop === "normal")      cfg_normalColor      = ""
        if (prop === "powerSave")   cfg_powerSaveColor   = "#FFD60A"
        if (prop === "balanced")    cfg_balancedColor    = ""
        if (prop === "performance") cfg_performanceColor = "#0A84FF"
        if (prop === "popupBgOverride") cfg_popupBgColorOverride = ""
    }

    function getCurrentColor(prop) {
        if (prop === "charging")    return cfg_chargingColor    !== "" ? cfg_chargingColor    : "#30D158"
        if (prop === "pluggedFull") return cfg_pluggedFullColor !== "" ? cfg_pluggedFullColor : "#30D158"
        if (prop === "critical")    return cfg_criticalColor    !== "" ? cfg_criticalColor    : "#FF453A"
        if (prop === "low")         return cfg_lowColor         !== "" ? cfg_lowColor         : "#FFD60A"
        if (prop === "normal")      return cfg_normalColor      !== "" ? cfg_normalColor      : "#888888"
        if (prop === "powerSave")   return cfg_powerSaveColor   !== "" ? cfg_powerSaveColor   : "#FFD60A"
        if (prop === "balanced")    return cfg_balancedColor    !== "" ? cfg_balancedColor    : "#888888"
        if (prop === "performance") return cfg_performanceColor !== "" ? cfg_performanceColor : "#0A84FF"
        if (prop === "popupBgOverride") return cfg_popupBgColorOverride !== "" ? cfg_popupBgColorOverride : "#888888"
        return "#888888"
    }

    // ── Dialog de color ───────────────────────────────────────────────
    Dialog {
        id: colorDialog
        title: "Editar color"
        standardButtons: Dialog.Ok | Dialog.Cancel
        modal: true
        onAccepted: root.applyColor(colorField.text)

        ColumnLayout {
            spacing: 10

            // Paleta rápida
            Label { text: "Paleta rápida:"; font.pixelSize: 12; opacity: 0.7 }
            Flow {
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: ["#FF453A","#FFD60A","#FFD60A","#30D158","#0A84FF","#5E5CE6","#BF5AF2","#FF375F","#FFFFFF","#8E8E93"]
                    delegate: Rectangle {
                        width: 28; height: 28; radius: 6
                        color: modelData
                        border.color: Qt.darker(color, 1.5); border.width: 1
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: colorField.text = modelData
                        }
                    }
                }
            }

            Label { text: "Formato hexadecimal: #RRGGBB"; font.pixelSize: 12 }
            RowLayout {
                spacing: 10
                TextField {
                    id: colorField
                    placeholderText: "#RRGGBB"
                    implicitWidth: 130
                    validator: RegularExpressionValidator { regularExpression: /^#[0-9a-fA-F]{0,6}$/ }
                }
                Rectangle {
                    width: 40; height: 36; radius: 6
                    color: colorField.text.match(/^#[0-9a-fA-F]{6}$/) ? colorField.text : "#444444"
                    border.color: Kirigami.Theme.textColor; border.width: 1
                }
            }
            Button {
                text: "↩ Restablecer a valor por defecto"
                flat: true
                font.pixelSize: 11
                onClicked: { root.applyColor("reset"); colorDialog.close() }
            }
        }
    }

    // Fuentes
    property var fontList: {
        var list = ["Por defecto (sistema)"]
        var fam = Qt.fontFamilies()
        for (var i = 0; i < fam.length; i++) list.push(fam[i])
        return list
    }

    // ── Componente de fila de color reutilizable ──────────────────────
    component ColorPicker: RowLayout {
        id: cpRow
        property string colorProp: ""
        property string label: ""
        spacing: 8

        Label {
            text: cpRow.label
            Layout.minimumWidth: 180
            font.pixelSize: 13
        }
        Rectangle {
            width: 28; height: 28; radius: 5
            color: {
                var v = root.getCurrentColor(cpRow.colorProp)
                return v
            }
            border.color: Qt.darker(color, 1.4); border.width: 1
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root.openColor(cpRow.colorProp)
            }
        }
        Label {
            text: {
                var v = (cpRow.colorProp === "normal")    ? root.cfg_normalColor :
                        (cpRow.colorProp === "balanced")  ? root.cfg_balancedColor : 
                        (cpRow.colorProp === "popupBgOverride") ? root.cfg_popupBgColorOverride : ""
                return (v === "") ? "Sigue el tema" : root.getCurrentColor(cpRow.colorProp)
            }
            font.pixelSize: 11; opacity: 0.6
        }
    }

    // ═════════════════════════════════════════════════════════════════
    Kirigami.FormLayout {

        // ── PRESETS VISUALES COMPLETOS ────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Presets de estilo" }

        ComboBox {
            id: visualPresetCombo
            Kirigami.FormData.label: "Preset:"
            model: [
                "Personalizado (manual)",
                "Pill — rayo grande",
                "Flat minimalista",
                "Catppuccin (suave, acento)",
                "Neon (arcoíris + shimmer)"
            ]
            onActivated: {
                // Aplica configuración según preset elegido
                if (currentIndex === 1) {
                    // Pill
                    iconPresetCombo.currentIndex = 1
                    boltStyleCombo.currentIndex = 1
                    boltScaleBox.value = 150
                    animShimmerCheck.checked = true
                    animPulseCheck.checked = true
                    animPopupCheck.checked = true
                    animRainbowCheck.checked = false
                    animBounceCheck.checked = false
                } else if (currentIndex === 2) {
                    // Flat
                    iconPresetCombo.currentIndex = 2
                    boltStyleCombo.currentIndex = 0
                    boltScaleBox.value = 100
                    animShimmerCheck.checked = false
                    animPulseCheck.checked = false
                    animRainbowCheck.checked = false
                    animBounceCheck.checked = false
                } else if (currentIndex === 3) {
                    // Catppuccin
                    iconPresetCombo.currentIndex = 3
                    boltStyleCombo.currentIndex = 1
                    boltScaleBox.value = 120
                    animShimmerCheck.checked = true
                    animPulseCheck.checked = true
                    animRainbowCheck.checked = false
                    animBounceCheck.checked = false
                } else if (currentIndex === 4) {
                    // Neon
                    iconPresetCombo.currentIndex = 1
                    boltStyleCombo.currentIndex = 1
                    boltScaleBox.value = 160
                    animShimmerCheck.checked = true
                    animPulseCheck.checked = true
                    animRainbowCheck.checked = true
                    animBounceCheck.checked = true
                    animRainbowSpeedBox.value = 2000
                }
            }
        }
        Label {
            Kirigami.FormData.label: ""
            text: [
                "Configura cada opción manualmente.",
                "Cápsula pill con rayo grande y visible.",
                "Sin redondeos, aspecto limpio y moderno.",
                "Bordes suaves con colores suaves del tema.",
                "Arcoíris animado + rayo grande + shimmer + bounce."
            ][visualPresetCombo.currentIndex] || ""
            font.pixelSize: 11; opacity: 0.6; wrapMode: Text.WordWrap
            Layout.maximumWidth: 380
        }

        // ── ICONO DEL PANEL ──────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Icono del panel" }

        ComboBox {
            id: iconThemeCombo
            Kirigami.FormData.label: "Color del texto:"
            model: ["Automático (tema)", "Forzar claro", "Forzar oscuro"]
        }
        ComboBox {
            id: percentPosCombo
            Kirigami.FormData.label: "Posición del %:"
            model: ["Derecha del icono", "Izquierda del icono", "Dentro del icono", "Oculto"]
        }
        SpinBox { id: widthSpinBox; Kirigami.FormData.label: "Ancho (px):"; from: 15; to: 80 }
        SpinBox { id: heightSpinBox; Kirigami.FormData.label: "Alto (px):"; from: 8; to: 40 }

        // ── PRESET DE ICONO ──────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Estilo del icono de batería" }

        ComboBox {
            id: iconPresetCombo
            Kirigami.FormData.label: "Forma:"
            model: [
                "Estándar (esquinas ligeras)",
                "Pill redondeada",
                "Flat minimal (sin redondeo)",
                "Ultra-redondeado"
            ]
        }

        Label {
            Kirigami.FormData.label: ""
            text: ["Forma suave similar al indicador de KDE.",
                   "Cápsula pill totalmente redondeada.",
                   "Bordes rectos, estilo minimalista.",
                   "Máximo radio, muy suave."][iconPresetCombo.currentIndex] || ""
            font.pixelSize: 11; opacity: 0.6
        }
        
        CheckBox {
            id: useCustomIconRadiusCheck
            Kirigami.FormData.label: "Radio personalizado:"
            text: "Modificar bordes libremente"
        }
        SpinBox {
            id: customIconRadiusBox
            Kirigami.FormData.label: "Radio de bordes (px):"
            from: 0; to: 40
            enabled: useCustomIconRadiusCheck.checked
        }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Icono de rayo (al cargar)" }

        ComboBox {
            id: boltStyleCombo
            Kirigami.FormData.label: "Estilo del rayo:"
            model: ["Clásico fino", "Grueso y visible"]
        }

        SpinBox {
            id: boltScaleBox
            Kirigami.FormData.label: "Escala del rayo (%):"
            from: 50; to: 200; stepSize: 10
            value: 100
            textFromValue: function(v) { return v + "%" }
            valueFromText: function(t) { return parseInt(t) || 100 }

            // boltScale en config es un Double (0.5–2.0), aquí lo mostramos como %
            property bool _loaded: false
            Component.onCompleted: {
                var v = Plasmoid ? (Plasmoid.configuration.boltScale || 1.0) : 1.0
                value = Math.round(v * 100)
                _loaded = true
            }
            onValueChanged: {
                if (_loaded) cfg_boltScale = value / 100.0
            }
        }

        // ── POPUP ────────────────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Menú emergente" }

        ComboBox {
            id: popupStyleCombo
            Kirigami.FormData.label: "Estilo visual:"
            model: ["Estándar (sólido)", "Paleta del tema (tinte acento)", "Blur / translúcido (KWin)"]
        }
        Label {
            Kirigami.FormData.label: ""
            text: ["Fondo sólido del color de tu tema.",
                   "Tinte sutil del color de acento (Catppuccin, etc.).",
                   "Fondo muy transparente — KWin aplica blur si el efecto está activado en Efectos de escritorio."][popupStyleCombo.currentIndex] || ""
            font.pixelSize: 11; opacity: 0.6; wrapMode: Text.WordWrap
            Layout.maximumWidth: 360
        }
        ColorPicker { Kirigami.FormData.label: "Fondo forzado (vacío=tema):"; colorProp: "popupBgOverride"; label: "" }
        SpinBox { id: popupWidthBox; Kirigami.FormData.label: "Ancho (px):"; from: 240; to: 500 }
        SpinBox { id: popupHeightBox; Kirigami.FormData.label: "Alto (0=auto):"; from: 0; to: 800; stepSize: 10 }

        // ── TIPOGRAFÍA ───────────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Tipografía" }
        ComboBox {
            id: fontCombo
            Kirigami.FormData.label: "Fuente:"
            model: root.fontList
            implicitWidth: 280
            font.family: currentIndex === 0 ? Kirigami.Theme.defaultFont.family : currentText
            font.pixelSize: 13
            Component.onCompleted: {
                var idx = root.fontList.indexOf(cfg_customFont)
                currentIndex = (cfg_customFont === "" || idx < 0) ? 0 : idx
            }
            onActivated: cfg_customFont = currentIndex === 0 ? "" : currentText
        }

        // ── ANIMACIONES ──────────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Animaciones" }

        CheckBox {
            id: animFillCheck
            Kirigami.FormData.label: "Relleno de batería:"
            text: "Animación suave al cambiar nivel"
        }
        CheckBox {
            id: animPulseCheck
            Kirigami.FormData.label: "Pulso al cargar:"
            text: "El rayo parpadea suavemente"
        }
        CheckBox {
            id: animShimmerCheck
            Kirigami.FormData.label: "Shimmer al cargar:"
            text: "Destello que recorre la barra"
        }
        SpinBox {
            id: animShimmerSpeedBox
            Kirigami.FormData.label: "Velocidad shimmer (ms):"
            from: 800; to: 6000; stepSize: 200
            enabled: animShimmerCheck.checked
        }
        CheckBox {
            id: animPopupCheck
            Kirigami.FormData.label: "Apertura del popup:"
            text: "Entrada con fade + escala"
        }
        CheckBox {
            id: animSpringCheck
            Kirigami.FormData.label: "Selección de perfil:"
            text: "Animación spring al hacer clic"
        }
        CheckBox {
            id: animRainbowCheck
            Kirigami.FormData.label: "Arcoíris al cargar:"
            text: "Color cíclico del relleno mientras carga"
        }
        SpinBox {
            id: animRainbowSpeedBox
            Kirigami.FormData.label: "Velocidad arcoíris (ms):"
            from: 800; to: 8000; stepSize: 200
            enabled: animRainbowCheck.checked
        }
        CheckBox {
            id: animBounceCheck
            Kirigami.FormData.label: "Bounce al cargar:"
            text: "El icono rebota suavemente"
        }

        // ── COLORES — CARGADOR ───────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Colores — Cargador" }

        Label {
            Kirigami.FormData.label: ""
            text: "Haz clic en el cuadro de color para editarlo. ↩ restablece al valor por defecto."
            font.pixelSize: 11; opacity: 0.55; wrapMode: Text.WordWrap
            Layout.maximumWidth: 380
        }

        ColorPicker { Kirigami.FormData.label: "Cargando activamente:"; colorProp: "charging";    label: "" }
        ColorPicker { Kirigami.FormData.label: "Enchufado / batería llena:"; colorProp: "pluggedFull"; label: "" }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Colores — Nivel de batería" }
        ColorPicker { Kirigami.FormData.label: "Crítico:";           colorProp: "critical";   label: "" }
        ColorPicker { Kirigami.FormData.label: "Bajo:";              colorProp: "low";        label: "" }
        ColorPicker { Kirigami.FormData.label: "Normal (vacío=tema):"; colorProp: "normal";   label: "" }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Colores — Perfiles de energía" }
        ColorPicker { Kirigami.FormData.label: "Ahorro:";                colorProp: "powerSave";   label: "" }
        ColorPicker { Kirigami.FormData.label: "Equilibrado (vacío=tema):"; colorProp: "balanced"; label: "" }
        ColorPicker { Kirigami.FormData.label: "Alto rendimiento:";       colorProp: "performance"; label: "" }
    }
}
