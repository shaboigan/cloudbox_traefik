#!/bin/sh
INPUT=/mnt/local/handbrake/source
OUTPUT=/mnt/local/handbrake/output
WATCH=/mnt/local/handbrake/watch
RADARR=/mnt/local/handbrake/radarr
ERROR=/mnt/local/handbrake/error
UPPER=2200000
LOWER=2050000
CRF=26.0
COUNTER=0

# check if an encode lock file exists
FILE_COUNT=$(ls $INPUT -1 | wc -l)
if [ "$FILE_COUNT" -lt 1 ]; then
    /opt/scripts/system/slack_handbrake_admin.sh "No files in the queue to process"
    exit
else
    /opt/scripts/system/slack_handbrake_admin.sh "Processing $FILE_COUNT files"
fi

while [ -e /opt/scripts/handbrake/handbrake.lock ]; do
    echo "encode is already running, sleeping"
    sleep 1800
done
touch /opt/scripts/handbrake/handbrake.lock

for FILE in "$INPUT"/*; do
    filename=$(basename "$FILE")
    extension=${filename##*.}
    filename=${filename%.*}
    NAME=$filename.$extension

    # start encode of file
    mv $INPUT/"$NAME" $WATCH/$CRF/
    /opt/scripts/system/slack_handbrake.sh "Running encode of $NAME, using CRF$CRF at $(date)"
    until [ -e "$OUTPUT"/"$filename".mp4 ]; do
        sleep 10
    done
    sleep 10
    BITRATE=`mediainfo --Inform="Video;%BitRate%" "$OUTPUT"/"$filename".mp4`
    RESULTS=`mediainfo "$OUTPUT"/"$filename".mp4`
    /opt/scripts/system/slack_handbrake.sh "$NAME CRF$CRF encoding results = $RESULTS"

    # check if file bitrate is between limits
    while [ "$BITRATE" -lt "$LOWER" ]; do
        if [ 1 -eq "$(echo "${CRF} > 26" | bc)" ] ;then
            mv "$OUTPUT"/"$filename".mp4 $ERROR && mv $WATCH/$CRF/"$NAME" $ERROR
            break
        else
            if [ "$COUNTER" -lt 4 ]; then
                COUNTER=$(( $COUNTER + 1 ))
                mv $WATCH/$CRF/"$NAME" $INPUT/"$NAME" && rm "$OUTPUT"/"$filename".mp4
                CRF=$(echo "scale=1; $CRF - 0.5" | bc -l)
                mv $INPUT/"$NAME" $WATCH/$CRF/
                /opt/scripts/system/slack_handbrake.sh "Running encode of $NAME, using CRF$CRF at $(date)"
                until [ -e "$OUTPUT"/"$filename".mp4 ]; do
                    sleep 10
                done
                sleep 10
                BITRATE=`mediainfo --Inform="Video;%BitRate%" "$OUTPUT"/"$filename".mp4`
                RESULTS=`mediainfo "$OUTPUT"/"$filename".mp4`
                /opt/scripts/system/slack_handbrake.sh "$NAME CRF$CRF encoding results = $RESULTS"
            else
            	mv $WATCH/$CRF/"$NAME" $ERROR && rm "$OUTPUT"/"$filename".mp4
                break
            fi
        fi
    done

    while [ "$BITRATE" -gt "$UPPER" ]; do
        if [ 1 -eq "$(echo "${CRF} < 26" | bc)" ] ;then
            mv "$OUTPUT"/"$filename".mp4 $ERROR && mv $WATCH/$CRF/"$NAME" $ERROR
            break
        else
            if [ "$COUNTER" -lt 8 ]; then
            	COUNTER=$(( $COUNTER + 1 ))
                mv $WATCH/$CRF/"$NAME" $INPUT/"$NAME" && rm "$OUTPUT"/"$filename".mp4
                CRF=$(echo "scale=1; $CRF + 0.5" | bc -l)
                mv $INPUT/"$NAME" $WATCH/$CRF/
                /opt/scripts/system/slack_handbrake.sh "Running encode of $NAME, using CRF$CRF at $(date)"
                until [ -e "$OUTPUT"/"$filename".mp4 ]; do
                    sleep 10
                done
                sleep 10
                BITRATE=`mediainfo --Inform="Video;%BitRate%" "$OUTPUT"/"$filename".mp4`
                RESULTS=`mediainfo "$OUTPUT"/"$filename".mp4`
                /opt/scripts/system/slack_handbrake.sh "$NAME CRF$CRF encoding results = $RESULTS"
            else
            	mv $WATCH/$CRF/"$NAME" $ERROR && rm "$OUTPUT"/"$filename".mp4
                break
            fi
        fi
    done

    sleep 30
    if [ -e "$OUTPUT"/"$filename".mp4 ]; then
        AtomicParsley "$OUTPUT"/"$filename".mp4 --title "" --overWrite
        mv "$OUTPUT"/"$filename".mp4 "$RADARR" && rm $WATCH/$CRF/"$NAME"
        /opt/scripts/system/slack_handbrake.sh "Encoding of $NAME completed, using CRF$CRF at $(date)"
    elif [ -e "$ERROR"/"$filename".mp4 ]; then
        /opt/scripts/system/slack_handbrake.sh "Encode of $NAME stuck in loop, moving files to $ERROR"
    else
    	/opt/scripts/system/slack_handbrake.sh "Unable to encode $NAME to the required bitrate with the available presets"
    fi
    CRF=26.0
    COUNTER=0
done
rm /opt/scripts/handbrake/handbrake.lock
