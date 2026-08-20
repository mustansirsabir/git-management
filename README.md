# Git Management Utilities

This repository provides helpful Git automation scripts to streamline the process of managing branches, particularly in large development environments where creating and cleaning up branches can become repetitive and error-prone.

---

## ⚡ Quick Start

```bash
git clone <repo>
cd git-management
chmod +x scripts/*.sh
```

---

## 📁 Repository Structure

### Branch Management

* `create-branches.sh`
  Automates the creation of multiple branches from a common base branch and pushes them to the remote.

* `checkout-branches.sh`
  Checks out multiple branches. If a branch exists locally, it pulls the latest changes. If not, it fetches and creates it from remote.

* `delete-local-branches.sh`
  Force-deletes all local Git branches **except** those explicitly listed, reducing clutter and helping you focus on relevant branches.

* `delete-remote-branches.sh`
  Deletes multiple specified branches from the remote repository.

* `list-local-branches.sh`
  Lists all local branches in a clean format and highlights the currently active branch.

* `find-missing-branches.sh`
  Checks a list of branch names against local and/or remote branches and prints a tabular report of which ones are missing.

### Advanced Operations

* `cherry-pick-automation.sh`
  Automates the process of pulling the latest changes from a source branch, checking out a target branch, and cherry-picking multiple commits.

---

## 🚀 Usage

### 🔧 Prerequisites

* Git installed and configured
* Proper permissions to push/delete branches in the remote repository
* Run from within a valid Git working directory

---

## 📌 Scripts

### ✅ Creating Branches

```bash
chmod +x scripts/create-branches.sh
./scripts/create-branches.sh <base_branch> <new_branch_name1> [new_branch_name2] ...
```

---

### 🔄 Checkout & Update Multiple Branches

```bash
chmod +x scripts/checkout-branches.sh
./scripts/checkout-branches.sh branch1 branch2 branch3
```

✔ Features:

* Fetches latest from remote
* Creates branch if missing
* Pulls latest changes
* Provides summary report

---

### 📋 List Local Branches

```bash
chmod +x scripts/list-local-branches.sh
./scripts/list-local-branches.sh
```

✔ Features:

* Displays all local branches
* Highlights current branch
* Clean formatted output

---

### 🔍 Finding Missing Branches

```bash
chmod +x scripts/find-missing-branches.sh
./scripts/find-missing-branches.sh branch1 branch2 branch3
./scripts/find-missing-branches.sh --local-only branch1 branch2
./scripts/find-missing-branches.sh --remote-only branch1 branch2
```

✔ Features:

* Checks each given branch name against local branches, remote branches, or both (default)
* `-l`, `--local-only` — only check local branches
* `-r`, `--remote-only` — only check branches on `origin`
* Prints a tabular report (branch / local / remote / status)
* Provides a found/missing summary report

---

### ❌ Deleting Local Branches

```bash
chmod +x scripts/delete-local-branches.sh
./scripts/delete-local-branches.sh main develop release
```

✔ Features:

* Keeps specified branches
* Deletes all others
* Updates kept branches
* Previews what will be updated/deleted and asks for confirmation before deleting (`-y`/`--yes` to skip)

---

### 🗑️ Deleting Remote Branches

```bash
chmod +x scripts/delete-remote-branches.sh
./scripts/delete-remote-branches.sh feature/old-feature bugfix/stale-fix
```

✔ Features:

* Deletes the specified branches from `origin`
* Skips branches that don't exist on the remote
* Skips protected branches (`main`, `master`, `develop`, `release`)
* Asks for confirmation before deleting (`-y`/`--yes` to skip)
* Provides a success/failed/skipped summary report

---

### 🍒 Cherry-Picking Commits

```bash
chmod +x scripts/cherry-pick-automation.sh
./scripts/cherry-pick-automation.sh <source_branch> <target_branch> <commit1> [commit2] ...
```

Example:

```bash
./scripts/cherry-pick-automation.sh feature/new-feature bugfix/hotfix abc123 def456
```

---

## ⚠️ Warnings

* Some scripts use `git branch -D` (force delete)
* `delete-remote-branches.sh` permanently deletes branches from the shared remote — this affects everyone using the repository
* Ensure all work is committed and pushed before running cleanup scripts
* Cherry-pick conflicts must be resolved manually

---

## 🔒 Safety Note

Always review scripts before running in production repositories.

---

## 💡 Suggestions / Future Improvements

You can extend this toolkit with:

* `sync-with-base.sh` → keep branches updated with develop/main
* `delete-merged-branches.sh` → safer cleanup
* `branch-status-report.sh` → visibility dashboard
* `smart-pull.sh` → safe pull with stash handling

---

## ⚙️ Standardized CLI Patterns

To ensure consistency and ease of use, all scripts in this repository follow a unified CLI design.

### 🔹 General Pattern

```bash
./script-name.sh [options] [arguments]
```

---

### 🔹 Common Flags (Implemented in All Scripts)

| Flag              | Description                               |
| ----------------- | ----------------------------------------- |
| `-h`, `--help`    | Show usage information                    |
| `-v`, `--verbose` | Enable detailed logging                   |
| `-q`, `--quiet`   | Minimal output                            |
| `--dry-run`       | Simulate execution without making changes |
| `--strict`        | Exit immediately on first failure         |

---

### 🔹 Help Menu Template

Each script should implement a help section like:

```bash
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Usage: ./script-name.sh [options] [arguments]"
  echo ""
  echo "Options:"
  echo "  -h, --help        Show this help message"
  echo "  -v, --verbose     Enable verbose output"
  echo "  -q, --quiet       Suppress non-essential logs"
  echo "  --dry-run         Simulate actions without executing"
  exit 0
fi
```

---

### 🔹 Output Conventions

* Use consistent color coding:

  * Green → Success
  * Red → Errors
  * Yellow → Warnings
  * Blue → Sections
* Always print:

  * Start banner
  * Operation steps
  * Final summary

---

### 🔹 Error Handling Standard

* Check exit codes (`$?`) after critical commands
* Provide clear error messages
* Use `exit 1` for failures

---

### 🔹 Summary Reporting

Where applicable, scripts should provide:

* Success list
* Failure list
* Skipped items

---

### 🔹 Naming Convention

* Use **kebab-case** for all script names
* Example: `checkout-branches.sh`

---

### 🔹 Argument Design Principles

* Positional arguments for required inputs
* Flags for optional behavior
* Avoid hardcoding values (like branch names)

---

## 🧑‍💻 Author

**Mustansir Sabir**

Feel free to contribute or fork this repository to build your own Git workflow toolkit 🚀
