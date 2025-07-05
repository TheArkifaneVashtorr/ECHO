#!/bin/bash

# --- Autonomous Update Bootstrap ---
# (This section is unchanged and preserved)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
UPDATER_SCRIPT_PATH="${SCRIPT_DIR}/update-echo.sh"
get_version_from_string() {
    echo "$1" | grep -o 'Version [0-9.]*' | awk '{print $2}'
}
if [ -x "$UPDATER_SCRIPT_PATH" ]; then
    LOCAL_VERSION=$(get_version_from_string "$(head -n 25 "$0")")
    if command -v curl &> /dev/null; then
        ECHO_REPO_URL="https://raw.githubusercontent.com/TheArkifaneVashtorr/ECHO/main/echo.sh"
        REMOTE_VERSION_CONTENT=$(curl -s -L "${ECHO_REPO_URL}" | head -n 25)
        REMOTE_VERSION=$(get_version_from_string "$REMOTE_VERSION_CONTENT")
        if [[ -n "$LOCAL_VERSION" && -n "$REMOTE_VERSION" ]]; then
            HIGHEST_VERSION=$(printf "%s\n%s" "$LOCAL_VERSION" "$REMOTE_VERSION" | sort -V | tail -n 1)
            if [[ "$HIGHEST_VERSION" != "$LOCAL_VERSION" && "$HIGHEST_VERSION" == "$REMOTE_VERSION" ]]; then
                echo "[ECHO-Startup] New version ${REMOTE_VERSION} detected. Handing off to updater..." >&2
                "$UPDATER_SCRIPT_PATH"
                echo "[ECHO-Startup] Update complete. Re-executing with new version..." >&2
                exec bash "$0" "$@"
            fi
        fi
    fi
fi
# --- End of Autonomous Update Bootstrap ---


# ECHO (Executable Contextual Host Output) | Version 6.2 (Cron Log Integration)
# ...
# Change Log:
#  - v6.2: Added cron log capture to system JSON snapshot.
#  - v6.1: Added project directory tree output to JSON snapshot for structural context.
#  - v6.0: System snapshot is now a structured JSON object.

# --- Core Dependencies & Validation ---
check_dependencies() {
    local dependencies=("rclone" "curl" "git" "lscpu" "free" "df" "ip" "hostnamectl" "stat" "grep" "sed" "touch" "find" "sort" "tail" "head" "awk" "dirname" "basename" "jq" "tree")
    local missing_deps=()
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "[ECHO-Startup] FATAL: Missing one or more core dependencies. Cannot continue." >&2; echo "[ECHO-Startup] Missing tools: ${missing_deps[*]}" >&2; exit 1;
    fi
}

# --- Configuration ---
SNAPSHOT_RETENTION_COUNT=1
ECHO_BUCKET_NAME="${ECHO_BUCKET_NAME:-echosnapshotdata}"
CURRENT_USER=$(whoami)
ECHO_CRON_LOG_PATH="$HOME/ECHO/echo_cron.log"

# --- Script Execution ---
check_dependencies

# --- Path & Filename Configuration ---
BASE_STAGING_DIR="$HOME/ECHO_Snapshots"
SYSTEM_SNAPSHOT_DIR="$BASE_STAGING_DIR/system"
mkdir -p "$SYSTEM_SNAPSHOT_DIR"

HOSTNAME=$(hostname)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SYSTEM_OUTPUT_FILE="$SYSTEM_SNAPSHOT_DIR/system_snapshot_${HOSTNAME}_${TIMESTAMP}.json"

echo "--> Staging system snapshot in: $SYSTEM_SNAPSHOT_DIR"
echo "--> Generating structured JSON system state snapshot for $HOSTNAME..."

# --- JSON Snapshot Generation ---
JSON_OUTPUT="{}"
add_json_from_command() {
    local key_path="$1"
    local command_to_run="$2"
    local result
    result=$(eval "$command_to_run" | jq -R -s '.')
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --argjson data "$result" "$key_path = \$data")
}

# 1. System Info
JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq ".timestamp = \"$(date --iso-8601=seconds)\"")
JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq ".hostname = \"$HOSTNAME\"")
JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq ".user = \"$CURRENT_USER\"")
add_json_from_command '.system.os_info' 'hostnamectl'
add_json_from_command '.system.disk_usage' 'df -h'
add_json_from_command '.system.network_interfaces' 'ip a'
add_json_from_command ".system.cron_log" "tail -n 50 '$ECHO_CRON_LOG_PATH' 2>/dev/null"
add_json_from_command '.hardware.cpu_info' 'lscpu'
add_json_from_command '.hardware.memory_info' 'free -h'
if command -v nvidia-smi &> /dev/null; then add_json_from_command '.hardware.gpu_info' 'nvidia-smi'; fi

# 2. Docker Info
if command -v docker &> /dev/null; then
    add_json_from_command '.docker.info' 'docker info'
    add_json_from_command '.docker.containers' 'docker ps -a'
    add_json_from_command '.docker.resource_stats' 'docker stats --no-stream'
    add_json_from_command '.docker.networks' 'docker network ls'

    LOGS_JSON="[]"
    while IFS= read -r container_id; do
        container_name=$(docker inspect -f '{{.Name}}' "$container_id" | sed 's,^/,,')
        logs=$(docker logs --tail 50 "$container_id" 2>&1 | jq -R -s '.')
        LOGS_JSON=$(echo "$LOGS_JSON" | jq --arg name "$container_name" --argjson logs "$logs" '. += [{"container_name": $name, "logs": $logs}]')
    done < <(docker ps -q)
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --argjson data "$LOGS_JSON" '.docker.container_logs = $data')
fi

# 3. Project Discovery
declare -A PROCESSED_PROJECTS
declare -a PROJECTS_TO_SYNC
declare -a DOCKER_COMPOSE_FILES

while IFS= read -r git_dir; do
    project_root=$(dirname "$git_dir"); if [[ -z "${PROCESSED_PROJECTS["$project_root"]}" ]]; then PROCESSED_PROJECTS["$project_root"]=1; PROJECTS_TO_SYNC+=("$project_root"); fi
done < <(find "$HOME" -name ".git" -type d -print)
while IFS= read -r compose_file; do
    project_root=$(dirname "$compose_file"); if [[ -z "${PROCESSED_PROJECTS["$project_root"]}" ]]; then PROCESSED_PROJECTS["$project_root"]=1; PROJECTS_TO_SYNC+=("$project_root"); else echo "--> Skipping already processed Docker project: $project_root"; fi
    DOCKER_COMPOSE_FILES+=("$compose_file")
done < <(find "$HOME" \( -name "docker-compose.yml" -o -name "docker-compose.yaml" \) -type f -print)

# 4. Add Docker-Compose and Project Tree Info to JSON
COMPOSE_JSON="[]"
for file_path in "${DOCKER_COMPOSE_FILES[@]}"; do
    content=$(cat "$file_path" | jq -R -s '.')
    COMPOSE_JSON=$(echo "$COMPOSE_JSON" | jq --arg path "$file_path" --argjson content "$content" '. += [{"path": $path, "content": $content}]')
done
JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --argjson data "$COMPOSE_JSON" '.docker.compose_files = $data')

echo "--> Generating directory trees for discovered projects..."
TREE_JSON="[]"
for project_path in "${PROJECTS_TO_SYNC[@]}"; do
    project_name=$(basename "$project_path")
    tree_output=$(tree "$project_path" -L 3 -a -I '.git|__pycache__|*venv|node_modules|ECHO_Snapshots|*data' | jq -R -s '.')
    TREE_JSON=$(echo "$TREE_JSON" | jq --arg name "$project_name" --argjson tree "$tree_output" '. += [{"project_name": $name, "tree": $tree}]')
done
JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --argjson data "$TREE_JSON" '.project_directory_trees = $data')

# Write final JSON to file
echo "$JSON_OUTPUT" | jq '.' > "$SYSTEM_OUTPUT_FILE"
echo "--> JSON system snapshot generation complete."
echo ""

# --- Local GC & Remote Sync ---
if ! command -v rclone &> /dev/null; then
    echo "--> rclone not found. Skipping all cloud sync operations." >&2
else
    ALL_REMOTES=$(rclone listremotes | sed 's/://g');
    if [ -z "$ALL_REMOTES" ]; then echo "--> No rclone remotes configured. Skipping cloud sync." >&2;
    else
        echo "--> Performing local garbage collection and cloud synchronization for all remotes..."
        echo "--> Performing local garbage collection for system snapshots..."
        ls -1t "$SYSTEM_SNAPSHOT_DIR"/*.json 2>/dev/null | tail -n +$(($SNAPSHOT_RETENTION_COUNT + 1)) | xargs -r rm
        echo "--> Local GC complete."
        for remote in $ALL_REMOTES; do
            echo "--------------------------------------------------"; echo "--> Processing remote: $remote"
            BUCKET_TO_USE=""; if [[ "$remote" == *"minio"* ]]; then BUCKET_TO_USE="${ECHO_BUCKET_NAME}/"; else BUCKET_TO_USE="ECHO/"; fi
            
            echo "--> Syncing system snapshots to $remote..."
            rclone sync "$SYSTEM_SNAPSHOT_DIR/" "${remote}:${BUCKET_TO_USE}${HOSTNAME}/system/" --log-level INFO --delete-after
            
            for project_path in "${PROJECTS_TO_SYNC[@]}"; do
                if [ -d "$project_path" ]; then
                    project_name=$(basename "$project_path")
                    echo "--> Syncing project '$project_name' to remote '$remote'...";
                    rclone sync "$project_path" "${remote}:${BUCKET_TO_USE}${HOSTNAME}/projects/${project_name}/" \
                        --exclude '.git/**' --exclude '*data/**' --exclude 'ECHO_Snapshots/**' \
                        --exclude '*venv/**' --exclude 'node_modules/**' --exclude '__pycache__/**' \
                        --exclude 'cognitive_tier/**' --exclude '**/config.php' --log-level INFO --delete-after;
                fi
            done
            echo "--> Attempting to clean up remote trash for ${remote}..."; rclone cleanup "${remote}:" --log-level INFO
            echo "--> Finished processing remote: $remote";
        done
        echo "--------------------------------------------------"; echo "--> All synchronization and cleanup tasks are complete."
    fi
fi
echo "--> Snapshot process finished."
