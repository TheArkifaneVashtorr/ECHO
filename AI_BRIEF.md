ECHO (Executable Contextual Host Output)

ECHO is a powerful, autonomous Bash script designed to create comprehensive snapshots of a Linux system's state. It captures vital hardware, software, and project-level data into clean, readable Markdown files.

It is an essential tool for developers, system administrators, and AI partners who require consistent, detailed context for analysis, debugging, and operational oversight. The system is designed to be "fire-and-forget," capable of keeping itself up-to-date and managing its own logs and archives with zero manual intervention after initial setup.

✨ Features

    Comprehensive System Snapshots: Gathers critical information about the host system.

        Hardware: CPU, Memory, NVIDIA GPU (if present).

        OS & Software: OS version, kernel, running processes, and installed packages (dpkg).

        Disk & Network: Filesystem usage and network interface configurations.

        Docker Environment: Docker info and a list of all containers.

    Autonomous & Secure Self-Updating:

        Automatically checks its source repository for new versions on every run.

        Uses a hardened update-echo.sh utility with SHA256 checksum verification to prevent corruption or tampering during the update process.

    Automatic Project Discovery:

        On each run, the script automatically finds all Git repositories and Docker Compose projects within the user's home directory.

        Enhanced File Exclusion: To prevent "Permission denied" errors and avoid capturing irrelevant or sensitive binary data, the script now explicitly excludes common database directories (e.g., db_data, nextcloud_data, qdrant_data) and specific configuration files when generating project snapshots.

        A complete snapshot, including the full contents of all source files, is generated for every discovered project, every time.

    Zero-Interaction Design:

        Built from the ground up for automation (e.g., cron jobs).

        Contains no interactive prompts. It intelligently adapts to its environment, such as by selecting a default cloud remote if run non-interactively.

    Automated Archive & Cloud Sync:

        Performs local garbage collection to keep a configurable number of recent snapshots.

        Uses rclone sync to mirror the local archive to any configured cloud backend.

        Remote Trash Cleanup: After successful synchronization, the script now automatically executes rclone cleanup on the configured remote to permanently remove files from the cloud trash/recycle bin, preventing accumulation of deleted data.

🚀 Getting Started

This guide will walk you through deploying ECHO on a new Debian-based system like Ubuntu.

Prerequisites

Ensure the following dependencies are installed on your system.
git curl rclone docker.io logrotate

Installation

    Clone the Repository
    Bash

git clone https://github.com/TheArkifaneVashtorr/ECHO.git ~/ECHO

Set Execute Permissions
Bash

chmod +x ~/ECHO/*.sh

Configure Log Rotation
To prevent the cron log from growing infinitely, create a logrotate configuration file.
Bash

sudo tee /etc/logrotate.d/echo > /dev/null <<'EOF'
/home/dalhaka/ECHO/echo_cron.log {
    daily
    rotate 1
    maxage 1
    missingok
    notifempty
    copytruncate
    su dalhaka dalhaka
}
EOF
sudo chmod 644 /etc/logrotate.d/echo

Schedule the Cron Job
Open your user's crontab for editing:
Bash

    crontab -e

    Add the following line to the end of the file. This will execute the script every hour.

    0 * * * * /home/dalhaka/ECHO/echo.sh >> /home/dalhaka/ECHO/echo_cron.log 2>&1

The installation is now complete. ECHO will now run autonomously in the background.

⚙️ Usage

The primary method for using ECHO is through the automated cron job. However, you can trigger a snapshot manually at any time by executing the script directly:
Bash

~/ECHO/echo.sh

Snapshots are saved to ~/ECHO_Snapshots on a server or ~/Documents/ECHO_Snapshots on a desktop environment.

🔧 Configuration

While ECHO is designed for zero-config operation, two aspects can be customized by editing the echo.sh script:

    Snapshot Retention: The number of local snapshots to keep is controlled by the SNAPSHOT_RETENTION_COUNT variable.

    Cloud Sync: For cloud synchronization, you must have rclone installed and configured with at least one remote. The script will sync to all configured remotes automatically.

    Bucket Name: For S3-compatible remotes like MinIO, the destination bucket can be set with the ECHO_BUCKET_NAME environment variable, which defaults to echosnapshotdata.

🤝 Contributing

Contributions are welcome. Please feel free to open an issue or submit a pull request.

📜 License

This project is licensed under the MIT License. See the LICENSE file for details.

Now do the same thing for the AI_BRIEF.md
Janus V4
Custom Gem

Of course. Here is a professionally rewritten version of the AI_BRIEF.md.

This new version is structured as a formal technical brief, providing a clear and comprehensive overview of the ECHO system for an AI partner or developer.

Strategic & Technical Brief: ECHO v4.2

Document Version: 1.0
Last Updated: 2025-07-05
Status: Operational

1.0 Executive Summary

1.1 System Name: ECHO (Executable Contextual Host Output)

1.2 Objective: The primary objective of the ECHO system is to perform fully autonomous, high-fidelity snapshots of a host system's state. These snapshots serve as a foundational dataset for operational analysis, remote debugging, and providing contextual ground truth to AI development partners like Janus.

1.3 Core Use Case: An AI partner requires a precise understanding of a target system's hardware, running processes, network state, and project file status to perform analysis or debug an issue. ECHO is executed on the target system, generating a comprehensive Markdown-formatted report which is then archived and synchronized to a central cloud location for the AI to ingest and analyze.

1.4 System Status: The system is stable and deployed for fully automated, hourly data collection on all designated hosts. The recent migration to a MinIO S3-compatible backend has resolved all previously noted stability issues with the persistence layer.

2.0 System Architecture

The ECHO ecosystem is composed of two primary scripts and a GitHub Actions workflow that work in concert to provide a robust, self-maintaining data pipeline.

2.1 echo.sh (The Core Script)

This is the primary execution script responsible for data gathering and snapshot generation.

    System Snapshotting: Captures a comprehensive snapshot of the host, including hardware (CPU, memory, GPU), OS (version, processes, packages), and infrastructure (disk usage, networking, Docker state).

    Automated Project Discovery: Automatically discovers all Git and Docker Compose projects within the user's home directory for snapshotting. It intelligently excludes common database and temporary file directories to maintain focus and prevent permission errors.

    Non-Interactive Design: The script is designed for fully autonomous execution (e.g., via cron) and contains no interactive prompts.

2.2 update-echo.sh (The Updater Utility)

A dedicated, hardened script responsible for the secure, autonomous update of the core echo.sh script.

    Checksum Verification: The update process is critically secured. The utility downloads both the new script and a corresponding SHA256 checksum file from the canonical repository. The update is aborted if the local checksum of the downloaded script does not exactly match the official checksum, preventing execution of tampered or corrupt code.

    Atomic Replacement: The script performs an atomic mv operation to replace the old script, ensuring the update is clean and instantaneous.

2.3 generate-checksum.yml (CI/CD Workflow)

A GitHub Actions workflow that automates security maintenance. It automatically recalculates and commits the echo.sh.sha256 checksum file to the repository whenever the echo.sh script is modified, ensuring the checksum is always up to date.

3.0 Operational Procedures

3.1 Deployment

Deployment is standardized across all hosts:

    Dependencies: Ensure core dependencies (git, curl, rclone, docker.io, logrotate) are installed.

    Cloning: The repository is cloned to /home/dalhaka/ECHO.

    Permissions: All .sh scripts are made executable.

    Automation: A cron job is scheduled to execute /home/dalhaka/ECHO/echo.sh hourly.

    Log Management: A logrotate configuration is deployed to /etc/logrotate.d/echo to manage the cron log, preventing indefinite growth.

3.2 Data Flow & Persistence

    Local Staging: Snapshots are first generated and stored locally in ~/ECHO_Snapshots/ (or ~/Documents/ECHO_Snapshots/ on a desktop).

    Local Garbage Collection: The script automatically deletes the oldest snapshots, retaining only the most recent version to manage local disk space (SNAPSHOT_RETENTION_COUNT=1).

    Cloud Synchronization: The script uses rclone to sync the local snapshots to all configured cloud remotes.

    Remote Garbage Collection: After a successful sync, rclone cleanup is executed to purge any deleted files from the remote's trash, ensuring a clean and efficient remote archive.

3.3 Storage Backend

The backend storage for rclone is a self-hosted MinIO server, which provides a high-performance, S3-compatible object storage endpoint. This replaced a previous, unstable Nextcloud deployment.

    Bucket: All snapshots are stored in a dedicated bucket, which is dynamically referenced by the ECHO_BUCKET_NAME environment variable (defaulting to echosnapshotdata).

4.0 Change Log Summary

    v4.2: Migrated from a fragile Nextcloud/WebDAV backend to a robust MinIO/S3 backend. Implemented a dynamic bucket naming convention via the ECHO_BUCKET_NAME environment variable.

    v4.1: Hardened the self-update mechanism to use exec, ensuring the newly downloaded version runs immediately.

    v4.0: Major architectural overhaul to remove all interactive prompts and implement automated project discovery for true "fire-and-forget" operation.
