#!/bin/sh
set -eu

downloadsPath="/downloads"
profilePath="/config"
qbtConfigFile="$profilePath/qBittorrent/config/qBittorrent.conf"

isRoot="0"
if [ "$(id -u)" = "0" ]; then
    isRoot="1"
fi

if [ "$isRoot" = "1" ]; then
    if [ -n "${PUID:-}" ] && [ "$PUID" != "$(id -u qbtuser)" ]; then
        usermod -o -u "$PUID" qbtuser
    fi

    if [ -n "${PGID:-}" ] && [ "$PGID" != "$(id -g qbtuser)" ]; then
        groupmod -o -g "$PGID" qbtuser
    fi

    if [ -n "${PAGID:-}" ]; then
        _origIFS="$IFS"
        IFS=','
        for AGID in $PAGID; do
            AGID=$(echo "$AGID" | tr -d '[:space:]"')
            groupadd -g "$AGID" "qbtgroup-$AGID" 2>/dev/null || true
            usermod -aG "qbtgroup-$AGID" qbtuser 2>/dev/null || true
        done
        IFS="$_origIFS"
    fi
fi

if [ ! -f "$qbtConfigFile" ]; then
    mkdir -p "$(dirname "$qbtConfigFile")"
    cat <<EOF >"$qbtConfigFile"
[BitTorrent]
Session\\DefaultSavePath=$downloadsPath
Session\\Port=6881
Session\\TempPath=$downloadsPath/temp
[Preferences]
WebUI\\Port=8080
EOF
fi

argLegalNotice=""
_legalNotice=$(echo "${QBT_LEGAL_NOTICE:-}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
if [ "$_legalNotice" = "confirm" ]; then
    argLegalNotice="--confirm-legal-notice"
fi

argTorrentingPort=""
if [ -n "${QBT_TORRENTING_PORT:-}" ]; then
    argTorrentingPort="--torrenting-port=$QBT_TORRENTING_PORT"
fi

argWebUIPort=""
if [ -n "${QBT_WEBUI_PORT:-}" ]; then
    argWebUIPort="--webui-port=$QBT_WEBUI_PORT"
fi

if [ "$isRoot" = "1" ]; then
    if [ -d "$downloadsPath" ]; then
        chown qbtuser:qbtuser "$downloadsPath"
    fi
    if [ -d "$profilePath" ]; then
        chown -R qbtuser:qbtuser "$profilePath"
    fi
fi

if [ -n "${UMASK:-}" ]; then
    umask "$UMASK"
fi

if command -v ionice >/dev/null 2>&1 && ionice -c 2 -n 7 true >/dev/null 2>&1
then
    argIonice="ionice -c 2 -n 7"
fi

if [ "$isRoot" = "1" ]; then
    exec $argIonice gosu qbtuser qbittorrent-nox \
        $argLegalNotice \
        --profile="$profilePath" \
        $argTorrentingPort \
        $argWebUIPort \
        "$@"
else
    exec $argIonice qbittorrent-nox \
        $argLegalNotice \
        --profile="$profilePath" \
        $argTorrentingPort \
        $argWebUIPort \
        "$@"
fi
