#!/bin/bash

# --- Configuration ---
ECHO_REPO_URL="https://raw.githubusercontent.com/TheArkifaneVashtorr/ECHO/main/echo.sh"

# The name of the script we are updating.
SCRIPT_NAME="echo.sh"

# The full path to the script to be updated.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"
TEMP_SCRIPT_PATH="${SCRIPT_PATH}.new"

# --- Logging ---
log() {
    # Logs a message with a timestamp. Redirects stdout to stderr for cron job visibility.
    echo "[ECHO-Updater] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# --- Main Logic ---
log "Update process initiated by echo.sh."

# 1. Download the new version to a temporary file
log "Downloading new version from ${ECHO_REPO_URL}..."
http_status=$(curl -s -w "%{http_code}" -L "${ECHO_REPO_URL}" -o "${TEMP_SCRIPT_PATH}")

if [ "$http_status" -ne 200 ]; then
    log "ERROR: Download failed. HTTP status code: ${http_status}. Leaving current version intact."
    rm -f "${TEMP_SCRIPT_PATH}"
    exit 1
fi

# 2. Verify the downloaded file
if [ ! -s "${TEMP_SCRIPT_PATH}" ]; then
    log "ERROR: Verification failed. Downloaded file is empty. Cleaning up."
    rm -f "${TEMP_SCRIPT_PATH}"
    exit 1
fi
log "Download successful and verified."

# 3. Set permissions on the new script
chmod +x "${TEMP_SCRIPT_PATH}"
if [ $? -ne 0 ]; then
    log "ERROR: Failed to set execute permissions on the new script. Cleaning up."
    rm -f "${TEMP_SCRIPT_PATH}"
    exit 1
fi
log "Execute permissions set on new script."

# 4. Atomically replace the old script with the new one
mv "${TEMP_SCRIPT_PATH}" "${SCRIPT_PATH}"
if [ $? -ne 0 ]; then
    log "ERROR: Failed to replace the old script with the new one. Update failed."
    rm -f "${TEMP_SCRIPT_PATH}" # Clean up the temp file if move fails
    exit 1
fi

log "SUCCESS: ${SCRIPT_NAME} has been updated to the latest version."
exit 0
