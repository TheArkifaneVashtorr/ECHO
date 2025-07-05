Of course. Here is a rewritten AI Brief, optimized for density and machine readability to serve as a manifest for an AI model.

---

### **`AI_BRIEF_ECHO_v6.1.md`**

**ID:** ECHO_SYSTEM_SNAPSHOT_GENERATOR

**Purpose:** To generate a comprehensive, structured system state snapshot for AI analysis and perform efficient, incremental project backups.

**Core_Function:** The script executes locally to produce two primary artifacts: a detailed **JSON system snapshot** and a direct-file **project backup** synced to one or more `rclone` remotes.

---
### **Output Artifacts**

#### **1. System Snapshot**
* **Format:** `JSON`
* **File Naming Convention:** `system_snapshot_<hostname>_<timestamp>.json`
* **Default Location:** `~/ECHO_Snapshots/system/`
* **JSON Schema Overview:**
    * `timestamp`: [string] ISO 8601 timestamp of snapshot creation.
    * `hostname`: [string] Hostname of the machine.
    * `user`: [string] User executing the script.
    * `system`: [object] OS-level information.
        * `os_info`: [string] Output of `hostnamectl`.
        * `disk_usage`: [string] Output of `df -h`.
        * `network_interfaces`: [string] Output of `ip a`.
    * `hardware`: [object] Hardware information.
        * `cpu_info`: [string] Output of `lscpu`.
        * `memory_info`: [string] Output of `free -h`.
        * `gpu_info`: [string, optional] Output of `nvidia-smi`.
    * `docker`: [object] Deep Docker environment context.
        * `info`: [string] Output of `docker info`.
        * `containers`: [string] Output of `docker ps -a`.
        * `resource_stats`: [string] Output of `docker stats --no-stream`.
        * `networks`: [string] Output of `docker network ls`.
        * `container_logs`: [array] List of objects, each containing `container_name` and the last 50 lines of its `logs`.
        * `compose_files`: [array] List of objects, each containing the `path` and `content` of a found `docker-compose.yml` file.
    * `project_directory_trees`: [array] List of objects, each containing `project_name` and the output of `tree -L 3` for that project's directory.

#### **2. Project Backups**
* **Method:** `rclone sync`
* **Type:** Incremental, direct file mirror (preserves directory structure).
* **Features:** Deletes files on the remote if they are deleted locally (`--delete-after`).
* **Remote Path Structure:** `remote:<bucket_name>/<hostname>/projects/<project_name>/`

---
### **Primary Use Cases**

1.  **AI Context Briefing:** The primary intended use. The `system_snapshot.json` file should be provided as the foundational context document for any analysis or debugging task related to the system.
2.  **Codebase Analysis for RAG:** The project backups on the `rclone` remote serve as a clean, mirrored data source. Point a vector embedding pipeline at this remote to create and maintain embeddings of the codebase for Retrieval-Augmented Generation.
3.  **Disaster Recovery:** The project backups are a fully restorable, browsable mirror of the project files.

---
### **Execution & Dependencies**

* **Command:** `./echo.sh`
* **Location:** Can be run from any directory on the host machine.
* **Dependencies (must be in PATH):** `rclone`, `curl`, `git`, `lscpu`, `free`, `df`, `ip`, `hostnamectl`, `stat`, `grep`, `sed`, `touch`, `find`, `sort`, `tail`, `head`, `awk`, `dirname`, `basename`, `jq`, `tree`.
