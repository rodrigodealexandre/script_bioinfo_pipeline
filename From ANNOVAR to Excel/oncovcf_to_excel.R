args <- commandArgs(TRUE)

oncovcf_to_excel <- function(filename){
  
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
  excelname <- gsub("txt", "xlsx", filename)
  
  ### Read annotated CSV file
  #temp <- read.csv(filename)
  #temp <- read.table(filename, sep="\t", header=TRUE)
  
  ###it seems the amount of characters in each line is bigger than R can handle with read.table, it is cutting the information therfore reducing the amount of elements.
  ### due this factor, data was imported with readLines.
  
	# Read in the file as a vector of character strings
	lines <- readLines(filename)
	
	# Split the first line into separate fields using '\t' as the separator
	header <- strsplit(lines[1], "\t")[[1]]
	
	# Split each remaining line into separate fields using '\t' as the separator
	fields <- lapply(lines[-1], function(x) strsplit(x, "\t")[[1]])
	
	# Combine the header and fields into a data frame
	temp <- data.frame(matrix(unlist(c(header, fields)), ncol=length(header), byrow=TRUE), stringsAsFactors=FALSE)
	
	# Set the header as the column names
	names(temp) <- temp[1,]
	temp <- temp[-1,]
	
	# Rename the duplicate columns using make.names()
	names(temp) <- make.names(names(temp), unique = TRUE)
  
  ### Modify R Options to Disable Scientific Notation
  options(scipen = 999) 

  
  ### Text manipulation for extracting quality scores and variant info
  {
    ###text manipulation for extracting quality scores and variant info
	###check if is the file with gnomAD_2_WGS (HG19)
	if("AF.1" %in% colnames(temp)) {	
		temp$DP <- as.numeric(temp$Otherinfo3)
		#temp$DP <- as.numeric(str_extract(temp$Otherinfo1,'(?<=DP=)[0-9]+'))
		#temp$DP_UMI <- as.numeric(str_extract(temp$Otherinfo1,'(?<=UMT=)[0-9]+'))
		temp$VAF <- as.numeric(sapply(strsplit(temp$Otherinfo13,":"), `[`, 4))
		#temp$AF_UMI <- as.numeric(str_extract(temp$Otherinfo1,'(?<=VMF=)[0-9.]+'))
		#temp$Zigozity <- str_extract(temp$Otherinfo1,'(?<=VF\t)[0-9]/[0-9]')
		#temp$RepRegion <- str_extract(temp$Otherinfo1,'(?<=RepRegion=)[a-zA-z,]+')
		temp$VCF_QUAL <- as.numeric(str_extract(temp$Otherinfo11,'(?<=MQ=)[0-9.]+'))
		#temp$VCF_QUAL <- as.numeric(str_extract(temp$Otherinfo1,'(?<=\t)[0-9]+[.]{1}[0-9]+(?=\t[a-zA-Z0-9;]+\tTYPE=)'))
		temp$VCF_FILTER <- temp$Otherinfo10
		temp$gnomAD_2_WES <- as.numeric(gsub("^[.]", "0", temp$AF))
		temp$gnomAD_2_WGS <- as.numeric(gsub("^[.]", "0", temp$AF.1))
	
	###check if is the file with gnomad312_AF (HG38)
	} else if ("gnomad312_AF" %in% colnames(temp)) {
		temp$DP <- as.numeric(str_extract(temp$Otherinfo11,'(?<=DP=)[0-9]+'))
		temp$DP_UMI <- as.numeric(str_extract(temp$Otherinfo11,'(?<=UMT=)[0-9]+'))
		temp$AF_UMI <- as.numeric(str_extract(temp$Otherinfo11,'(?<=VMF=)[0-9.]+'))
		#temp$Zigozity <- str_extract(temp$Otherinfo1,'(?<=VF\t)[0-9]/[0-9]')
		t#emp$RepRegion <- str_extract(temp$Otherinfo1,'(?<=RepRegion=)[a-zA-z,]+')
		temp$VCF_QUAL <- as.numeric(str_extract(temp$Otherinfo11,'(?<=\t)[0-9]+[.]{1}[0-9]+(?=\t[a-zA-Z0-9;]+\tTYPE=)'))
		temp$VCF_FILTER <- str_extract(temp$Otherinfo11,'(?<=\t)[a-zA-Z0-9;]+(?=\tTYPE=)')
		temp$gnomAD_2_WES <- as.numeric(gsub("^[.]", "0", temp$AF))
		temp$gnomAD3.1.2 <- as.numeric(gsub("^[.]", "0", temp$gnomad312_AF))
		
	}
		
    #temp$gnomAD3.1 <- as.numeric(gsub("^[.]", "0", temp$AF.2))
    #temp$ABraOM <- as.numeric(gsub("^[.]", "0", temp$abraom_freq))
    #temp$Gene <- sapply(strsplit(temp$Gene_refGeneWithVer,";"), `[`, 1)
	temp$HGVS <- temp$AAChange_refGeneWithVer
	
	pattern <- "NM_005157|NM_001014431|NM_005465|NM_004304|NM_000044|NM_021913|NM_004333|NM_053056|NM_000075|NM_001145306|NM_001904|NM_006182|NM_005228|NM_004448|NM_001982|NM_005235|NM_182918|NM_001122740|NM_001163147|NM_001079675|NM_004454|NM_001174067|NM_000141|NM_000142|NM_213647|NM_002067|NM_002072|NM_005343|NM_005896|NM_002168|NM_002227|NM_004972|NM_000215|NM_000222|NM_004985|NM_002755|NM_030662|NM_000245|NM_004958|NM_002467|NM_005378|NM_002524|NM_002529|NM_006180|NM_001012338|NM_006206|NM_006218|NM_015869|NM_002880|NM_020975|NM_002944|NM_005631"
	
	temp$HGVS[grep(pattern, temp$AAChange_refGeneWithVer)] <- unlist(lapply(temp$AAChange_refGeneWithVer[grep(pattern, temp$AAChange_refGeneWithVer)],function(x)
      paste(unlist(strsplit(x, ","))[grep(pattern, unlist(strsplit(x, ",")))], collapse=",")))
    temp$HGVS_intron <- temp$GeneDetail_refGeneWithVer
    temp$HGVS_intron[grep(pattern, temp$GeneDetail_refGeneWithVer)] <- unlist(lapply(temp$GeneDetail_refGeneWithVer[grep(pattern, temp$GeneDetail_refGeneWithVer)],function(x)
      paste(unlist(strsplit(x, ";"))[grep(pattern, unlist(strsplit(x, ";")))], collapse=",")))
	

	replacements <- c("NM_005157"="ABL1:NM_005157",
                  "NM_001014431"="AKT1:NM_001014431",
                  "NM_005465"="AKT3:NM_005465",
                  "NM_004304"="ALK:NM_004304",
                  "NM_000044"="AR:NM_000044",
                  "NM_021913"="AXL:NM_021913",
                  "NM_004333"="BRAF:NM_004333",
                  "NM_053056"="CCND1:NM_053056",
                  "NM_000075"="CDK4:NM_000075",
                  "NM_001145306"="CDK6:NM_001145306",
                  "NM_001904"="CTNNB1:NM_001904",
                  "NM_006182"="DDR2:NM_006182",
                  "NM_005228"="EGFR:NM_005228",
                  "NM_004448"="ERBB2:NM_004448",
                  "NM_001982"="ERBB3:NM_001982",
                  "NM_005235"="ERBB4:NM_005235",
                  "NM_182918"="ERG:NM_182918",
                  "NM_001122740"="ESR1:NM_001122740",
                  "NM_001163147"="ETV1:NM_001163147",
                  "NM_001079675"="ETV4:NM_001079675",
                  "NM_004454"="ETV5:NM_004454",
                  "NM_001174067"="FGFR1:NM_001174067",
                  "NM_000141"="FGFR2:NM_000141",
                  "NM_000142"="FGFR3:NM_000142",
                  "NM_213647"="FGFR4:NM_213647",
                  "NM_002067"="GNA11:NM_002067",
                  "NM_002072"="GNAQ:NM_002072",
                  "NM_005343"="HRAS:NM_005343",
                  "NM_005896"="IDH1:NM_005896",
                  "NM_002168"="IDH2:NM_002168",
                  "NM_002227"="JAK1:NM_002227",
                  "NM_004972"="JAK2:NM_004972",
                  "NM_000215"="JAK3:NM_000215",
                  "NM_000222"="KIT:NM_000222",
                  "NM_004985"="KRAS:NM_004985",
                  "NM_002755"="MAP2K1:NM_002755",
                  "NM_030662"="MAP2K2:NM_030662",
				  "NM_000245"="MET:NM_000245",
				  "NM_004958"="MTOR:NM_004958",
				  "NM_002467"="MYC:NM_002467",
				  "NM_005378"="MYCN:NM_005378",
				  "NM_002524"="NRAS:NM_002524",
				  "NM_002529"="NTRK1:NM_002529",
				  "NM_006180"="NTRK2:NM_006180",
				  "NM_001012338"="NTRK3:NM_001012338",
				  "NM_006206"="PDGFRA:NM_006206",
				  "NM_006218"="PIK3CA:NM_006218",
				  "NM_015869"="PPARG:NM_015869",
				  "NM_002880"="RAF1:NM_002880",
				  "NM_020975"="RET:NM_020975",
				  "NM_002944"="ROS1:NM_002944",
				  "NM_005631"="SMO:NM_005631")

	temp$HGVS_intron <- stringr::str_replace_all(temp$HGVS_intron, replacements)

	

    temp$HGVS[grep("^[.]", temp$AAChange_refGeneWithVer)] <- temp$HGVS_intron[grep("^[.]", temp$AAChange_refGeneWithVer)]
	temp$cosmic97 <- temp$cosmic97_coding
	temp$cosmic97[grep("^[.]", temp$cosmic97_coding)] <- temp$cosmic97_noncoding[grep("^[.]", temp$cosmic97_coding)]
  }
  
  
  {
  	###check if is the file with gnomAD_2_WGS (HG19)
	if("AF.1" %in% colnames(temp)) {	
  
		### Subset with select function
		selected <- temp %>% select(Chr,Start,End,Ref,Alt,CLNSIG,CLNREVSTAT,Gene_refGeneWithVer,Func_refGeneWithVer,ExonicFunc_refGeneWithVer,
                              HGVS,VAF,DP,VCF_QUAL,VCF_FILTER,gnomAD_2_WES,gnomAD_2_WGS,avsnp150,cosmic97)
							  
	###check if is the file with gnomad312_AF (HG38)
	} else if ("gnomad312_AF" %in% colnames(temp)) {
		
		### Subset with select function
		selected <- temp %>% select(Chr,Start,End,Ref,Alt,CLNSIG,CLNREVSTAT,Gene_refGeneWithVer,Func_refGeneWithVer,ExonicFunc_refGeneWithVer,
                              HGVS,AF_UMI,DP,DP_UMI,VCF_QUAL,VCF_FILTER,gnomAD_2_WES,gnomAD3.1.2,avsnp150,cosmic97)


	}
  }
  
  ### Order anr write Excel
  return(write_xlsx(selected[order(selected$gnomAD_2_WES),], excelname))
  
}

oncovcf_to_excel(args)
