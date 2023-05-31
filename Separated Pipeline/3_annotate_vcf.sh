#!/bin/bash

ANNOVAR_SCRIPT="/home/bioinfotools/annovar/convert2annovar.pl -format vcf4 -includeinfo"
ANNOVAR_TABLE_SCRIPT="/home/bioinfotools/annovar/table_annovar.pl"
ANNOVAR_DB="/home/bioinfotools/annovar/humandb/"
MAMAVCF_TO_EXCEL_SCRIPT="/home/bioinfotools/annovar/mamavcf_to_excel.R"
ONCOVCF_TO_EXCEL_SCRIPT="/home/bioinfotools/annovar/oncovcf_to_excel.R"

# Prompt for the NGS kit
read -p "Enter the NGS kit (QiaSeqMama, QiaSeqOnco, or IlluminaFocus): " ngs_kit

# Set the appropriate script and database based on the NGS kit
if [ "$ngs_kit" = "QiaSeqMama" ]; then
    VCF_TO_EXCEL_SCRIPT="$MAMAVCF_TO_EXCEL_SCRIPT"
    BUILD_VER="hg38"
    PROTOCOL='refGeneWithVer,clinvar_20221231,dbnsfp42a,dbscsnv11,regsnpintron,gnomad211_exome,gnomad211_genome,gnomad312_genome,abraom,avsnp150,genomicSuperDups'
    OPERATION='gx,f,f,f,f,f,f,f,f,f,r'
    ARGUMENT='-hgvs -splicing_threshold 20,,,,,,,,,,'
    ANNOVAR_OPTIONS='-intronhgvs 100 -nastring . -dot2underline -otherinfo -csvout'
    INPUT_EXT="annovar"
    OUTPUT_EXT="csv"

elif [ "$ngs_kit" = "QiaSeqOnco" ]; then
    VCF_TO_EXCEL_SCRIPT="$ONCOVCF_TO_EXCEL_SCRIPT"
    BUILD_VER="hg38"
    PROTOCOL='refGeneWithVer,clinvar_20221231,gnomad211_exome,gnomad312_genome,avsnp150,cosmic97_coding,cosmic97_noncoding'
    OPERATION='gx,f,f,f,f,f,f'
    ARGUMENT='-hgvs -splicing_threshold 20,,,,,,'
    ANNOVAR_OPTIONS='-intronhgvs 1000 -nastring . -vcfinput -dot2underline -otherinfo'
	INPUT_EXT="vcf"
    OUTPUT_EXT="txt"

elif [ "$ngs_kit" = "IlluminaFocus" ]; then
    VCF_TO_EXCEL_SCRIPT="$ONCOVCF_TO_EXCEL_SCRIPT"
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
			
        else

        perl $ANNOVAR_TABLE_SCRIPT $vcf_file $ANNOVAR_DB -buildver $BUILD_VER -remove \
            -protocol "$PROTOCOL" \
            -operation "$OPERATION" \
            -argument "$ARGUMENT" \
            $ANNOVAR_OPTIONS
			
		fi

        # Convert the output file to Excel
        Rscript $VCF_TO_EXCEL_SCRIPT $base_name.${INPUT_EXT}.${BUILD_VER}_multianno.$OUTPUT_EXT
				
    fi
done

sleep 5

# Remove unused files
rm *.annovar *.avinput *.txt *.csv *_multianno.vcf
