# ECHO (Executable Contextual Host Output) | Version 3.2

**Author:** TheArkifaneVashtorr & Janus.v4

## Overview

ECHO is a powerful and flexible Bash script designed to create comprehensive snapshots of a Linux system's state. It captures vital hardware, software, and configuration data, archiving it locally and synchronizing it to a cloud backend. It is an essential tool for system administrators, developers, and AI partners who require consistent, detailed context for analysis, debugging, and operational oversight.

The system is designed to be fully autonomous, capable of keeping itself up-to-date with the canonical version in its central Git repository, ensuring all clients are running the most current, approved version with zero manual intervention.

## Features

* **Comprehensive System Snapshots:** Gathers critical information into a clean, readable Markdown file.
    * **Hardware:** CPU, Memory, NVIDIA GPU (if present), PCI devices.
    * **OS & Software:** OS version, kernel, running processes, and installed packages (dpkg).
    * **Disk & Network:** Filesystem usage and network interface configurations.
    * **Docker Environment:** Docker info, running/stopped containers.

* **Autonomous & Resilient Self-Updating:**
    * Upon execution, the script automatically checks its source repository for new versions.
    * Utilizes a secure "External Updater" model (`update-echo.sh`) to perform updates safely, eliminating race conditions.
    * Includes semantic versioning protection to prevent accidental downgrades, ensuring it only updates to a demonstrably newer version.

* **Intelligent Project Indexing:**
    * Automatically detects if it is being run inside a Git repository.
    * Scans for file modifications since the last snapshot, creating project-specific reports only when changes have occurred.
    * Includes the full content of modified source files directly in the snapshot for complete context.

* **Persistent Caching System:**
    * Remembers your choices for indexing specific project files (`always` or `never`), minimizing repeated prompts during interactive use.

* **Automated Archive Management:**
    * Performs local garbage collection to keep a configurable number of recent snapshots (defined by `SNAPSHOT_RETENTION_COUNT`).
    * Uses `rclone sync` to mirror the local archive state to the cloud, ensuring old snapshots are pruned remotely as well.

## Requirements

The script is designed for Linux and relies on several common command-line utilities.

* **Core Utilities:** `curl`, `git`, `lscpu`, `free`, `df`, `ip`, `ps`, `hostnamectl`, `stat`, `grep`, `sed`, `touch`, `find`.
* **Cloud Sync (Optional):** `rclone` must be installed and configured with at least one remote for the cloud synchronization feature to work.
* **NVIDIA GPU Info (Optional):** `nvidia-smi` is required to capture GPU details.
* **Docker Info (Optional):** `docker` is required to capture Docker environment details.

On a Debian/Ubuntu-based system, you can ensure most dependencies are met with:
```bash
sudo apt-get update && sudo apt-get install -y coreutils util-linux procps iproute2 git rclone docker.io

Installation & Deployment

    Place both echo.sh and the essential update-echo.sh scripts in the same directory on your target system (e.g., /home/user/ECHO/).

    Make both scripts executable: chmod +x echo.sh update-echo.sh.

    The script is designed to be run from cron for automated, periodic snapshots.

Automation with Cron

To schedule ECHO to run automatically, open your crontab for editing (crontab -e) and add a line to schedule the script. The following example runs the script every hour and logs all output for debugging purposes.

0 * * * * /path/to/your/echo.sh >> /path/to/your/echo_cron.log 2>&1

Configuration

    Snapshot Retention: You can change the number of snapshots to keep locally by editing the SNAPSHOT_RETENTION_COUNT variable at the top of the echo.sh script.

    Repository URL: The canonical URL for self-updating is hardcoded in the ECHO_REPO_URL variable in both echo.sh and update-echo.sh.

    File Indexing Cache: The cache is stored at [Snapshot_Directory]/cache/.echo_cache. You can manually edit or delete this file to reset your indexing preferences.



