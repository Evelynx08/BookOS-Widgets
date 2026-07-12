import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

// Los ajustes viven en ~/.config/bookos-notificationsrc (grupo [Popups]),
// compartidos con bookos-settings. Se aplican al instante (sin botón Aplicar).
Kirigami.FormLayout {
    id: page

    property bool   loaded: false
    property bool   vEnabled: true
    property int    vTimeout: 6
    property bool   vCountdown: true
    property string vPosition: "bottomright"
    property string vTheme: "auto"

    function tr(es, en) { return Qt.locale().name.indexOf("es") === 0 ? es : en }

    Plasma5Support.DataSource {
        id: cfgIo; engine: "executable"; connectedSources: []
        onNewData: (s, data) => {
            disconnectSource(s)
            if (s.indexOf("kreadconfig6") < 0) return
            var lines = (data.stdout || "").trim().split("\n")
            if (lines.length >= 5) {
                page.vEnabled   = lines[0].trim() !== "false"
                page.vTimeout   = parseInt(lines[1]) >= 0 ? parseInt(lines[1]) : 6
                page.vCountdown = lines[2].trim() !== "false"
                page.vPosition  = lines[3].trim()
                page.vTheme     = lines[4].trim()
                page.loaded = true
            }
        }
    }
    function save(key, value) {
        if (!loaded) return
        cfgIo.connectSource("kwriteconfig6 --file bookos-notificationsrc --group Popups --key " + key + " '" + value + "'")
    }
    Component.onCompleted: {
        cfgIo.connectSource("sh -c '" +
            "f=bookos-notificationsrc; g=Popups; " +
            "kreadconfig6 --file $f --group $g --key Enabled --default true; " +
            "kreadconfig6 --file $f --group $g --key Timeout --default 6; " +
            "kreadconfig6 --file $f --group $g --key ShowCountdown --default true; " +
            "kreadconfig6 --file $f --group $g --key Position --default bottomright; " +
            "kreadconfig6 --file $f --group $g --key Theme --default auto'")
    }

    QQC2.CheckBox {
        Kirigami.FormData.label: page.tr("Ventanas emergentes:", "Popups:")
        text: page.tr("Mostrar notificaciones emergentes", "Show notification popups")
        checked: page.vEnabled
        onToggled: { page.vEnabled = checked; page.save("Enabled", checked) }
    }

    QQC2.ComboBox {
        Kirigami.FormData.label: page.tr("Posición en pantalla:", "Screen position:")
        enabled: page.vEnabled
        model: [
            { label: page.tr("Abajo a la derecha","Bottom right"), value: "bottomright" },
            { label: page.tr("Abajo a la izquierda","Bottom left"), value: "bottomleft" },
            { label: page.tr("Arriba a la derecha","Top right"), value: "topright" },
            { label: page.tr("Arriba a la izquierda","Top left"), value: "topleft" },
            { label: page.tr("Arriba centrado","Top center"), value: "topcenter" }
        ]
        textRole: "label"
        currentIndex: Math.max(0, model.findIndex(m => m.value === page.vPosition))
        onActivated: { page.vPosition = model[currentIndex].value; page.save("Position", page.vPosition) }
    }

    QQC2.SpinBox {
        Kirigami.FormData.label: page.tr("Cerrar automáticamente tras:", "Auto-hide after:")
        enabled: page.vEnabled
        from: 0; to: 60
        value: page.vTimeout
        textFromValue: (v) => v === 0 ? page.tr("Nunca","Never") : v + " s"
        valueFromText: (t) => parseInt(t) || 0
        onValueModified: { page.vTimeout = value; page.save("Timeout", value) }
    }

    QQC2.CheckBox {
        Kirigami.FormData.label: page.tr("Cuenta atrás:", "Countdown:")
        text: page.tr("Mostrar barra con el tiempo restante", "Show remaining-time bar")
        enabled: page.vEnabled && page.vTimeout > 0
        checked: page.vCountdown
        onToggled: { page.vCountdown = checked; page.save("ShowCountdown", checked) }
    }

    QQC2.ComboBox {
        Kirigami.FormData.label: page.tr("Tema:", "Theme:")
        enabled: page.vEnabled
        model: [
            { label: page.tr("Automático (según sistema)","Automatic (follow system)"), value: "auto" },
            { label: page.tr("Claro","Light"), value: "light" },
            { label: page.tr("Oscuro","Dark"), value: "dark" }
        ]
        textRole: "label"
        currentIndex: Math.max(0, model.findIndex(m => m.value === page.vTheme))
        onActivated: { page.vTheme = model[currentIndex].value; page.save("Theme", page.vTheme) }
    }

    QQC2.Label {
        text: page.tr("Los cambios se aplican en unos segundos.\nTambién puedes cambiarlos desde Ajustes de BookOS.",
                      "Changes apply within a few seconds.\nYou can also change them from BookOS Settings.")
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
}
