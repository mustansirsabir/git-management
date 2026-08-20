#!/bin/bash

# This script deletes multiple specified branches from the remote repository.
# Branches are provided as command-line arguments.
# Provides a summary report at the end.

# --- ANSI Color Codes for enhanced output ---
RED='\033[0;31m'    # Error/Deletion
GREEN='\033[0;32m'  # Success
YELLOW='\033[0;33m' # Warning/Info
BLUE='\033[0;34m'   # Section headers
PURPLE='\033[0;35m' # Author/Special Info
NC='\033[0m'       # No Color

REMOTE="origin"

# --- Flag Defaults ---
VERBOSE=0
QUIET=0
DRY_RUN=0
STRICT=0
ASSUME_YES=0

print_usage() {
    echo -e "${YELLOW}Usage: $0 [options] <branch1> [branch2] ...${NC}"
    echo -e "${YELLOW}Example: $0 feature/old-feature bugfix/stale-fix${NC}"
    echo -e "${YELLOW}"
    echo -e "Options:"
    echo -e "  -h, --help        Show this help message"
    echo -e "  -v, --verbose     Show full output of git commands"
    echo -e "  -q, --quiet       Suppress non-essential logs"
    echo -e "  --dry-run         Show what would be deleted without doing it"
    echo -e "  --strict          Exit immediately on first failure"
    echo -e "  -y, --yes         Skip the confirmation prompt${NC}"
}

# --- Argument Parsing ---
POSITIONAL=()
for arg in "$@"; do
    case "$arg" in
        -h|--help) print_usage; exit 0 ;;
        -v|--verbose) VERBOSE=1 ;;
        -q|--quiet) QUIET=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --strict) STRICT=1 ;;
        -y|--yes) ASSUME_YES=1 ;;
        *) POSITIONAL+=("$arg") ;;
    esac
done
set -- "${POSITIONAL[@]}"

if [ "$VERBOSE" -eq 1 ] && [ "$QUIET" -eq 1 ]; then
    echo -e "${RED}Error: --verbose and --quiet are mutually exclusive.${NC}"
    exit 1
fi

log()     { [ "$QUIET" -eq 0 ] && echo -e "$1"; return 0; }
log_err() { echo -e "$1" >&2; }

# Runs a mutating git command, honoring --dry-run and --verbose
run_git() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log "${YELLOW}[dry-run] git $*${NC}"
        return 0
    fi
    if [ "$VERBOSE" -eq 1 ]; then
        git "$@"
    else
        git "$@" > /dev/null 2>&1
    fi
}

# Logs a failure and aborts immediately when --strict is set
handle_failure() {
    log_err "${RED}$1${NC}"
    if [ "$STRICT" -eq 1 ]; then
        log_err "${RED}Strict mode enabled: aborting on first failure.${NC}"
        exit 1
    fi
}

log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE} Git Remote Branch Deletion Utility${NC}"
log "${PURPLE} Author: Mustansir Sabir${NC}"
log "${BLUE}--------------------------------------------------${NC}"
log "${YELLOW}WARNING: This script deletes branches from the remote '${REMOTE}'.${NC}"
log "${YELLOW}This action affects everyone using the remote repository.${NC}"
log "${BLUE}--------------------------------------------------${NC}"

# Check if inside a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log_err "${RED}Error: This is not a Git repository.${NC}"
    exit 1
fi

# Validate input
if [ "$#" -eq 0 ]; then
    log_err "${RED}Error: No branches provided.${NC}"
    print_usage
    exit 1
fi

log "${GREEN}Branches to delete from '${REMOTE}':${NC}"
for branch in "$@"; do
    log "  - $branch"
done
log "${BLUE}--------------------------------------------------${NC}"

if [ "$DRY_RUN" -eq 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
    echo -e "${YELLOW}Delete $# branch(es) listed above from '${REMOTE}'? [y/N]${NC}"
    read -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log "${YELLOW}Aborted by user. No branches were deleted.${NC}"
        exit 0
    fi
fi

# --- Result Tracking ---
SUCCESS_BRANCHES=()
FAILED_BRANCHES=()
SKIPPED_BRANCHES=()

# Fetch latest references so remote branch state is up to date
log "${BLUE}Fetching latest updates from remote...${NC}"
if [ "$VERBOSE" -eq 1 ]; then
    git fetch --all --prune
else
    git fetch --all --prune > /dev/null 2>&1
fi
if [ $? -ne 0 ]; then
    log_err "${RED}Error: Failed to fetch from remote.${NC}"
    exit 1
fi

# Protect commonly used branches from accidental deletion
PROTECTED_BRANCHES=("main" "master" "develop" "release")

for branch in "$@"; do
    log "${BLUE}--------------------------------------------------${NC}"
    log "${BLUE}Processing branch: ${branch}${NC}"

    if [[ " ${PROTECTED_BRANCHES[@]} " =~ " ${branch} " ]]; then
        log "${YELLOW}Skipping protected branch: ${branch}${NC}"
        SKIPPED_BRANCHES+=("$branch")
        continue
    fi

    if ! git ls-remote --exit-code --heads "$REMOTE" "$branch" > /dev/null 2>&1; then
        log "${YELLOW}Branch '${branch}' does not exist on '${REMOTE}'. Skipping.${NC}"
        SKIPPED_BRANCHES+=("$branch")
        continue
    fi

    log "${RED}Deleting '${branch}' from '${REMOTE}'...${NC}"
    run_git push "$REMOTE" --delete "$branch"

    if [ $? -eq 0 ]; then
        log "${GREEN}Successfully deleted '${branch}' from '${REMOTE}'.${NC}"
        SUCCESS_BRANCHES+=("$branch")
    else
        handle_failure "Error: Failed to delete '${branch}' from '${REMOTE}'."
        FAILED_BRANCHES+=("$branch")
    fi
done

# --- Summary Report ---
log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE} Summary Report${NC}"
log "${BLUE}--------------------------------------------------${NC}"

log "${GREEN}Successfully deleted (${#SUCCESS_BRANCHES[@]}):${NC}"
for branch in "${SUCCESS_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${RED}Failed to delete (${#FAILED_BRANCHES[@]}):${NC}"
for branch in "${FAILED_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${YELLOW}Skipped (${#SKIPPED_BRANCHES[@]}):${NC}"
for branch in "${SKIPPED_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${BLUE}--------------------------------------------------${NC}"
log "${GREEN}✅ Processing complete.${NC}"
log "${BLUE}--------------------------------------------------${NC}"
