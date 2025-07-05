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
