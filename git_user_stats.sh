#!/bin/bash

# Validate input parameter
if [ $# -ne 1 ]; then
    echo "Usage: $0 <git_repository_path>"
    exit 1
fi

# Variables
CURRENT_DIR=$(pwd)
GIT_REPO_PATH="$1"
OUTPUT_FILE="$CURRENT_DIR/output/git_author_stats.txt"

# Change to the Git repository directory
cd "$GIT_REPO_PATH" || { echo "Error: Unable to access $GIT_REPO_PATH"; exit 1; }

# Get the list of unique authors (by full name)
AUTHORS=$(git log --format='%an' | sort | uniq -c | sort -nr | sed 's/^[0-9]\+ //')

# Display list of authors
echo "Select an author to analyze:"
IFS=$'\n' read -d '' -r -a AUTHOR_ARRAY <<< "$AUTHORS"

for i in "${!AUTHOR_ARRAY[@]}"; do
    echo "$((i+1))) ${AUTHOR_ARRAY[$i]}"
done

while true; do
    read -p "Enter the number of the author: " AUTHOR_INDEX
    if [[ "$AUTHOR_INDEX" =~ ^[0-9]+$ ]] && (( AUTHOR_INDEX > 0 && AUTHOR_INDEX <= ${#AUTHOR_ARRAY[@]} )); then
        AUTHOR="${AUTHOR_ARRAY[$((AUTHOR_INDEX-1))]}"
        break
    else
        echo "Invalid selection. Please enter a number between 1 and ${#AUTHOR_ARRAY[@]}"
    fi
done

# Get all emails linked to the selected author
AUTHOR_EMAILS=$(git log --format='%an <%ae>' | grep -i "$AUTHOR" | sort -u | awk -F '<|>' '{print $2}' | tr '\n' '|' | sed 's/|$//')

# Clear output file and write header
echo "Generating statistics for: $AUTHOR" > "$OUTPUT_FILE"
echo "Repository: $GIT_REPO_PATH" >> "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "------------------------------------------------------------" >> "$OUTPUT_FILE"

# Total number of commits
TOTAL_COMMITS=$(git log --author="$AUTHOR_EMAILS" --pretty=oneline | wc -l)
echo "Total commits: $TOTAL_COMMITS" >> "$OUTPUT_FILE"

# Most modified files
echo -e "\nMost modified files:" >> "$OUTPUT_FILE"
echo -e "Format: <number of commits> <file name>" >> "$OUTPUT_FILE"   
git log --author="$AUTHOR_EMAILS" --name-only --pretty=format: | sort | uniq -c | sort -nr | head -20 >> "$OUTPUT_FILE"

# Lines added and removed
echo -e "\nLines added and removed:" >> "$OUTPUT_FILE"
LINE_STATS=$(git log --author="$AUTHOR_EMAILS" --pretty=tformat: --numstat | awk '{added+=$1; deleted+=$2} END {print added, deleted}')
echo "Lines added: $(echo $LINE_STATS | awk '{print $1}')" >> "$OUTPUT_FILE"
echo "Lines removed: $(echo $LINE_STATS | awk '{print $2}')" >> "$OUTPUT_FILE"

# Most used keywords in commit messages
echo -e "\nMost used keywords in commit messages:" >> "$OUTPUT_FILE"
echo -e "Format: <number of occurrences> <keyword>" >> "$OUTPUT_FILE"
git log --author="$AUTHOR_EMAILS" --pretty=format:"%s" | sed 's/[[:punct:]]//g' | tr ' ' '\n' | sort | uniq -c | sort -nr | head -10 >> "$OUTPUT_FILE"

# Number of merge commits
MERGE_COMMITS=$(git log --author="$AUTHOR_EMAILS" --grep="Merge pull request" --pretty=format:"%h - %s" | wc -l)
echo -e "\nNumber of merge commits: $MERGE_COMMITS" >> "$OUTPUT_FILE"

# Commits per month
echo -e "\nCommits per month:" >> "$OUTPUT_FILE"
git log --author="$AUTHOR_EMAILS" --date=short --pretty=format:"%ad" | cut -d'-' -f1,2 | sort -nr | uniq -c | sort -nr >> "$OUTPUT_FILE"

# Commits by day of the week
echo -e "\nCommits by day of the week:" >> "$OUTPUT_FILE"
git log --author="$AUTHOR_EMAILS" --pretty=format:"%ad" --date=short | cut -d'-' -f3 | while read day; do date -d "2024-01-$day" +%A; done | sort | uniq -c | sort -nr >> "$OUTPUT_FILE"

# Commits by hour of the day
echo -e "\nCommits by hour of the day:" >> "$OUTPUT_FILE"
git log --author="$AUTHOR_EMAILS" --pretty=format:"%ad" --date=iso | cut -d' ' -f2 | cut -d':' -f1 | sort | uniq -c | sort -nr | awk '{print $2 "h: " $1}' >> "$OUTPUT_FILE"

# Average lines added and removed per commit
echo -e "\nAverage lines added and removed per commit:" >> "$OUTPUT_FILE"
git log --author="$AUTHOR_EMAILS" --pretty=tformat: --numstat | awk '{added+=$1; deleted+=$2; commits+=1} END {if (commits > 0) {print "Average lines added:", added/commits, "\nAverage lines removed:", deleted/commits} else {print "No line changes"}}' >> "$OUTPUT_FILE"

echo -e "\nStatistics saved in $OUTPUT_FILE"

# Ask to create a .txt with a prompt to share with chatgpt
while true; do
    read -p "Would you like to create a .txt file with the prompt for ChatGPT? (y/n): " yn
    case $yn in
        [Yy]* ) 
            TEMPLATE_FILE="$CURRENT_DIR/prompt.txt"
            AUTHOR=$(echo "$AUTHOR" | tr -d '[:space:]')
            OUTPUT_CHATGPT_FILE="$CURRENT_DIR/output/prompt_$AUTHOR.txt"
            
            if [ -f "$TEMPLATE_FILE" ]; then
                awk -v data="$(cat "$OUTPUT_FILE")" '{gsub(/\[data\]/, data)}1' "$TEMPLATE_FILE" > "$OUTPUT_CHATGPT_FILE"
            else
                echo -e "Statistics for: $AUTHOR\n\n$(cat "$OUTPUT_FILE")" > "$OUTPUT_CHATGPT_FILE"
            fi
            
            echo -e "Statistics saved in $OUTPUT_CHATGPT_FILE"
            break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes (y) or no (n).";;
    esac
done



