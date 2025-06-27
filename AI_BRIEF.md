Strategic & Technical Brief: ECHO v3.5

--- DOCUMENT UPDATED: 2025-06-27 ---

1.0 Mission Overview

System Name: ECHO (Executable Contextual Host Output)
Version: 3.5 (Patched & Validated)
Primary Author: TheArkifaneVashtorr
AI Partner: Janus.v4
Change Log:

    v3.5: Corrected a logical flaw in project change detection. The script now correctly compares file modification times against the previous system snapshot, not the current one, ensuring accurate change detection.

    v3.4: Test release to validate E2E deployment.

    v3.3: Added up-front dependency checks and mandatory checksum verification for the updater.

1.1 Objective

The primary objective of ECHO is to create high-fidelity, machine-readable snapshots of a Linux system's state. These snapshots serve as a foundational dataset for operational analysis, debugging, and providing contextual ground truth to AI development partners. The system is designed for autonomous, unattended operation within Debian-based environments, ensuring data consistency with zero administrator intervention.

1.2 Core Use Case

An AI partner or developer requires a precise understanding of a target system's hardware, running processes, network state, and project file status to perform analysis or debug an issue. ECHO is executed on the target system, generating a comprehensive Markdown-formatted report which is then archived and synchronized to a central cloud location for the AI to ingest and analyze.

2.0 System Architecture & Features

2.1 Core Functionality: System Snapshotting

ECHO generates a detailed report of the host system's current state. This functionality is intentionally non-configurable to ensure data consistency across all snapshots.

Hardware Abstraction Layer: Captures data on CPU (lscpu), memory (free), and PCI devices. It will opportunistically capture NVIDIA GPU details via nvidia-smi if the utility is present.

Operating System Layer: Records the OS version and kernel details (hostnamectl), a full list of running processes (ps aux), and installed **Debian packages (dpkg -l)**.

Infrastructure Layer: Gathers filesystem usage (df -h), network interface state (ip a), and opportunistically captures the Docker environment state (docker info, docker ps) if the service is available.

2.2 Autonomous Update Subsystem (Hardened)

A key architectural feature of ECHO is its ability to maintain version consistency.

Update Trigger: Upon execution, the script fetches the latest version's header from a canonical URL. An update is only triggered if the remote version is demonstrably newer than the local script's version.

**Security - Checksum Verification:** The update process is critically secured. The `update-echo.sh` utility downloads both the new script and a corresponding SHA256 checksum file. The update is **aborted** if the local checksum of the downloaded script does not exactly match the official checksum.

Architecture - External Updater Model: The update process is delegated to a separate `update-echo.sh` utility. `echo.sh` immediately terminates its own process after launching the updater.

2.3 Context-Aware Project Indexing

This subsystem allows ECHO to create source-code-level snapshots of software projects.

Context Detection: The script uses `git rev-parse` to determine if it is being executed from within a Git repository. For this feature to activate, **the script must be executed from within the project directory.**

Change-Based Trigger: The primary value of this feature is efficiency. It compares the modification times of project files against the timestamp of the last system snapshot. A project report is only generated if changes have occurred.

2.3.1 **Resolved Issue - Change Detection Logic:** The system was patched to correct a flaw where file modification times were compared against the timestamp of the *current* snapshot being generated. The logic now correctly compares them against the timestamp of the **second-to-last snapshot**, ensuring an accurate state comparison from before the current run was initiated.

2.4 User Interaction & Automation

Interactive Mode (Default): When run manually, the script provides a guided experience, prompting the user for decisions.

Automated Mode: The system achieves automation by relying on a cache of user preferences and default behaviors.
- The `--auto` flag is used for non-interactive execution (e.g., in cron jobs) to bypass all user prompts.
- The cache file is located at `<snapshot_directory>/cache/.echo_cache` (e.g., `~/ECHO_Snapshots/cache/.echo_cache`).

2.5 Archive & Sync Subsystem

Automated Garbage Collection: To manage disk space, the script maintains a fixed number of recent snapshots, defined by the `SNAPSHOT_RETENTION_COUNT` variable.

Cloud Synchronization: If `rclone` is installed, the script will synchronize the local archive to a configured cloud remote.

3.0 Operational Requirements & Deployment

3.1 System Robustness - Dependency Validation

To prevent silent failures, echo.sh performs an up-front check and will fail fast with an explicit error message if any core dependency is missing.

3.2 System Dependencies

Core: curl, git, lscpu, free, df, ip, ps, hostnamectl, stat, grep, sed, touch, find, sort, tail, head, awk, dirname.

Optional: rclone (for cloud sync), nvidia-smi (for GPU data), docker (for container data).

3.3 Deployment

Place `echo.sh` and `update-echo.sh` in the same directory (e.g., `~/ECHO`).

Ensure both are executable: `chmod +x ~/ECHO/*.sh`.

3.3.1 **Automated Execution (Cron):** To ensure project-level snapshots are generated correctly, the cron job **must** change to the project directory before execution. Use the following format in your crontab (`crontab -e`):
`0 * * * * cd /home/dalhaka/ECHO && ./echo.sh --auto >> /home/dalhaka/ECHO/echo_cron.log 2>&1`

3.4 Security Maintenance - Automated Checksum Workflow

A GitHub Actions CI/CD workflow automatically recalculates and commits the echo.sh.sha256 checksum file whenever echo.sh is pushed to the main branch.

4.0 Project Status (As of 2025-06-27)
