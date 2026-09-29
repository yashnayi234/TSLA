# 02_preprocess.R -- build the nested case-control data set, binary ICD-9 matrix, and ICD-9 tree.
source("00_config.R")
suppressPackageStartupMessages(library(data.table))
set.seed(SEED)
t0 <- Sys.time()

f <- function(pat) list.files(DATA_DIR, pattern = pat, full.names = TRUE)
# ---- 1. beneficiaries: read EVERYTHING as character (keeps leading zeros, avoids type guessing)
bene <- rbindlist(lapply(f("Beneficiary_Summary_File_Sample_[0-9]+\\.csv$"), function(p) {
  b <- fread(p, colClasses = "character",
             select = c("DESYNPUF_ID", "BENE_BIRTH_DT", "BENE_DEATH_DT", "BENE_SEX_IDENT_CD"))
  b[, file_year := as.integer(sub(".*DE1_0_(\\d{4})_.*", "\\1", p))]
  b
}))
setorder(bene, DESYNPUF_ID, -file_year)
bene <- bene[, .SD[1], by = DESYNPUF_ID]            # most recent year's record per person
bene[, birth := as.IDate(BENE_BIRTH_DT, format = "%Y%m%d")]
bene[, byear := year(birth)]
bene[, sex := as.integer(BENE_SEX_IDENT_CD)]        # 1 = male, 2 = female
cat("Beneficiaries:", nrow(bene), "\n")

# ---- 2. claims -> long table of (id, date, code)
read_claims <- function(p) {
  hdr <- names(fread(p, nrows = 0))
  dx  <- grep("ICD9_DGNS_CD", hdr, value = TRUE)    # includes ADMTNG_ICD9_DGNS_CD on inpatient
  cl  <- fread(p, colClasses = "character", select = c("DESYNPUF_ID", "CLM_FROM_DT", dx))
  cl[, claim_row := .I]
  long <- melt(cl, id.vars = c("DESYNPUF_ID", "CLM_FROM_DT", "claim_row"),
               value.name = "code", variable.factor = FALSE)[code != ""]
  list(visits = unique(cl[, .(DESYNPUF_ID, CLM_FROM_DT, claim_row)]),
       dx = unique(long[, .(DESYNPUF_ID, CLM_FROM_DT, claim_row, code)]))
}
claim_files <- c(f("Inpatient_Claims_Sample_[0-9]+\\.csv$"), f("Outpatient_Claims_Sample_[0-9]+\\.csv$"),
                 if (INCLUDE_CARRIER) f("Carrier_Claims_Sample_[0-9]+[AB]\\.csv$"))
parts <- lapply(claim_files, read_claims)
for (i in seq_along(parts)) {                          # make claim ids unique across files
  parts[[i]]$visits[, claim_row := paste0(i, "_", claim_row)]
  parts[[i]]$dx[,     claim_row := paste0(i, "_", claim_row)]
}
visits <- rbindlist(lapply(parts, `[[`, "visits"))
dx     <- rbindlist(lapply(parts, `[[`, "dx")); rm(parts); invisible(gc())
visits[, date := as.IDate(CLM_FROM_DT, format = "%Y%m%d")]
dx[,     date := as.IDate(CLM_FROM_DT, format = "%Y%m%d")]
visits <- visits[!is.na(date)]; dx <- dx[!is.na(date)]
dx[, code := toupper(trimws(code))]
cat("Claims:", nrow(visits), " diagnosis rows:", nrow(dx), "\n")

# ---- 3. outcome: first self-harm code (ICD-9 E950-E959) = index date
sh_claims <- unique(dx[grepl("^E95[0-9]", code), claim_row])
first_sh  <- dx[claim_row %in% sh_claims, .(sh_date = min(date)), by = DESYNPUF_ID]
first_claim <- visits[, .(first_date = min(date)), by = DESYNPUF_ID]
cat("People with any E950-E959 code:", nrow(first_sh), "\n")

cases <- merge(first_sh, first_claim, by = "DESYNPUF_ID")
cases <- merge(cases, bene[, .(DESYNPUF_ID, sex, byear, birth)], by = "DESYNPUF_ID")
n0 <- nrow(cases)
cases <- cases[first_date < sh_date]                  # need history: drop if first claim IS the attempt
cat("Cases after dropping 'first visit = self-harm':", nrow(cases), "of", n0, "\n")
cases[, age := as.numeric(sh_date - birth) / 365.25]
if (!is.na(AGE_MIN)) cases <- cases[age >= AGE_MIN]
if (!is.na(AGE_MAX)) cases <- cases[age <= AGE_MAX]
cases[, set_id := .I]

# ---- 4. risk-set sampling: 1:N controls matched on sex + birth year
ok_visits <- visits[!claim_row %in% sh_claims, .(DESYNPUF_ID, date)]  # non-self-harm claims
ok_visits <- unique(merge(ok_visits, bene[, .(DESYNPUF_ID, sex, byear)], by = "DESYNPUF_ID"))
ok_visits <- merge(ok_visits, first_claim, by = "DESYNPUF_ID")
ok_visits <- merge(ok_visits, first_sh, by = "DESYNPUF_ID", all.x = TRUE)
win <- cases[, .(set_id, case_id = DESYNPUF_ID, sex, byear, idx = sh_date,
                 lo = sh_date - WINDOW_DAYS, hi = sh_date + WINDOW_DAYS)]
cand <- ok_visits[win, on = .(sex, byear, date >= lo, date <= hi), nomatch = 0L,
                  .(set_id, case_id, idx, DESYNPUF_ID, first_date, sh_date)]
cand <- unique(cand[DESYNPUF_ID != case_id &
                    (is.na(sh_date) | sh_date > idx) &   # no self-harm on/before index date
                    first_date < idx,                     # has history before index (like cases)
                    .(set_id, idx, DESYNPUF_ID)])
ctrl <- cand[, .SD[sample(.N, min(.N, N_CONTROLS))], by = set_id]
cat("Controls per case: ", paste(names(table(table(ctrl$set_id))), collapse = ","), "(distribution of counts)\n")

recs <- rbind(cases[, .(set_id, DESYNPUF_ID, idx = sh_date, y = 1L)],
              ctrl[,  .(set_id, DESYNPUF_ID, idx, y = 0L)])
recs <- merge(recs, bene[, .(DESYNPUF_ID, sex, birth)], by = "DESYNPUF_ID")
recs[, age := as.numeric(idx - birth) / 365.25]
setorder(recs, set_id, -y); recs[, rec_id := .I]
cat("Records:", nrow(recs), " cases:", sum(recs$y), " controls:", sum(1 - recs$y),
    " unique people:", uniqueN(recs$DESYNPUF_ID), "\n")

# ---- 5. features: mental-disorder codes 290-319 recorded BEFORE the index date
mh <- dx[grepl("^(29[0-9]|30[0-9]|31[0-9])[0-9]{0,2}$", code), .(DESYNPUF_ID, date, code)]
feat <- mh[recs, on = .(DESYNPUF_ID, date < idx), nomatch = 0L, .(rec_id, code)]
feat <- unique(feat)
cnt  <- feat[, .N, by = code]
cat("Distinct MH codes before index (unscreened):", nrow(cnt), "\n")
keep <- sort(cnt[N >= MIN_COUNT, code])
cat("Codes kept after prevalence screen (>=", MIN_COUNT, "records):", length(keep), "\n")

X2 <- matrix(0L, nrow(recs), length(keep), dimnames = list(NULL, paste0("c", keep)))
ff <- feat[code %in% keep]
X2[cbind(ff$rec_id, match(ff$code, keep))] <- 1L

# ---- 6. ICD-9 tree built from the code strings (leaf -> 4-digit -> 3-digit -> section -> chapter)
section_of <- function(c3) { n <- as.integer(c3)
  ifelse(n <= 294, "290-294", ifelse(n <= 299, "295-299", ifelse(n <= 316, "300-316", "317-319"))) }
lab <- data.frame(leaf = keep, d4 = substr(keep, 1, 4), d3 = substr(keep, 1, 3), stringsAsFactors = FALSE)
lab$section <- section_of(lab$d3); lab$chapter <- "290-319"
lab <- lab[order(lab$section, lab$d3, lab$d4, lab$leaf), ]
X2  <- X2[, paste0("c", lab$leaf), drop = FALSE]
# TSLA format: rows = leaves; columns = levels (leaf left-most, root right-most);
# entries = integer index (1..k within each column) of the ancestor node at that level.
idx_of <- function(v) match(v, unique(v))
tree.org <- data.frame(leaf    = seq_len(nrow(lab)),
                       d4      = idx_of(paste(lab$section, lab$d4)),
                       d3      = idx_of(paste(lab$section, lab$d3)),
                       section = idx_of(lab$section),
                       chapter = 1L)
cat("Tree nodes per level:", paste(names(tree.org), sapply(tree.org, function(x) length(unique(x))), collapse = "; "), "\n")
cat("Children per section (3-digit codes):", paste(tapply(lab$d3, lab$section, function(x) length(unique(x))), collapse = ","), "\n")

X1 <- cbind(age = as.numeric(scale(recs$age)), male = as.numeric(recs$sex == 1))
saveRDS(list(y = recs$y, X1 = X1, X2.org = as.data.frame(X2), tree.org = tree.org,
             labels = lab, recs = recs, unscreened_codes = cnt),
        file.path(OUT_DIR, "analysis_data.rds"))
cat("Saved", file.path(OUT_DIR, "analysis_data.rds"), " runtime:",
    round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s\n")
