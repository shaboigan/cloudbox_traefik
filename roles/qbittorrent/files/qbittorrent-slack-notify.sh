#!/bin/bash

# A shell scirpt designed to be executed by qBittorrent's "Run external program on torrent completion"
# This scirpt will send a Slack notification using Slack's Incoming Webhooks with the information of completed torrent
#
# An example how to fill in qBittorrent's "Run external program on torrent completion" to execute this script
# /bin/bash -c "chmod +x /path/to/qbittorrent-slack-notify.sh; /path/to/qbittorrent-slack-notify.sh '%N' '%Z' 'https://hooks.slack.com/services/XXXXXXXXX/YYYYYYYYY/ZZZZZZZZZZZZZZZZZZZZZZZZ'"
#
# Supported parameters (case sensitive):
# - %N: Torrent name
# - %L: Category
# - %G: Tags (separated by comma)
# - %F: Content path (same as root path for multifile torrent)
# - %R: Root path (first torrent subdirectory path)
# - %D: Save path
# - %C: Number of files
# - %Z: Torrent size (bytes)
# - %T: Current tracker
# - %I: Info hash

# https://unix.stackexchange.com/a/259254
bytesToHuman() {
    b=${1:-0}; d=''; s=0; S=(Bytes {K,M,G,T,P,E,Y,Z}iB)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        let s++
    done
    echo "$b$d ${S[$s]}"
}

name="$1"
if [ -z "$name" ]; then 
    echo "ERROR: Expected <name> as the 1st argument but none given, <name> should be the Torrent name (\"%N\") from qBittorrent"
    exit 1
fi

sizeBytes="$2"
if [ -z "$sizeBytes" ]; then 
    echo "ERROR: Expected <size> as the 2nd argument but none given, <size> should be the Torrent size (bytes) (\"%Z\") from qBittorrent"
    exit 1
fi
size=`bytesToHuman $sizeBytes`

slack_webhook="$3"
if [ -z "$slack_webhook" ]; then 
    echo "ERROR: Expected <slack_webhook> as the 3rd argument but none given, <slack_webhook> should be the incoming webhook for a channel obtained from Slack"
    exit 1
fi

ts=`date "+%s"`

/usr/bin/curl -sS \
    -X POST \
    -H 'Content-type: application/json' \
    --data "{\"attachments\":[{\"fallback\":\"<!channel> :white_check_mark: Download completed - $name\",\"color\":\"good\",\"pretext\":\"<!channel> :white_check_mark: Download completed - $name\",\"fields\":[{\"title\":\"Name\",\"value\":\"$name\",\"short\":false},{\"title\":\"Size\",\"value\":\"$size\",\"short\":false}],\"footer\":\"qBittorrent\",\"footer_icon\":\"https://i.imgur.com/rEWsu2c.png\",\"ts\":$ts}]}" \
    $slack_webhook