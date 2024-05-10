#!/bin/bash

# Prompt for the NGS kit
read -p "Enter the NGS kit (QiaSeqMama, QiaSeqOnco, or IlluminaFocus): " ngs_kit

# Prompt for the folder name
read -p "Enter the folder name located in the AlignData folder that contains the aligned download files: " folder_name

# Set the folder path
folder_path="/mnt/d/5-AlignData/$folder_name"

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
for zip_file in *.zip; do
  if [ -e "$zip_file" ]; then
    echo "Unzipping $zip_file..."
    unzip "$zip_file"
  fi
done

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

echo "File extraction and renaming completed."

ANNOVAR_SCRIPT="/mnt/d/1-bioinfotools/annovar/convert2annovar.pl -format vcf4 -includeinfo"
ANNOVAR_TABLE_SCRIPT="/mnt/d/1-bioinfotools/annovar/table_annovar.pl"
ANNOVAR_DB="/mnt/d/1-bioinfotools/annovar/humandb/"

# Set the appropriate BED files and script/database based on the NGS kit for gene coverage
# Set the appropriate protocol, operation, and argument based on the NGS kit for annovar anotation
if [ "$ngs_kit" = "QiaSeqMama" ]; then
    exon_bed="/mnt/d/1-bioinfotools/genes_coverage/MAMA_V1.0_splice10.bed"
    cnv_bed="/mnt/d/1-bioinfotools/genes_coverage/MAMA_V1.0_CNV.bed"
	ExomeDepth_script="/mnt/d/1-bioinfotools/genes_coverage/ExomeDepth_auto.R"

    VCF_TO_EXCEL_SCRIPT="/mnt/d/1-bioinfotools/annovar/mamavcf_to_excel.R"
    BUILD_VER="hg38"
    PROTOCOL='refGeneWithVer,clinvar_20221231,dbnsfp42a,dbscsnv11,regsnpintron,gnomad211_exome,gnomad211_genome,gnomad312_genome,abraom,avsnp150,genomicSuperDups,spliceai'
    OPERATION='gx,f,f,f,f,f,f,f,f,f,r,f'
    ARGUMENT='-hgvs -splicing_threshold 20,,,,,,,,,,,'
    ANNOVAR_OPTIONS='-intronhgvs 100 -nastring . -dot2underline -otherinfo -csvout'
    INPUT_EXT="annovar"
    OUTPUT_EXT="csv"

elif [ "$ngs_kit" = "QiaSeqOnco" ]; then
    cnv_bed="/mnt/d/1-bioinfotools/genes_coverage/ONCO_V1.0_exons.bed"
    snv_bed="/mnt/d/1-bioinfotools/genes_coverage/ONCO_V1.0_codons.bed"

    VCF_TO_EXCEL_SCRIPT="/mnt/d/1-bioinfotools/annovar/oncovcf_to_excel.R"
    BUILD_VER="hg38"
    PROTOCOL='refGeneWithVer,clinvar_20221231,gnomad211_exome,gnomad312_genome,avsnp150,cosmic97_coding,cosmic97_noncoding'
    OPERATION='gx,f,f,f,f,f,f'
    ARGUMENT='-hgvs -splicing_threshold 20,,,,,,'
    ANNOVAR_OPTIONS='-intronhgvs 1000 -nastring . -vcfinput -dot2underline -otherinfo'
    INPUT_EXT="vcf"
    OUTPUT_EXT="xlsx"

elif [ "$ngs_kit" = "IlluminaFocus" ]; then
    region_bed="/mnt/d/1-bioinfotools/genes_coverage/FOCUS_snv_V1.0.bed"
    cnv_bed="/mnt/d/1-bioinfotools/genes_coverage/FOCUS_cnv_V1.0.bed"
    fusion_bed="/mnt/d/1-bioinfotools/genes_coverage/FOCUS_RNA_V1.0.bed"

    VCF_TO_EXCEL_SCRIPT="/mnt/d/1-bioinfotools/annovar/oncovcf_to_excel.R"
    BUILD_VER="hg19"
    PROTOCOL='refGeneWithVer,clinvar_20221231,gnomad211_exome,gnomad211_genome,avsnp150,cosmic97_coding,cosmic97_noncoding'
    OPERATION='gx,f,f,f,f,f,f'
    ARGUMENT='-hgvs -splicing_threshold 20,,,,,,'
    ANNOVAR_OPTIONS='-intronhgvs 1000 -nastring . -vcfinput -dot2underline -otherinfo'
	INPUT_EXT="vcf"
    OUTPUT_EXT="txt"

else
    echo "Invalid NGS kit. Exiting."
    exit 1
fi

# Function to check if an Excel file exists for a given BAM file
check_excel_exists() {
  local bam_file="$1"
  local bam_name="${bam_file%.bam}"
  local bam_prefix="${bam_name%%_*}" # Extract the prefix before the first underscore
  local excel_files=( "${bam_prefix}"*_coverage.xlsx )
  
  if [[ ${#excel_files[@]} -gt 0 ]]; then
    for excel_file in "${excel_files[@]}"; do
      if [[ -f $excel_file ]]; then
        return 0 # Excel file exists
      fi
    done
  fi
  
  return 1 # Excel file does not exist
}

# Process BAM files based on the chosen NGS kit
if [[ $ngs_kit == "QiaSeqMama" || $ngs_kit == "QiaSeqOnco" ]]; then
  # For QiaSeqMama and QiaSeqOnco kits, process all BAM files in the current folder
  
  for bam_file in *.bam; do
    if [[ -f $bam_file ]]; then
      # Skip processing if Excel file already exists
	  
      if check_excel_exists "$bam_file"; then
        echo "Skipping $bam_file as a corresponding Excel file already exists."
        continue
      fi

      if [[ $ngs_kit == "QiaSeqMama" ]]; then
        # Run the coverage command for QiaSeqMama
        bedtools coverage -hist -abam "$bam_file" -b "$exon_bed" > "${bam_file%.bam}_exon.hist.all.txt"
        bedtools coverage -hist -abam "$bam_file" -b "$cnv_bed" > "${bam_file%.bam}_CNV.hist.all.txt"
        python3.9 /mnt/d/1-bioinfotools/genes_coverage/calc_coverage_20x.py --cov "${bam_file%.bam}_exon.hist.all.txt" --output .
        python3.9 /mnt/d/1-bioinfotools/genes_coverage/calc_coverage_20x.py --cov "${bam_file%.bam}_CNV.hist.all.txt" --output .
		
      elif [[ $ngs_kit == "QiaSeqOnco" ]]; then
        # Run the coverage command for QiaSeqOnco
        bedtools coverage -hist -abam "$bam_file" -b "$snv_bed" > "${bam_file%.bam}_SNV.hist.all.txt"
        bedtools coverage -hist -abam "$bam_file" -b "$cnv_bed" > "${bam_file%.bam}_CNV.hist.all.txt"
        python3.9 /mnt/d/1-bioinfotools/genes_coverage/calc_coverage_500x.py --cov "${bam_file%.bam}_CNV.hist.all.txt" --output .
        python3.9 /mnt/d/1-bioinfotools/genes_coverage/calc_coverage_500x.py --cov "${bam_file%.bam}_SNV.hist.all.txt" --output .
		
      fi
    fi
  done
  
elif [[ $ngs_kit == "IlluminaFocus" ]]; then
  # For IlluminaFocus kit, process BAM files in two separate steps
  # First step: Process BAM files ending with "_tumor.bam"
  
  for bam_file in *_tumor.bam; do
    if [[ -f $bam_file ]]; then
      # Skip processing if Excel file already exists
      if check_excel_exists "$bam_file"; then
        echo "Skipping $bam_file as a corresponding Excel file already exists."
        continue
      fi
      
      # Run the coverage command for tumor samples
      bedtools coverage -hist -abam "$bam_file" -b "$region_bed" > "${bam_file%.bam}_regions.hist.all.txt"
      bedtools coverage -hist -abam "$bam_file" -b "$cnv_bed" > "${bam_file%.bam}_CNV.hist.all.txt"
      python3.9 /mnt/d/1-bioinfotools/genes_coverage/calc_coverage_500x.py --cov "${bam_file%.bam}_regions.hist.all.txt" --output .
      python3.9 /mnt/d/1-bioinfotools/genes_coverage/calc_coverage_500x.py --cov "${bam_file%.bam}_CNV.hist.all.txt" --output .
    fi
  done

  # Second step: Process BAM files not ending with "_tumor.bam"
  for bam_file in *.bam; do
    if [[ -f $bam_file && ! $bam_file == *_tumor.bam ]]; then
      # Skip processing if Excel file already exists
      if check_excel_exists "$bam_file"; then
        echo "Skipping $bam_file as a corresponding Excel file already exists."
        continue
      fi
      
      # Run the coverage command for non-tumor samples
      bedtools coverage -hist -abam "$bam_file" -b "$fusion_bed" > "${bam_file%.bam}_fusion.hist.all.txt"
      python3.9 /mnt/d/1-bioinfotools/genes_coverage/calc_coverage_500x.py --cov "${bam_file%.bam}_fusion.hist.all.txt" --output .
    fi
  done
fi

# Remove unused files
rm *.all.txt

echo "NGS coverage calculation completed."


# Starting ExomeDepth pipeline for QiaSeqMama
if [[ $ngs_kit == "QiaSeqMama" ]]; then
    echo "Running  ExomeDepth for QiaSeqMama Pipeline"
	Rscript $ExomeDepth_script $cnv_bed $exon_bed
	
	echo "ExomeDepth calculation completed."
fi

echo "ExomeDepth calculation completed."



# Starting SpliceAI pipeline for QiaSeqMama

if [[ $ngs_kit == "QiaSeqMama" ]]; then
    echo "Checking SpliceAI Database for QiaSeqMama Pipeline"

# Set the folders accordingly
# Folders for database and scripts
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
touch $temp_var

# Initialize the file for new calls with a HG38/hg38 header
header="##fileformat=VCFv4.2\n##fileDate=$(date +'%Y%m%d')\n##reference=GRCh38/hg38\n##contig=<ID=chr1,length=248956422>\n##contig=<ID=chr2,length=242193529>\n##contig=<ID=chr3,length=198295559>\n##contig=<ID=chr4,length=190214555>\n##contig=<ID=chr5,length=181538259>\n##contig=<ID=chr6,length=170805979>\n##contig=<ID=chr7,length=159345973>\n##contig=<ID=chr8,length=145138636>\n##contig=<ID=chr9,length=138394717>\n##contig=<ID=chr10,length=133797422>\n##contig=<ID=chr11,length=135086622>\n##contig=<ID=chr12,length=133275309>\n##contig=<ID=chr13,length=114364328>\n##contig=<ID=chr14,length=107043718>\n##contig=<ID=chr15,length=101991189>\n##contig=<ID=chr16,length=90338345>\n##contig=<ID=chr17,length=83257441>\n##contig=<ID=chr18,length=80373285>\n##contig=<ID=chr19,length=58617616>\n##contig=<ID=chr20,length=64444167>\n##contig=<ID=chr21,length=46709983>\n##contig=<ID=chr22,length=50818468>\n##contig=<ID=chrX,length=156040895>\n##contig=<ID=chrY,length=57227415>\n#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO"

echo -e $header > $new_calls

# Iterate through each VCF file in the current folder
for file in *.vcf; do
  if [ -e "$file" ]; then
	# Extract and modify the relevant columns, and append to the temporary database
	# The VCF has 115 lines in the header configure as needed
	tail -n +$n_lines $file| awk 'BEGIN{OFS="\t"}{print $1, $2, ".", $4, $5, ".", ".", "."}' >> $temp_var
  fi
done

# Remove duplicate lines from the temporary database
sort -u -o $temp_var $temp_var

# Create a backup copy of the current database file
cp $VCF_database $VCF_database_backup

# Use comm to append only new and unique lines to the existing database
comm -13 <(sort $VCF_database) <(sort $temp_var) >> $VCF_database

# Check if the database was modified
if ! cmp -s $VCF_database $VCF_database_backup; then
	echo "New lines appended to SpliceAI_VCF_database.vcf."
	
	# Extract and store the new lines in new_calls.vcf
	comm -13 <(sort $VCF_database_backup) <(sort $VCF_database) >> $new_calls
	
	# Annotate new unique variants using spliceai hg38 and set the fasta folder and paramters accordingly
	spliceai -I $new_calls -O $new_calls_annotated -R $hg38_fasta -A grch38 -D 200
	
	# Merge annotated new calls to the database
	tail -n +31 $new_calls_annotated >> $database_ann
	
	# Remove duplicate and sort
	sort -u -o $database_ann $database_ann
	
	# Check extra first line in the file
	if [[ $(head -n 1 "$database_ann") == "" ]]; then
		tail -n +2 $database_ann > $temp_database
		mv $temp_database $database_ann
	fi
	
	# Convert the VCF to a annovar database
	perl $ANNOVAR_SCRIPT $database_ann > $temp_convertion

	# Create the header for the output file
	echo -e "#Chr\tStart\tEnd\tRef\tAlt\tSpliceAI_ALLELE_Gene\tDS_AG\tDP_AG\tDS_AL\tDP_AL\tDS_DG\tDP_DG\tDS_DL\tDP_DL" > $spliceai_annovar_database
	
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
}' $temp_convertion >> $spliceai_annovar_database
		 
else
	echo "No new lines to append. SpliceAI_VCF_database.vcf remains the same."
fi

# Clean up the temporary database and backup copy
rm $temp_convertion $VCF_database_backup $new_calls_annotated $new_calls $temp_database $temp_var
fi




# Iterate over VCF files in the current folder
for vcf_file in *.vcf; do
    base_name="${vcf_file%.vcf}"  # Extract base name without extension
    excel_file="${base_name}.${INPUT_EXT}.${BUILD_VER}_multianno.xlsx"

    # Check if an Excel file already exists for the current VCF file
    if [ -f "$excel_file" ]; then
        echo "Skipping $vcf_file. Excel file already exists."
		
    else
        # Run annovar script
        if [ "$ngs_kit" = "QiaSeqMama" ]; then
            perl $ANNOVAR_SCRIPT $vcf_file > $base_name.annovar
			perl $ANNOVAR_TABLE_SCRIPT $base_name.annovar $ANNOVAR_DB -buildver $BUILD_VER -remove \
				-protocol "$PROTOCOL" \
				-operation "$OPERATION" \
				-argument "$ARGUMENT" \
				$ANNOVAR_OPTIONS
			
        elif [ "$ngs_kit" = "QiaSeqOnco" ] || [ "$ngs_kit" = "IlluminaFocus" ]; then
			perl $ANNOVAR_TABLE_SCRIPT $vcf_file $ANNOVAR_DB -buildver $BUILD_VER -remove \
				-protocol "$PROTOCOL" \
				-operation "$OPERATION" \
				-argument "$ARGUMENT" \
				$ANNOVAR_OPTIONS
			
		fi

        # Convert annovar output to Excel
        Rscript $VCF_TO_EXCEL_SCRIPT $base_name.${INPUT_EXT}.${BUILD_VER}_multianno.$OUTPUT_EXT
				
    fi
done

sleep 5

# Remove unused files
rm *.annovar *.avinput *.txt *.csv *_multianno.vcf

# Define the destination path for the mirror folder
mirror_folder="/mnt/d/OneDrive - Kasvi/Farmacogenética/Resultados e Documentos pacientes/Dados brutos rotina NGS/$folder_name"

# Create the mirror folder
mkdir -p "$mirror_folder"

# Copy all .xlsx files to the mirror folder
cp *.xlsx "$mirror_folder"

echo "Copy files to mirror folder completed."