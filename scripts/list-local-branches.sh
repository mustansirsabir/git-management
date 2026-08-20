#!/bin/bash

# This script lists all local Git branches in the repository.
# It highlights the currently active branch and provides a clean, readable output.

# --- ANSI Color Codes for enhanced output ---
RED='\033[0;31m'    # Error
GREEN='\033[0;32m'  # Success/Highlight
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
    echo -e "${YELLOW}Usage: $0 [options]${NC}"
    echo -e "${YELLOW}"
    echo -e "Options:"
    echo -e "  -h, --help        Show this help message"
    echo -e "  -v, --verbose     Show the last commit for each branch"
    echo -e "  -q, --quiet       Print branch names only, no banner/labels"
    echo -e "  --dry-run         Accepted for consistency; this script makes no changes"
    echo -e "  --strict          Accepted for consistency; this script has no failure cases to abort on${NC}"
}

# --- Argument Parsing ---
for arg in "$@"; do
    case "$arg" in
        -h|--help) print_usage; exit 0 ;;
        -v|--verbose) VERBOSE=1 ;;
        -q|--quiet) QUIET=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --strict) STRICT=1 ;;
        *)
            echo -e "${RED}Error: Unknown argument '$arg'.${NC}"
            print_usage
            exit 1
            ;;
    esac
done

if [ "$VERBOSE" -eq 1 ] && [ "$QUIET" -eq 1 ]; then
    echo -e "${RED}Error: --verbose and --quiet are mutually exclusive.${NC}"
    exit 1
fi

log() { [ "$QUIET" -eq 0 ] && echo -e "$1"; return 0; }

log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE} Git Local Branch Listing Utility${NC}"
log "${PURPLE} Author: Mustansir Sabir${NC}"
log "${BLUE}--------------------------------------------------${NC}"

# Check if inside a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo -e "${RED}Error: This is not a Git repository.${NC}"
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

log "${YELLOW}Current active branch: ${GREEN}${CURRENT_BRANCH}${NC}"
log "${BLUE}--------------------------------------------------${NC}"

# Get all local branches
ALL_BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads)

if [ -z "$ALL_BRANCHES" ]; then
    log "${YELLOW}No local branches found.${NC}"
    exit 0
fi

log "${GREEN}Listing all local branches:${NC}"

# Loop through branches and highlight current branch
for branch in $ALL_BRANCHES; do
    EXTRA=""
    if [ "$VERBOSE" -eq 1 ]; then
        EXTRA=" ${YELLOW}($(git log -1 --format='%h %s' "$branch"))${NC}"
    fi

    if [ "$QUIET" -eq 1 ]; then
        echo "$branch"
        continue
    fi

    if [[ "$branch" == "$CURRENT_BRANCH" ]]; then
        echo -e "  -> ${GREEN}$branch (current)${NC}${EXTRA}"
    else
        echo -e "     $branch${EXTRA}"
    fi
done

log "${BLUE}--------------------------------------------------${NC}"
log "${GREEN}✅ Branch listing complete.${NC}"
log "${BLUE}--------------------------------------------------${NC}"
