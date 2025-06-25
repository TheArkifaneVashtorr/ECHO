# ECHO (Executable Contextual Host Output)

**Version:** 2.6 (Stable)
**Author:** TheArkifaneVashtorr

## 1. Overview

ECHO is a comprehensive, self-contained POSIX shell script designed to capture a detailed, point-in-time snapshot of a Linux system's state. Its primary purpose is to generate a concise, verifiable ground-truth document that can be used to provide context to collaborators, for archival purposes, or to feed into an AI partner's context window for more effective analysis and reasoning.

The tool generates modular, human-readable Markdown files that are segregated by type (system-wide vs. project-specific) and automatically organized into a clean folder structure. It features a sophisticated, interactive module for indexing `git`-managed projects, which intelligently tracks file changes over time to reduce redundant data capture.

All generated snapshots can be automatically synchronized with a cloud storage remote (e.g., Google Drive) via `rclone`, which also manages the deletion of old snapshots to maintain a tidy archive both locally and remotely.

## 2. Key Features

* **Zero-Configuration Setup:**
    * **Dynamic Paths:** Automatically detects if it's running in a desktop or server environment and creates a sensible snapshot directory (`~/Documents/ECHO_Snapshots` or `~/ECHO_Snapshots`) without requiring manual path configuration.
    * **Dynamic Remote Detection:** Automatically detects available `rclone` remotes. If only one exists, it's used by default. If multiple are found, the user is presented with a selection menu.

* **Modular & Organized Output:**
    * Creates separate snapshot files for the general system state and for individual software projects.
    * Generates a clean local folder structure (`/system`, `/projects/[project_name]`, `/cache`) which is mirrored to the cloud.

* **Intelligent Project Indexing:**
    * Automatically detects if it is being run from within a `git` repository.
    * Uses file modification times (`mtime`) to trigger project snapshot creation only when files have actually been modified since the last snapshot, preventing empty or redundant reports.
    * Prompts the user interactively (`y/N/always/never`) to include new or modified files.
    * Persistently caches user decisions for "always" and "never" index files to avoid repeated prompting on subsequent runs.
    * For unchanged files within a project snapshot, it writes a reference to the last snapshot where the content was captured instead of re-indexing the data.

* **Automated Cloud Sync & Garbage Collection:**
    * Uses `rclone sync` to maintain a perfect mirror of the local archive in the cloud.
    * Automatically prunes both local and remote snapshots based on a configurable retention count, ensuring a clean and manageable archive.

## 3. Requirements

* A **POSIX-compliant shell** (e.g., `bash`).
* **`git`**: Required for all project-related indexing features.
* **`rclone`**: Required for the cloud synchronization functionality. You must have at least one remote configured via `rclone config` for the script to use.
* **`python3`**: An underlying dependency for many modern Linux administration and diagnostic tools that may be called by this script. It should be present on most modern Linux systems.
* Standard Linux utilities such as `stat`, `sed`, `grep`, `find`, `ls`, `tput`, and `lscpu`.

## 4. Installation

1.  **Clone the Repository:**
    ```bash
    git clone [https://github.com/TheArkifaneVashtorr/ECHO.git](https://github.com/TheArkifaneVashtorr/ECHO.git)
    cd ECHO
    ```

2.  **Make the Script Executable:**
    ```bash
    chmod +x echo.sh
    ```

3.  **Create a Shorthand Command (Recommended):**
    To run the script easily from any directory, create a symbolic link. The name `echosnap` is recommended to avoid conflicts with built-in system commands.

    ```bash
    # Ensure the target directory exists
    mkdir -p ~/.local/bin
    
    # Create the symlink (use an absolute path for reliability)
    ln -s "$(pwd)/echo.sh" ~/.local/bin/echosnap
    ```
    *Note: You may need to log out and log back in or run `source ~/.profile` for your shell to recognize the new `echosnap` command.*

## 5. Configuration

The script is designed to be nearly zero-configuration. The only variable you may wish to edit is located at the top of the `echo.sh` file:

* **`SNAPSHOT_RETENTION_COUNT`**: Sets the number of old snapshots to keep in the archive for both system and project reports (default is `5`).

## 6. Usage

The script's behavior changes based on the directory from which it is run.

* **To Capture a System-Only Snapshot:**
    Run the script from any directory that is **not** a `git` repository.
    ```bash
    echosnap
    ```

* **To Capture a System & Project Snapshot:**
    Navigate (`cd`) into a `git`-managed project directory before running the script.
    ```bash
    cd /path/to/my/project
    echosnap
    ```
    The script will detect the project, and if any files have been modified since the last snapshot, it will begin the interactive indexing process.
