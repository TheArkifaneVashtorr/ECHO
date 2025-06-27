#!/bin/bash

# --- Configuration ---
ECHO_REPO_BASE_URL="https://raw.githubusercontent.com/TheArkifaneVashtorr/ECHO/main"
SCRIPT_NAME="echo.sh"
CHECKSUM_FILE_NAME="${SCRIPT_NAME}.sha256"

# The full path to the script to be updated.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"
TEMP_SCRIPT_PATH="${SCRIPT_PATH}.new"
TEMP_CHECKSUM_PATH="${SCRIPT_DIR}/${CHECKSUM_FILE_NAME}.new"

# --- Logging ---
log() {
    # Logs a message with a timestamp. Redirects stdout to stderr for cron job visibility.
    echo "[ECHO-Updater] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# --- Cleanup ---
cleanup() {
    rm -f "${TEMP_SCRIPT_PATH}" "${TEMP_CHECKSUM_PATH}"
}

# --- Main Logic ---
log "Update process initiated by echo.sh."

# Ensure cleanup happens on script exit
trap cleanup EXIT

# 1. Download the new version and its checksum file
log "Downloading new script from ${ECHO_REPO_BASE_URL}/${SCRIPT_NAME}..."
http_status_script=$(curl -s -w "%{http_code}" -L "${ECHO_REPO_BASE_URL}/${SCRIPT_NAME}" -o "${TEMP_SCRIPT_PATH}")

if [ "$http_status_script" -ne 200 ]; then
    log "ERROR: Script download failed. HTTP status code: ${http_status_script}. Aborting update."
    exit 1
fi

log "Downloading checksum file from ${ECHO_REPO_BASE_URL}/${CHECKSUM_FILE_NAME}..."
http_status_checksum=$(curl -s -w "%{http_code}" -L "${ECHO_REPO_BASE_URL}/${CHECKSUM_FILE_NAME}" -o "${TEMP_CHECKSUM_PATH}")

if [ "$http_status_checksum" -ne 200 ]; then
    log "ERROR: Checksum download failed. HTTP status code: ${http_status_checksum}. Aborting update."
    exit 1
fi

# 2. Verify the downloaded files are not empty
if [ ! -s "${TEMP_SCRIPT_PATH}" ] || [ ! -s "${TEMP_CHECKSUM_PATH}" ]; then
    log "ERROR: Verification failed. Downloaded script or checksum file is empty. Aborting update."
    exit 1
fi
log "Downloads successful."

# 3. Verify the checksum
log "Verifying file integrity..."
# The checksum file from GitHub may have extra text, so we extract the hash
REMOTE_CHECKSUM=$(awk '{print $1}' "${TEMP_CHECKSUM_PATH}")
LOCAL_CHECKSUM=$(sha256sum "${TEMP_SCRIPT_PATH}" | awk '{print $1}')

if [ "$LOCAL_CHECKSUM" != "$REMOTE_CHECKSUM" ]; then
    log "ERROR: CHECKSUM MISMATCH!"
    log "  - Expected: ${REMOTE_CHECKSUM}"
    log "  - Got:      ${LOCAL_CHECKSUM}"
    log "The downloaded file may be corrupt or tampered with. Aborting update."
    exit 1
fi
log "Checksum VERIFIED. File integrity is confirmed."

# 4. Set permissions on the new script
chmod +x "${TEMP_SCRIPT_PATH}"
if [ $? -ne 0 ]; then
    log "ERROR: Failed to set execute permissions on the new script. Aborting update."
    exit 1
fi
log "Execute permissions set on new script."

# 5. Atomically replace the old script with the new one
mv "${TEMP_SCRIPT_PATH}" "${SCRIPT_PATH}"
if [ $? -ne 0 ]; then
    log "ERROR: Failed to replace the old script with the new one. Update failed."
    exit 1
fi

log "SUCCESS: ${SCRIPT_NAME} has been updated to the latest version."
exit 0
