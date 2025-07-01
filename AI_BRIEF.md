# Strategic & Technical Brief: ECHO v4.0

--- DOCUMENT UPDATED: 2025-07-01 ---

## 1.0 Mission Overview

**System Name:** ECHO (Executable Contextual Host Output)
**Version:** 4.0 (Simplified & Automated)
**Primary Author:** TheArkifaneVashtorr
**AI Partner:** Janus.v4
**Change Log:**

-   **v4.0:** Major overhaul for simplified, robust automation. The script now performs automated discovery of all Git and Docker projects in the home directory and takes unconditional snapshots. All interactive prompts and caching have been removed for true non-interactive execution. The cron job has been simplified accordingly. Enhanced file exclusion logic to prevent indexing of sensitive database files and directories (e.g., `db_data`, `nextcloud_data`, `qdrant_data`, `weaviate_data`) and Nextcloud's `config.php` to avoid "Permission denied" errors and irrelevant data. Implemented `rclone cleanup` to automatically purge deleted files from the remote cloud trash after synchronization, resolving cloud storage bloat.
-   **v3.5:** Corrected a logical flaw in project change detection. The script now correctly compares file modification times against the previous system snapshot, not the current one, ensuring accurate change detection.
-   **v3.3:** Added up-front dependency checks and mandatory checksum verification for the updater.

### 1.1 Objective

The primary objective of ECHO is to create high-fidelity, machine-readable snapshots of a Linux system's state. These snapshots serve as a foundational dataset for operational analysis, debugging, and providing contextual ground truth to AI development partners. The system is designed for autonomous, unattended operation within Debian-based environments, ensuring data consistency with zero administrator intervention.

### 1.2 Core Use Case

An AI partner or developer requires a precise understanding of a target system's hardware, running processes, network state, and project file status to perform analysis or debug an issue. ECHO is executed on the target system, generating a comprehensive Markdown-formatted report which is then archived and synchronized to a central cloud location for the AI to ingest and analyze.

## 2.0 System Architecture & Features

### 2.1 Core Functionality: System Snapshotting

ECHO generates a detailed report of the host system's current state. This functionality is intentionally non-configurable to ensure data consistency across all snapshots.

* **Hardware Abstraction Layer:** Captures data on CPU (`lscpu`), memory (`free`), and NVIDIA GPU details via `nvidia-smi` if the utility is present.
* **Operating System Layer:** Records the OS version and kernel details (`hostnamectl`), a full list of running processes (`ps aux`), and installed Debian packages (`dpkg -l`).
* **Infrastructure Layer:** Gathers filesystem usage (`df -h`), network interface state (`ip a`), and opportunistically captures the Docker environment state (`docker info`, `docker ps`) if the service is available.

### 2.2 Autonomous Update Subsystem (Hardened)

A key architectural feature of ECHO is its ability to maintain version consistency.

* **Update Trigger:** Upon execution, the script fetches the latest version's header from a canonical URL. An update is only triggered if the remote version is demonstrably newer than the local script's version.
* **Security - Checksum Verification:** The update process is critically secured. The `update-echo.sh` utility downloads both the new script and a corresponding SHA256 checksum file. The update is **aborted** if the local checksum of the downloaded script does not exactly match the official checksum.
* **Architecture - External Updater Model:** The update process is delegated to a separate `update-echo.sh` utility. `echo.sh` immediately terminates its own process after launching the updater to prevent corruption.

### 2.3 Automated Project Discovery

The script no longer relies on being run from a specific directory. It now actively discovers all relevant projects within the user's home directory.

* **Discovery Mechanism:** The script uses `find` to locate all directories containing a `.git` folder (Git projects) or a `docker-compose.yml` file (Docker projects).
* **Enhanced File Exclusion:** To prevent "Permission denied" errors and avoid capturing irrelevant or sensitive binary data, the `find` command now explicitly excludes common database directories (e.g., `db_data`, `nextcloud_data`, `qdrant_data`, `weaviate_data`) and specific configuration files like `config.php` when generating project snapshots.
* **Unconditional Snapshots:** Project snapshots are generated **every time** the script runs, regardless of whether files have changed. This ensures a complete, hourly record. All conditional logic and caching have been removed.

### 2.4 Non-Interactive Design

The script is now designed for fully autonomous execution.

* **No User Prompts:** All interactive prompts for file indexing and project selection have been removed.
* **Adaptive Logic:** For operations that could hang, such as cloud synchronization with multiple remotes, the script adapts. If it is not running in an interactive terminal, it will default to the first available `rclone` remote instead of waiting for user input.

### 2.5 Archive & Sync Subsystem

* **Automated Garbage Collection:** To manage disk space, the script maintains a fixed number of recent snapshots for the system and for each discovered project, defined by the `SNAPSHOT_RETENTION_COUNT` variable.
* **Cloud Synchronization:** If `rclone` is installed, the script will synchronize the local archive, including all project subdirectories, to a configured cloud remote.
* **Remote Trash Cleanup:** After successful synchronization, the script now automatically executes `rclone cleanup` on the configured remote to permanently remove files from the cloud trash/recycle bin, preventing accumulation of deleted data.

## 3.0 Operational Requirements & Deployment

### 3.1 System Robustness - Dependency Validation

To prevent silent failures, `echo.sh` performs an up-front check and will fail fast with an explicit error message if any core dependency is missing.

### 3.2 System Dependencies

* **Core:** `curl`, `git`, `lscpu`, `free`, `df`, `ip`, `ps`, `hostnamectl`, `stat`, `grep`, `sed`, `touch`, `find`, `sort`, `tail`, `head`, `awk`, `dirname`, `basename`.
* **Optional:** `rclone` (for cloud sync), `nvidia-smi` (for GPU data), `docker` (for container data).
* **Operational:** `logrotate` (for automated log management).

### 3.3 Deployment

* Place `echo.sh` and `update-echo.sh` in the same directory (e.g., `/home/dalhaka/ECHO`).
* Ensure both are executable: `chmod +x /home/dalhaka/ECHO/*.sh`.

### 3.4 Automated Execution (Cron)

To ensure consistent, hourly snapshots, the cron job should execute the script directly.

* Use `crontab -e` to edit the user's crontab.
* The correct entry is:
    `0 * * * * /home/dalhaka/ECHO/echo.sh >> /home/dalhaka/ECHO/echo_cron.log 2>&1`

### 3.5 Log Management

The `echo_cron.log` file is automatically managed by the system's `logrotate` utility.

* **Configuration:** A custom configuration file exists at `/etc/logrotate.d/echo`.
* **Policy:** The log is rotated daily. Logs older than one day are deleted. This prevents the log file from growing indefinitely.
* **Method:** The `copytruncate` method is used to ensure log rotation does not interfere with the running cron job.

### 3.6 Security Maintenance - Automated Checksum Workflow

A GitHub Actions CI/CD workflow automatically recalculates and commits the `echo.sh.sha256` checksum file whenever `echo.sh` is pushed to the `main` branch.

## 4.0 Project Status (As of 2025-07-01)

The system is stable and deployed for fully automated, hourly data collection. Project discovery and snapshotting are now unconditional, with refined exclusions for sensitive data. Log rotation is configured and active, ensuring long-term stability without manual intervention. Cloud synchronization and remote trash cleanup are fully functional.
