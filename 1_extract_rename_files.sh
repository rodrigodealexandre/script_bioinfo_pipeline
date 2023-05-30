#!/bin/bash

# Prompt for the folder name
read -p "Enter the folder name (XXX): " folder_name

# Set the folder path
folder_path="/mnt/d/AlignData/$folder_name"

# Check if the folder exists
if [ ! -d "$folder_path" ]; then
  echo "Folder '$folder_name' does not exist."
  exit 1
fi

# Change to the folder
cd "$folder_path" || exit 1

# Check if unzip command is available
if ! command -v unzip &> /dev/null; then
    echo "Error: unzip command is not available. Please install unzip and try again."
    exit 1
fi

# Unzip .zip files
if ls *.zip 1> /dev/null 2>&1; then
  echo "Unzipping .zip files..."
  unzip "*.zip"
fi

# Move specific files to the current folder
echo "Moving files..."
mv */*.bam */*.bai */*.smCounter.anno.vcf */*hard-filtered.vcf.gz */*.fusion_candidates.final ./

# Extract .vcf.gz files
if ls *.vcf.gz 1> /dev/null 2>&1; then
  echo "Extracting .vcf.gz files..."
  gunzip -k *.vcf.gz
fi

# Iterate over the files in the folder
for file in "$folder_path"/*.vcf; do
    if [[ -f "$file" ]]; then
        # Extract the filename without the path
        file_name=$(basename "$file")

        # Check if the file starts with "POOL"
        if [[ "$file_name" == POOL* ]]; then
            echo "Skipping file: $file_name"
            continue
        fi

        # Get the new file name by removing the name up to the first dot
        new_file_name="${file_name#*.}"

        # Rename the file
        mv "$file" "$folder_path/$new_file_name"
    fi
done

echo "File processing completed."
