### script_bioinfo_pipeline
### Bioinformatics script to automate file location and name normalization, and execute coverage pipeline and Annovar annotation on all BAM and VCF files within a specified folder, based on the chosen NGS kit.

### First, you will need to install and set up a Conda environment. Follow these steps in a Linux Ubuntu environment. These steps can also be applied in a Windows Ubuntu environment.

# --- Coverage ---
### Install conda
sudo apt update  \
sudo apt upgrade \
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
bash Miniconda3-latest-Linux-x86_64.sh \
conda create -n bioinfo python=3.9 \

### Enter the conda environment
conda activate bioinfo

### Versions needed for this pipeline:
conda install -c bioconda -c conda-forge gatk4=4.2.6.0 \
    freebayes=1.3.6 \
    picard=2.27.4 \
    bwa=0.7.17 \
    fastqc=0.11.9 \
    samtools=1.14 \
    bedtools=2.22.0

conda install -c bioconda pandas=1.5.1 \
pip install click \
pip install pandas \
pip install XlsxWriter \

# --- Select and convert Annovar QiagenSeq BRCA (hg38) pipeline to excel ---
### Install r-stringi via Conda to enable installation within R later on.
conda install -c conda-forge r-stringi

### Instal perl
conda install perl

### Download and install Annovar (to download the file it is needed a licence, check Annovar website).
wget http://www.openbioinformatics.org/annovar/download/XXXX/annovar.latest.tar.gz \
sudo tar xzvf annovar.latest.tar.gz

### Opend R and install these packages.
install.packages("stringr", dep=TRUE, repos = "http://cran.us.r-project.org") \
install.packages("dplyr", dep=TRUE, repos = "http://cran.us.r-project.org") \
install.packages("writexl", dep=TRUE, repos = "http://cran.us.r-project.org") \

### install all of the following database for the BRCA pipeline.
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar refGene humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar refGeneWithVer humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar dbnsfp42a humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar dbscsnv11 humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar gnomad211_genome humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar gnomad312_genome humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar abraom humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar avsnp150 humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar clinvar_20221231 humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar regsnpintron humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb genomicSuperDups humandb/ \

# --- Select and convert Annovar QiagenSeq ONCO (hg38) pipeline to excel ---
### install all of the following database for the ONCO pipeline.
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar refGeneWithVer humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar avsnp150 humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar clinvar_20221231 humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar gnomad211_exome humandb/ \
sudo perl annotate_variation.pl -buildver hg38 -downdb -webfrom annovar gnomad312_genome humandb/ \

### Login at COSMIC and download files: CosmicCodingMuts.vcf.gz; CosmicNonCodingVariants.vcf.gz; CosmicMutantExport.tsv.gz; CosmicNCV.tsv.gz  (to download the file it is needed a licence, check Cosmic website)
curl -H "Authorization: Basic XXXX=" https://cancer.sanger.ac.uk/cosmic/file_download/GRCh38/cosmic/v97/VCF/CosmicCodingMuts.normal.vcf.gz \
curl -H "Authorization: Basic XXXX=" https://cancer.sanger.ac.uk/cosmic/file_download/GRCh38/cosmic/v97/VCF/CosmicNonCodingVariants.normal.vcf.gz \
curl -H "Authorization: Basic XXXX=" https://cancer.sanger.ac.uk/cosmic/file_download/GRCh38/cosmic/v97/CosmicMutantExport.tsv.gz \
curl -H "Authorization: Basic XXXX=" https://cancer.sanger.ac.uk/cosmic/file_download/GRCh38/cosmic/v97/CosmicNCV.tsv.gz \

### Download prepare_annovar_user.pl from http://www.openbioinformatics.org/annovar/download/prepare_annovar_user.pl and paste all files to Annovar folder
### Ddownload and unzip cosmic files to Annovar folder
sudo gzip -d **.gz \
sudo /home/bioinfotools/annovar/prepare_annovar_user.pl -dbtype cosmic CosmicMutantExport.tsv -vcf CosmicCodingMuts.normal.vcf > hg38_cosmic97_coding.txt \
sudo /home/bioinfotools/annovar/prepare_annovar_user.pl -dbtype cosmic CosmicNCV.tsv -vcf CosmicNonCodingVariants.normal.vcf > hg38_cosmic97_noncoding.txt \

# --- Select and convert Annovar Illumina Focus (hg19) pipeline to excel ---
### install all of the following database for the ONCO pipeline.
sudo perl annotate_variation.pl -buildver hg19 -downdb -webfrom annovar refGeneWithVer humandb/ \
sudo perl annotate_variation.pl -buildver hg19 -downdb -webfrom annovar avsnp150 humandb/ \
sudo perl annotate_variation.pl -buildver hg19 -downdb -webfrom annovar clinvar_20221231 humandb/ \
sudo perl annotate_variation.pl -buildver hg19 -downdb -webfrom annovar gnomad211_exome humandb/ \
sudo perl annotate_variation.pl -buildver hg19 -downdb -webfrom annovar gnomad211_genome humandb/ \

### Login at COSMIC and download files: CosmicCodingMuts.vcf.gz; CosmicNonCodingVariants.vcf.gz; CosmicMutantExport.tsv.gz; CosmicNCV.tsv.gz  (to download the file it is needed a licence, check Cosmic website)
curl -H "Authorization: Basic XXXX=" https://cancer.sanger.ac.uk/cosmic/file_download/GRCh37/cosmic/v97/VCF/CosmicCodingMuts.normal.vcf.gz \
curl -H "Authorization: Basic XXXX=" https://cancer.sanger.ac.uk/cosmic/file_download/GRCh37/cosmic/v97/VCF/CosmicNonCodingVariants.normal.vcf.gz \
curl -H "Authorization: Basic XXXX=" https://cancer.sanger.ac.uk/cosmic/file_download/GRCh37/cosmic/v97/CosmicMutantExport.tsv.gz \
curl -H "Authorization: Basic XXXX=" https://cancer.sanger.ac.uk/cosmic/file_download/GRCh37/cosmic/v97/CosmicNCV.tsv.gz \

### Download prepare_annovar_user.pl from http://www.openbioinformatics.org/annovar/download/prepare_annovar_user.pl and paste all files to Annovar folder
### Ddownload and unzip cosmic files to Annovar folder
sudo gzip -d **.gz \
sudo /home/bioinfotools/annovar/prepare_annovar_user.pl -dbtype cosmic CosmicMutantExport.tsv -vcf CosmicCodingMuts.normal.vcf > hg19_cosmic97_coding.txt \
sudo /home/bioinfotools/annovar/prepare_annovar_user.pl -dbtype cosmic CosmicNCV.tsv -vcf CosmicNonCodingVariants.normal.vcf > hg19_cosmic97_noncoding.txt \
