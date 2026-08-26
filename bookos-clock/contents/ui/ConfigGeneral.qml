import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_dateFormat: dateField.text
    property alias cfg_use24h: h24.checked
    property alias cfg_showSeconds: secs.checked
    property alias cfg_fontSize: sizeSpin.value
    property alias cfg_clockWeight: weightCombo.currentIndex
    property string cfg_fontFamily
    // eventsJson lo gestiona el widget; se declara para que el sistema lo reconozca
    property string cfg_eventsJson

    function tr(es, en) { return Qt.locale().name.indexOf("es") === 0 ? es : en }

    // ── Fecha ────────────────────────────────────────────────────────────
    QQC2.TextField {
        id: dateField
        Kirigami.FormData.label: page.tr("Formato de fecha:", "Date format:")
        placeholderText: "d/M/yy"
    }
    QQC2.Label {
        text: page.tr("Ej.: d/M/yy · dd/MM/yyyy · ddd d MMM", "e.g. d/M/yy · dd/MM/yyyy · ddd d MMM")
        opacity: 0.6; font.pixelSize: 11
    }

    // ── Reloj ────────────────────────────────────────────────────────────
    QQC2.CheckBox {
        id: h24
        Kirigami.FormData.label: page.tr("Reloj:", "Clock:")
        text: page.tr("Formato de 24 horas", "24-hour format")
    }
    QQC2.CheckBox {
        id: secs
        text: page.tr("Mostrar segundos", "Show seconds")
    }

    Item { Kirigami.FormData.isSection: true }

    // ── Tipografía ───────────────────────────────────────────────────────
    QQC2.ComboBox {
        id: fontCombo
        Kirigami.FormData.label: page.tr("Fuente:", "Font:")
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        textRole: "text"
        model: {
            var arr = [{ text: page.tr("Predeterminada", "Default"), val: "" }]
            var f = Qt.fontFamilies()
            for (var i = 0; i < f.length; i++) arr.push({ text: f[i], val: f[i] })
            return arr
        }
        onActivated: page.cfg_fontFamily = model[currentIndex].val
        Component.onCompleted: {
            for (var i = 0; i < model.length; i++)
                if (model[i].val === (page.cfg_fontFamily || "")) { currentIndex = i; break }
        }
    }

    QQC2.ComboBox {
        id: weightCombo
        Kirigami.FormData.label: page.tr("Grosor del texto:", "Text weight:")
        model: [
            page.tr("Normal", "Normal"),
            page.tr("Medio", "Medium"),
            page.tr("Seminegrita", "Semi-bold"),
            page.tr("Negrita", "Bold")
        ]
    }

    QQC2.SpinBox {
        id: sizeSpin
        Kirigami.FormData.label: page.tr("Tamaño del texto:", "Text size:")
        from: 8; to: 48; stepSize: 1
    }
    QQC2.Label {
        text: page.tr("Tamaño del reloj en el panel (px)", "Panel clock size (px)")
        opacity: 0.6; font.pixelSize: 11
    }
}
