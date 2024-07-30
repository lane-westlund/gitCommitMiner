#!/bin/bash

function getCommitParameters {
    # Get the output of `git cat-file -p HEAD`
    output=$(git cat-file -p HEAD)
    start_hash=$(git rev-parse HEAD)

    # Initialize variables
    tree=""
    parent=""
    author_name=""
    author_email=""
    author_date=""
    committer_name=""
    committer_email=""
    committer_date=""
    commit_message=""

    # Parse the output
    while IFS= read -r line; do
        if [[ "$line" =~ ^tree\ ([a-f0-9]+)$ ]]; then
            tree="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^parent\ ([a-f0-9]+)$ ]]; then
            parent="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^author\ (.+)\ \<(.+)\>\ ([0-9]+)\ ([+-][0-9]+)$ ]]; then
            author_name="${BASH_REMATCH[1]}"
            author_email="${BASH_REMATCH[2]}"
            author_date="${BASH_REMATCH[3]} ${BASH_REMATCH[4]}"
        elif [[ "$line" =~ ^committer\ (.+)\ \<(.+)\>\ ([0-9]+)\ ([+-][0-9]+)$ ]]; then
            committer_name="${BASH_REMATCH[1]}"
            committer_email="${BASH_REMATCH[2]}"
            committer_date="${BASH_REMATCH[3]} ${BASH_REMATCH[4]}"
        elif [[ -z "$line" ]]; then
            break
        fi
    done <<< "$output"

    # Read the commit message
    commit_message=$(echo "$output" | sed -n '/^$/,$p' | tail -n +2)
}

function buildCommitParameters {
    # Format the output
    newOutput="tree $tree"
    if [ -n "$parent" ]; then
        newOutput+="\nparent $parent"
    fi
    newOutput+="\nauthor $author_name <$author_email> $author_date"
    newOutput+="\ncommitter $committer_name <$committer_email> $committer_date"
    newOutput+="\n\n"
    newCommitMessage="$commit_message"
    hexRandom=$(printf '%x\n' $SRANDOM)
    newCommitMessage+="\n\n$hexRandom"
    newOutput+="$newCommitMessage"
}

getCommitParameters
while true; do
    buildCommitParameters
    hash=$((printf "commit %s\0" $(echo -e "$newOutput" | wc -c); echo -e "$newOutput")|sha1sum)
    current_hash=$(git rev-parse HEAD)
    if [ "$current_hash" != "$start_hash" ]; then
        echo "Someone else modified our hash, exiting"
        exit 0
    fi
    if [[ $hash == 0000* ]]; then
        echo "Commit hash starting with 0 found: $hash"
        break
    fi
done

export GIT_AUTHOR_DATE="$author_date"
export GIT_COMMITTER_DATE="$committer_date"
temp_file=$(mktemp)
echo -e "$newCommitMessage" > "$temp_file"
git commit --amend -F "$temp_file"
rm "$temp_file"
unset GIT_AUTHOR_DATE
unset GIT_COMMITTER_DATE
