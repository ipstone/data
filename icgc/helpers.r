library(dplyr)
.b = import('base')
.ar = import('array')
.io = import('io')
.p = import('../path')

.icgc_raw_dir = .icgc_data_dir = .p$path('icgc')

.clinical = NULL
.clinicalsample = NULL

#' Helper function to get ICGC RData contents
#'
#' @param var   The variable name to cache to, either `.clinical` or `.clinicalsample`
#' @param file  The file name, either 'clinical.RData' or 'clinicalsample.RData'
#' @return      A data.frame containing the file contents
getRData = function(var, file) {
    re = base::get(var, envir=parent.env(environment()))
    if (is.null(re)) {
        re = .io$load(.io$file_path(.icgc_data_dir, file))
        assign(var, re, envir=parent.env(environment()))
    }
    re
}

#' Helper function to get ICGC HDF5 objects
#'
#' @param fname  The file name
#' @param ...    Arguments passed to varmap
#' @return       A matrix with mapped IDs
getHDF5 = function(fname, ...) {
    args = list(...)
    index = args$index
    args$index = NULL

    if (is.null(args$samples) && is.null(args$specimen) && is.null(args$donors)) {
        re = t(h5store::h5load(.io$file_path(.icgc_data_dir,
            fname, ext=".h5"), index=index))
        colnames(re) = idmap(colnames(re),
            from="icgc_sample_id", to=args$map.ids)[,2]
    } else {
        f = do.call(varmap, args)
        re = t(h5store::h5load(.io$file_path(.icgc_data_dir,
            fname, ext=".h5"), index=f$index))
        colnames(re) = f$cnames
    }
    re
}

#' Function to map the identifiers `x` from field `from` to field `to`
#'
#' @param x     Character vector with identifiers
#' @param from  Type of the identifiers
#' @param to    Type of the identifiers to map to
idmap = function(x, from, to, filter_to=NULL) {
    if (from == to || to == TRUE)
        re = data.frame(from=x, to=x)
    else {
        re = getRData('.clinicalsample', 'clinicalsample.RData') %>% select_(from, to)
        colnames(re) = c('from', 'to')
        re = re[match(x,re$from),]
    }

    if (!is.null(filter_to))
        re = re[re$to %in% filter_to,]

    if (nrow(re) == 0)
        stop("id mapping: no matches found")
    else
        re
}

#' Function to map the given variables to an HDF5 index and name mappings
#'
#' @param valid     A vector of valid identifiers
#' @param samples   ICGC sample ids
#' @param specimen  ICGC specimen ids
#' @param donors    ICGC donor ids
#' @param char      Character vector: 'sample', 'specimen', or 'donor'
#' @return          List with file index and mapped column names
varmap = function(valid, samples=NULL, specimen=NULL, donors=NULL,
                  char="", map.ids=TRUE) {
    nNull = is.null(samples) + is.null(specimen) + is.null(donors)
    if (nNull < 2)
        stop("can take ONE of index, samples, specimen, donors")
    if (nchar(char)>0 && nNull > 0)
        stop("can not map characters and variables in one go")

    if (!is.null(specimen) || grepl("specimen", char)) {
        to = "icgc_specimen_id"
        filter_to = specimen
    } else if (!is.null(donors) || grepl("donor", char)) {
        to = "icgc_donor_id"
        filter_to = donors
    } else if (!is.null(samples) || grepl("sample", char)) {
        to = "icgc_sample_id"
        filter_to = samples
    } else
        stop("invalid option. error checking before should have caught this")

    lookup = idmap(x=valid, from="icgc_sample_id", to=to, filter_to=filter_to)

    if (identical(map.ids, TRUE))
        cnames = lookup[,2]
    else if (is.character(map.ids))
        cnames = idmap(lookup[,1], from="icgc_sample_id", to=map.ids)[,2]

    list(index=lookup[,1], cnames=cnames)
}

mat = function(fname, regex, formula, map.hgnc=FALSE, force=FALSE, fun.aggregate=sum) {
    if (!force && file.exists(file.path(.icgc_data_dir, fname)))
        return()

    efiles = list.files(.icgc_raw_dir, regex, recursive=T, full.names=T)

    file2matrix = function(fname) {
        message(fname)
        mat = .ar$construct(read.table(fname, header=T, sep="\t"),
                           formula = formula,
                           fun.aggregate=fun.aggregate)
        mat = mat[!rownames(mat) %in% c('?',''),] # aggr fun might handle his?
        if (map.hgnc)
            mat = idmap$gene(mat, to='hgnc_symbol', fun.aggregate=fun.aggregate)
        mat
    }
    obj = lapply(efiles, file2matrix)

    if (length(obj) == 0)
        stop("all file reads failed, something is wrong")

    ids = unlist(sapply(obj, function(x) colnames(x)))
    dups = duplicated(ids)
    if (any(dups))
        warning(paste("Duplicate entries will be overstacked:", ids[dups]))

    mat = t(.ar$stack(obj, along=2)) # this can be done better
    if (grepl("\\.h5$", fname))
        h5store::h5save(mat, file=file.path(.icgc_data_dir, fname))
    else
        save(mat, file=file.path(.icgc_data_dir, fname))
}

df = function(fname, regex, transform=function(x) x, force=FALSE) {
    if (!force && file.exists(file.path(.icgc_data_dir, fname)))
        return()

    files = list.files(.icgc_raw_dir, regex, recursive=T, full.names=T)
    mat = do.call(rbind, lapply(files, function(f) cbind(
        study = b$grep("/([^/]+)/[^/]+$", f),
        read.table(f, header=T, sep="\t") #FIXME: io$read should work here
    ))) %>% transform

    if (grepl("\\.h5$", fname))
        h5store::h5save(mat, file=file.path(.icgc_data_dir, fname))
    else
        save(mat, file=file.path(.icgc_data_dir, fname))
}
