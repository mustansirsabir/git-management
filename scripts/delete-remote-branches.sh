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

echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${BLUE} Git Remote Branch Deletion Utility${NC}"
echo -e "${PURPLE} Author: Mustansir Sabir${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${YELLOW}WARNING: This script deletes branches from the remote '${REMOTE}'.${NC}"
echo -e "${YELLOW}This action affects everyone using the remote repository.${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"

# Check if inside a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo -e "${RED}Error: This is not a Git repository.${NC}"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    exit 1
fi

# Validate input
if [ "$#" -eq 0 ]; then
    echo -e "${RED}Error: No branches provided.${NC}"
    echo -e "${YELLOW}Usage: $0 <branch1> [branch2] ...${NC}"
    echo -e "${YELLOW}Example: $0 feature/old-feature bugfix/stale-fix${NC}"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    exit 1
fi

echo -e "${GREEN}Branches to delete from '${REMOTE}':${NC}"
for branch in "$@"; do
    echo -e "  - $branch"
done
echo -e "${BLUE}--------------------------------------------------${NC}"

# --- Result Tracking ---
SUCCESS_BRANCHES=()
FAILED_BRANCHES=()
SKIPPED_BRANCHES=()

# Fetch latest references so remote branch state is up to date
echo -e "${BLUE}Fetching latest updates from remote...${NC}"
git fetch --all --prune
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to fetch from remote.${NC}"
    exit 1
fi

# Protect commonly used branches from accidental deletion
PROTECTED_BRANCHES=("main" "master" "develop" "release")

for branch in "$@"; do
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "${BLUE}Processing branch: ${branch}${NC}"

    if [[ " ${PROTECTED_BRANCHES[@]} " =~ " ${branch} " ]]; then
        echo -e "${YELLOW}Skipping protected branch: ${branch}${NC}"
        SKIPPED_BRANCHES+=("$branch")
        continue
    fi

    if ! git ls-remote --exit-code --heads "$REMOTE" "$branch" > /dev/null 2>&1; then
        echo -e "${YELLOW}Branch '${branch}' does not exist on '${REMOTE}'. Skipping.${NC}"
        SKIPPED_BRANCHES+=("$branch")
        continue
    fi

    echo -e "${RED}Deleting '${branch}' from '${REMOTE}'...${NC}"
    git push "$REMOTE" --delete "$branch"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully deleted '${branch}' from '${REMOTE}'.${NC}"
        SUCCESS_BRANCHES+=("$branch")
    else
        echo -e "${RED}Error: Failed to delete '${branch}' from '${REMOTE}'.${NC}"
        FAILED_BRANCHES+=("$branch")
    fi
done

# --- Summary Report ---
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${BLUE} Summary Report${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"

echo -e "${GREEN}Successfully deleted (${#SUCCESS_BRANCHES[@]}):${NC}"
for branch in "${SUCCESS_BRANCHES[@]}"; do
    echo -e "  - $branch"
done

echo -e "${RED}Failed to delete (${#FAILED_BRANCHES[@]}):${NC}"
for branch in "${FAILED_BRANCHES[@]}"; do
    echo -e "  - $branch"
done

echo -e "${YELLOW}Skipped (${#SKIPPED_BRANCHES[@]}):${NC}"
for branch in "${SKIPPED_BRANCHES[@]}"; do
    echo -e "  - $branch"
done

echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${GREEN}✅ Processing complete.${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"
