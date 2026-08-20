#!/bin/bash

# This script automates the process of pulling a source branch,
# checking out a target branch, and then cherry-picking multiple
# commits from the source branch onto the target branch.

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
    echo -e "${RED}Usage: $0 [options] <source_branch> <target_branch> <commit_hash1> [commit_hash2] ...${NC}"
    echo -e "${YELLOW}Example: $0 develop main abc1234 def5678${NC}"
    echo -e "${YELLOW}"
    echo -e "Options:"
    echo -e "  -h, --help        Show this help message"
    echo -e "  -v, --verbose     Show full output of git commands"
    echo -e "  -q, --quiet       Suppress non-essential logs"
    echo -e "  --dry-run         Simulate the cherry-picks without applying them"
    echo -e "  --strict          Accepted for consistency; a conflict always pauses for manual resolution${NC}"
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

if [ "$#" -lt 3 ]; then
    print_usage
    exit 1
fi

SOURCE_BRANCH="$1"
TARGET_BRANCH="$2"
shift 2
COMMITS_TO_CHERRY_PICK=("$@")

log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE} Git Cherry-Pick Automation${NC}"
log "${PURPLE} Author: Mustansir Sabir${NC}"
log "${BLUE}--------------------------------------------------${NC}"
log "${YELLOW}Source Branch: ${SOURCE_BRANCH}${NC}"
log "${YELLOW}Target Branch: ${TARGET_BRANCH}${NC}"
log "${YELLOW}Commits to Cherry-Pick: ${COMMITS_TO_CHERRY_PICK[*]}${NC}"
log "${BLUE}--------------------------------------------------${NC}"

# Check if inside a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log_err "${RED}Error: This is not a Git repository.${NC}"
    exit 1
fi

# Store the branch we started on so we can bounce back to it if setup fails
# before any cherry-pick has been applied. Once cherry-picking starts, the
# script intentionally leaves you on TARGET_BRANCH for review, even on success.
ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# 1. Pull the latest from the given source branch
log "${BLUE}Step 1: Pulling latest from '${SOURCE_BRANCH}'...${NC}"
run_git checkout "$SOURCE_BRANCH"
if [ $? -ne 0 ]; then
    log_err "${RED}Error: Could not checkout source branch '${SOURCE_BRANCH}'. Exiting.${NC}"
    git checkout "$ORIGINAL_BRANCH" > /dev/null 2>&1
    exit 1
fi
run_git pull origin "$SOURCE_BRANCH"
if [ $? -ne 0 ]; then
    log_err "${RED}Error: Could not pull '${SOURCE_BRANCH}'. Exiting.${NC}"
    git checkout "$ORIGINAL_BRANCH" > /dev/null 2>&1
    exit 1
fi
log "${GREEN}Successfully pulled '${SOURCE_BRANCH}'.${NC}"

# 2. Check out the target branch
log "${BLUE}Step 2: Checking out target branch '${TARGET_BRANCH}'...${NC}"
run_git checkout "$TARGET_BRANCH"
if [ $? -ne 0 ]; then
    log_err "${RED}Error: Could not checkout target branch '${TARGET_BRANCH}'. Exiting.${NC}"
    git checkout "$ORIGINAL_BRANCH" > /dev/null 2>&1
    exit 1
fi
log "${GREEN}Successfully checked out '${TARGET_BRANCH}'.${NC}"

# 3. Perform cherry-pick from multiple commits
log "${BLUE}Step 3: Performing cherry-pick of commits into '${TARGET_BRANCH}'...${NC}"

SUCCESS_COMMITS=()
FAILED_COMMITS=()

for commit_hash in "${COMMITS_TO_CHERRY_PICK[@]}"; do
    log "${YELLOW}Attempting to cherry-pick commit: ${commit_hash}${NC}"

    if [ "$DRY_RUN" -eq 1 ]; then
        log "${YELLOW}[dry-run] git cherry-pick ${commit_hash}${NC}"
        SUCCESS_COMMITS+=("$commit_hash")
        continue
    fi

    if [ "$VERBOSE" -eq 1 ]; then
        git cherry-pick "$commit_hash"
    else
        git cherry-pick "$commit_hash" > /dev/null 2>&1
    fi

    if [ $? -ne 0 ]; then
        log_err "${RED}Warning: Cherry-pick of commit '${commit_hash}' failed. Please resolve conflicts manually and then run 'git cherry-pick --continue' or 'git cherry-pick --abort'.${NC}"
        FAILED_COMMITS+=("$commit_hash")
        echo -e "${YELLOW}Script paused. Press Enter to continue after manual resolution or abort.${NC}"
        read -r
        # Exit here rather than guessing whether the conflict was resolved or
        # aborted -- re-run the script for any remaining commits afterward.
        break
    else
        log "${GREEN}Successfully cherry-picked commit: ${commit_hash}${NC}"
        SUCCESS_COMMITS+=("$commit_hash")
    fi
done

# --- Summary Report ---
log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE} Summary Report${NC}"
log "${BLUE}--------------------------------------------------${NC}"

log "${GREEN}Cherry-picked (${#SUCCESS_COMMITS[@]}):${NC}"
for commit in "${SUCCESS_COMMITS[@]}"; do
    log "  - $commit"
done

log "${RED}Failed/paused (${#FAILED_COMMITS[@]}):${NC}"
for commit in "${FAILED_COMMITS[@]}"; do
    log "  - $commit"
done

log "${BLUE}--------------------------------------------------${NC}"

if [ "${#FAILED_COMMITS[@]}" -gt 0 ]; then
    log_err "${RED}Cherry-pick process stopped due to a conflict. Resolve it, then re-run for any remaining commits.${NC}"
    exit 1
fi

log "${GREEN}Cherry-pick process completed. You are on '${TARGET_BRANCH}'.${NC}"
log "${YELLOW}Please review the changes and commit them if everything looks good.${NC}"
log "${BLUE}--------------------------------------------------${NC}"
