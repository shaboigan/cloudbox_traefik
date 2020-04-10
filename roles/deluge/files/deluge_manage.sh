#!/bin/sh

CURRENT=$(df / | grep / | awk '{ print $5}' | sed 's/%//g')
PAUSE=90
RESUME=40

# check if a pause command needs to be sent
  if [ "$CURRENT" -ge "$PAUSE" ] ; then
# check if pause lock file exists
    if [ -e /opt/scripts/torrents/deluge/pause.lock ]; then
        echo "deluge is already paused, exiting"
        exit
    else
# create a pause lock file and remove resume lock file
        touch /opt/scripts/torrents/deluge/pause.lock && rm /opt/scripts/torrents/deluge/resume.lock
        /opt/scripts/system/slack_deluge.sh "Running out of space on $(hostname), Currently \"($CURRENT%)\" used as of $(date) - pausing deluge queue" && docker exec deluge deluge-console "connect 127.0.0.1:58846 plex deluge ; pause *"
    fi
# check if a resume command needs to be sent
  elif [ "$CURRENT" -le "$RESUME" ] ; then
# check if resume lock file exists
    if [ -e /opt/scripts/torrents/deluge/resume.lock ]; then
        echo "deluge is already resumed, exiting"
        exit
    else
# create a resume lock file and remove pause lock file
        touch /opt/scripts/torrents/deluge/resume.lock && rm /opt/scripts/torrents/deluge/pause.lock
        /opt/scripts/system/slack_deluge.sh "Space available on $(hostname), Currently \"($CURRENT%)\" used as of $(date) - resuming deluge queue" && docker exec deluge deluge-console "connect 127.0.0.1:58846 plex deluge ; resume *"
    fi
  fi

