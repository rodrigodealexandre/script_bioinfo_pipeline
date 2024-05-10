#!/bin/bash

# Check if FastQC is installed
if ! command -v fastqc &>/dev/null; then
    echo "FastQC is not installed. Please install it before running this script."
    exit 1
fi

# Loop through all FASTQ files in the current folder and run FastQC
for file in *.fastq *.fq *.fastq.gz *.fq.gz; do
    if [ -e "$file" ]; then
        echo "Running FastQC on $file..."
        fastqc "$file"
        echo "Finished FastQC for $file"
    fi
done

echo "FastQC analysis complete for all FASTQ files."
