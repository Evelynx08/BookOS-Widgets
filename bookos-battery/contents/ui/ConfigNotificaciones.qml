import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: root

    property alias cfg_enableNotifications: masterSwitch.checked
    property alias cfg_notifyCharging:      notifyChargingCheck.checked
    property alias cfg_notifyDischarging:   notifyDischargingCheck.checked
    property alias cfg_notifyLow:           notifyLowCheck.checked
    property alias cfg_notifyFull:          notifyFullCheck.checked
    property alias cfg_notifyLowThreshold:  lowThresholdBox.value
    property alias cfg_notifyCritThreshold: critThresholdBox.value

    Kirigami.FormLayout {
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Activar" }
        CheckBox {
            id: masterSwitch
            Kirigami.FormData.label: "Notificaciones:"
            text: "Habilitadas"
        }
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Eventos" }
        CheckBox {
            id: notifyChargingCheck
            Kirigami.FormData.label: "Al conectar cargador:"
            enabled: masterSwitch.checked
        }
        CheckBox {
            id: notifyDischargingCheck
            Kirigami.FormData.label: "Al desconectar cargador:"
            enabled: masterSwitch.checked
        }
        CheckBox {
            id: notifyFullCheck
            Kirigami.FormData.label: "Al llegar al 100%:"
            enabled: masterSwitch.checked
        }
        CheckBox {
            id: notifyLowCheck
            Kirigami.FormData.label: "Batería baja:"
            enabled: masterSwitch.checked
        }
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Umbrales" }
        SpinBox {
            id: lowThresholdBox
            Kirigami.FormData.label: "Umbral bajo (%):"
            from: 5; to: 50
            enabled: masterSwitch.checked && notifyLowCheck.checked
        }
        SpinBox {
            id: critThresholdBox
            Kirigami.FormData.label: "Umbral crítico (%):"
            from: 1; to: 30
            enabled: masterSwitch.checked && notifyLowCheck.checked
        }
        Label {
            Kirigami.FormData.label: ""
            text: "Aviso normal al umbral bajo, urgente al crítico."
            font.pixelSize: 11; opacity: 0.6
        }
    }
}
