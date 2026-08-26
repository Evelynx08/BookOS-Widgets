/*
    BookOS Launchpad — ColorPicker.qml
    Selector de color HSV: cuadro de saturación/brillo + barra de tono.

    Sin diálogos del sistema a propósito: el launchpad es una ventana que se
    cierra al perder el foco, así que abrir otra ventana encima lo cerraría.
    Y sin shaders: los dos gradientes de QtQuick bastan para el cuadro.

    SPDX-License-Identifier: GPL-2.0+
*/
import QtQuick 2.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: picker

    property bool dark: true
    // Color mostrado. Escribirlo desde fuera recoloca los manejadores.
    property color color: "#3F51B5"

    // picked: en vivo mientras se arrastra, solo para previsualizar.
    // committed: al soltar. Guardar en cada fotograma significaría serializar y
    // escribir la configuración del plasmoide 60 veces por segundo.
    signal picked(color c)
    signal committed(color c)

    FolderTokens { id: tokens }

    // Valor inicial por binding, no en Component.onCompleted: si el color de
    // entrada coincide con el valor por defecto de `color` no hay señal de
    // cambio, y una carpeta con el color por defecto salía en rojo.
    // Al arrastrar se asignan a pelo (rompiendo el binding), que es lo que se
    // quiere: a partir de ahí mandan los manejadores.
    property real hue:        color.hsvHue        >= 0 ? color.hsvHue        : 0
    property real saturation: color.hsvSaturation >= 0 ? color.hsvSaturation : 1
    property real brightness: color.hsvValue      >= 0 ? color.hsvValue      : 1
    // Evita que la reentrada (picked → color → setFromColor) mueva el manejador
    // mientras se está arrastrando.
    property bool _internal: false

    implicitHeight: svBox.height + hueBar.height + Kirigami.Units.smallSpacing

    function setFromColor(c) {
        if (_internal) return
        hue        = c.hsvHue        >= 0 ? c.hsvHue        : 0
        saturation = c.hsvSaturation >= 0 ? c.hsvSaturation : 0
        brightness = c.hsvValue      >= 0 ? c.hsvValue      : 0
    }
    // Cambios que vienen de fuera (los chips del fondo de pantalla) después de
    // haber tocado los manejadores, que ya rompieron el binding de arriba.
    onColorChanged: setFromColor(color)

    // El color que representan los manejadores ahora mismo. No se asigna a
    // `color`: eso rompería el binding con quien nos usa y el picker dejaría de
    // seguir los cambios de fuera (los chips del fondo de pantalla).
    readonly property color currentColor: Qt.hsva(hue, saturation, brightness, 1)

    function emitColor() {
        _internal = true
        picker.picked(picker.currentColor)
        _internal = false
    }

    // ── cuadro saturación × brillo ───────────────────────────────────────
    Rectangle {
        id: svBox
        width:  parent.width
        height: Kirigami.Units.gridUnit * 7
        radius: tokens.radiusButton
        clip: true
        // Blanco → tono puro, de izquierda a derecha.
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#ffffff" }
            GradientStop { position: 1.0; color: Qt.hsva(picker.hue, 1, 1, 1) }
        }

        // Negro por abajo: el brillo.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: "#000000" }
            }
        }

        Rectangle {
            id: svHandle
            width:  Kirigami.Units.gridUnit
            height: width
            radius: tokens.radiusPill
            color: "transparent"
            border.width: 2
            border.color: "#ffffff"
            x: picker.saturation * svBox.width  - width  / 2
            y: (1 - picker.brightness) * svBox.height - height / 2
            // Anillo interior oscuro: sobre un color claro un aro blanco solo
            // desaparece.
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: tokens.radiusPill
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.45)
            }
        }

        MouseArea {
            anchors.fill: parent
            preventStealing: true
            onPressed:         mouse => picker._pickSV(mouse.x, mouse.y)
            onPositionChanged: mouse => { if (pressed) picker._pickSV(mouse.x, mouse.y) }
            onReleased: picker.committed(picker.currentColor)
        }
    }

    function _pickSV(x, y) {
        saturation = Math.max(0, Math.min(1, x / svBox.width))
        brightness = Math.max(0, Math.min(1, 1 - y / svBox.height))
        emitColor()
    }

    // ── barra de tono ────────────────────────────────────────────────────
    Rectangle {
        id: hueBar
        anchors.top: svBox.bottom
        anchors.topMargin: Kirigami.Units.smallSpacing
        width:  parent.width
        height: Kirigami.Units.gridUnit * 1.2
        radius: height / 2
        clip: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.000; color: "#ff0000" }
            GradientStop { position: 0.166; color: "#ffff00" }
            GradientStop { position: 0.333; color: "#00ff00" }
            GradientStop { position: 0.500; color: "#00ffff" }
            GradientStop { position: 0.666; color: "#0000ff" }
            GradientStop { position: 0.833; color: "#ff00ff" }
            GradientStop { position: 1.000; color: "#ff0000" }
        }

        Rectangle {
            width:  Kirigami.Units.smallSpacing
            height: hueBar.height
            radius: width / 2
            color: "#ffffff"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.35)
            x: Math.max(0, Math.min(hueBar.width - width,
                                    picker.hue * hueBar.width - width / 2))
        }

        MouseArea {
            anchors.fill: parent
            preventStealing: true
            onPressed:         mouse => picker._pickHue(mouse.x)
            onPositionChanged: mouse => { if (pressed) picker._pickHue(mouse.x) }
            onReleased: picker.committed(picker.currentColor)
        }
    }

    function _pickHue(x) {
        hue = Math.max(0, Math.min(0.9999, x / hueBar.width))
        // Un tono elegido con el cuadro en blanco o negro no se vería: al tocar
        // el arcoíris se da por hecho que se quiere ese color.
        if (saturation < 0.05) saturation = 1
        if (brightness < 0.05) brightness = 1
        emitColor()
    }
}
