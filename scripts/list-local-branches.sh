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

echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${BLUE} Git Local Branch Listing Utility${NC}"
echo -e "${PURPLE} Author: Mustansir Sabir${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"

# Check if inside a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo -e "${RED}Error: This is not a Git repository.${NC}"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo -e "${YELLOW}Current active branch: ${GREEN}${CURRENT_BRANCH}${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"

# Get all local branches
ALL_BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads)

if [ -z "$ALL_BRANCHES" ]; then
    echo -e "${YELLOW}No local branches found.${NC}"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    exit 0
fi

echo -e "${GREEN}Listing all local branches:${NC}"

# Loop through branches and highlight current branch
for branch in $ALL_BRANCHES; do
    if [[ "$branch" == "$CURRENT_BRANCH" ]]; then
        echo -e "  -> ${GREEN}$branch (current)${NC}"
    else
        echo -e "     $branch"
    fi
done

echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${GREEN}✅ Branch listing complete.${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"