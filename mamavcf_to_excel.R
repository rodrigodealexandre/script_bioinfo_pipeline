args <- commandArgs(TRUE)

mamavcf_to_excel <- function(filename){
  
  ### Check if all package are installed
  ### Install and load stringr for text manipulation
  {
    if (!require("stringr",character.only = TRUE))
    {
      install.packages("stringr", dep=TRUE, repos = "http://cran.us.r-project.org")
      if(!require("stringr",character.only = TRUE)) stop("Package not found")
    }
  }
  library("stringr")
  
  ### Install and load dplyr for subseletction columns
  {
    if (!require("dplyr",character.only = TRUE))
    {
      install.packages("dplyr", dep=TRUE, repos = "http://cran.us.r-project.org")
      if(!require("dplyr",character.only = TRUE)) stop("Package not found")
    }
  }
  library("dplyr")
  
  ### Install and load writexl for writing excel files
  {
    if (!require("writexl",character.only = TRUE))
    {
      install.packages("writexl", dep=TRUE, repos = "http://cran.us.r-project.org")
      if(!require("writexl",character.only = TRUE)) stop("Package not found")
    }
  }
  library("writexl")
  
  ### Set excel out name
  excelname <- gsub("csv", "xlsx", filename)
  
  ### Read annotated CSV file
  temp <- read.csv(filename)
  
  ### Modify R Options to Disable Scientific Notation
  options(scipen = 999) 

  
  ### Text manipulation for extracting quality scores and variant info
  {
    ###text manipulation for extracting quality scores and variant info
    temp$DP <- as.numeric(str_extract(temp$Otherinfo1,'(?<=DP=)[0-9]+'))
    temp$DP_UMI <- as.numeric(str_extract(temp$Otherinfo1,'(?<=UMT=)[0-9]+'))
    temp$AF_UMI <- as.numeric(str_extract(temp$Otherinfo1,'(?<=VMF=)[0-9.]+'))
    temp$Zigozity <- str_extract(temp$Otherinfo1,'(?<=VF\t)[0-9]/[0-9]')
    temp$RepRegion <- str_extract(temp$Otherinfo1,'(?<=RepRegion=)[a-zA-z,]+')
    temp$VCF_QUAL <- as.numeric(str_extract(temp$Otherinfo1,'(?<=\t)[0-9]+[.]{1}[0-9]+(?=\t[a-zA-Z0-9;]+\tTYPE=)'))
    temp$VCF_FILTER <- str_extract(temp$Otherinfo1,'(?<=\t)[a-zA-Z0-9;]+(?=\tTYPE=)')
    temp$gnomAD3.1.2 <- as.numeric(gsub("^[.]", "0", temp$gnomad312_AF))
    temp$ABraOM <- as.numeric(gsub("^[.]", "0", temp$abraom_freq))
    #temp$Gene <- sapply(strsplit(temp$Gene_refGeneWithVer,";"), `[`, 1)
    temp$HGVS <- temp$AAChange_refGeneWithVer
	
	pattern <- "NM_007294|NM_000059|NM_000546"
	
    temp$HGVS[grep(pattern, temp$AAChange_refGeneWithVer)] <- unlist(lapply(temp$AAChange_refGeneWithVer[grep(pattern, temp$AAChange_refGeneWithVer)],function(x)
      paste(unlist(strsplit(x, ","))[grep(pattern, unlist(strsplit(x, ",")))], collapse=",")))
    temp$HGVS_intron <- temp$GeneDetail_refGeneWithVer
    temp$HGVS_intron[grep(pattern, temp$GeneDetail_refGeneWithVer)] <- unlist(lapply(temp$GeneDetail_refGeneWithVer[grep(pattern, temp$GeneDetail_refGeneWithVer)],function(x)
      paste(unlist(strsplit(x, ";"))[grep(pattern, unlist(strsplit(x, ";")))], collapse=",")))
	  
	
	replacements <- c("NM_007294"="BRCA1:NM_007294",
					"NM_000059"="BRCA2:NM_000059",
					"NM_000546"="TP53:NM_000546")

	temp$HGVS_intron <- stringr::str_replace_all(temp$HGVS_intron, replacements)
	
	
    temp$HGVS[grep("^[.]", temp$AAChange_refGeneWithVer)] <- temp$HGVS_intron[grep("^[.]", temp$AAChange_refGeneWithVer)]
  }
  {
  ### Subset with select function
  selected <- temp %>% select(Chr,Start,End,Ref,Alt,CLNSIG,CLNREVSTAT,Gene_refGeneWithVer,Func_refGeneWithVer,ExonicFunc_refGeneWithVer,
                              HGVS,Zigozity,AF_UMI,DP,DP_UMI,VCF_QUAL,genomicSuperDups,RepRegion,gnomAD3.1.2,ABraOM,avsnp150,REVEL_score,
                              dbscSNV_ADA_SCORE,dbscSNV_RF_SCORE,regsnp_fpr,regsnp_disease)
  }
  
  ### Order anr write Excel
  return(write_xlsx(selected[order(selected$gnomAD3.1.2),], excelname))
  
}

mamavcf_to_excel(args)