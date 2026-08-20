#!/bin/bash

# This script checks out multiple Git branches provided as arguments.
# For each branch:
# - If it exists locally → it will checkout and pull latest changes.
# - If it does NOT exist locally → it will fetch from remote and create it.
# Ensures all specified branches are up to date with the remote repository.
# Provides a summary report at the end.

# --- ANSI Color Codes for enhanced output ---
RED='\033[0;31m'    # Error
GREEN='\033[0;32m'  # Success
YELLOW='\033[0;33m' # Warning/Info
BLUE='\033[0;34m'   # Section headers
PURPLE='\033[0;35m' # Author/Special Info
NC='\033[0m'       # No Color

# --- Flag Defaults ---
VERBOSE=0
QUIET=0
DRY_RUN=0
STRICT=0

print_usage() {
    echo -e "${YELLOW}Usage: $0 [options] branch1 [branch2] [branch3] ...${NC}"
    echo -e "${YELLOW}"
    echo -e "Options:"
    echo -e "  -h, --help        Show this help message"
    echo -e "  -v, --verbose     Show full output of git commands"
    echo -e "  -q, --quiet       Suppress non-essential logs"
    echo -e "  --dry-run         Simulate actions without checking out or pulling"
    echo -e "  --strict          Exit immediately on first failure${NC}"
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

# Logs a failure, restores the original branch, and aborts when --strict is set
handle_failure() {
    log_err "${RED}$1${NC}"
    if [ "$STRICT" -eq 1 ]; then
        log_err "${RED}Strict mode enabled: aborting on first failure.${NC}"
        git checkout "$ORIGINAL_BRANCH" > /dev/null 2>&1
        exit 1
    fi
}

log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE} Git Multi-Branch Checkout & Update Utility${NC}"
log "${PURPLE} Author: Mustansir Sabir${NC}"
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

# Store original branch
ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
log "${YELLOW}Script started on branch: ${ORIGINAL_BRANCH}${NC}"

log "${BLUE}--------------------------------------------------${NC}"
log "${GREEN}Branches to process:${NC}"
for branch in "$@"; do
    log "  - $branch"
done
log "${BLUE}--------------------------------------------------${NC}"

# --- Result Tracking ---
SUCCESS_BRANCHES=()
FAILED_BRANCHES=()
SKIPPED_BRANCHES=()

# Fetch latest references
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

# Process each branch
for branch in "$@"; do
    log "${BLUE}--------------------------------------------------${NC}"
    log "${BLUE}Processing branch: ${branch}${NC}"

    if git show-ref --verify --quiet "refs/heads/$branch"; then
        log "${GREEN}Branch exists locally. Checking out...${NC}"
        run_git checkout "$branch"

        if [ $? -ne 0 ]; then
            handle_failure "Error: Failed to checkout '${branch}'."
            FAILED_BRANCHES+=("$branch")
            continue
        fi

        log "${BLUE}Pulling latest changes for '${branch}'...${NC}"
        run_git pull origin "$branch"

        if [ $? -eq 0 ]; then
            log "${GREEN}Successfully updated '${branch}'.${NC}"
            SUCCESS_BRANCHES+=("$branch")
        else
            handle_failure "Warning: Pull failed for '${branch}'."
            FAILED_BRANCHES+=("$branch")
        fi
    else
        log "${YELLOW}Branch not found locally. Attempting to fetch from remote...${NC}"

        run_git checkout -b "$branch" "origin/$branch"

        if [ $? -ne 0 ]; then
            handle_failure "Error: Branch '${branch}' not found on remote."
            SKIPPED_BRANCHES+=("$branch")
            continue
        fi

        log "${GREEN}Successfully created '${branch}'.${NC}"

        run_git pull origin "$branch"
        SUCCESS_BRANCHES+=("$branch")
    fi
done

# Return to original branch
log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE}Returning to original branch: ${ORIGINAL_BRANCH}${NC}"
run_git checkout "$ORIGINAL_BRANCH"

# --- Summary Report ---
log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE} Summary Report${NC}"
log "${BLUE}--------------------------------------------------${NC}"

log "${GREEN}Successful branches (${#SUCCESS_BRANCHES[@]}):${NC}"
for branch in "${SUCCESS_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${RED}Failed branches (${#FAILED_BRANCHES[@]}):${NC}"
for branch in "${FAILED_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${YELLOW}Skipped branches (${#SKIPPED_BRANCHES[@]}):${NC}"
for branch in "${SKIPPED_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${BLUE}--------------------------------------------------${NC}"
log "${GREEN}✅ Processing complete.${NC}"
log "${BLUE}--------------------------------------------------${NC}"
