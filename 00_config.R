# 00_config.R -- shared settings, sourced by every other script.
# Edit values here, not inside the numbered scripts.

SAMPLES         <- 1        # DE-SynPUF sample numbers to use, e.g. 1 or 1:4 (each ~0.25% of Medicare 5% sample)
INCLUDE_CARRIER <- FALSE    # carrier (Part B physician) claims: ~113 MB zipped per half-file, 2 halves per sample
DATA_DIR        <- "data"   # raw downloads + unzipped CSVs
OUT_DIR         <- "output" # processed data, fits, tables

SEED            <- 2024
N_CONTROLS      <- 10       # controls per case (paper: 10)
WINDOW_DAYS     <- 30       # control must have a non-self-harm claim within +/- this many days of the case index date
AGE_MIN         <- NA       # paper used 18-64; Medicare is mostly 65+, so default = no age restriction
AGE_MAX         <- NA
MIN_COUNT       <- 5        # prevalence screen: keep a code only if >= this many records have it
                            # (paper: 0.04% of 13,398 records ~= 5 records)

# model fitting
N_REPEATS       <- 3        # repeated train/test splits
TEST_FRAC       <- 0.3      # fraction of matched sets held out for testing
NFOLDS          <- 3        # inner CV folds for tuning
TSLA_CONTROL    <- list(maxit = 500, mu = 1e-3, tol = 1e-5, verbose = FALSE)
TSLA_MODSTR     <- list(nlambda = 6, lambda.min.ratio = 1e-3, alpha = c(0, 0.5, 1))
# ^ small grid so the demo runs in minutes; the paper-style run would use e.g. nlambda = 50,
#   alpha = seq(0, 1, length.out = 10), NFOLDS = 5, maxit = 10000 (hours).
N_CORES         <- max(1, min(4, parallel::detectCores() - 1))  # parallel repeats (Mac/Linux; Windows uses 1)

dir.create(DATA_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_DIR,  showWarnings = FALSE, recursive = TRUE)
