`%>%` = magrittr::`%>%`
.io = import('ebits/io')
.map_id = import('./map_id')$map_id

.load = function(...) .io$load(module_file(..., mustWork=TRUE))

#' Get a data.frame listing all GISTIC scores for CNAs
#'
#' @param id_type  Where to cut the barcode, either "patient", "specimen", or "full"
#' @return         A data.frame with data for all the simple mutations
cna_gistic = function(id_type="specimen", ...) {
    .load("cache", "cna.RData") %>%
        .map_id(id_type=id_type, along="barcode", ...)
}

#' Get a data.frame listing all GISTIC scores for CNAs
#'
#' @param id_type  Where to cut the barcode, either "patient", "specimen", or "full"
#' @return         A data.frame with data for all the simple mutations
cna_thresholded = function(id_type="specimen", ...) {
    .load("cache", "cna_thresholded.RData") %>%
        .map_id(id_type=id_type, along="barcode", ...)
}

#' Get ABSOLUTE copy numbers from synapse
#'
#' this is from synapse: https://www.synapse.org/#!Synapse:syn1710464
#'
#' @param id_type  Where to cut the barcode, either "patient", "specimen", or "full"
#' @return  Data.frame with 'Sample' ID and genomic regions
cna_absolute = function(id_type="specimen", ...) {
    fpath = module_file("data/pancan12_absolute.segtab.txt")
    stopifnot(file.exists(fpath))
    cna = readr::read_tsv(fpath) %>%
        .map_id(id_type=id_type, along="Sample", ...)
}
