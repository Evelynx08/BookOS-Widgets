import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import QtQuick.Dialogs as Dialogs

Kirigami.ScrollablePage {
    id: page

    property alias cfg_iconTheme:           iconThemeCombo.currentIndex
    property alias cfg_iconWidth:           widthSpinBox.value
    property alias cfg_iconHeight:          heightSpinBox.value
    property alias cfg_percentPosition:     percentPosCombo.currentIndex
    property alias cfg_forceManager:        managerCombo.currentIndex
    property alias cfg_popupWidth:          popupWidthBox.value
    property alias cfg_popupHeight:         popupHeightBox.value
    property alias cfg_enableNotifications: notifCheck.checked
    property alias cfg_showPercentage:      _hiddenCheck.checked
    property alias cfg_customFont:          _hiddenFont.text
    property alias cfg_chargingColor:       _hiddenCharging.text
    property alias cfg_criticalColor:       _hiddenCritical.text
    property alias cfg_powerSaveColor:      _hiddenPower.text
    property alias cfg_performanceColor:    _hiddenPerformance.text

    CheckBox { id: _hiddenCheck; visible: false; checked: true }
    TextField { id: _hiddenFont; visible: false }
    TextField { id: _hiddenCharging; visible: false }
    TextField { id: _hiddenCritical; visible: false }
    TextField { id: _hiddenPower; visible: false }
    TextField { id: _hiddenPerformance; visible: false }

    Kirigami.FormLayout {

        // ─── ICONO ────────────────────────────────────────────────────
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

        // ─── MENÚ ─────────────────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Menú emergente" }

        SpinBox {
            id: popupWidthBox
            Kirigami.FormData.label: "Ancho del menú:"
            from: 240; to: 500
        }

        SpinBox {
            id: popupHeightBox
            Kirigami.FormData.label: "Alto del menú (0=auto):"
            from: 0; to: 800
            stepSize: 10
        }

        // ─── FUENTE ───────────────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Tipografía" }

        RowLayout {
            Kirigami.FormData.label: "Fuente personalizada:"
            Button {
                text: cfg_customFont !== "" ? cfg_customFont : "Por defecto"
                font.family: cfg_customFont !== "" ? cfg_customFont : Kirigami.Theme.defaultFont.family
                onClicked: fontDlg.open()
            }
            Button {
                icon.name: "edit-clear"
                visible: cfg_customFont !== ""
                onClicked: cfg_customFont = ""
            }
        }

        Label {
            Kirigami.FormData.label: ""
            text: "Elige la tipografía para el widget.\nSi está vacía, se usa la del sistema."
            font.pixelSize: 11; opacity: 0.6; wrapMode: Text.WordWrap
        }

        // ─── GESTOR ───────────────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Gestor de energía" }

        ComboBox {
            id: managerCombo
            Kirigami.FormData.label: "Gestor a usar:"
            model: ["Automático (detectar)", "Forzar PPD (perfiles)", "Forzar TLP", "Ninguno"]
        }

        Label {
            Kirigami.FormData.label: ""
            text: "PPD: cambia entre Ahorro / Equilibrado / Rendimiento.\nTLP: gestión automática de ahorro."
            font.pixelSize: 11; opacity: 0.6; wrapMode: Text.WordWrap
        }

        // ─── NOTIFICACIONES ───────────────────────────────────────────
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

        // ─── COLORES ──────────────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Colores de estado" }

        RowLayout {
            Kirigami.FormData.label: "Cargando:"
            Rectangle {
                width: 22; height: 22; radius: 5
                color: cfg_chargingColor || "#34C759"
                border.color: Qt.darker(color, 1.4); border.width: 1
                MouseArea { anchors.fill: parent; onClicked: dlgCharging.open() }
            }
            Label { text: cfg_chargingColor || "#34C759"; opacity: 0.6; font.pixelSize: 12 }
        }
        RowLayout {
            Kirigami.FormData.label: "Crítico (≤20%):"
            Rectangle {
                width: 22; height: 22; radius: 5
                color: cfg_criticalColor || "#FF3B30"
                border.color: Qt.darker(color, 1.4); border.width: 1
                MouseArea { anchors.fill: parent; onClicked: dlgCritical.open() }
            }
            Label { text: cfg_criticalColor || "#FF3B30"; opacity: 0.6; font.pixelSize: 12 }
        }
        RowLayout {
            Kirigami.FormData.label: "Ahorro energía:"
            Rectangle {
                width: 22; height: 22; radius: 5
                color: cfg_powerSaveColor || "#FFCC00"
                border.color: Qt.darker(color, 1.4); border.width: 1
                MouseArea { anchors.fill: parent; onClicked: dlgPowerSave.open() }
            }
            Label { text: cfg_powerSaveColor || "#FFCC00"; opacity: 0.6; font.pixelSize: 12 }
        }
        RowLayout {
            Kirigami.FormData.label: "Rendimiento:"
            Rectangle {
                width: 22; height: 22; radius: 5
                color: cfg_performanceColor || "#32ADE6"
                border.color: Qt.darker(color, 1.4); border.width: 1
                MouseArea { anchors.fill: parent; onClicked: dlgPerformance.open() }
            }
            Label { text: cfg_performanceColor || "#32ADE6"; opacity: 0.6; font.pixelSize: 12 }
        }
    }

    Dialog { id: dlgCharging;    title: "Color al cargar";     standardButtons: Dialog.Ok | Dialog.Cancel
        TextField { id: fldCharging;    placeholderText: "#34C759" }
        onOpened: fldCharging.text    = cfg_chargingColor    || "#34C759"
        onAccepted: cfg_chargingColor    = fldCharging.text }
    Dialog { id: dlgCritical;    title: "Color crítico";       standardButtons: Dialog.Ok | Dialog.Cancel
        TextField { id: fldCritical;    placeholderText: "#FF3B30" }
        onOpened: fldCritical.text    = cfg_criticalColor    || "#FF3B30"
        onAccepted: cfg_criticalColor    = fldCritical.text }
    Dialog { id: dlgPowerSave;   title: "Color ahorro";        standardButtons: Dialog.Ok | Dialog.Cancel
        TextField { id: fldPowerSave;   placeholderText: "#FFCC00" }
        onOpened: fldPowerSave.text   = cfg_powerSaveColor   || "#FFCC00"
        onAccepted: cfg_powerSaveColor   = fldPowerSave.text }
    Dialog { id: dlgPerformance; title: "Color rendimiento";   standardButtons: Dialog.Ok | Dialog.Cancel
        TextField { id: fldPerformance; placeholderText: "#32ADE6" }
        onOpened: fldPerformance.text = cfg_performanceColor || "#32ADE6"
        onAccepted: cfg_performanceColor = fldPerformance.text }
        
    Dialogs.FontDialog {
        id: fontDlg
        title: "Seleccionar Tipografía"
        onAccepted: cfg_customFont = selectedFont.family
    }
}
