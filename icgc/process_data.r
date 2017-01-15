util = import('./process_util')
config = import('./config')
io = import('ebits/io')
ar = import('ebits/array')

#' Process rna_seq data
#'
#' @param force  Overwrite existing files instead of skipping
rna_seq = function(force=FALSE) {
    files = util$list_files("^exp_seq")
    exprs = util$get_matrix(files,
                            raw_read_count ~ gene_id + icgc_sample_id,
                            map.hgnc=TRUE)

    io$save(t(ar$stack(exprs, along=2)),
            file=file.path(config$cached_data, "expr_seq_raw.gctx"))

    voomfile = file.path(config$cached_data, "expr_seq_voom.gctx")
    if (identical(force, TRUE) || !file.exists(voomfile)) {
        exprs = lapply(exprs, function(e) limma::voom(e)$E)
        io$save(t(ar$stack(exprs, along=2)),
                file=voomfile)
    }
}

clinical = function(force=FALSE) {
    tfun = function(x) mutate(x, tissue = .b$grep("^(\\w+)", project_code))
    df1 = util$df("clinical.RData", "clinical\\.", transform=tfun, force=force)
    df2 = util$df("clinicalsample.RData", "clinicalsample\\.", force=force)

    io$save(df1, file=file.path(config$cached_data, fname))
}

mutations = function(force=FALSE) {
    mut_aggr = function(x) {
        any(x != 0)
    }
    util$mat('mutations.h5', '^simple_somatic',
             consequence_type ~ gene_affected + icgc_sample_id,
             fun.aggregate = mut_aggr, force=force, map.hgnc=TRUE)
}

cnv = function(force=FALSE) {
    util$mat("cnv.h5", '^copy_number_somatic_mutation',
             segment_median ~ gene_affected + icgc_sample_id,
             fun.aggregate = mean, map.hgnc=T, force=force)
}

rppa = function(force=FALSE) {
    util$mat("protein.h5", '^protein_expression',
        normalized_expression_level ~ antibody_id + icgc_sample_id,
        map.hgnc=FALSE, force=force)
}
