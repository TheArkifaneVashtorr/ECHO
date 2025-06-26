ECHO (Executable Contextual Host Output)

Version: 2.7 | Author: TheArkifaneVashtorr & Janus.v4

ECHO is a powerful and flexible Bash script designed to create comprehensive snapshots of a Linux system's state. It captures vital hardware, software, and configuration data, archiving it locally and synchronizing it to a cloud backend. It is an essential tool for system administrators, developers, and AI partners who require consistent, detailed context for analysis, debugging, and operational oversight.
Features

    Comprehensive System Snapshots: Gathers critical information into a clean, readable Markdown file.

        Hardware: CPU, Memory, NVIDIA GPU (if present), PCI devices.

        OS & Software: OS version, kernel, running processes, and installed packages (dpkg).

        Disk & Network: Filesystem usage and network interface configurations.

        Docker Environment: Docker info, running/stopped containers.

    Intelligent Project Indexing:

        Automatically detects git repositories in the current directory.

        Scans for file modifications since the last snapshot, creating project-specific reports only when changes have occurred.

        Includes the full content of modified source files directly in the snapshot.

    Interactive & Automated Operation:

        Interactive Mode: A guided, prompt-driven process for manual snapshots.

        Automated Mode (--auto): A non-interactive mode designed for cron jobs and other automation, relying on cached settings to prevent hanging.

    Persistent Caching System:

        Remembers your choices for indexing specific project files (always or never), minimizing repeated prompts.

    Zero-Configuration Defaults:

        Dynamically creates snapshot directories in ~/Documents/ECHO_Snapshots for desktop environments or ~/ECHO_Snapshots for headless servers.

        Automatically detects and uses a single rclone remote. If multiple are found in interactive mode, it prompts for a selection.

    Automated Archive Management:

        Performs local garbage collection to keep a configurable number of recent snapshots (SNAPSHOT_RETENTION_COUNT).

        Uses rclone sync to mirror the local archive state to the cloud, ensuring old snapshots are pruned remotely as well.

Requirements

The script is designed for Linux and relies on several common command-line utilities. Most are installed by default on modern distributions like Ubuntu.

    Core Utilities: lscpu, free, df, ip, ps, dpkg, git, hostnamectl, stat, grep, sed, touch, find.

    Cloud Sync (Optional): rclone must be installed and configured with at least one remote for the cloud synchronization and remote garbage collection features to work.

    NVIDIA GPU Info (Optional): nvidia-smi is required to capture GPU details.

    Docker Info (Optional): docker is required to capture Docker environment details.

On a Debian/Ubuntu-based system, you can ensure all dependencies are met with:

sudo apt-get update
sudo apt-get install -y coreutils util-linux procps iproute2 git rclone docker.io

Installation

    Place the echo.sh script in a suitable directory on your system (e.g., /home/user/ECHO/echo.sh).

    Make the script executable:

    chmod +x /path/to/echo.sh

    (Optional) Create an alias in your .bashrc or .zshrc for easier access:

    echo "alias echosnap='/path/to/echo.sh'" >> ~/.bashrc
    source ~/.bashrc

Usage
Interactive Mode

To run a snapshot manually, simply execute the script from within your project directory.

./echo.sh

The script will guide you through the process, prompting you when it detects a project and asking which new files you wish to index.
Automated Mode

To run the script non-interactively for automation, use the --auto flag.

./echo.sh --auto

In this mode, the script will:

    Not prompt you to index a project; it will proceed automatically.

    Rely entirely on the .echo_cache file to decide which files to index. New, uncached files will be skipped.

    Skip cloud sync if multiple rclone remotes are found, preventing it from hanging.

Automation with Cron

You can schedule ECHO to run automatically using cron.

    Open your crontab for editing:

    crontab -e

    Add a line to schedule the script. The following example runs the script non-interactively every hour and logs the output for debugging.

    0 * * * * /path/to/echo.sh --auto >> /path/to/echo_cron.log 2>&1

Configuration

    Snapshot Retention: You can change the number of snapshots to keep locally (and by extension, on the cloud remote) by editing the SNAPSHOT_RETENTION_COUNT variable at the top of the echo.sh script.

    Snapshot Directory: The script automatically determines the snapshot directory. No configuration is needed.

    File Indexing Cache: The cache is stored at [Snapshot_Directory]/cache/.echo_cache. You can manually edit or delete this file to reset your indexing preferences.

License

This project is licensed under the MIT License. See the LICENSE file for details.
