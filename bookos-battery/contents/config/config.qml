import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "Apariencia"
        icon: "preferences-desktop-color"
        source: "ConfigApariencia.qml"
    }
    ConfigCategory {
        name: "Perfiles"
        icon: "battery"
        source: "ConfigPerfiles.qml"
    }
    ConfigCategory {
        name: "Notificaciones"
        icon: "notifications"
        source: "ConfigNotificaciones.qml"
    }
}
