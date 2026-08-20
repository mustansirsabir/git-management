#!/bin/bash

# This script checks a list of branch names against the local and/or remote
# repository and prints a tabular report of which branches are missing.
# By default both local and remote branches are checked; -l/--local-only or
# -r/--remote-only restrict the check to a single scope.

# --- ANSI Color Codes for enhanced output ---
RED='\033[0;31m'    # Error/Missing
GREEN='\033[0;32m'  # Success/Found
YELLOW='\033[0;33m' # Warning/Info
BLUE='\033[0;34m'   # Section headers
PURPLE='\033[0;35m' # Author/Special Info
NC='\033[0m'       # No Color

REMOTE="origin"
SCOPE="both"
BRANCHES=()

# --- Flag Defaults ---
VERBOSE=0
QUIET=0
DRY_RUN=0
STRICT=0

print_usage() {
    echo -e "${YELLOW}Usage: $0 [options] <branch1> [branch2] ...${NC}"
    echo -e "${YELLOW}Example: $0 feature/foo bugfix/bar${NC}"
    echo -e "${YELLOW}Example: $0 --local-only feature/foo bugfix/bar${NC}"
    echo -e "${YELLOW}"
    echo -e "Options:"
    echo -e "  -l, --local-only   Only check for branches locally"
    echo -e "  -r, --remote-only  Only check for branches on '${REMOTE}'"
    echo -e "  -h, --help         Show this help message"
    echo -e "  -v, --verbose      Show full output of git commands"
    echo -e "  -q, --quiet        Print only the table and summary"
    echo -e "  --dry-run          Accepted for consistency; this script makes no changes"
    echo -e "  --strict           Accepted for consistency; this script has no failure cases to abort on${NC}"
}

# --- Argument Parsing ---
for arg in "$@"; do
    case "$arg" in
        -l|--local-only)
            if [ "$SCOPE" == "remote" ]; then
                echo -e "${RED}Error: --local-only and --remote-only are mutually exclusive.${NC}"
                exit 1
            fi
            SCOPE="local"
            ;;
        -r|--remote-only)
            if [ "$SCOPE" == "local" ]; then
                echo -e "${RED}Error: --local-only and --remote-only are mutually exclusive.${NC}"
                exit 1
            fi
            SCOPE="remote"
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        -v|--verbose) VERBOSE=1 ;;
        -q|--quiet) QUIET=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --strict) STRICT=1 ;;
        *)
            BRANCHES+=("$arg")
            ;;
    esac
done

if [ "$VERBOSE" -eq 1 ] && [ "$QUIET" -eq 1 ]; then
    echo -e "${RED}Error: --verbose and --quiet are mutually exclusive.${NC}"
    exit 1
fi

log()     { [ "$QUIET" -eq 0 ] && echo -e "$1"; return 0; }
log_err() { echo -e "$1" >&2; }

log "${BLUE}--------------------------------------------------${NC}"
log "${BLUE} Git Branch Existence Checker${NC}"
log "${PURPLE} Author: Mustansir Sabir${NC}"
log "${BLUE}--------------------------------------------------${NC}"

# Check if inside a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log_err "${RED}Error: This is not a Git repository.${NC}"
    exit 1
fi

# Validate input
if [ "${#BRANCHES[@]}" -eq 0 ]; then
    log_err "${RED}Error: No branches provided.${NC}"
    print_usage
    exit 1
fi

log "${YELLOW}Scope: ${SCOPE}${NC}"
log "${GREEN}Branches to check (${#BRANCHES[@]}):${NC}"
for branch in "${BRANCHES[@]}"; do
    log "  - $branch"
done
log "${BLUE}--------------------------------------------------${NC}"

# Helper: returns 0 (true) if $1 is present in the array named $2
contains() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        if [ "$item" == "$needle" ]; then
            return 0
        fi
    done
    return 1
}

LOCAL_BRANCHES=()
REMOTE_BRANCHES=()

# Gather local branches
if [ "$SCOPE" == "local" ] || [ "$SCOPE" == "both" ]; then
    log "${BLUE}Reading local branches...${NC}"
    while IFS= read -r line; do
        [ -n "$line" ] && LOCAL_BRANCHES+=("$line")
    done < <(git for-each-ref --format='%(refname:short)' refs/heads)
fi

# Gather remote branches
if [ "$SCOPE" == "remote" ] || [ "$SCOPE" == "both" ]; then
    log "${BLUE}Fetching latest updates from '${REMOTE}'...${NC}"
    if [ "$VERBOSE" -eq 1 ]; then
        git fetch --all --prune
    else
        git fetch --all --prune > /dev/null 2>&1
    fi
    if [ $? -ne 0 ]; then
        log "${YELLOW}Warning: Failed to fetch from remote. Remote branch data may be stale.${NC}"
    fi

    log "${BLUE}Reading remote branches on '${REMOTE}'...${NC}"
    while IFS= read -r line; do
        line="${line#${REMOTE}/}"
        [ -n "$line" ] && [ "$line" != "HEAD" ] && REMOTE_BRANCHES+=("$line")
    done < <(git for-each-ref --format='%(refname:short)' "refs/remotes/${REMOTE}")
fi

log "${BLUE}--------------------------------------------------${NC}"

# --- Result Tracking ---
FOUND_BRANCHES=()
MISSING_BRANCHES=()

# --- Tabular Report ---
printf "%-35s %-10s %-10s %-10s\n" "BRANCH" "LOCAL" "REMOTE" "STATUS"
printf "%-35s %-10s %-10s %-10s\n" "-----------------------------------" "----------" "----------" "----------"

for branch in "${BRANCHES[@]}"; do
    IN_LOCAL="N/A"
    IN_REMOTE="N/A"
    IS_MISSING=1 # 1 = missing, 0 = found in at least one checked scope

    if [ "$SCOPE" == "local" ] || [ "$SCOPE" == "both" ]; then
        if contains "$branch" "${LOCAL_BRANCHES[@]}"; then
            IN_LOCAL="Yes"
            IS_MISSING=0
        else
            IN_LOCAL="No"
        fi
    fi

    if [ "$SCOPE" == "remote" ] || [ "$SCOPE" == "both" ]; then
        if contains "$branch" "${REMOTE_BRANCHES[@]}"; then
            IN_REMOTE="Yes"
            IS_MISSING=0
        else
            IN_REMOTE="No"
        fi
    fi

    if [ "$IS_MISSING" -eq 1 ]; then
        STATUS="MISSING"
        MISSING_BRANCHES+=("$branch")
        printf "${RED}%-35s %-10s %-10s %-10s${NC}\n" "$branch" "$IN_LOCAL" "$IN_REMOTE" "$STATUS"
    else
        STATUS="FOUND"
        FOUND_BRANCHES+=("$branch")
        printf "${GREEN}%-35s %-10s %-10s %-10s${NC}\n" "$branch" "$IN_LOCAL" "$IN_REMOTE" "$STATUS"
    fi
done

# --- Summary Report ---
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${BLUE} Summary Report${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"

echo -e "${GREEN}Found (${#FOUND_BRANCHES[@]}):${NC}"
for branch in "${FOUND_BRANCHES[@]}"; do
    echo -e "  - $branch"
done

echo -e "${RED}Missing (${#MISSING_BRANCHES[@]}):${NC}"
for branch in "${MISSING_BRANCHES[@]}"; do
    echo -e "  - $branch"
done

echo -e "${BLUE}--------------------------------------------------${NC}"
if [ "${#MISSING_BRANCHES[@]}" -eq 0 ]; then
    echo -e "${GREEN}✅ All branches were found.${NC}"
else
    echo -e "${YELLOW}⚠ ${#MISSING_BRANCHES[@]} branch(es) not found.${NC}"
fi
echo -e "${BLUE}--------------------------------------------------${NC}"
