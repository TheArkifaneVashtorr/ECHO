#!/bin/bash

# --- Autonomous Update Bootstrap ---
# This section ensures the script is always the latest version.
# It calls a separate updater script and then uses 'exec' to replace the
# current running process with the new version, ensuring the update is immediate.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
UPDATER_SCRIPT_PATH="${SCRIPT_DIR}/update-echo.sh"

# Extract the version number from a script file's header.
get_version_from_string() {
    echo "$1" | grep -o 'Version [0-9.]*' | awk '{print $2}'
}

# Only check for updates if the updater script itself exists.
if [ -x "$UPDATER_SCRIPT_PATH" ]; then
    # Get Local Version from this script's own header.
    LOCAL_VERSION=$(get_version_from_string "$(head -n 20 "$0")")

    # Fetch remote version (only if curl is available)
    if command -v curl &> /dev/null; then
        ECHO_REPO_URL="https://raw.githubusercontent.com/TheArkifaneVashtorr/ECHO/main/echo.sh"
        REMOTE_VERSION_CONTENT=$(curl -s -L "${ECHO_REPO_URL}" | head -n 20)
        REMOTE_VERSION=$(get_version_from_string "$REMOTE_VERSION_CONTENT")

        # Proceed only if both versions were successfully parsed
        if [[ -n "$LOCAL_VERSION" && -n "$REMOTE_VERSION" ]]; then
            # Determine the highest version number using a version-aware sort
            HIGHEST_VERSION=$(printf "%s\n%s" "$LOCAL_VERSION" "$REMOTE_VERSION" | sort -V | tail -n 1)

            # Trigger an update if the remote version is higher than the local version
            if [[ "$HIGHEST_VERSION" != "$LOCAL_VERSION" && "$HIGHEST_VERSION" == "$REMOTE_VERSION" ]]; then
                echo "[ECHO-Startup] New version ${REMOTE_VERSION} detected. Handing off to updater..." >&2
                
                # Execute the updater script
                "$UPDATER_SCRIPT_PATH"
                
                # After updating, replace the current script process with the new version
                # and pass along any arguments that were originally provided.
                echo "[ECHO-Startup] Update complete. Re-executing with new version..." >&2
                exec bash "$0" "$@"
            fi
        fi
    fi
fi
# --- End of Autonomous Update Bootstrap ---


# ECHO (Executable Contextual Host Output) | Version 4.1 (Simplified & Automated)
# ...
# Change Log:
#  - v4.1: Refined update bootstrap to use 'exec' for immediate execution of new version.
#  - v4.0: Major overhaul for simplified, robust automation.
#          1. Added project discovery to find all git and docker-compose projects.
#          2. Removed all conditional snapshot logic (the "gatekeeper").
#          3. Removed all file-indexing cache logic and user prompts for non-interactive use.
#          4. Made rclone remote selection non-interactive for cron compatibility.
#  - v3.9: Corrected project snapshotting to match user specification.
#  - v3.8: Logic validated by diagnostics, but objective was misunderstood.
#  - v3.7: Flawed logic attempting to automate placeholder generation.
#  - v3.6: Flawed logic removing the snapshot gatekeeper.
#  - v3.5: Original logic.

# --- Core Dependencies & Validation ---
check_dependencies() {
    # Ensures all required command-line tools are available before execution.
    local dependencies=("curl" "git" "lscpu" "free" "df" "ip" "ps" "hostnamectl" "stat" "grep" "sed" "touch" "find" "sort" "tail" "head" "awk" "dirname" "basename")
    local missing_deps=()
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "[ECHO-Startup] FATAL: Missing one or more core dependencies. Cannot continue." >&2
        echo "[ECHO-Startup] Missing tools: ${missing_deps[*]}" >&2
        exit 1
    fi
}


# --- Configuration ---
SNAPSHOT_RETENTION_COUNT=1

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
        # If not running in an interactive terminal, default to the first remote.
        if ! [ -t 0 ]; then
            local first_remote=$(echo "$remotes" | head -n 1)
            echo "--> Multiple remotes detected in non-interactive mode. Defaulting to first remote: $first_remote" >&2
            echo "$first_remote"
            return 0
        fi

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

snapshot_project() {
    local project_root="$1"
    local system_snapshot_filename="$2"
    local project_snapshot_dir_base="$3"

    local project_name
    project_name=$(basename "$project_root")
    echo "--> Found project '$project_name' at: $project_root"

    local project_dir_path="$project_snapshot_dir_base/$project_name"
    mkdir -p "$project_dir_path"

    local project_output_file="$project_dir_path/project_${project_name}_${TIMESTAMP}.md"
    echo "--> Generating project snapshot: $project_output_file"

    {
        echo "# Project Snapshot: ${project_name}"
        echo "**Parent System Snapshot:** $system_snapshot_filename"
        echo "**Generated:** $(date)"
        echo -e "\n---"
    } > "$project_output_file"

    # Find and index all files, excluding:
    # - .git directory
    # - files with _EXCLUDE in their path
    # - common database data directories (using -path ... -prune)
    # - specific problematic files like Nextcloud's config.php
    local file_list_tmp
    file_list_tmp=$(mktemp)
    find "$project_root" \
        -path '*/.git' -prune -o \
        -path '*/db_data' -prune -o \
        -path '*/nextcloud_data' -prune -o \
        -path '*/qdrant_data' -prune -o \
        -path '*/weaviate_data' -prune -o \
        -path '*/ollama_data' -prune -o \
        -name 'config.php' -prune -o \
        -type f -print | grep -v "_EXCLUDE" > "$file_list_tmp"

    while IFS= read -r file; do
        if [ ! -f "$file" ]; then continue; fi
        echo "--> Indexing: $file"
        {
            echo -e "\n#### File: $(realpath "$file")"
            echo "\`\`\`"
            # Attempt to cat the file. If permission is denied or it's a binary, skip content.
            # This ensures the file path is listed, but content isn't captured if problematic.
            if head -c 1K "$file" > /dev/null 2>&1; then # Check if readable as text
                cat "$file"
            else
                echo "ERROR: Could not read file content (permission denied or binary file)."
            fi
            echo -e "\`\`\`"
        } >> "$project_output_file"
    done < "$file_list_tmp"
    
    rm "$file_list_tmp"
}


# --- Script Execution ---
# Run dependency check first to ensure a stable environment.
check_dependencies

# --- Dynamic Path Configuration ---
if [ -n "$DISPLAY" ]; then
    BASE_STAGING_DIR="$HOME/Documents/ECHO_Snapshots"
else
    BASE_STAGING_DIR="$HOME/ECHO_Snapshots"
fi

SYSTEM_SNAPSHOT_DIR="$BASE_STAGING_DIR/system"
PROJECT_SNAPSHOT_DIR_BASE="$BASE_STAGING_DIR/projects"
mkdir -p "$SYSTEM_SNAPSHOT_DIR" "$PROJECT_SNAPSHOT_DIR_BASE"

HOSTNAME=$(hostname)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SYSTEM_OUTPUT_FILE="$SYSTEM_SNAPSHOT_DIR/system_snapshot_${HOSTNAME}_${TIMESTAMP}.md"

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
echo "--> System snapshot generation complete."

# --- Project File Indexing ---
declare -A PROCESSED_PROJECTS

# 1. Find and process all git repositories
echo "--> Searching for Git projects in $HOME..."
while IFS= read -r git_dir; do
    project_root=$(dirname "$git_dir")
    PROCESSED_PROJECTS["$project_root"]=1
    snapshot_project "$project_root" "$(basename "$SYSTEM_OUTPUT_FILE")" "$PROJECT_SNAPSHOT_DIR_BASE"
done < <(find "$HOME" -name ".git" -type d -print)

# 2. Find and process all docker-compose projects, avoiding duplicates
echo "--> Searching for Docker projects in $HOME..."
while IFS= read -r compose_file; do
    project_root=$(dirname "$compose_file")
    if [[ -z "${PROCESSED_PROJECTS["$project_root"]}" ]]; then
        PROCESSED_PROJECTS["$project_root"]=1
        snapshot_project "$project_root" "$(basename "$SYSTEM_OUTPUT_FILE")" "$PROJECT_SNAPSHOT_DIR_BASE"
    else
        echo "--> Skipping already processed Docker project: $project_root"
    fi
done < <(find "$HOME" \( -name "docker-compose.yml" -o -name "docker-compose.yaml" \) -type f -print)


echo ""

# --- Local GC & Remote Sync ---
if ! command -v rclone &> /dev/null; then
    echo "--> rclone not found. Skipping all cloud sync operations." >&2
else
    ALL_REMOTES=$(rclone listremotes | sed 's/://g')
    if [ -z "$ALL_REMOTES" ]; then
        echo "--> No rclone remotes configured. Skipping cloud sync." >&2
    else
        echo "--> Performing local garbage collection and cloud synchronization for all remotes..."

        # Perform local GC once for all snapshot directories before looping through remotes.
        echo "--> Performing local garbage collection..."
        ls -1t "$SYSTEM_SNAPSHOT_DIR"/*.md 2>/dev/null | tail -n +$(($SNAPSHOT_RETENTION_COUNT + 1)) | xargs -r rm
        for project_dir in "$PROJECT_SNAPSHOT_DIR_BASE"/*/; do
            if [ -d "$project_dir" ]; then
                ls -1t "$project_dir"/*.md 2>/dev/null | tail -n +$(($SNAPSHOT_RETENTION_COUNT + 1)) | xargs -r rm
            fi
        done
        echo "--> Local GC complete."

        # Loop through each configured remote for sync and cleanup operations.
        for remote in $ALL_REMOTES; do
            echo "--------------------------------------------------"
            echo "--> Processing remote: $remote"
            
            # Sync system snapshots
            echo "--> Syncing system snapshots to $remote..."
            rclone sync "$SYSTEM_SNAPSHOT_DIR/" "${remote}:ECHO/${HOSTNAME}/system/" --log-level INFO

            # Sync each project directory
            for project_dir in "$PROJECT_SNAPSHOT_DIR_BASE"/*/; do
                if [ -d "$project_dir" ]; then
                    project_name=$(basename "$project_dir")
                    echo "--> Syncing project '$project_name' to remote '$remote'..."
                    rclone sync "$project_dir" "${remote}:ECHO/${HOSTNAME}/projects/${project_name}/" --log-level INFO
                fi
            done
            
            # Conditionally clean up the remote's trash
            # The 'cleanup' command is not supported by all remotes (e.g., standard WebDAV).
            if [[ "$remote" != "nextcloud" ]]; then
                echo "--> Cleaning up remote trash for ${remote}..."
                rclone cleanup "${remote}:" --log-level INFO
            else
                echo "--> Skipping cleanup for remote '${remote}' (not supported)."
            fi

            echo "--> Finished processing remote: $remote"
        done
        echo "--------------------------------------------------"
        echo "--> All synchronization and cleanup tasks are complete."
    fi
fi

echo "--> Snapshot process finished."
