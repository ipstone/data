.b = import('base')
.io = import('io')

DRUG_PROPS = .io$data('DATA/R_objects/Drugs/props_public') # v18

name2id = function(x, fuzzy_level=1, table=FALSE) {
    .b$match(x = x,
             from = DRUG_PROPS$DRUG_NAME,
             to = DRUG_PROPS$DRUG_ID,
             fuzzy_level = fuzzy_level, table = table)
}

id2name = function(id, table=FALSE) {
    .b$match(x = as.character(id),
             from = DRUG_PROPS$DRUG_ID,
             to = DRUG_PROPS$DRUG_NAME,
             fuzzy_level = 0, table = table)
}
