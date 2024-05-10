#!/bin/bash

# Set the folders accordingly
# Folders for database and scripts
convert2annovar="/mnt/d/1-bioinfotools/annovar/convert2annovar.pl"
hg38_fasta="/mnt/d/1-bioinfotools/HG38/hg38.fa"

# Files created by the pipeline as database
VCF_database="/mnt/d/1-bioinfotools/annovar/humandb/SpliceAI_VCF_database.vcf" 
database_ann="/mnt/d/1-bioinfotools/annovar/humandb/SpliceAI_VCF_database_ann.vcf"
spliceai_annovar_database="/mnt/d/1-bioinfotools/annovar/humandb/hg38_spliceai.txt"

# Temp files that will be deleted at the end of the pipeline
VCF_database_backup="/mnt/d/1-bioinfotools/annovar/humandb/SpliceAI_VCF_database_backup.vcf"
new_calls_annotated="new_calls_annotated.vcf"
new_calls="new_calls.vcf"
temp_convertion="/mnt/d/1-bioinfotools/annovar/humandb/spliceai.avinput"
temp_database="temp_database.vcf"
temp_var="temp_var.txt"

# Number of header line's the samples VCF have
n_lines=115

# Initialize the temporary database file
touch "$temp_var"

# Initialize the file for new calls with a HG38/hg38 header
header="##fileformat=VCFv4.2
##fileDate=$(date +'%Y%m%d')
##reference=GRCh38/hg38
##contig=<ID=chr1,length=248956422>
##contig=<ID=chr2,length=242193529>
##contig=<ID=chr3,length=198295559>
##contig=<ID=chr4,length=190214555>
##contig=<ID=chr5,length=181538259>
##contig=<ID=chr6,length=170805979>
##contig=<ID=chr7,length=159345973>
##contig=<ID=chr8,length=145138636>
##contig=<ID=chr9,length=138394717>
##contig=<ID=chr10,length=133797422>
##contig=<ID=chr11,length=135086622>
##contig=<ID=chr12,length=133275309>
##contig=<ID=chr13,length=114364328>
##contig=<ID=chr14,length=107043718>
##contig=<ID=chr15,length=101991189>
##contig=<ID=chr16,length=90338345>
##contig=<ID=chr17,length=83257441>
##contig=<ID=chr18,length=80373285>
##contig=<ID=chr19,length=58617616>
##contig=<ID=chr20,length=64444167>
##contig=<ID=chr21,length=46709983>
##contig=<ID=chr22,length=50818468>
##contig=<ID=chrX,length=156040895>
##contig=<ID=chrY,length=57227415>
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO"

echo -e "$header" > "$new_calls"

# Iterate through each VCF file in the current folder
for file in *.vcf; do
  if [ -e "$file" ]; then
    # Extract and modify the relevant columns, and append to the temporary database
	# The VCF has 115 lines in the header configure as needed
    tail -n +$n_lines "$file" | awk 'BEGIN{OFS="\t"}{print $1, $2, ".", $4, $5, ".", ".", "."}' >> "$temp_var"
  fi
done

# Remove duplicate lines from the temporary database
sort -u -o "$temp_var" "$temp_var"

# Create a backup copy of the current database file
cp "$VCF_database" "$VCF_database_backup"

# Use comm to append only new and unique lines to the existing database
comm -13 <(sort "$VCF_database") <(sort "$temp_var") >> "$VCF_database"

# Check if the database was modified
if ! cmp -s "$VCF_database" "$VCF_database_backup"; then
	echo "New lines appended to SpliceAI_VCF_database.vcf."
	
	# Extract and store the new lines in new_calls.vcf
	comm -13 <(sort "$VCF_database_backup") <(sort "$VCF_database") >> "$new_calls"
	
	# Annotate new unique variants using spliceai hg38 and set the fasta folder and paramters accordingly
	spliceai -I "$new_calls" -O "$new_calls_annotated" -R "$hg38_fasta" -A grch38 -D 200
	
	# Merge annotated new calls to the database
	tail -n +31 "$new_calls_annotated" >> "$database_ann"
	
	# Remove duplicate and sort
	sort -u -o "$database_ann" "$database_ann"
	
	# Check extra first line in the file
	if [[ $(head -n 1 "$database_ann") == "" ]]; then
		tail -n +2 "$database_ann" > "$temp_database"
		mv "$temp_database" "$database_ann"
	fi
	
	# Convert the VCF to a annovar database
	perl "$convert2annovar" -format vcf4 -includeinfo "$database_ann" > "$temp_convertion"

	# Create the header for the output file
	echo -e "#Chr\tStart\tEnd\tRef\tAlt\tSpliceAI_ALLELE_Gene\tDS_AG\tDP_AG\tDS_AL\tDP_AL\tDS_DG\tDP_DG\tDS_DL\tDP_DL" > "$spliceai_annovar_database"
	
	# Process the input file and generate the output
awk 'BEGIN {FS="\t"; OFS="\t"} {
    allele_info = $13
    split(allele_info, allele_array, "|")
    if (allele_array[1] == ".") {
        SpliceAI_ALLELE_Gene = "NA"
        ds_ag = "NA"
        ds_al = "NA"
        ds_dg = "NA"
        ds_dl = "NA"
        dp_ag = "NA"
        dp_al = "NA"
        dp_dg = "NA"
        dp_dl = "NA"
    } else {
        SpliceAI_ALLELE_Gene = allele_array[1] " (" allele_array[2] ")"
        ds_ag = allele_array[3]
        ds_al = allele_array[4]
        ds_dg = allele_array[5]
        ds_dl = allele_array[6]
        dp_ag = allele_array[7]
        dp_al = allele_array[8]
        dp_dg = allele_array[9]
        dp_dl = allele_array[10]
    }

    # Output the desired columns
    print $1, $2, $3, $4, $5, SpliceAI_ALLELE_Gene, ds_ag, dp_ag, ds_al, dp_al, ds_dg, dp_dg, ds_dl, dp_dl
}' "$temp_convertion" >> "$spliceai_annovar_database"
		 
else
	echo "No new lines to append. SpliceAI_VCF_database.vcf remains the same."
fi

# Clean up the temporary database and backup copy
rm "$temp_convertion" "$VCF_database_backup" "$new_calls_annotated" "$new_calls" "$temp_database" "$temp_var"