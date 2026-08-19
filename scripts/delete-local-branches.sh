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

# --- Argument Parsing ---
# If command-line arguments are provided, use them as KEEP_BRANCHES.
# Otherwise, use the DEFAULT_KEEP_BRANCHES.
if [ "$#" -gt 0 ]; then
    KEEP_BRANCHES=("$@")
    echo -e "${BLUE}ℹ️ Using branches to keep from command-line arguments.${NC}"
else
    KEEP_BRANCHES=("${DEFAULT_KEEP_BRANCHES[@]}")
    echo -e "${BLUE}ℹ️ Using default branches to keep. To specify, pass them as arguments.${NC}"
fi

echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${BLUE} Git Local Branch Cleanup Utility${NC}"
echo -e "${PURPLE} Author: Mustansir Sabir${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${YELLOW}WARNING: This script performs force deletions (git branch -D).${NC}"
echo -e "${YELLOW}Ensure all important work is pushed to remote before proceeding!${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${GREEN}Branches to KEEP (and update):${NC}" # Updated description
for branch in "${KEEP_BRANCHES[@]}"; do
  echo -e "  - ${GREEN}$branch${NC}"
done
echo -e "${BLUE}--------------------------------------------------${NC}"

# Store the branch that was active when the script started
ORIGINAL_STARTING_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo -e "${YELLOW}Script started on branch: ${ORIGINAL_STARTING_BRANCH}${NC}"

# Check if KEEP_BRANCHES is not empty before proceeding
if [ ${#KEEP_BRANCHES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No branches specified to keep. Exiting.${NC}"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    exit 1
fi

# Set the first branch from KEEP_BRANCHES as the primary branch for operations.
# This branch will be checked out, pulled, and returned to after other operations.
PRIMARY_KEEP_BRANCH="${KEEP_BRANCHES[0]}"

echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${BLUE} Initiating operations with '${PRIMARY_KEEP_BRANCH}' as primary branch.${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"

# Step 1: Switch to the primary keep branch and pull latest
echo -e "${BLUE}Step 1: Preparing primary branch '${PRIMARY_KEEP_BRANCH}'...${NC}"

# Check if the primary branch exists locally
if ! git show-ref --verify --quiet "refs/heads/$PRIMARY_KEEP_BRANCH"; then
    echo -e "${YELLOW}  Primary branch '${PRIMARY_KEEP_BRANCH}' not found locally. Attempting to fetch from remote.${NC}"
    git fetch origin "$PRIMARY_KEEP_BRANCH:$PRIMARY_KEEP_BRANCH"
    if [ $? -ne 0 ]; then
        echo -e "${RED}  Error: Could not fetch primary branch '${PRIMARY_KEEP_BRANCH}' from remote. Make sure it exists. Exiting.${NC}"
        # Attempt to switch back to original branch before exiting
        git checkout "$ORIGINAL_STARTING_BRANCH" > /dev/null 2>&1 || true # Don't fail if this also fails
        exit 1
    fi
    echo -e "${GREEN}  Successfully fetched '${PRIMARY_KEEP_BRANCH}' from remote.${NC}"
fi

# Now that we know it exists locally (or was just fetched), checkout and pull
echo -e "${BLUE}  Switching to '${PRIMARY_KEEP_BRANCH}' and pulling latest...${NC}"
git checkout "$PRIMARY_KEEP_BRANCH" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}  Error: Could not checkout primary branch '${PRIMARY_KEEP_BRANCH}'. Exiting.${NC}"
    git checkout "$ORIGINAL_STARTING_BRANCH" > /dev/null 2>&1 || true
    exit 1
fi
echo -e "${GREEN}  Successfully checked out '${PRIMARY_KEEP_BRANCH}'.${NC}"

git pull origin "$PRIMARY_KEEP_BRANCH"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}  Successfully pulled latest for '${PRIMARY_KEEP_BRANCH}'.${NC}"
else
    echo -e "${YELLOW}  Warning: Could not pull latest for '${PRIMARY_KEEP_BRANCH}'. Manual review needed.${NC}"
fi

echo -e "${BLUE}Current active branch is now: $(git rev-parse --abbrev-ref HEAD)${NC}"


# Get list of all local branches (re-fetch to ensure the list is current after primary branch pull)
echo -e "${BLUE}Re-fetching all local branches for processing...${NC}"
ALL_BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads)
if [ -z "$ALL_BRANCHES" ]; then
    echo -e "${YELLOW}No local branches found after initial setup. Nothing more to delete.${NC}"
    echo -e "${GREEN}✅ Cleanup complete.${NC}"
    # The script is already on PRIMARY_KEEP_BRANCH, so no need to switch back to ORIGINAL_STARTING_BRANCH here.
    exit 0
fi

echo -e "${BLUE}Starting branch cleanup and secondary update process...${NC}"

# Loop and delete/update branches
for branch in $ALL_BRANCHES; do
  # Skip the primary branch for operations within this loop, as it's already handled
  if [[ "$branch" == "$PRIMARY_KEEP_BRANCH" ]]; then
    echo -e "${YELLOW}Skipping operations on primary branch: ${branch} (already updated).${NC}"
    continue
  fi

  # Check if the branch is in the KEEP_BRANCHES list (excluding the primary branch)
  if [[ " ${KEEP_BRANCHES[@]} " =~ " ${branch} " ]]; then
    echo -e "${GREEN}Keeping and attempting to update secondary branch: $branch${NC}"
    # Temporarily checkout the branch to pull latest
    git checkout "$branch" > /dev/null 2>&1 # Suppress output
    if [ $? -ne 0 ]; then
      echo -e "${RED}  Error: Could not checkout secondary branch '$branch' for update. Skipping pull.${NC}"
      continue # Skip pull if checkout fails
    fi
    git pull origin "$branch"
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}  Successfully pulled latest for: $branch${NC}"
    else
      echo -e "${YELLOW}  Warning: Could not pull latest for '$branch'. Manual review needed.${NC}"
    fi
    # Switch back to the primary keep branch after updating a 'kept' branch
    git checkout "$PRIMARY_KEEP_BRANCH" > /dev/null 2>&1 # Suppress output
    if [ $? -ne 0 ]; then
      echo -e "${RED}  CRITICAL ERROR: Could not switch back to primary branch '$PRIMARY_KEEP_BRANCH'. Please resolve manually.${NC}"
      # Attempt to switch back to original branch before exiting
      git checkout "$ORIGINAL_STARTING_BRANCH" > /dev/null 2>&1 || true # Fallback to original
      exit 1 # Exit on critical error to prevent unexpected state
    fi
  else
    # Branch is NOT in KEEP_BRANCHES and not the PRIMARY_KEEP_BRANCH, so delete it
    echo -e "${RED}Deleting branch: $branch${NC}"
    git branch -D "$branch"
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}  Successfully deleted: $branch${NC}"
    else
      echo -e "${RED}  Failed to delete: $branch. Manual intervention might be needed.${NC}"
    fi
  fi
done

# Final step: Ensure we are on the PRIMARY_KEEP_BRANCH at the very end
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${BLUE}Finalizing: Ensuring current branch is: ${PRIMARY_KEEP_BRANCH}${NC}"
# The script should already be on PRIMARY_KEEP_BRANCH from the last checkout inside the loop,
# or from Step 1 if no other branches were processed.
# This check ensures it, and provides an error if it fails (which it shouldn't under normal ops).
if [[ "$(git rev-parse --abbrev-ref HEAD)" != "$PRIMARY_KEEP_BRANCH" ]]; then
  git checkout "$PRIMARY_KEEP_BRANCH" || {
    echo -e "${RED}CRITICAL ERROR: Failed to switch to primary branch '$PRIMARY_KEEP_BRANCH' at script end. Please resolve manually.${NC}"
    exit 1
  }
fi

echo -e "${GREEN}✅ Local branch cleanup and update process complete. You are now on '${PRIMARY_KEEP_BRANCH}'.${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"
