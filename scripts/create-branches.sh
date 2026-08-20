#!/bin/bash

# This script automates the creation of multiple new Git branches
# from a specified base branch, ensures the base branch is up-to-date,
# and then switches back to the base branch.

# --- ANSI Color Codes for enhanced output ---
RED='\033[0;31m'    # Error/Failure
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
    echo -e "${RED}Usage: $0 [options] <base_branch> <new_branch_name1> [new_branch_name2] ...${NC}"
    echo -e "${YELLOW}Example: $0 main feature/my-feature bugfix/an-issue${NC}"
    echo -e "${YELLOW}"
    echo -e "Options:"
    echo -e "  -h, --help        Show this help message"
    echo -e "  -v, --verbose     Show full output of git commands"
    echo -e "  -q, --quiet       Suppress non-essential logs"
    echo -e "  --dry-run         Simulate actions without creating or pushing branches"
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

# Logs a failure and aborts immediately when --strict is set
handle_failure() {
    log_err "${RED}$1${NC}"
    if [ "$STRICT" -eq 1 ]; then
        log_err "${RED}Strict mode enabled: aborting on first failure.${NC}"
        exit 1
    fi
}

# Check if enough arguments are provided
if [ "$#" -lt 2 ]; then
    print_usage
    exit 1
fi

BASE_BRANCH="$1"
shift
NEW_BRANCHES=("$@")

# --- Script Start ---
log "${BLUE}----------------------------------------${NC}"
log "${BLUE} Git Branch Creation Automation${NC}"
log "${PURPLE} Author: Mustansir Sabir${NC}"
log "${BLUE}----------------------------------------${NC}"
log "${YELLOW}Base Branch: ${BASE_BRANCH}${NC}"
log "${YELLOW}Branches to Create: ${NEW_BRANCHES[*]}${NC}"
log "${BLUE}----------------------------------------${NC}"

# Check if inside a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log_err "${RED}Error: This is not a Git repository.${NC}"
    exit 1
fi

SUCCESS_BRANCHES=()
FAILED_BRANCHES=()
SKIPPED_BRANCHES=()

# 1. Pull the latest given branch (BASE_BRANCH)
log "${BLUE}Step 1: Checking out and pulling latest from '${BASE_BRANCH}'...${NC}"

# Check if the base branch exists locally
if git show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
    log "${YELLOW}Local branch '${BASE_BRANCH}' found.${NC}"
else
    log "${YELLOW}Local branch '${BASE_BRANCH}' not found. Attempting to fetch and checkout.${NC}"
    run_git fetch origin "$BASE_BRANCH:$BASE_BRANCH"
    if [ $? -ne 0 ]; then
        log_err "${RED}Error: Could not fetch and checkout '${BASE_BRANCH}' from remote. Exiting.${NC}"
        exit 1
    fi
fi

# Checkout the base branch
run_git checkout "$BASE_BRANCH"
if [ $? -ne 0 ]; then
    log_err "${RED}Error: Could not checkout base branch '${BASE_BRANCH}'. Exiting.${NC}"
    exit 1
fi
log "${GREEN}Successfully checked out '${BASE_BRANCH}'.${NC}"

# Pull the latest changes from the remote
run_git pull origin "$BASE_BRANCH"
if [ $? -ne 0 ]; then
    log_err "${RED}Error: Could not pull latest from '${BASE_BRANCH}'. Exiting.${NC}"
    exit 1
fi
log "${GREEN}Successfully pulled latest from '${BASE_BRANCH}'.${NC}"

# 2. Sequentially Create branches from branch "A" (BASE_BRANCH)
log "${BLUE}Step 2: Creating new branches from '${BASE_BRANCH}'...${NC}"
for branch_name in "${NEW_BRANCHES[@]}"; do
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        log "${YELLOW}Branch '${branch_name}' already exists locally. Skipping creation.${NC}"
        SKIPPED_BRANCHES+=("$branch_name")
        continue
    fi

    log "${GREEN}Creating branch: ${branch_name}${NC}"
    run_git branch "$branch_name"
    if [ $? -ne 0 ]; then
        handle_failure "Error: Could not create branch '${branch_name}'."
        FAILED_BRANCHES+=("$branch_name")
        continue
    fi
    log "${GREEN}Successfully created branch '${branch_name}'.${NC}"

    log "${YELLOW}Pushing branch '${branch_name}' to remote...${NC}"
    run_git push -u origin "$branch_name"
    if [ $? -ne 0 ]; then
        handle_failure "Warning: Could not push branch '${branch_name}' to remote. Please push manually."
        FAILED_BRANCHES+=("$branch_name")
        continue
    fi
    SUCCESS_BRANCHES+=("$branch_name")
done

# 3. Once all the branches are created switch the current branch to branch "A"
log "${BLUE}Step 3: Switching back to '${BASE_BRANCH}'...${NC}"
run_git checkout "$BASE_BRANCH"
if [ $? -ne 0 ]; then
    log_err "${RED}Error: Could not switch back to '${BASE_BRANCH}'. Exiting.${NC}"
    exit 1
fi
log "${GREEN}Successfully switched back to '${BASE_BRANCH}'.${NC}"

# --- Summary Report ---
log "${BLUE}----------------------------------------${NC}"
log "${BLUE} Summary Report${NC}"
log "${BLUE}----------------------------------------${NC}"

log "${GREEN}Created (${#SUCCESS_BRANCHES[@]}):${NC}"
for branch in "${SUCCESS_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${RED}Failed (${#FAILED_BRANCHES[@]}):${NC}"
for branch in "${FAILED_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${YELLOW}Skipped (${#SKIPPED_BRANCHES[@]}):${NC}"
for branch in "${SKIPPED_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${BLUE}----------------------------------------${NC}"
log "${GREEN}Branch creation process completed.${NC}"
log "${YELLOW}You are currently on branch: $(git rev-parse --abbrev-ref HEAD)${NC}"
log "${BLUE}----------------------------------------${NC}"
