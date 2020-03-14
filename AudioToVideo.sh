#!/usr/bin/env bash

# Create a slideshow or still image video for YouTube from an audio file,
# image and text input with a waveform animation.

# TODO Specify the colours of the waveform

# Configuration
FFMPEG_EXE=ffmpeg
TMP_METADATA_FILE=/tmp/$(echo ${$})-metadata.txt
EXIT_SUCCESS=0
EXIT_FAILURE=1

IMAGE_FILE=$1
AUDIO_FILE=$2
ARTIST=
TITLE=

IMG_TEXT=image-text.png
VIDEO_IMG=video-img.png
COVER_HD=
COVER_SND=
VIDEO_FILE=

extract_metadata () {
    # Handle missing metadata
    ffmpeg -i $AUDIO_FILE -f ffmetadata $TMP_METADATA_FILE
    ARTIST=`cat $TMP_METADATA_FILE | tr a-z A-Z | egrep "ARTIST" | cut -d '=' -f2`
    TITLE=`cat $TMP_METADATA_FILE | tr a-z A-Z | egrep "TITLE" | cut -d '=' -f2`

    if [ -z "$ARTIST" ] || [ -z "$TITLE" ]; then
        echo -e "A metadata field is missing in \"$AUDIO_FILE\": artist or title" 1>&2
        return 1
    else
        COVER_HD=${ARTIST}-${TITLE}-cover-hd.png
        COVER_SND=${ARTIST}-${TITLE}-cover-snd.png
        VIDEO_FILE=${ARTIST}-${TITLE}-video.mkv
        return 0
    fi
}

generate_full_hd_text_image_for_video () {
    convert -gravity southeast -splice 40x40 -gravity northwest -splice 40x40 \
    -font Helvetica-Bold -gravity Center -weight 700 -pointsize 100 caption:"$ARTIST\n$TITLE" $IMG_TEXT && \
    convert -gravity Center -resize 1920x1080^ -extent 1920x1080 "$IMG_TEXT" $COVER_HD && \
    echo "$COVER_HD generated" && \
    return 0 || return 1
}

merge_text_and_cover_for_video () {
    composite -dissolve 50 -gravity Center $IMG_TEXT $COVER_HD -alpha Set $VIDEO_IMG && \
    echo "$VIDEO_IMG generated" && \
    return 0 || return 1
}

convert_hd_image_for_soundcloud_cover () {
    convert -gravity Center -resize 1080x1080^ -extent 1080x1080 $VIDEO_IMG $COVER_SND && \
    echo "$COVER_SND generated" && \
    return 0 || return 1
}

generate_video () {
    $FFMPEG_EXE -i "$AUDIO_FILE" -loop 1 -i $VIDEO_IMG \
    -filter_complex "[0:a]showwaves=s=1920x200:mode=cline:colors=0xFFFFFF|0xD3D3D3:scale=sqrt[fg];[1:v]scale=1920:-1[bg];[bg][fg]overlay=shortest=1:850:format=auto,format=yuv420p[out]" \
    -map "[out]" -map 0:a -pix_fmt yuv420p -c:v libx264 -preset fast -crf 18 -c:a copy -shortest $VIDEO_FILE && \
    echo "$VIDEO_FILE generated" && \
    return 0 || return 1
}

audeo () {
    extract_metadata && \
    generate_full_hd_text_image_for_video && \
    merge_text_and_cover_for_video && \
    convert_hd_image_for_soundcloud_cover && \
    generate_video
    local AUDEO_RESULT=$?
    rm -f $TMP_METADATA_FILE
    rm -vf $IMG_TEXT $VIDEO_IMG
    return $AUDEO_RESULT
}

if [ -z "$IMAGE_FILE" ] || [ -z "$AUDIO_FILE" ]; then
    echo "Syntax:"
    echo `basename $0`" /path/to/image.[png|jpg] /path/to/audio_file.[flac|mp3|wav|ogg]"
else
    audeo
fi
