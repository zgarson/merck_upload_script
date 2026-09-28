#!/bin/bash

target_dir="${1:?Usage: $0 <target_directory>}"
audit_file="${2:?Usage: $0 <target_directory>}"
year=$(date +%Y)
datetime=$(date +%Y%m%d)
response_count=0
total_count=0
total_records=0

# for FILE in "$target_dir"/"*.txt"; do
#     file_name=$(basename "$FILE")
#     if [[ "$file_name" =~ "Response" ]]; then
#         records=$(wc -l < "$FILE" | awk '{print $1}' | xargs)
#         records=$((records - 1))
#         echo "$year|$datetime|$file_name|$records" >> "$audit_file"
#         cat "$audit_file"
#         ((response_count+=1))
#         ((total_records+=records))
#     else
#         continue
#     fi
# done

# start appending new audit file metadata on a new line
# If the file exists and doesn't end with a newline, add one before appending
if [ -s "$audit_file" ] && [ "$(tail -c1 "$audit_file" | wc -l)" -eq 0 ]; then
    printf '\n' >> "$audit_file"
fi

while IFS= read -r FILE; do
    file_name=$(basename "$FILE")
    if [[ "$file_name" =~ "Response" ]]; then
        records=$(wc -l < "$FILE" | awk '{print $1}' | xargs)
        records=$((records - 1))
        line="$year|$datetime|$file_name|$records"
        # Only write if this exact line doesn't already exist in the audit file
        if ! grep -qF "$line" "$audit_file" 2>/dev/null; then
            printf "%s\n" "$line" >> "$audit_file"
            ((response_count+=1))
            ((total_records+=records))
        fi
    fi
done < <(find "$target_dir" -type f -name "*.txt")

# Remove trailing newline
[ -n "$(tail -c 1 "$audit_file")" ] || truncate -s -1 "$audit_file"

