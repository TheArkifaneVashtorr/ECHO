# ECHO (Executable Contextual Host Output) | Version 4.0

**Author:** TheArkifaneVashtorr & Janus.v4

![Shell Script](https://img.shields.io/badge/Language-Shell_Script-blue?style=for-the-badge&logo=gnu-bash)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

## 1. Overview

ECHO is a powerful, autonomous Bash script designed to create comprehensive snapshots of a Linux system's state. It captures vital hardware, software, and project-level data into clean, readable Markdown files.

It is an essential tool for system administrators, developers, and AI partners who require consistent, detailed context for analysis, debugging, and operational oversight. The system is designed to be "fire-and-forget," capable of keeping itself up-to-date and managing its own logs and archives with zero manual intervention after initial setup.

## 2. Features

* **Comprehensive System Snapshots:** Gathers critical information about the host system.
    * **Hardware:** CPU, Memory, NVIDIA GPU (if present).
    * **OS & Software:** OS version, kernel, running processes, and installed packages (`dpkg`).
    * **Disk & Network:** Filesystem usage and network interface configurations.
    * **Docker Environment:** Docker info and a list of all containers.

* **Autonomous & Secure Self-Updating:**
    * Automatically checks its source repository for new versions on every run.
    * Uses a hardened `update-echo.sh` utility with **SHA256 checksum verification** to prevent corruption or tampering during the update process.

* **Automatic Project Discovery:**
    * On each run, the script automatically finds all **Git repositories** and **Docker Compose projects** within the user's home directory.
    * A complete snapshot, including the full contents of all source files, is generated for every discovered project, every time.

* **Zero-Interaction Design:**
    * Built from the ground up for automation (e.g., cron jobs).
    * Contains no interactive prompts. It intelligently adapts to its environment, such as by selecting a default cloud remote if run non-interactively.

* **Automated Archive & Cloud Sync:**
    * Performs local garbage collection to keep a configurable number of recent snapshots.
    * Uses `rclone sync` to mirror the local archive to a cloud backend, automatically pruning old remote snapshots to match the local state.

## 3. Installation & Deployment

This step-by-step guide will help you deploy ECHO on a new Debian-based system like Ubuntu.

### Step 1: Install Dependencies

First, ensure all required software packages are installed. `logrotate` is essential for long-term automated use.

```bash
sudo apt-get update && sudo apt-get install -y git rclone docker.io logrotate

Step 2: Clone the Repository

Clone the ECHO repository into the recommended directory in your home folder.
Bash

git clone [https://github.com/TheArkifaneVashtorr/ECHO.git](https://github.com/TheArkifaneVashtorr/ECHO.git) /home/dalhaka/ECHO

Step 3: Set Execute Permissions

Make the scripts executable.
Bash

chmod +x /home/dalhaka/ECHO/*.sh

Step 4: Configure Log Rotation

To prevent the cron log from growing infinitely, create a logrotate configuration file. This command will create the required file with the correct permissions.
Bash

cat << 'EOF' | sudo tee /etc/logrotate.d/echo > /dev/null
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

Step 5: Schedule the Cron Job

Finally, schedule the script to run automatically.

    Open your user's crontab for editing:
    Bash

    crontab -e

    Add the following line to the end of the file. This will execute the script every hour at the top of the hour.

    0 * * * * /home/dalhaka/ECHO/echo.sh >> /home/dalhaka/ECHO/echo_cron.log 2>&1

The installation is now complete. ECHO will run autonomously in the background.

4. Usage

The primary method for using ECHO is through the automated cron job scheduled during installation. The script will run hourly without any user interaction.

To trigger a snapshot manually at any time, you can execute the script directly:
Bash

/home/dalhaka/ECHO/echo.sh

Snapshots will be saved to ~/ECHO_Snapshots (or ~/Documents/ECHO_Snapshots on a desktop system).

5. Configuration

While ECHO is designed to run with zero configuration, you can tweak its behavior by editing the echo.sh script.

    Snapshot Retention: The number of snapshots to keep for the system and for each project is controlled by the SNAPSHOT_RETENTION_COUNT variable at the top of the script.

    Cloud Sync: For cloud synchronization to work, you must have rclone installed and configured with at least one remote (rclone config).

6. License

This project is licensed under the MIT License.
