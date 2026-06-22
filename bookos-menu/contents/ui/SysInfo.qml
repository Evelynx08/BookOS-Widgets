/*
    SysInfo — collects machine facts via shell one-shots.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.plasma.plasma5support 2.0 as P5Support

Item {
    id: root

    property string model:    ""
    property string chip:     ""
    property string memory:   ""
    property string serial:   ""
    property string osName:   ""
    property string osVersion: ""
    property string graphics: ""

    // Laptop render for the detected model. Add per-model files named
    // laptop-<slug>.png (e.g. laptop-book4pro.png) and they're picked up
    // automatically; otherwise the generic Book render is used.
    readonly property url modelImage: {
        var m = (model || "").toLowerCase().replace(/\s+/g, "")
        var known = ["book5pro", "book4pro", "book5", "book4", "book3pro", "book3"]
        for (var i = 0; i < known.length; i++)
            if (m.indexOf(known[i]) !== -1) {
                // prefer a model-specific render if present, else generic
                if (modelFiles.indexOf("laptop-" + known[i] + ".png") !== -1)
                    return Qt.resolvedUrl("../icons/laptop-" + known[i] + ".png")
                break
            }
        return Qt.resolvedUrl("../icons/generic_book2.png")
    }
    // List of model-specific render filenames that exist (extend as you add).
    readonly property var modelFiles: []

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []

        property var pending: ({})

        function run(tag, cmd) {
            connectSource("echo BOOKOS_TAG=" + tag + "; " + cmd)
        }

        onNewData: function(source, data) {
            disconnectSource(source)
            var out = (data["stdout"] || "").trim()
            var m = out.match(/^BOOKOS_TAG=(\w+)\n?([\s\S]*)$/)
            if (!m) return
            var tag = m[1]
            var val = (m[2] || "").trim()
            switch (tag) {
                case "model":    root.model    = val; break
                case "chip":     root.chip     = val; break
                case "mem":      root.memory   = val; break
                case "serial":   root.serial   = val; break
                case "os":       root.osName   = val; break
                case "ver":      root.osVersion = val; break
                case "gpu":      root.graphics = val; break
            }
        }
    }

    function refresh() {
        // Model name: friendly marketing name. Map known DMI codes, else use
        // product_family / product_version, else the raw product_name.
        exec.run("model",
            "P=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null);" +
            "F=$(cat /sys/devices/virtual/dmi/id/product_family 2>/dev/null);" +
            "case \"$P\" in" +
            "  940XHA*) echo 'Book5 Pro' ;;" +
            "  *) if [ -n \"$F\" ] && ! echo \"$F\" | grep -qiE 'to be filled|default|^$'; then echo \"$F\"; else echo \"${P:-PC}\"; fi ;;" +
            "esac")
        // Chip: CPU model name, stripped of (R)/(TM)/CPU noise
        exec.run("chip",
            "LANG=C lscpu 2>/dev/null | grep -m1 'Model name' | sed 's/.*: *//' " +
            "| sed -E 's/\\(R\\)//g; s/\\(TM\\)//g; s/ CPU.*//; s/ @.*//; s/  */ /g; s/^ *//; s/ *$//'")
        // Memory: physical RAM, rounded up to nearest 4 GB (marketing size)
        exec.run("mem",
            "awk '/MemTotal/{gb=$2/1024/1024; n=int((gb+3.999)/4)*4; printf \"%d GB\", n}' /proc/meminfo")
        // Serial: DMI is root-only. Try a direct read (in case it's readable),
        // else the privileged helper via polkit (no password for active session,
        // nothing cached — works on any install/VM). Falls back to —.
        exec.run("serial",
            "v=$(cat /sys/devices/virtual/dmi/id/product_serial 2>/dev/null);" +
            "if [ -z \"$v\" ] && [ -x /usr/libexec/bookos-serial ]; then" +
            "  v=$(pkexec /usr/libexec/bookos-serial 2>/dev/null);" +
            "fi;" +
            "echo \"$v\" | grep -vi -e '^$' -e 'none' -e 'default' || echo —")
        // OS: pretty name
        exec.run("os",
            "(. /etc/os-release 2>/dev/null; echo \"$PRETTY_NAME\")")
        // BookOS version: VERSION → VERSION_ID → BUILD_ID → fallback
        exec.run("ver",
            "(. /etc/os-release 2>/dev/null; echo \"${VERSION:-${VERSION_ID:-${BUILD_ID:-1.0}}}\")")
        // GPU: short form -> e.g. 'Intel Arc 140V', 'NVIDIA RTX 4070'
        exec.run("gpu",
            "G=$(LANG=C lspci 2>/dev/null | grep -m1 -iE 'vga|3d|display' | sed 's/.*: //');" +
            "ven=$(echo \"$G\" | grep -oiE 'intel|nvidia|amd|radeon' | head -1);" +
            "case \"$ven\" in" +
            "  [Nn]*) ven=NVIDIA ;; [Aa]*|[Rr]*) ven=AMD ;; [Ii]*) ven=Intel ;; esac;" +
            "mod=$(echo \"$G\" | grep -oiE 'arc|radeon|geforce|rtx|gtx|iris|uhd' | head -1);" +
            "num=$(echo \"$G\" | grep -oiE '[0-9]{3,4}V|RTX [0-9]+|GTX [0-9]+|RX [0-9]+|[0-9]{3,4}' | tail -1);" +
            "out=$(echo \"$ven $mod $num\" | sed -E 's/  */ /g; s/^ *//; s/ *$//');" +
            "[ -n \"$out\" ] && echo \"$out\" || echo \"$G\"")
    }

    Component.onCompleted: refresh()
}
