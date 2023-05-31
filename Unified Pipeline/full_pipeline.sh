#!/bin/bash

# Prompt for the NGS kit
read -p "Enter the NGS kit (QiaSeqMama, QiaSeqOnco, or IlluminaFocus): " ngs_kit

# Prompt for the folder name
read -p "Enter the folder name located in the AlignData folder that contains the aligned download files: " folder_name

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

echo "File extraction and renaming completed."

ANNOVAR_SCRIPT="/home/bioinfotools/annovar/convert2annovar.pl -format vcf4 -includeinfo"
ANNOVAR_TABLE_SCRIPT="/home/bioinfotools/annovar/table_annovar.pl"
ANNOVAR_DB="/home/bioinfotools/annovar/humandb/"

# Set the appropriate BED files and script/database based on the NGS kit for gene coverage
# Set the appropriate protocol, operation, and argument based on the NGS kit for annovar anotation
if [ "$ngs_kit" = "QiaSeqMama" ]; then
    exon_bed="/home/bioinfotools/genes_coverage/MAMA_V1.0_splice10.bed"
    cnv_bed="/home/bioinfotools/genes_coverage/MAMA V1.0 - CNV.bed"

    VCF_TO_EXCEL_SCRIPT="/home/bioinfotools/annovar/mamavcf_to_excel.R"
    BUILD_VER="hg38"
    PROTOCOL='refGeneWithVer,clinvar_20221231,dbnsfp42a,dbscsnv11,regsnpintron,gnomad211_exome,gnomad211_genome,gnomad312_genome,abraom,avsnp150,genomicSuperDups'
    OPERATION='gx,f,f,f,f,f,f,f,f,f,r'
    ARGUMENT='-hgvs -splicing_threshold 20,,,,,,,,,,'
    ANNOVAR_OPTIONS='-intronhgvs 100 -nastring . -dot2underline -otherinfo -csvout'
    INPUT_EXT="annovar"
    OUTPUT_EXT="csv"

elif [ "$ngs_kit" = "QiaSeqOnco" ]; then
    cnv_bed="/home/bioinfotools/genes_coverage/ONCO_V1.0_exons.bed"
    snv_bed="/home/bioinfotools/genes_coverage/ONCO_V1.0_codons.bed"

    VCF_TO_EXCEL_SCRIPT="/home/bioinfotools/annovar/oncovcf_to_excel.R"
    BUILD_VER="hg38"
    PROTOCOL='refGeneWithVer,clinvar_20221231,gnomad211_exome,gnomad312_genome,avsnp150,cosmic97_coding,cosmic97_noncoding'
    OPERATION='gx,f,f,f,f,f,f'
    ARGUMENT='-hgvs -splicing_threshold 20,,,,,,'
    ANNOVAR_OPTIONS='-intronhgvs 1000 -nastring . -vcfinput -dot2underline -otherinfo'
    INPUT_EXT="vcf"
    OUTPUT_EXT="xlsx"

elif [ "$ngs_kit" = "IlluminaFocus" ]; then
    region_bed="/home/bioinfotools/genes_coverage/FOCUS_snv_V1.0.bed"
    cnv_bed="/home/bioinfotools/genes_coverage/FOCUS_cnv_V1.0.bed"
    fusion_bed="/home/bioinfotools/genes_coverage/FOCUS_RNA_V1.0.bed"

    VCF_TO_EXCEL_SCRIPT="/home/bioinfotools/annovar/oncovcf_to_excel.R"
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
        python3.9 /home/bioinfotools/genes_coverage/calc_coverage_20x.py --cov "${bam_file%.bam}_exon.hist.all.txt" --output .
        python3.9 /home/bioinfotools/genes_coverage/calc_coverage_20x.py --cov "${bam_file%.bam}_CNV.hist.all.txt" --output .
		
      elif [[ $ngs_kit == "QiaSeqOnco" ]]; then
        # Run the coverage command for QiaSeqOnco
        bedtools coverage -hist -abam "$bam_file" -b "$snv_bed" > "${bam_file%.bam}_SNV.hist.all.txt"
        bedtools coverage -hist -abam "$bam_file" -b "$cnv_bed" > "${bam_file%.bam}_CNV.hist.all.txt"
        python3.9 /home/bioinfotools/genes_coverage/calc_coverage_500x.py --cov "${bam_file%.bam}_CNV.hist.all.txt" --output .
        python3.9 /home/bioinfotools/genes_coverage/calc_coverage_500x.py --cov "${bam_file%.bam}_SNV.hist.all.txt" --output .
		
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
      python3.9 /home/bioinfotools/genes_coverage/calc_coverage_500x.py --cov "${bam_file%.bam}_regions.hist.all.txt" --output .
      python3.9 /home/bioinfotools/genes_coverage/calc_coverage_500x.py --cov "${bam_file%.bam}_CNV.hist.all.txt" --output .
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
      python3.9 /home/bioinfotools/genes_coverage/calc_coverage_500x.py --cov "${bam_file%.bam}_fusion.hist.all.txt" --output .
    fi
  done
fi

# Remove unused files
rm *.all.txt

echo "NGS coverage calculation completed."

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
