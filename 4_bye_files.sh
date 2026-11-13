#!/bin/bash

PROHIBITED_FILE_TYPES=("*.exe" "*.torrent" "*.appimage" "*.bat" "*.msi" "*.mp3" "*.mp4" "*.mkv" "*.avi" "*.mov" "*.wmv" "*.webm" "*.flv" "*.m4v" "*.mpg" "*.mpeg" "*.3gp" "*.vob" "*.ts" "*.ogv" "*.aac" "*.ogg" "*.wma" "*.m4a" "*.opus" • "*.wav" "*.flac" "*.alac" "*.aiff")
SEARCH_DIRS=("/home" "/opt" "/var" "/tmp")
LOG_FILE="/var/log/application_policy.log"

touch "$LOG_FILE"

echo "Scanning for risky files..."

for ext in "${PROHIBITED_FILE_TYPES[@]}"; do
    for dir in "${SEARCH_DIRS[@]}"; do
        # Use find and store results in an array first to avoid subshell issues
        mapfile -t files < <(find "$dir" -type f -iname "$ext" 2>/dev/null)
        for file in "${files[@]}"; do
            echo "Found file: $file"
            while true; do
                read -p "Delete this file? (y/n): " answer
                answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]' | xargs)
                if [[ "$answer" == "y" ]]; then
                    chmod u+w "$file" 2>/dev/null
                    rm -f "$file" && echo "Deleted file: $file" | tee -a "$LOG_FILE"
                    break
                elif [[ "$answer" == "n" ]]; then
                    echo "Skipped file: $file" | tee -a "$LOG_FILE"
                    break
                else
                    echo "Please enter y or n."
                fi
            done
        done
    done
done

echo "Scan complete." | tee -a "$LOG_FILE"
