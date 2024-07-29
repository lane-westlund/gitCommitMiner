#!/bin/bash

# Ensure you are in a git repository
if [ ! -d ".git" ]; then
    echo "This script must be run from the root of a git repository."
    exit 1
fi

# Function to get the latest commit hash
get_commit_hash() {
    git rev-parse HEAD
}

# Function to get the original commit message (without the random number)
get_original_commit_message() {
    # Extract the commit message and remove the appended random number if it exists
    git log -1 --pretty=%s
}

# Amend the commit until the hash starts with 0
while true; do
    # Generate a random number
    random_number=$RANDOM
    
    # Get the original commit message without the random number
    original_commit_message=$(get_original_commit_message)
    
    # Amend the last commit with the original commit message and a new random number appended
    git commit --quiet --amend -m "$original_commit_message" -m "$random_number"
    
    # Get the new commit hash
    hash=$(get_commit_hash)
    
    # Check if the hash starts with 0
    if [[ $hash == 000* ]]; then
        echo "Commit hash starting with 0 found: $hash"
        break
    fi
done
