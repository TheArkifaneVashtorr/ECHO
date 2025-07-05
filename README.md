# ECHO: Executable Contextual Host Output

ECHO is not just a backup script; it's a powerful **context engineering** tool designed to give you and your AI development partners a comprehensive, machine-readable understanding of your system's state.

## What is Context Engineering?

An AI coding assistant is only as good as the context it's given. Manually feeding it files and logs is slow and inefficient. **Context Engineering** is the practice of automatically capturing and structuring all the relevant information about a system—the hardware, the OS, the running services, the project files, the code structure—and formatting it in a way that an AI can instantly understand.

ECHO automates this entire process. It runs a series of diagnostic commands and scans your projects to create a single, data-rich **JSON snapshot**. This snapshot acts as a "briefing document" for an AI, giving it the deep context needed to perform complex tasks accurately.

-----

## Features

  * **Structured JSON Snapshots:** Creates a detailed `system_snapshot.json` file, providing a perfectly machine-readable overview of your system's state.
  * **Deep Docker Context:** The snapshot includes a list of all Docker containers, their recent logs, resource usage statistics, and the contents of their `docker-compose.yml` files.
  * **Project Architecture View:** Automatically generates a `tree` view for each discovered project, giving instant insight into its directory and file structure.
  * **Efficient Project Backups:** In addition to the system snapshot, ECHO performs efficient, incremental backups of your project directories using `rclone`. It only transfers files that have changed, saving time and bandwidth.
  * **Self-Updating:** The script can automatically check for new versions from its GitHub repository and update itself.
  * **Dynamic and Portable:** The script is designed to be portable, using system variables like `$USER` and `$HOSTNAME` instead of hardcoded values.

-----

## Installation

ECHO is designed to be run on a Linux-based system and has a few core dependencies.

### 1\. Install Dependencies

First, ensure you have all the necessary command-line tools. You can install them using your system's package manager.

**For Debian/Ubuntu:**

```bash
sudo apt-get update && sudo apt-get install -y rclone git jq tree
```

### 2\. Clone the Repository

Clone the ECHO repository to your machine.

```bash
git clone https://github.com/TheArkifaneVashtorr/ECHO.git
cd ECHO
```

### 3\. Configure `rclone`

ECHO uses `rclone` to sync your snapshots and backups to cloud storage. You must configure at least one `rclone` remote.

  * Run the configuration utility:
    ```bash
    rclone config
    ```
  * Follow the interactive prompts to add a new remote for your preferred cloud storage provider (e.g., Google Drive, MinIO, Dropbox, etc.).

-----

## How to Use

Simply execute the script from within its directory:

```bash
./echo.sh
```

The script will automatically discover your projects, generate a system snapshot in `~/ECHO_Snapshots/system`, and sync both the snapshot and your project backups to all configured `rclone` remotes.

-----

## Use Cases

### 1\. AI Context Briefing

The primary use case is to provide deep context to an AI assistant like me.

  * **Workflow:**
    1.  Run `./echo.sh` on your server.
    2.  Provide me with the latest `system_snapshot_...json` file from the `~/ECHO_Snapshots/system` directory.
    3.  I can instantly parse this file to get a comprehensive understanding of your server's hardware, OS, Docker environment, and project structures, allowing me to provide more accurate and insightful assistance.

### 2\. Vector Embedding and RAG

The incremental project backups are ideal for creating a **Retrieval-Augmented Generation (RAG)** system.

  * **Workflow:**
    1.  The `ECHO.sh` script continuously syncs your project directories to a cloud storage location (like a MinIO bucket).
    2.  You can point a vector embedding service at this remote directory.
    3.  The service can then read the files, create vector embeddings of your code, and store them in a vector database like Qdrant.
    4.  This allows your AI agents to perform semantic searches over your entire codebase to find the most relevant context for any given task.
