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

echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${BLUE} Git Multi-Branch Checkout & Update Utility${NC}"
echo -e "${PURPLE} Author: Mustansir Sabir${NC}"
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
    echo -e "${YELLOW}Usage: ./script.sh branch1 branch2 branch3${NC}"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    exit 1
fi

# Store original branch
ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo -e "${YELLOW}Script started on branch: ${ORIGINAL_BRANCH}${NC}"

echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${GREEN}Branches to process:${NC}"
for branch in "$@"; do
    echo -e "  - $branch"
done
echo -e "${BLUE}--------------------------------------------------${NC}"

# --- Result Tracking ---
SUCCESS_BRANCHES=()
FAILED_BRANCHES=()
SKIPPED_BRANCHES=()

# Fetch latest references
echo -e "${BLUE}Fetching latest updates from remote...${NC}"
git fetch --all --prune
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to fetch from remote.${NC}"
    exit 1
fi

# Process each branch
for branch in "$@"; do
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "${BLUE}Processing branch: ${branch}${NC}"

    if git show-ref --verify --quiet "refs/heads/$branch"; then
        echo -e "${GREEN}Branch exists locally. Checking out...${NC}"
        git checkout "$branch" > /dev/null 2>&1

        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to checkout '${branch}'.${NC}"
            FAILED_BRANCHES+=("$branch")
            continue
        fi

        echo -e "${BLUE}Pulling latest changes for '${branch}'...${NC}"
        git pull origin "$branch" > /dev/null 2>&1

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Successfully updated '${branch}'.${NC}"
            SUCCESS_BRANCHES+=("$branch")
        else
            echo -e "${YELLOW}Warning: Pull failed for '${branch}'.${NC}"
            FAILED_BRANCHES+=("$branch")
        fi
    else
        echo -e "${YELLOW}Branch not found locally. Attempting to fetch from remote...${NC}"

        git checkout -b "$branch" "origin/$branch" > /dev/null 2>&1

        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Branch '${branch}' not found on remote.${NC}"
            SKIPPED_BRANCHES+=("$branch")
            continue
        fi

        echo -e "${GREEN}Successfully created '${branch}'.${NC}"

        git pull origin "$branch" > /dev/null 2>&1
        SUCCESS_BRANCHES+=("$branch")
    fi
done

# Return to original branch
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${BLUE}Returning to original branch: ${ORIGINAL_BRANCH}${NC}"
git checkout "$ORIGINAL_BRANCH" > /dev/null 2>&1

# --- Summary Report ---
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${BLUE} Summary Report${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"

echo -e "${GREEN}Successful branches (${#SUCCESS_BRANCHES[@]}):${NC}"
for branch in "${SUCCESS_BRANCHES[@]}"; do
    echo -e "  - $branch"
done

echo -e "${RED}Failed branches (${#FAILED_BRANCHES[@]}):${NC}"
for branch in "${FAILED_BRANCHES[@]}"; do
    echo -e "  - $branch"
done

echo -e "${YELLOW}Skipped branches (${#SKIPPED_BRANCHES[@]}):${NC}"
for branch in "${SKIPPED_BRANCHES[@]}"; do
    echo -e "  - $branch"
done

echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${GREEN}✅ Processing complete.${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"