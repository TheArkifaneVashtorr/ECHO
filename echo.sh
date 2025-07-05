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


# ECHO (Executable Contextual Host Output) | Version 4.2 (MinIO Integration)
# ...
# Change Log:
#  - v4.2: Migrated rclone target from hardcoded 'ECHO' to dynamic S3 bucket.
#          - Uses new ECHO_BUCKET_NAME env var, defaults to 'echosnapshotdata'.
#          - Simplified rclone cleanup logic.
#  - v4.1: Refined update bootstrap to use 'exec' for immediate execution of new version.
#  - v4.0: Major overhaul for simplified, robust automation.

# --- Core Dependencies & Validation ---
check_dependencies() {
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
# Use environment variable for bucket name if it exists, otherwise default to 'echosnapshotdata'
ECHO_BUCKET_NAME="${ECHO_BUCKET_NAME:-echosnapshotdata}"


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
            if head -c 1K "$file" > /dev/null 2>&1; then
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
echo "--> Searching for Git projects in $HOME..."
while IFS= read -r git_dir; do
    project_root=$(dirname "$git_dir")
    PROCESSED_PROJECTS["$project_root"]=1
    snapshot_project "$project_root" "$(basename "$SYSTEM_OUTPUT_FILE")" "$PROJECT_SNAPSHOT_DIR_BASE"
done < <(find "$HOME" -name ".git" -type d -print)

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

        echo "--> Performing local garbage collection..."
        ls -1t "$SYSTEM_SNAPSHOT_DIR"/*.md 2>/dev/null | tail -n +$(($SNAPSHOT_RETENTION_COUNT + 1)) | xargs -r rm
        for project_dir in "$PROJECT_SNAPSHOT_DIR_BASE"/*/; do
            if [ -d "$project_dir" ]; then
                ls -1t "$project_dir"/*.md 2>/dev/null | tail -n +$(($SNAPSHOT_RETENTION_COUNT + 1)) | xargs -r rm
            fi
        done
        echo "--> Local GC complete."

        for remote in $ALL_REMOTES; do
            echo "--------------------------------------------------"
            echo "--> Processing remote: $remote"
            
            # Use the bucket name for S3-compatible remotes
            BUCKET_TO_USE=""
            if [[ "$remote" == *"minio"* ]]; then
                BUCKET_TO_USE="${ECHO_BUCKET_NAME}/"
            else
                # Fallback to the old 'ECHO' path for other remotes like Google Drive
                BUCKET_TO_USE="ECHO/"
            fi

            echo "--> Syncing system snapshots to $remote..."
            rclone sync "$SYSTEM_SNAPSHOT_DIR/" "${remote}:${BUCKET_TO_USE}${HOSTNAME}/system/" --log-level INFO

            for project_dir in "$PROJECT_SNAPSHOT_DIR_BASE"/*/; do
                if [ -d "$project_dir" ]; then
                    project_name=$(basename "$project_dir")
                    echo "--> Syncing project '$project_name' to remote '$remote'..."
                    rclone sync "$project_dir" "${remote}:${BUCKET_TO_USE}${HOSTNAME}/projects/${project_name}/" --log-level INFO
                fi
            done
            
            echo "--> Attempting to clean up remote trash for ${remote}..."
            rclone cleanup "${remote}:" --log-level INFO

            echo "--> Finished processing remote: $remote"
        done
        echo "--------------------------------------------------"
        echo "--> All synchronization and cleanup tasks are complete."
    fi
fi

echo "--> Snapshot process finished."
