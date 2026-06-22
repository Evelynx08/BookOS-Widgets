.pragma library

// Lightweight i18n. lang() picks "es" if system locale starts with es, else "en".
var S = {
    en: {
        about:        "About This PC",
        prefs:        "System Preferences…",
        store:        "BookOS Store…",
        sleep:        "Sleep",
        restart:      "Restart…",
        shutdown:     "Shut Down…",
        lock:         "Lock Screen",
        logout:       "Log Out…",
        // About dialog
        moreInfo:     "More info…",
        chip:         "Chip",
        memory:       "Memory",
        serial:       "Serial number",
        os:           "BookOS",
        graphics:     "Graphics",
        regulatory:   "Regulatory Certification",
        rights:       "© 1983–2025 BookOS. All rights reserved.",
        unknown:      "Unknown"
    },
    es: {
        about:        "Acerca de este PC",
        prefs:        "Preferencias del sistema…",
        store:        "BookOS Store…",
        sleep:        "Dormir",
        restart:      "Reiniciar…",
        shutdown:     "Apagar…",
        lock:         "Pantalla de bloqueo",
        logout:       "Cerrar sesión…",
        moreInfo:     "Más información…",
        chip:         "Chip",
        memory:       "Memoria",
        serial:       "Número de serie",
        os:           "BookOS",
        graphics:     "Gráficos",
        regulatory:   "Certificación de normativas",
        rights:       "© 1983–2025 BookOS. Todos los derechos reservados.",
        unknown:      "Desconocido"
    }
};

function lang(locale) {
    if (locale && locale.toLowerCase().indexOf("es") === 0) return "es";
    return "en";
}

function tr(locale, key) {
    var l = lang(locale);
    return (S[l] && S[l][key]) || S.en[key] || key;
}
