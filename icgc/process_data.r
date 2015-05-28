import('./helpers', attach=TRUE)

#' Function that processes a raw data download from ICGC to .RData/hdf5 files that can be used for analysis
#'
#' @param force  overwrite existing files instead of skipping
process_raw_data = function(force=FALSE) {
    tfun = function(x) mutate(x, tissue = .b$grep("^(\\w+)", project_code))

    df("clinical.RData", "clinical\\.", transform=tfun, force=force)
    df("clinicalsample.RData", "clinicalsample\\.", force=force)
    mat("expr_seq_raw.h5", '^exp_seq',
          raw_read_count ~ gene_id + icgc_sample_id, map.hgnc=TRUE, force=force)
    mat("expr_seq_norm.h5", '^exp_seq',
          normalized_read_count ~ gene_id + icgc_sample_id, map.hgnc=TRUE, force=force)
    mat("protein.h5", '^protein_expression',
          normalized_expression_level ~ antibody_id + icgc_sample_id, map.hgnc=FALSE, force=force)

#    mat("cnv.h5", '^copy_number_somatic_mutation',
#          segment_median ~ gene_affected + icgc_sample_id,
#          fun.aggregate = mean, map.hgnc=T, force=force)

#    mut_aggr = function(x) {
#        if (length(x) == 0)
#            return(0)
#        if (!is.numeric(x)) {
#            mtypes = getMutationTypes(bits=TRUE)
#            x = mtypes$bit_code[mtypes$consequence_type %in% x]
#        }
#        Reduce(bitwOr, x)
#    }
    mut_aggr = function(x) {
        any(x != 0)
    }
    mat('mutations.h5', '^simple_somatic',
        consequence_type ~ gene_affected + icgc_sample_id,
        fun.aggregate = mut_aggr, force=force, map.hgnc=TRUE)

    voomfile = file.path(icgc_data_dir, "expr_seq_voom.h5")
    if (identical(force, TRUE) || !file.exists(voomfile)) {
        expr = getRNASeq(raw.counts=TRUE) %>% na.omit()
        expr = limma::voom(expr)$E
        h5store::h5save(t(expr), file=voomfile)
    }
}
