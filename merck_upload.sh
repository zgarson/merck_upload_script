#!/bin/bash

# ---------------------------------------------------------------------------
# Resolve the directory this script lives in, so the support script is found
# no matter where the repo was cloned or how the script was invoked.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECORD_COUNT_SCRIPT="$SCRIPT_DIR/record_count_v3.sh"

# ---------------------------------------------------------------------------
# Config — written on first run, reused on every run after that.
# ---------------------------------------------------------------------------
CONFIG_DIR="$HOME/.config/merck_upload"
CONFIG_FILE="$CONFIG_DIR/config"

prompt_path() {
    # $1 = prompt text, $2 = name of variable to set
    local prompt="$1" varname="$2" input=""
    while true; do
        read -r -e -p "$prompt" input
        # expand a leading ~ to the home directory
        input="${input/#\~/$HOME}"
        # strip a trailing slash
        input="${input%/}"
        if [ -z "$input" ]; then
            echo "  Path cannot be empty."
            continue
        fi
        printf -v "$varname" '%s' "$input" 2>/dev/null || eval "$varname=\$input"
        return 0
    done
}

run_setup() {
    echo "----------------------------------------------------------"
    echo " Merck Upload — first-time setup"
    echo "----------------------------------------------------------"
    echo "These paths are saved to $CONFIG_FILE"
    echo "and reused automatically on every future run."
    echo

    prompt_path "Upload staging directory (where dated folders are created): " UPLOAD_DIR
    if [ ! -d "$UPLOAD_DIR" ]; then
        read -r -p "  '$UPLOAD_DIR' does not exist. Create it? [y/N] " reply
        case "$reply" in
            [Yy]*) mkdir -p "$UPLOAD_DIR" || { echo "  ERROR: could not create it."; exit 1; } ;;
            *) echo "  Aborting — staging directory is required."; exit 1 ;;
        esac
    fi

    echo
    prompt_path "Full path to the RELEVATE audit file (.txt): " AUDIT_FILE
    audit_parent="$(dirname "$AUDIT_FILE")"
    if [ ! -d "$audit_parent" ]; then
        echo "  WARNING: '$audit_parent' is not currently reachable."
        echo "  If this lives on the CloudMounter share, mount it before running the upload."
        read -r -p "  Save this path anyway? [y/N] " reply
        case "$reply" in
            [Yy]*) ;;
            *) echo "  Aborting."; exit 1 ;;
        esac
    fi

    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
# Merck Upload configuration
# Written $(date '+%Y-%m-%d %H:%M:%S')
# Re-run the script with --reconfigure to change these values.
UPLOAD_DIR="$UPLOAD_DIR"
AUDIT_FILE="$AUDIT_FILE"
EOF
    chmod 600 "$CONFIG_FILE"

    echo
    echo "Saved:"
    echo "  UPLOAD_DIR = $UPLOAD_DIR"
    echo "  AUDIT_FILE = $AUDIT_FILE"
    echo "----------------------------------------------------------"
    echo
}

# --reconfigure forces the setup prompts to run again
if [ "$1" == "--reconfigure" ]; then
    run_setup
    echo "Configuration updated. Re-run the script with your source directory."
    exit 0
fi

# Load saved config, or run setup if this is the first execution
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

if [ -z "$UPLOAD_DIR" ] || [ -z "$AUDIT_FILE" ]; then
    run_setup
fi

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
SOURCE_DIR="${1:?Usage: $0 <source_directory> [test]   |   $0 --reconfigure}"
# test the process without actually uploading the files for new users
TEST_MODE=$2
CURRENT_DATE=$(date +%Y%m%d)

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: source directory does not exist: $SOURCE_DIR"
    exit 1
fi
if [ ! -x "$RECORD_COUNT_SCRIPT" ]; then
    echo "ERROR: support script not found or not executable: $RECORD_COUNT_SCRIPT"
    echo "Run: chmod +x \"$RECORD_COUNT_SCRIPT\""
    exit 1
fi
if [ ! -d "$(dirname "$AUDIT_FILE")" ]; then
    echo "ERROR: audit file directory is not reachable: $(dirname "$AUDIT_FILE")"
    echo "If it lives on the CloudMounter share, mount it and try again."
    exit 1
fi

# ---------------------------------------------------------------------------
# create a new directory with the current date
# if uploading multiple times in a day, create a new directory with
# "<CURRENT_DATE>_n" to avoid overwriting previous uploads
# ---------------------------------------------------------------------------
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

# copy the files from given directory to the new directory
find "$SOURCE_DIR" -name "*.txt" -exec cp {} "$UPLOAD_FOLDER/" \;

# add the new PLD lines to the merck audit file
"$RECORD_COUNT_SCRIPT" "$SOURCE_DIR" "$AUDIT_FILE"

# copy the updated merck audit file to the new directory
cp "$AUDIT_FILE" "$UPLOAD_FOLDER/"

if [ "$TEST_MODE" == "test" ]; then
    echo "Test mode enabled. Files copied to $UPLOAD_FOLDER but not uploaded."
else
    # upload the files to the S3 bucket
    aws s3 cp "$UPLOAD_FOLDER" "s3://com-merck-ghhusdw-prod-relevatehealth/inbound/ACE/" --recursive --profile mercks3access
    echo "Upload process completed. Files are in $UPLOAD_FOLDER."
fi
