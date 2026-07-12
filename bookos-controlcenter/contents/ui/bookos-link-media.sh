#!/usr/bin/env bash
# BookOS-Link media bridge — control the phone's media player over KDE Connect.
# Reads/writes the org.kde.kdeconnect mprisremote D-Bus interface via busctl.
#
#   bookos-link-media.sh status              -> KEY=VALUE lines for the active phone player
#   bookos-link-media.sh action <Action>     -> PlayPause | Next | Previous | Play | Pause | Stop
#
# Exit is always 0 so the QML executable DataSource keeps polling.

set -u

DEST="org.kde.kdeconnect"
ROOT="/modules/kdeconnect"
DAEMON_IFACE="org.kde.kdeconnect.daemon"
DEV_IFACE="org.kde.kdeconnect.device"
MPRIS_IFACE="org.kde.kdeconnect.device.mprisremote"

bc() { busctl --user "$@" 2>/dev/null; }

# Strip busctl's leading type tag ("s ", "b ", "i ", "x ", "u "…) and surrounding
# quotes, then undo busctl's backslash escaping (\" \\ \' etc.).
unwrap() {
    local v="$1"
    v="${v#* }"          # drop "<type> "
    v="${v#\"}"          # drop leading quote
    v="${v%\"}"          # drop trailing quote
    printf '%s' "$v" | sed -E 's/\\(.)/\1/g'
}

getprop() { unwrap "$(bc get-property "$DEST" "$1" "$2" "$3")"; }

# Space-separated list of reachable+paired device ids.
device_ids() {
    # returns:  as N "id1" "id2" ...
    local raw
    raw="$(bc call "$DEST" "$ROOT" "$DAEMON_IFACE" devices bb true true)"
    [ -z "$raw" ] && return
    # keep only the quoted tokens
    printf '%s\n' "$raw" | grep -oE '"[^"]+"' | tr -d '"'
}

status() {
    local id path name title artist album playing length pos players
    for id in $(device_ids); do
        path="$ROOT/devices/$id/mprisremote"
        # Skip devices without the mprisremote plugin loaded.
        players="$(getprop "$path" "$MPRIS_IFACE" playerList)"
        title="$(getprop "$path" "$MPRIS_IFACE" title)"
        # A device is "active" for us if it exposes a player with a title.
        if [ -n "$title" ] || [ -n "$players" ]; then
            name="$(getprop "$ROOT/devices/$id" "$DEV_IFACE" name)"
            artist="$(getprop "$path" "$MPRIS_IFACE" artist)"
            album="$(getprop "$path" "$MPRIS_IFACE" album)"
            length="$(getprop "$path" "$MPRIS_IFACE" length)"
            pos="$(getprop "$path" "$MPRIS_IFACE" position)"
            playing="$(getprop "$path" "$MPRIS_IFACE" isPlaying)"
            canseek="$(getprop "$path" "$MPRIS_IFACE" canSeek)"
            art="$(getprop "$path" "$MPRIS_IFACE" localAlbumArtUrl)"
            printf 'AVAIL=1\n'
            printf 'ID=%s\n' "$id"
            printf 'DEV=%s\n' "$name"
            printf 'PLAYING=%s\n' "$playing"
            printf 'TITLE=%s\n' "$title"
            printf 'ARTIST=%s\n' "$artist"
            printf 'ALBUM=%s\n' "$album"
            printf 'LENGTH=%s\n' "${length:-0}"
            printf 'POS=%s\n' "${pos:-0}"
            printf 'CANSEEK=%s\n' "${canseek:-false}"
            printf 'ART=%s\n' "$art"
            return
        fi
    done
    printf 'AVAIL=0\n'
}

action() {
    local act="$1" id path
    for id in $(device_ids); do
        path="$ROOT/devices/$id/mprisremote"
        if [ -n "$(getprop "$path" "$MPRIS_IFACE" title)" ] || \
           [ -n "$(getprop "$path" "$MPRIS_IFACE" playerList)" ]; then
            bc call "$DEST" "$path" "$MPRIS_IFACE" sendAction s "$act" >/dev/null
            break
        fi
    done
}

# Seek the active phone player to an absolute position in milliseconds.
seekto() {
    local ms="$1" id path
    for id in $(device_ids); do
        path="$ROOT/devices/$id/mprisremote"
        if [ -n "$(getprop "$path" "$MPRIS_IFACE" title)" ] || \
           [ -n "$(getprop "$path" "$MPRIS_IFACE" playerList)" ]; then
            bc set-property "$DEST" "$path" "$MPRIS_IFACE" position i "$ms" >/dev/null
            break
        fi
    done
}

# Best-effort album art for LOCAL players when the active MPRIS player exposes
# none (e.g. plasma-browser-integration on YouTube). Scans sibling MPRIS players
# for a real artUrl; falls back to the YouTube thumbnail from xesam:url.
localart() {
    local svc meta art url="" id=""
    for svc in $(busctl --user list 2>/dev/null | grep -oE 'org\.mpris\.MediaPlayer2\.[^ ]+' | sort -u); do
        case "$svc" in *kdeconnect*) continue ;; esac
        meta="$(busctl --user get-property "$svc" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Metadata 2>/dev/null)"
        art="$(printf '%s' "$meta" | grep -oE '"mpris:artUrl" s "[^"]*"' | sed -E 's/.*s "([^"]*)"/\1/')"
        if [ -n "$art" ]; then printf '%s\n' "$art"; return; fi
        [ -z "$url" ] && url="$(printf '%s' "$meta" | grep -oE '"xesam:url" s "[^"]*"' | sed -E 's/.*s "([^"]*)"/\1/')"
    done
    case "$url" in
        *youtu.be/*)          id="${url##*youtu.be/}"; id="${id%%\?*}" ;;
        *youtube.com/watch*)  id="${url##*v=}";        id="${id%%&*}" ;;
    esac
    [ -n "$id" ] && printf 'https://i.ytimg.com/vi/%s/hqdefault.jpg\n' "$id"
}

case "${1:-status}" in
    status)    status ;;
    action)    [ $# -ge 2 ] && action "$2" ;;
    position)  [ $# -ge 2 ] && seekto "$2" ;;
    localart)  localart ;;
    *)         printf 'AVAIL=0\n' ;;
esac
exit 0
