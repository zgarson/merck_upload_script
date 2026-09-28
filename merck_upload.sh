#!/bin/bash

SOURCE_DIR=$1
# test the process without actually uploading the files for new users
TEST_MODE=$2
UPLOAD_DIR='/Users/zachgarson/Data_Engineering/Merck Weekly PLDs'
CURRENT_DATE=$(date +%Y%m%d)
AUDIT_FILE="/Users/zachgarson/Library/CloudStorage/CloudMounter-rh-data-processing/DataFeeds/audit_files/Merck/RELEVATE_Audit_2026.txt"

# create a new directory with the current date
# if uploading multiple times in a day, create a new directory with "<CURRENT_DATE>_n" to avoid overwriting previous uploads
if [ -d "$UPLOAD_DIR/$CURRENT_DATE" ]; then
    n=2
    while [ -d "$UPLOAD_DIR/${CURRENT_DATE}_$n" ]; do
        ((n++))
    done
    echo "Directory $UPLOAD_DIR/$CURRENT_DATE already exists. Creating a new directory with suffix _$n."
    CURRENT_DATE="${CURRENT_DATE}_$n"
    mkdir -p "$UPLOAD_DIR/${CURRENT_DATE}"
    UPLOAD_FOLDER="$UPLOAD_DIR/${CURRENT_DATE}"
else
    mkdir -p "$UPLOAD_DIR/$CURRENT_DATE"
    echo "Creating directory $UPLOAD_DIR/$CURRENT_DATE"
    UPLOAD_FOLDER="$UPLOAD_DIR/$CURRENT_DATE"
fi

#copy the files from given directory to the new directory
find "$SOURCE_DIR" -name "*.txt" -exec cp {} "$UPLOAD_FOLDER/" \;

# add the new PLD lines to the merck audit file
/Users/zachgarson/Data_Engineering/Bash_Scripts/merck_upload/merck_record_count/record_count_v3.sh "$SOURCE_DIR" "$AUDIT_FILE"

# copy the updated merck audit file to the new directory
cp "$AUDIT_FILE" "$UPLOAD_FOLDER/"

if [ "$TEST_MODE" == "test" ]; then
    echo "Test mode enabled. Files copied to $UPLOAD_FOLDER but not uploaded."
else
    # upload the files to the SFTP server
    aws s3 cp "$UPLOAD_FOLDER" "s3://com-merck-ghhusdw-prod-relevatehealth/inbound/ACE/" --recursive --profile mercks3access
    echo "Upload process completed. Files are in $UPLOAD_FOLDER."
fi







