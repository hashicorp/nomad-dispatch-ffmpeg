#!/bin/bash
set -e

# Ensure we have at least an input file
if [ $# -eq 0 ]; then
    echo "Usage: transcode.sh <input file> <profile>"
    exit 1
fi

# Setup the S3 defaults, allow overwrite
BUCKET=${S3_BUCKET:-"armon-test-dispatch"}

# Store the various profile configurations
SMALL="-vf scale=640:-1 -c:v libx264 -preset medium -crf 30 -c:a aac -b:a 128k -profile:v high -level 4.0"
LARGE="-vf scale=1280:-1 -c:v libx264 -preset medium -crf 25 -c:a aac -b:a 192k -profile:v high -level 4.0"

# Default to small
PROFILE=$SMALL
PROFILE_NAME="small"

# Check for override
if [ "$2" == "large" ]; then
    PROFILE=$LARGE
    PROFILE_NAME="large"
fi
echo "Profile: ${PROFILE_NAME}"

# Get the input file
INPUT=$1
echo "Input file: $INPUT"

# Fetch the input file if via http(s)
if [[ $INPUT == http* ]]; then
    echo "Fetching input"
    wget $INPUT -O input
    INPUT="input"
fi

# Check that the input file exists
if [ ! -e $INPUT ]; then
    echo "Missing input file!"
    exit 1
fi

# Dump the MD5
MD5=`md5sum $INPUT | cut -f1 -d " "`
echo "Input MD5: $MD5"

# Convert the file
OUT="out-$MD5-${PROFILE_NAME}.mp4"
echo "Output file: $OUT"

# Only attempt conversion if the output file does not exist
if [ ! -e $OUT ]; then
	echo "Starting conversion"
	ffmpeg -n -i $INPUT $PROFILE $OUT
	echo "Conversion done"
fi

# Upload to S3
s3cmd put -c local/s3cfg.ini $OUT "s3://$BUCKET/videos/${OUT}"

