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

# --- Argument Parsing ---
# This script requires the BASE_BRANCH and at least one NEW_BRANCH name
# as command-line arguments.

# Check if enough arguments are provided
if [ "$#" -lt 2 ]; then
    echo -e "${RED}Usage: $0 <base_branch> <new_branch_name1> [new_branch_name2] ...${NC}"
    echo -e "${YELLOW}Example: $0 main feature/my-feature bugfix/an-issue${NC}"
    exit 1
fi

BASE_BRANCH="$1"
shift # Remove BASE_BRANCH from arguments
NEW_BRANCHES=("$@") # Assign all remaining arguments to NEW_BRANCHES array


# --- Script Start ---
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${BLUE} Git Branch Creation Automation${NC}"
echo -e "${PURPLE} Author: Mustansir Sabir${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${YELLOW}Base Branch: ${BASE_BRANCH}${NC}"
echo -e "${YELLOW}Branches to Create: ${NEW_BRANCHES[*]}${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

# 1. Pull the latest given branch (BASE_BRANCH)
echo -e "${BLUE}Step 1: Checking out and pulling latest from '${BASE_BRANCH}'...${NC}"

# Check if the base branch exists locally
if git show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
    echo -e "${YELLOW}Local branch '${BASE_BRANCH}' found.${NC}"
else
    echo -e "${YELLOW}Local branch '${BASE_BRANCH}' not found. Attempting to fetch and checkout.${NC}"
    git fetch origin "$BASE_BRANCH:$BASE_BRANCH" || {
        echo -e "${RED}Error: Could not fetch and checkout '${BASE_BRANCH}' from remote. Exiting.${NC}"
        exit 1
    }
fi

# Checkout the base branch
git checkout "$BASE_BRANCH" > /dev/null 2>&1 || {
    echo -e "${RED}Error: Could not checkout base branch '${BASE_BRANCH}'. Exiting.${NC}"
    exit 1
}
echo -e "${GREEN}Successfully checked out '${BASE_BRANCH}'.${NC}"

# Pull the latest changes from the remote
git pull origin "$BASE_BRANCH" || {
    echo -e "${RED}Error: Could not pull latest from '${BASE_BRANCH}'. Exiting.${NC}"
    exit 1
}
echo -e "${GREEN}Successfully pulled latest from '${BASE_BRANCH}'.${NC}"

# 2. Sequentially Create branches from branch "A" (BASE_BRANCH)
echo -e "${BLUE}Step 2: Creating new branches from '${BASE_BRANCH}'...${NC}"
for branch_name in "${NEW_BRANCHES[@]}"; do
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo -e "${YELLOW}Branch '${branch_name}' already exists locally. Skipping creation.${NC}"
    else
        echo -e "${GREEN}Creating branch: ${branch_name}${NC}"
        git branch "$branch_name" || {
            echo -e "${RED}Error: Could not create branch '${branch_name}'. Exiting.${NC}"
            exit 1
        }
        echo -e "${GREEN}Successfully created branch '${branch_name}'.${NC}"
        # Push the new branch to remote immediately
        echo -e "${YELLOW}Pushing branch '${branch_name}' to remote...${NC}"
        git push -u origin "$branch_name" || {
            echo -e "${YELLOW}Warning: Could not push branch '${branch_name}' to remote. Please push manually.${NC}"
        }
    fi
done

echo -e "${GREEN}All specified branches have been created locally and pushed to remote (if successful).${NC}"

# 3. Once all the branches are created switch the current branch to branch "A"
echo -e "${BLUE}Step 3: Switching back to '${BASE_BRANCH}'...${NC}"
git checkout "$BASE_BRANCH" > /dev/null 2>&1 || {
    echo -e "${RED}Error: Could not switch back to '${BASE_BRANCH}'. Exiting.${NC}"
    exit 1
}
echo -e "${GREEN}Successfully switched back to '${BASE_BRANCH}'.${NC}"

echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${GREEN}Branch creation process completed.${NC}"
echo -e "${YELLOW}You are currently on branch: $(git rev-parse --abbrev-ref HEAD)${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
