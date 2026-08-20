# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A small collection of standalone Bash scripts (in `scripts/`) that automate common Git branch-management operations (creating, checking out/updating, deleting locally and remotely, listing branches, and cherry-picking commits across branches). There is no build system, package manifest, test suite, or CI — each `.sh` file is a self-contained utility invoked directly from a shell.

## Running the scripts

```bash
chmod +x scripts/*.sh   # after cloning, since executable bits aren't preserved by all transports
./scripts/create-branches.sh <base_branch> <new_branch_name1> [new_branch_name2] ...
./scripts/checkout-branches.sh branch1 branch2 branch3
./scripts/delete-local-branches.sh main develop release   # defaults to keeping main/master/develop/release if no args given
./scripts/delete-remote-branches.sh <branch1> [branch2] ...   # deletes from origin; skips main/master/develop/release
./scripts/list-local-branches.sh
./scripts/cherry-pick-automation.sh <source_branch> <target_branch> <commit1> [commit2] ...
```

There are no automated tests. To validate a change, run the script by hand against a scratch/throwaway Git repo (or a repo you don't mind mutating) and read the printed summary/output — most scripts print a success/failure/skipped report at the end.

## Architecture / conventions shared across scripts

Every script follows the same shape, so when editing one, match the existing pattern rather than introducing a new style:

- **Structure**: banner header (script name + `Author: Mustansir Sabir`) → argument validation with a `Usage:` message on failure → main logic with step-by-step colored logging → a final summary report (success/failed/skipped lists where applicable).
- **Colors**: ANSI codes defined at the top of each script as `RED`/`GREEN`/`YELLOW`/`BLUE`/`PURPLE`/`NC` — red for errors, green for success, yellow for warnings/info, blue for section headers, purple for the author line. Reuse these exact variables rather than hardcoding escape codes.
- **Error handling**: check `$?` (or use `|| { ... ; exit 1; }`) after critical `git` commands; hard failures `exit 1` with a red message, soft failures (e.g. a `pull` that fails) get a yellow warning and the script continues.
- **Branch restoration**: scripts that hop between branches (`checkout-branches.sh`, `delete-local-branches.sh`) record the branch the user started on (or the first "keep" branch, for `delete-local-branches.sh`) and explicitly `git checkout` back to it before exiting, including on error paths.
- **Destructive operations**: `delete-local-branches.sh` uses `git branch -D` (force delete, no merge check) — any change here needs to preserve the existing "keep list" safeguard rather than deleting indiscriminately. `delete-remote-branches.sh` runs `git push origin --delete` against a shared remote and hardcodes a `PROTECTED_BRANCHES` list (`main`/`master`/`develop`/`release`) that is skipped even if explicitly passed in — preserve this safeguard when editing.
- **cherry-pick-automation.sh** deliberately stops and waits for manual input (`read -r`) on a cherry-pick conflict rather than attempting automatic conflict resolution — preserve this behavior; don't make it auto-abort or auto-continue. `--strict` is accepted for consistency but does not change this: conflicts always pause.

All scripts implement the standardized CLI flags described in the README's "Standardized CLI Patterns" section: `-h/--help`, `-v/--verbose` (shows full git command output instead of suppressing it), `-q/--quiet` (suppresses non-essential logs via each script's local `log()` helper; errors and the final summary still print), `--dry-run` (mutating git calls are routed through a local `run_git()` helper that logs `[dry-run] git ...` and returns success instead of executing — read-only inspection commands like `show-ref`/`ls-remote`/`fetch` still run for accurate planning), and `--strict` (a local `handle_failure()` helper exits immediately on the first failure instead of continuing to the next item, restoring the starting branch first in scripts that hop branches). `-v` and `-q` are mutually exclusive. `delete-local-branches.sh` and `delete-remote-branches.sh` additionally preview what will be changed and prompt for confirmation before deleting anything, unless `-y/--yes` or `--dry-run` is passed. Follow this same pattern (flags parsed out of `"$@"` into a `POSITIONAL` array, then `set --`) when adding new scripts or new mutating operations to existing ones.
