#!/bin/bash

# This script force-deletes all local Git branches except those explicitly listed.
# It also ensures that all "kept" branches are updated with their latest changes
# from the remote repository.
# Branches to keep can be provided as command-line arguments or
# a default list will be used if no arguments are given.

# --- ANSI Color Codes for enhanced output ---
RED='\033[0;31m'    # Error/Deletion
GREEN='\033[0;32m'  # Success/Keeping
YELLOW='\033[0;33m' # Warning/Info
BLUE='\033[0;34m'   # Section headers
PURPLE='\033[0;35m' # Author/Special Info
NC='\033[0m'       # No Color

# --- Configuration (Default KEEP_BRANCHES if no arguments are provided) ---
DEFAULT_KEEP_BRANCHES=(
  "main"
  "master"
  "develop"
  "release"
)

# --- Flag Defaults ---
VERBOSE=0
QUIET=0
DRY_RUN=0
STRICT=0
ASSUME_YES=0

print_usage() {
    echo -e "${YELLOW}Usage: $0 [options] [branch_to_keep1] [branch_to_keep2] ...${NC}"
    echo -e "${YELLOW}If no branches are given, defaults to: ${DEFAULT_KEEP_BRANCHES[*]}${NC}"
    echo -e "${YELLOW}"
    echo -e "Options:"
    echo -e "  -h, --help        Show this help message"
    echo -e "  -v, --verbose     Show full output of git commands"
    echo -e "  -q, --quiet       Suppress non-essential logs"
    echo -e "  --dry-run         Show what would be deleted/updated without doing it"
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

# Logs a failure, restores the starting branch, and aborts when --strict is set
handle_failure() {
    log_err "${RED}$1${NC}"
    if [ "$STRICT" -eq 1 ]; then
        log_err "${RED}Strict mode enabled: aborting on first failure.${NC}"
        git checkout "$ORIGINAL_STARTING_BRANCH" > /dev/null 2>&1 || true
        exit 1
    fi
}

# If command-line arguments are provided, use them as KEEP_BRANCHES.
# Otherwise, use the DEFAULT_KEEP_BRANCHES.
if [ "$#" -gt 0 ]; then
    KEEP_BRANCHES=("$@")
    log "${BLUE}Using branches to keep from command-line arguments.${NC}"
else
    KEEP_BRANCHES=("${DEFAULT_KEEP_BRANCHES[@]}")
    log "${BLUE}Using default branches to keep. To specify, pass them as arguments.${NC}"
fi

log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE} Git Local Branch Cleanup Utility${NC}"
log "${PURPLE} Author: Mustansir Sabir${NC}"
log "${BLUE}--------------------------------------------------${NC}"
log "${YELLOW}WARNING: This script performs force deletions (git branch -D).${NC}"
log "${YELLOW}Ensure all important work is pushed to remote before proceeding!${NC}"
log "${BLUE}--------------------------------------------------${NC}"
log "${GREEN}Branches to KEEP (and update):${NC}"
for branch in "${KEEP_BRANCHES[@]}"; do
  log "  - ${GREEN}$branch${NC}"
done
log "${BLUE}--------------------------------------------------${NC}"

# Check if inside a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log_err "${RED}Error: This is not a Git repository.${NC}"
    exit 1
fi

# Store the branch that was active when the script started
ORIGINAL_STARTING_BRANCH=$(git rev-parse --abbrev-ref HEAD)
log "${YELLOW}Script started on branch: ${ORIGINAL_STARTING_BRANCH}${NC}"

# Check if KEEP_BRANCHES is not empty before proceeding
if [ ${#KEEP_BRANCHES[@]} -eq 0 ]; then
    log_err "${RED}Error: No branches specified to keep. Exiting.${NC}"
    exit 1
fi

# Set the first branch from KEEP_BRANCHES as the primary branch for operations.
PRIMARY_KEEP_BRANCH="${KEEP_BRANCHES[0]}"

log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE} Initiating operations with '${PRIMARY_KEEP_BRANCH}' as primary branch.${NC}"
log "${BLUE}--------------------------------------------------${NC}"

# --- Preview which branches will be deleted vs. updated, before touching anything ---
ALL_BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads)
TO_DELETE=()
TO_UPDATE=()
for branch in $ALL_BRANCHES; do
    if [[ "$branch" == "$PRIMARY_KEEP_BRANCH" ]]; then
        continue
    elif [[ " ${KEEP_BRANCHES[@]} " =~ " ${branch} " ]]; then
        TO_UPDATE+=("$branch")
    else
        TO_DELETE+=("$branch")
    fi
done

log "${YELLOW}Branches to update (${#TO_UPDATE[@]}): ${TO_UPDATE[*]}${NC}"
log "${RED}Branches to force-delete (${#TO_DELETE[@]}): ${TO_DELETE[*]}${NC}"

if [ "${#TO_DELETE[@]}" -gt 0 ] && [ "$DRY_RUN" -eq 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
    echo -e "${YELLOW}Force-delete ${#TO_DELETE[@]} local branch(es) listed above? [y/N]${NC}"
    read -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log "${YELLOW}Aborted by user. No branches were deleted.${NC}"
        exit 0
    fi
fi

# Step 1: Switch to the primary keep branch and pull latest
log "${BLUE}Step 1: Preparing primary branch '${PRIMARY_KEEP_BRANCH}'...${NC}"

# Check if the primary branch exists locally
if ! git show-ref --verify --quiet "refs/heads/$PRIMARY_KEEP_BRANCH"; then
    log "${YELLOW}  Primary branch '${PRIMARY_KEEP_BRANCH}' not found locally. Attempting to fetch from remote.${NC}"
    run_git fetch origin "$PRIMARY_KEEP_BRANCH:$PRIMARY_KEEP_BRANCH"
    if [ $? -ne 0 ]; then
        log_err "${RED}  Error: Could not fetch primary branch '${PRIMARY_KEEP_BRANCH}' from remote. Make sure it exists. Exiting.${NC}"
        git checkout "$ORIGINAL_STARTING_BRANCH" > /dev/null 2>&1 || true
        exit 1
    fi
    log "${GREEN}  Successfully fetched '${PRIMARY_KEEP_BRANCH}' from remote.${NC}"
fi

# Now that we know it exists locally (or was just fetched), checkout and pull
log "${BLUE}  Switching to '${PRIMARY_KEEP_BRANCH}' and pulling latest...${NC}"
run_git checkout "$PRIMARY_KEEP_BRANCH"
if [ $? -ne 0 ]; then
    log_err "${RED}  Error: Could not checkout primary branch '${PRIMARY_KEEP_BRANCH}'. Exiting.${NC}"
    git checkout "$ORIGINAL_STARTING_BRANCH" > /dev/null 2>&1 || true
    exit 1
fi
log "${GREEN}  Successfully checked out '${PRIMARY_KEEP_BRANCH}'.${NC}"

run_git pull origin "$PRIMARY_KEEP_BRANCH"
if [ $? -eq 0 ]; then
    log "${GREEN}  Successfully pulled latest for '${PRIMARY_KEEP_BRANCH}'.${NC}"
else
    handle_failure "  Warning: Could not pull latest for '${PRIMARY_KEEP_BRANCH}'. Manual review needed."
fi

# --- Result Tracking ---
UPDATED_BRANCHES=()
UPDATE_FAILED_BRANCHES=()
DELETED_BRANCHES=()
DELETE_FAILED_BRANCHES=()

# Step 2: Update secondary keep branches
log "${BLUE}Step 2: Updating secondary branches to keep...${NC}"
for branch in "${TO_UPDATE[@]}"; do
    log "${GREEN}Keeping and attempting to update: $branch${NC}"
    run_git checkout "$branch"
    if [ $? -ne 0 ]; then
        handle_failure "  Error: Could not checkout secondary branch '$branch' for update. Skipping pull."
        UPDATE_FAILED_BRANCHES+=("$branch")
        continue
    fi
    run_git pull origin "$branch"
    if [ $? -eq 0 ]; then
        log "${GREEN}  Successfully pulled latest for: $branch${NC}"
        UPDATED_BRANCHES+=("$branch")
    else
        handle_failure "  Warning: Could not pull latest for '$branch'. Manual review needed."
        UPDATE_FAILED_BRANCHES+=("$branch")
    fi
    # Switch back to the primary keep branch after updating a 'kept' branch
    run_git checkout "$PRIMARY_KEEP_BRANCH"
    if [ $? -ne 0 ]; then
        log_err "${RED}  CRITICAL ERROR: Could not switch back to primary branch '$PRIMARY_KEEP_BRANCH'. Please resolve manually.${NC}"
        git checkout "$ORIGINAL_STARTING_BRANCH" > /dev/null 2>&1 || true
        exit 1
    fi
done

# Step 3: Delete everything else
log "${BLUE}Step 3: Deleting branches not in the keep list...${NC}"
for branch in "${TO_DELETE[@]}"; do
    log "${RED}Deleting branch: $branch${NC}"
    run_git branch -D "$branch"
    if [ $? -eq 0 ]; then
        log "${GREEN}  Successfully deleted: $branch${NC}"
        DELETED_BRANCHES+=("$branch")
    else
        handle_failure "  Failed to delete: $branch. Manual intervention might be needed."
        DELETE_FAILED_BRANCHES+=("$branch")
    fi
done

# Final step: Ensure we are on the PRIMARY_KEEP_BRANCH at the very end
log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE}Finalizing: Ensuring current branch is: ${PRIMARY_KEEP_BRANCH}${NC}"
if [ "$DRY_RUN" -eq 0 ] && [[ "$(git rev-parse --abbrev-ref HEAD)" != "$PRIMARY_KEEP_BRANCH" ]]; then
  git checkout "$PRIMARY_KEEP_BRANCH" || {
    log_err "${RED}CRITICAL ERROR: Failed to switch to primary branch '$PRIMARY_KEEP_BRANCH' at script end. Please resolve manually.${NC}"
    exit 1
  }
fi

# --- Summary Report ---
log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE} Summary Report${NC}"
log "${BLUE}--------------------------------------------------${NC}"

log "${GREEN}Updated (${#UPDATED_BRANCHES[@]}):${NC}"
for branch in "${UPDATED_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${YELLOW}Update failed (${#UPDATE_FAILED_BRANCHES[@]}):${NC}"
for branch in "${UPDATE_FAILED_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${RED}Deleted (${#DELETED_BRANCHES[@]}):${NC}"
for branch in "${DELETED_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${RED}Delete failed (${#DELETE_FAILED_BRANCHES[@]}):${NC}"
for branch in "${DELETE_FAILED_BRANCHES[@]}"; do
    log "  - $branch"
done

log "${BLUE}--------------------------------------------------${NC}"
log "${GREEN}✅ Local branch cleanup and update process complete. You are now on '${PRIMARY_KEEP_BRANCH}'.${NC}"
log "${BLUE}--------------------------------------------------${NC}"
