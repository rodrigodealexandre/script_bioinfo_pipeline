#!/bin/bash

# Move all ".fastq.gz" files from subfolders to the current folder
find . -type f -name "*.fastq.gz" -exec mv {} . \;

# Loop through each pair of forward and reverse files
for forward_file in *R1*.fastq.gz; do
    # Extract POOL name from the forward file name
    pool_name=$(echo "$forward_file" | cut -d '_' -f 1-2)

    # Extract the corresponding reverse file name
    reverse_file=$(echo "$forward_file" | sed 's/R1/R2/')

    # Align the data using BWA
    bwa mem -t 12 /mnt/d/HG38/hg38.fa.gz "$forward_file" "$reverse_file" > "$pool_name.sam"
    samtools view -S -b "$pool_name.sam" > "$pool_name"_ns.bam
    samtools sort "$pool_name"_ns.bam -o "$pool_name.bam"
    samtools index "$pool_name.bam"

    # Remove intermediate files (optional)
    rm "$pool_name.sam" "$pool_name"_ns.bam
done
