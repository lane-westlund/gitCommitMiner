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

# Function to display usage
function usage {
    echo "Usage: $0 -d <difficulty> -j <number of threads>"
    exit 1
}

difficulty=4
threads=1

# Parse command line arguments
while getopts ":d:j:" opt; do
    case ${opt} in
        d )
            difficulty=$OPTARG
            ;;
        j )
            threads=$OPTARG
            ;;
        \? )
            usage
            ;;
    esac
done

if ! [[ "$difficulty" =~ ^[0-9]+$ ]]; then
    usage
fi

# Check if j is a valid integer
if ! [[ "$threads" =~ ^-?[0-9]+$ ]]; then
  echo "Error: -j must be an integer."
  exit 1
fi

if [ $threads -gt 1 ]; then
    ./$(basename $0) -j $((threads - 1)) -d $difficulty &
fi

desiredHeaderStart="$(printf "%0${difficulty}d" 0)"
echo "looking for commit starting with $desiredHeaderStart"
getCommitParameters
while true; do
    buildCommitParameters
    hash=$((printf "commit %s\0" $(echo -e "$newOutput" | wc -c); echo -e "$newOutput")|sha1sum)
    current_hash=$(git rev-parse HEAD)
    if [ "$current_hash" != "$start_hash" ]; then
        echo "Someone else modified our hash, exiting"
        exit 0
    fi
    if [[ $hash == $desiredHeaderStart* ]]; then
        echo "Commit hash starting with $desiredHeaderStart found: $hash"
        break
    fi
done

export GIT_AUTHOR_DATE="$author_date"
export GIT_COMMITTER_DATE="$committer_date"
temp_file=$(mktemp)
echo -e "$newCommitMessage" > "$temp_file"
git commit -q --amend -F "$temp_file"
rm "$temp_file"
unset GIT_AUTHOR_DATE
unset GIT_COMMITTER_DATE
