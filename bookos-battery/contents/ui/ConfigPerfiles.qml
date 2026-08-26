import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: root

    property alias cfg_forceManager: managerCombo.currentIndex
    property string cfg_profile1Label: "Ahorro"
    property string cfg_profile1Desc:  "Máx. duración de batería"
    property string cfg_profile1Cmd:   ""
    property string cfg_profile2Label: "Equilibrado"
    property string cfg_profile2Desc:  "Rendimiento recomendado"
    property string cfg_profile2Cmd:   ""
    property string cfg_profile3Label: "Alto rendimiento"
    property string cfg_profile3Desc:  "Máx. potencia del sistema"
    property string cfg_profile3Cmd:   ""

    Kirigami.FormLayout {

        // ── GESTOR DE ENERGÍA ──────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Gestor de energía" }

        ComboBox {
            id: managerCombo
            Kirigami.FormData.label: "Gestor:"
            model: ["Automático (detectar)", "Forzar PPD", "Forzar TLP", "Ninguno"]
        }

        Label {
            Kirigami.FormData.label: ""
            text: "PPD (power-profiles-daemon) es el estándar en sistemas modernos.\nTLP es una alternativa avanzada para portátiles."
            font.pixelSize: 11; opacity: 0.55; wrapMode: Text.WordWrap
            Layout.maximumWidth: 380
        }

        // ── PERFIL 1: AHORRO ───────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Perfil 1 — Ahorro (power-saver)" }

        TextField {
            Kirigami.FormData.label: "Nombre:"
            implicitWidth: 240
            text: cfg_profile1Label
            onTextChanged: cfg_profile1Label = text
        }
        TextField {
            Kirigami.FormData.label: "Descripción:"
            implicitWidth: 300
            text: cfg_profile1Desc
            onTextChanged: cfg_profile1Desc = text
        }
        TextField {
            Kirigami.FormData.label: "Comando extra:"
            placeholderText: "Ej: echo quiet > /sys/devices/.../platform_profile"
            implicitWidth: 360
            text: cfg_profile1Cmd
            onTextChanged: cfg_profile1Cmd = text
        }

        // ── PERFIL 2: EQUILIBRADO ──────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Perfil 2 — Equilibrado (balanced)" }

        TextField {
            Kirigami.FormData.label: "Nombre:"
            implicitWidth: 240
            text: cfg_profile2Label
            onTextChanged: cfg_profile2Label = text
        }
        TextField {
            Kirigami.FormData.label: "Descripción:"
            implicitWidth: 300
            text: cfg_profile2Desc
            onTextChanged: cfg_profile2Desc = text
        }
        TextField {
            Kirigami.FormData.label: "Comando extra:"
            placeholderText: "Ej: echo balanced > /sys/devices/.../platform_profile"
            implicitWidth: 360
            text: cfg_profile2Cmd
            onTextChanged: cfg_profile2Cmd = text
        }

        // ── PERFIL 3: ALTO RENDIMIENTO ─────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Perfil 3 — Alto rendimiento (performance)" }

        TextField {
            Kirigami.FormData.label: "Nombre:"
            implicitWidth: 240
            text: cfg_profile3Label
            onTextChanged: cfg_profile3Label = text
        }
        TextField {
            Kirigami.FormData.label: "Descripción:"
            implicitWidth: 300
            text: cfg_profile3Desc
            onTextChanged: cfg_profile3Desc = text
        }
        TextField {
            Kirigami.FormData.label: "Comando extra:"
            placeholderText: "Ej: echo performance > /sys/devices/.../platform_profile"
            implicitWidth: 360
            text: cfg_profile3Cmd
            onTextChanged: cfg_profile3Cmd = text
        }

        Label {
            Kirigami.FormData.label: ""
            text: "Los comandos extra se ejecutan tras cambiar el perfil con PPD.\nÚsalos para ajustar el perfil de plataforma del portátil,\ngovernor de CPU, límites de TDP, etc."
            font.pixelSize: 11; opacity: 0.55; wrapMode: Text.WordWrap
            Layout.maximumWidth: 380
        }
    }
}
