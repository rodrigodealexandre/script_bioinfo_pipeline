#!/bin/bash

# Activate the conda environment
conda activate bioinfo

# Prompt for the NGS kit
read -p "Enter the NGS kit (QiaSeqMama, QiaSeqOnco, or IlluminaFocus): " ngs_kit

# Set the appropriate BED files based on the NGS kit
case $ngs_kit in
  QiaSeqMama)
    exon_bed="/mnt/d/1-bioinfotools/genes_coverage/MAMA_V1.0_splice10.bed"
    cnv_bed="/mnt/d/1-bioinfotools/genes_coverage/MAMA V1.0 - CNV.bed"
    ;;
  QiaSeqOnco)
    cnv_bed="/mnt/d/1-bioinfotools/genes_coverage/ONCO_V1.0_exons.bed"
    snv_bed="/mnt/d/1-bioinfotools/genes_coverage/ONCO_V1.0_codons.bed"
    ;;
  IlluminaFocus)
    region_bed="/mnt/d/1-bioinfotools/genes_coverage/FOCUS_snv_V1.0.bed"
    cnv_bed="/mnt/d/1-bioinfotools/genes_coverage/FOCUS_cnv_V1.0.bed"
    fusion_bed="/mnt/d/1-bioinfotools/genes_coverage/FOCUS_RNA_V1.0.bed"
    ;;
  *)
    echo "Invalid NGS kit. Please choose one of the provided options."
    exit 1
    ;;
esac

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
