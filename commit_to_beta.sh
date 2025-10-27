#!/bin/bash
#===============================================================================
# COMMIT TO BETA BRANCH
#===============================================================================
# Purpose: Standardized way to commit changes to beta branch
# Usage: ./commit_to_beta.sh "commit message"
#===============================================================================

if [ $# -eq 0 ]; then
    echo "Usage: $0 \"commit message\""
    echo "Example: $0 \"fix: Update OpenCV protection mechanism\""
    exit 1
fi

COMMIT_MSG="$1"

echo "=========================================================="
echo "COMMITTING TO BETA BRANCH"
echo "=========================================================="

# Ensure we're on beta branch
current_branch=$(git branch --show-current)
if [ "$current_branch" != "beta" ]; then
    echo "Switching to beta branch..."
    git checkout beta
fi

# Add all changes
echo "Adding all changes..."
git add -A

# Check if there are changes to commit
if git diff --cached --quiet; then
    echo "No changes to commit"
    exit 0
fi

# Commit with message
echo "Committing changes..."
git commit -m "$COMMIT_MSG"

# Push to beta branch
echo "Pushing to beta branch..."
git push origin beta

echo "✓ Successfully committed and pushed to beta branch"
echo "Commit: $COMMIT_MSG"