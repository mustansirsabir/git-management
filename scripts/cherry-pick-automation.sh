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

# --- Argument Parsing ---
if [ "$#" -lt 3 ]; then
    echo -e "${RED}Usage: $0 <source_branch> <target_branch> <commit_hash1> [commit_hash2] ...${NC}"
    echo -e "${YELLOW}Example: $0 develop main abc1234 def5678${NC}"
    exit 1
fi

SOURCE_BRANCH="$1"
TARGET_BRANCH="$2"
# Shift arguments so that $@ now contains only commit hashes
shift 2
COMMITS_TO_CHERRY_PICK="$@"

echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${BLUE} Git Cherry-Pick Automation${NC}"
echo -e "${PURPLE} Author: Mustansir Sabir${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${YELLOW}Source Branch: ${SOURCE_BRANCH}${NC}"
echo -e "${YELLOW}Target Branch: ${TARGET_BRANCH}${NC}"
echo -e "${YELLOW}Commits to Cherry-Pick: ${COMMITS_TO_CHERRY_PICK}${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"

# 1. Pull the latest from the given source branch
echo -e "${BLUE}Step 1: Pulling latest from '${SOURCE_BRANCH}'...${NC}"
git checkout "$SOURCE_BRANCH" > /dev/null 2>&1 || { echo -e "${RED}Error: Could not checkout source branch '${SOURCE_BRANCH}'. Exiting.${NC}"; exit 1; }
git pull origin "$SOURCE_BRANCH" || { echo -e "${RED}Error: Could not pull '${SOURCE_BRANCH}'. Exiting.${NC}"; exit 1; }
echo -e "${GREEN}Successfully pulled '${SOURCE_BRANCH}'.${NC}"

# 2. Check out the target branch
echo -e "${BLUE}Step 2: Checking out target branch '${TARGET_BRANCH}'...${NC}"
git checkout "$TARGET_BRANCH" > /dev/null 2>&1 || { echo -e "${RED}Error: Could not checkout target branch '${TARGET_BRANCH}'. Exiting.${NC}"; exit 1; }
echo -e "${GREEN}Successfully checked out '${TARGET_BRANCH}'.${NC}"

# 3. Perform cherry-pick from multiple commits
echo -e "${BLUE}Step 3: Performing cherry-pick of commits into '${TARGET_BRANCH}'...${NC}"
# Loop through each commit hash and attempt to cherry-pick
for commit_hash in $COMMITS_TO_CHERRY_PICK; do
    echo -e "${YELLOW}Attempting to cherry-pick commit: ${commit_hash}${NC}"
    # The --no-commit flag allows multiple cherry-picks to be applied
    # without creating a new commit after each one, allowing for a single
    # commit at the end if desired (or manual resolution).
    # For multiple individual commits, remove --no-commit if each should be a separate commit.
    # Here, we'll assume individual commits for simplicity, if you want a single commit
    # you would need to run `git commit` after all cherry-picks are done.
    git cherry-pick "$commit_hash"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Warning: Cherry-pick of commit '${commit_hash}' failed. Please resolve conflicts manually and then run 'git cherry-pick --continue' or 'git cherry-pick --abort'.${NC}"
        echo -e "${YELLOW}Script paused. Press Enter to continue after manual resolution or abort.${NC}"
        read -r
        # After manual resolution, the user needs to decide to continue or abort.
        # This script won't automatically continue to avoid unexpected behavior.
        # It's better for the user to manually continue or abort and then re-run the script for remaining commits.
        exit 1 # Exit if a conflict occurs, requiring manual intervention
    else
        echo -e "${GREEN}Successfully cherry-picked commit: ${commit_hash}${NC}"
    fi
done

echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${GREEN}Cherry-pick process completed.${NC}"
echo -e "${YELLOW}Please review the changes and commit them if everything looks good.${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"
