#!/bin/bash

# ==============================================================================
# ECHO (Executable Contextual Host Output) | Version 2.6 (Stable)
#
# Author: TheArkifaneVashtorr & Janus.v4
# Purpose: To capture a comprehensive snapshot of a system's state for
#          archiving, analysis, and providing context to collaborators.
# ==============================================================================

# --- Configuration ---
SNAPSHOT_RETENTION_COUNT=5

# --- Function Definitions ---
write_command_output() {
    local cmd_string="$1"
    local header_text="$2"
    local target_file="$3"
    if [ ! -f "$target_file" ]; then return; fi
    echo -e "\n### $header_text" >> "$target_file"
    echo "\`\`\`" >> "$target_file"
    eval "$cmd_string" >> "$target_file" 2>&1
    echo "\`\`\`" >> "$target_file"
}

select_rclone_remote() {
    if ! command -v rclone &> /dev/null; then
        echo "--> rclone not found. Skipping cloud sync." >&2
        return 1
    fi
    local remotes
    remotes=$(rclone listremotes | sed 's/://g')
    local remote_count
    remote_count=$(echo "$remotes" | wc -w)
    if [ "$remote_count" -eq 0 ]; then
        echo "--> No rclone remotes configured. Skipping cloud sync." >&2
        return 1
    elif [ "$remote_count" -eq 1 ]; then
        echo "--> Auto-detected single rclone remote: $remotes" >&2
        echo "$remotes"
        return 0
    else
        echo "--> Multiple rclone remotes detected. Please choose one:" >&2
        select remote_choice in $remotes "Quit"; do
            if [[ "$remote_choice" == "Quit" ]]; then
                echo "--> No remote selected. Skipping cloud sync." >&2; return 1
            elif [ -n "$remote_choice" ]; then
                echo "--> Using remote: $remote_choice" >&2; echo "$remote_choice"; return 0
            else
                echo "Invalid selection. Please try again." >&2
            fi
        done < /dev/tty
    fi
}

# --- Dynamic Path Configuration ---
if [ -n "$DISPLAY" ]; then
    BASE_STAGING_DIR="$HOME/Documents/ECHO_Snapshots"
else
    BASE_STAGING_DIR="$HOME/ECHO_Snapshots"
fi

SYSTEM_SNAPSHOT_DIR="$BASE_STAGING_DIR/system"
PROJECT_SNAPSHOT_DIR_BASE="$BASE_STAGING_DIR/projects"
CACHE_DIR="$BASE_STAGING_DIR/cache"
mkdir -p "$SYSTEM_SNAPSHOT_DIR" "$PROJECT_SNAPSHOT_DIR_BASE" "$CACHE_DIR"

# --- Script Execution ---
HOSTNAME=$(hostname)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SYSTEM_OUTPUT_FILE="$SYSTEM_SNAPSHOT_DIR/system_snapshot_${HOSTNAME}_${TIMESTAMP}.md"
CACHE_FILE="$CACHE_DIR/.echo_cache"
touch "$CACHE_FILE"

LAST_SNAPSHOT_FILE=$(ls -1t "$SYSTEM_SNAPSHOT_DIR"/system_snapshot_*.md 2>/dev/null | head -n 1)
LAST_SNAPSHOT_MTIME=0
if [ -f "$LAST_SNAPSHOT_FILE" ]; then
    LAST_SNAPSHOT_MTIME=$(stat -c %Y "$LAST_SNAPSHOT_FILE")
fi

echo "--> Staging snapshots in: $BASE_STAGING_DIR"
echo "--> Generating system state snapshot for $HOSTNAME..."
echo "--> Output will be saved to: $SYSTEM_OUTPUT_FILE"

# --- Generate System Snapshot ---
{
    echo "# System State Snapshot: ${HOSTNAME}"
    echo "**Generated:** $(date)"
    echo -e "\n---"
} > "$SYSTEM_OUTPUT_FILE"
echo -e "\n## 1. Hardware Information" >> "$SYSTEM_OUTPUT_FILE"
write_command_output "lscpu" "CPU Info" "$SYSTEM_OUTPUT_FILE"
write_command_output "free -h" "Memory Info" "$SYSTEM_OUTPUT_FILE"
if command -v nvidia-smi &> /dev/null; then write_command_output "nvidia-smi" "NVIDIA GPU Info" "$SYSTEM_OUTPUT_FILE"; fi
echo -e "\n## 2. OS & Software" >> "$SYSTEM_OUTPUT_FILE"
write_command_output "hostnamectl" "OS Info" "$SYSTEM_OUTPUT_FILE"
write_command_output "ps aux" "Running Processes" "$SYSTEM_OUTPUT_FILE"
if command -v dpkg &> /dev/null; then write_command_output "dpkg -l" "Installed Packages (dpkg)" "$SYSTEM_OUTPUT_FILE"; fi
echo -e "\n## 3. Disk & Network" >> "$SYSTEM_OUTPUT_FILE"
write_command_output "df -h" "Disk Usage" "$SYSTEM_OUTPUT_FILE"
write_command_output "ip a" "Network Interfaces" "$SYSTEM_OUTPUT_FILE"
echo -e "\n## 4. Docker Environment" >> "$SYSTEM_OUTPUT_FILE"
if command -v docker &> /dev/null; then
  write_command_output "docker info" "Docker Info" "$SYSTEM_OUTPUT_FILE"
  write_command_output "docker ps -a" "Docker Containers" "$SYSTEM_OUTPUT_FILE"
fi

# --- Project File Indexing ---
PROJECT_ROOT=$(git -C . rev-parse --show-toplevel 2>/dev/null)
PROJECT_NAME=""
if [ -n "$PROJECT_ROOT" ]; then
    PROJECT_NAME=$(basename "$PROJECT_ROOT")
    read -p "Project root detected at: $PROJECT_ROOT. Index files? (y/N) " -n 1 -r REPLY < /dev/tty; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        PROJECT_DIR_PATH="$PROJECT_SNAPSHOT_DIR_BASE/$PROJECT_NAME"
        mkdir -p "$PROJECT_DIR_PATH"
        FILE_LIST_TMP=$(mktemp)
        find "$PROJECT_ROOT" -path '*/.git' -prune -o -type f -print | grep -v "_EXCLUDE" > "$FILE_LIST_TMP"
        NEEDS_SNAPSHOT=false
        while IFS= read -r file; do
            if [ -f "$file" ] && [[ $(stat -c %Y "$file") -gt $LAST_SNAPSHOT_MTIME ]]; then
                NEEDS_SNAPSHOT=true; break
            fi
        done < "$FILE_LIST_TMP"
        if [ "$NEEDS_SNAPSHOT" = true ]; then
            PROJECT_OUTPUT_FILE="$PROJECT_DIR_PATH/project_${PROJECT_NAME}_${TIMESTAMP}.md"
            echo "--> Changes detected. Generating project snapshot: $PROJECT_OUTPUT_FILE"
            {
                echo "# Project Snapshot: ${PROJECT_NAME}"
                echo "**Parent System Snapshot:** $(basename "$SYSTEM_OUTPUT_FILE")"
                echo "**Generated:** $(date)"
                echo -e "\n---"
            } > "$PROJECT_OUTPUT_FILE"
            while IFS= read -r file; do
                if [ ! -f "$file" ]; then continue; fi
                decision=$(grep "^${file}:" "$CACHE_FILE" | cut -d: -f2)
                action="ask"
                CURRENT_FILE_MTIME=$(stat -c %Y "$file")
                if [[ "$decision" == "never" ]]; then
                    action="no"
                elif [ "$CURRENT_FILE_MTIME" -le "$LAST_SNAPSHOT_MTIME" ] && [[ "$decision" != "always" ]]; then
                    action="skip_unchanged"
                elif [[ "$decision" == "always" ]]; then
                    action="yes"
                fi
                if [[ "$action" == "ask" ]]; then
                    read -p "Index content of '$file'? (y/N/always/never) " choice < /dev/tty
                    case "$choice" in
                        y|Y|yes) action="yes_once" ;;
                        a|A|always) action="yes" ; sed -i "\|^${file}:|d" "$CACHE_FILE"; echo "${file}:always" >> "$CACHE_FILE" ;;
                        e|E|never) action="no" ; sed -i "\|^${file}:|d" "$CACHE_FILE"; echo "${file}:never" >> "$CACHE_FILE" ;;
                        *) action="no" ;;
                    esac
                fi
                if [[ "$action" == "yes" || "$action" == "yes_once" ]]; then
                    echo "--> Indexing $file"
                    {
                        echo -e "\n#### File: $(realpath "$file")"
                        echo "\`\`\`"
                        cat "$file"
                        echo -e "\`\`\`"
                    } >> "$PROJECT_OUTPUT_FILE"
                elif [[ "$action" == "skip_unchanged" ]]; then
                    echo "--> Skipping unchanged file: $file"
                    {
                        echo -e "\n#### File: $(realpath "$file")"
                        echo "*File content unchanged since last snapshot.*"
                    } >> "$PROJECT_OUTPUT_FILE"
                fi
            done < "$FILE_LIST_TMP"
        else
            echo "--> No project file changes detected. Skipping project snapshot."
        fi
        rm "$FILE_LIST_TMP"
    fi
fi

echo "--> System snapshot generation complete."
echo ""

# --- Local GC & Remote Sync ---
RCLONE_REMOTE_NAME=$(select_rclone_remote)
if [ -n "$RCLONE_REMOTE_NAME" ]; then
    echo "--> Performing local garbage collection and cloud synchronization..."
    ls -1t "$SYSTEM_SNAPSHOT_DIR"/*.md 2>/dev/null | tail -n +$(($SNAPSHOT_RETENTION_COUNT + 1)) | xargs -r rm
    rclone sync "$SYSTEM_SNAPSHOT_DIR/" "${RCLONE_REMOTE_NAME}:ECHO/${HOSTNAME}/system/" --log-level INFO
    if [ -n "$PROJECT_NAME" ] && [ -d "$PROJECT_SNAPSHOT_DIR_BASE/$PROJECT_NAME" ]; then
        PROJECT_DIR_PATH="$PROJECT_SNAPSHOT_DIR_BASE/$PROJECT_NAME"
        ls -1t "$PROJECT_DIR_PATH"/*.md 2>/dev/null | tail -n +$(($SNAPSHOT_RETENTION_COUNT + 1)) | xargs -r rm
        rclone sync "$PROJECT_DIR_PATH/" "${RCLONE_REMOTE_NAME}:ECHO/${HOSTNAME}/projects/${PROJECT_NAME}/" --log-level INFO
    fi
    echo "--> Synchronization complete."
fi

echo "--> Snapshot process finished."
