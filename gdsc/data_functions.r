library(dplyr)
.b = import('ebits/base')
.ar = import('ebits/array')
.file = import('./file')
cosmic = import('./cosmic')
drug = import('./drug')
MASTER_LIST = cosmic$MASTER_LIST
DRUG_PROPS = drug$DRUG_PROPS

#' Returns a binary event matrix (BEM) for mutated genes
ngs_bem = function() {
    .file$get('NGS_BEM_FATHMM_29052013v2.ro')
}

#' Returns a matrix of frequency- and intogen-filtered mutated genes
mutated_genes = function(frequency=0, intogen=FALSE, tissue=NULL, drop=FALSE) {
    mut = t(.file$get('NGS_BEM')$logical)

    if (!is.null(tissue))
        mut = mut[rownames(mut) %in% names(tissues(tissue)),]

    if (intogen) {
        drivers = drivers(tissue=tissue)
        mut = mut[,intersect(unique(drivers$HGNC), colnames(mut))]
    }

    if (frequency > 0)
        mut = mut[,colSums(mut)/nrow(mut) > frequency]

    if (drop)
        mut = mut[,colSums(mut)>0]

    mut
}

#' Returns a list of drivers for each tissue
#'
#' @param tissue  A vector of tissues to filter for
#' @return        A list of drivers per tissue
drivers = function(tissue=NULL) {
    ig = .file$get('INTOGEN_DRIVERS')

    if (!is.null(tissue)) {
        if (tissue %in% c("COAD", "READ", "COADREAD"))
            tissue = "COREAD"

        ig = dplyr::filter(ig, Tumor_Type %in% tissue)
    }

    transmute(ig, HGNC=ActingDriver_Symbol, tissue=Tumor_Type)
}

#' Returns a gene expression matrix
#'
#' @return  A matrix with (genes x cell lines)
basal_expression = function() {
    obj = .file$get('BASAL_EXPRESSION')
    rownames(obj$DATA) = obj$GENE_SYMBOLS
    obj$DATA[rownames(obj$DATA) != "",]
}

#' Returns a drug response matrix using the filters specified
#'
#' @param metric         Either 'IC50s' or 'AUC'
#' @param filter_cosmic  A vector of COSMIC IDs to filter for (default: TRUE, include all)
#' @param drug_names     Boolean flag indicating whether to name drugs or use IDs
#' @param cell_names     Boolean flag indicating whether to use cell line names or COSMIC IDs
#' @param min_tissue_measured  Minimum number of measured responses per tissue, NA otherwise
#' @param drop           Remove columns that only contain NAs
#' @param median_top     Include only drug responses where the tissue median is in the top N tissues
#' @param stage          The minimum clinical stage; 0: experimental, 1: in dev; 2: approved
#' @return               A filtered and ID-mapped drug response matrix
drug_response = function(metric='IC50s', tissue=NULL, filter_cosmic=TRUE, drug_names=TRUE,
        cell_names=FALSE, min_tissue_measured=0, drop=FALSE, median_top=NA, stage=0) {
    if (grepl("IC50", metric))
        SCREENING = .file$get('DRUG_IC50')
    else if (grepl("AUC", metric))
        SCREENING = .file$get('DRUG_AUC')
    else
        stop("invalid metric")

    ar = import('ebits/array')
    io = import('ebits/io')
    tissues = tissues()
    stages = io$read_table(module_file('drugs_s1f.csv'), header=TRUE)

    if (is.numeric(median_top)) {
        ar$intersect(SCREENING, tissues, along=1)
        tissue_ranks = ar$map(SCREENING, along=1, subsets=tissues,
            function(x) median(x, na.rm=TRUE)) %>%
            ar$map(along=1, function(x) rank(x, ties.method="min"))

        for (tt in unique(tissues))
            for (did in colnames(SCREENING))
                if (tissue_ranks[tt,did] > median_top)
                    SCREENING[tt == tissues, did] = NA
    }

    if (!is.null(tissue)) {
        tissues = tissues(tissue)
        ar$intersect(SCREENING, tissues, along=1)
    }

    if (min_tissue_measured > 0) {
        if (grepl("AUC", metric))
            stop("concentration measurements only for IC50")

        for (tt in unique(tissues))
            for (did in colnames(SCREENING))
                if (sum(SCREENING[tt==tissues, did] <
                        drug$conc('max',ids=did), na.rm=TRUE) < min_tissue_measured)
                    SCREENING[tt==tissues, did] = NA
    }

    if (stage > 0) {
        if (stage == 1)
            keep = stages %>%
                filter(`Clinical Stage` != "experimental") %>%
                select(Identifier) %>%
                unlist() %>% unname()
        if (stage == 2)
            keep = stages %>%
                filter(`Clinical Stage` == "clinically approved") %>%
                select(Identifier) %>%
                unlist() %>% unname()

        SCREENING = SCREENING[,intersect(colnames(SCREENING), as.character(keep))]
    }

    if (drug_names)
        colnames(SCREENING) = drug$id2name(colnames(SCREENING))

    if (cell_names)
        rownames(SCREENING) = cosmic$id2name(rownames(SCREENING))

    if (drop)
        SCREENING = SCREENING[,apply(SCREENING, 2, function(x) !all(is.na(x)))]

    SCREENING
}

#' Returns a vector of tissues, with COSMIC IDs as names
#'
#' @param tissue        Character vector of tissues to filter for
#' @param unknown       Data type to encode unknown tissue; default: NA
#' @param drop_unknown  Remove cell lines where tissue is unknown
#' @param TCGA          Use TCGA tissue descriptors
#' @param minN          Minimum number of cell lines to include per tissue
tissues = function(tissue=NULL, unknown=NA, drop_unknown=TRUE, TCGA=TRUE, minN=2) {
    stopifnot(!drop_unknown || is.na(unknown)) # if drop_unknown, unknown needs to be NA

    if (TCGA)
        tissueVec = as.character(MASTER_LIST$Study.Abbreviation) # v16 TCGA
    else
        tissueVec = as.character(MASTER_LIST$GDSC.description_1) # v16 tissues
    names(tissueVec) = MASTER_LIST$COSMIC.ID # v16 cosmic id

    tissueVec[is.na(tissueVec)] = unknown
    tissueVec[tissueVec %in% c("unknown", "", "UNABLE TO CLASSIFY")] = unknown
    tissueVec = na.omit(tissueVec)

    if (!is.null(tissue))
        tissueVec = tissueVec[tissueVec %in% tissue]

    n = sapply(tissueVec, function(t) sum(t==tissueVec, na.rm=T))
    tissueVec[n>=minN]
}
