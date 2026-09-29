# 03_fit.R -- TSLA (tree-guided selection + logic aggregation) vs elastic net, repeated train/test splits.
source("00_config.R")
suppressPackageStartupMessages({ library(TSLA); library(glmnet); library(pROC); library(PRROC); library(parallel) })
d  <- readRDS(file.path(OUT_DIR, "analysis_data.rds"))
y  <- d$y; X1 <- d$X1; X2.org <- d$X2.org; set_id <- d$recs$set_id

# 1. tree-guided expansion (adds OR-interaction columns; required for penalty = "CL2")
t_exp <- system.time(ex <- getetmat(d$tree.org, X2.org))
X2 <- ex$x.expand; tree.expand <- ex$tree.expand
cat("Original leaf codes:", ncol(X2.org), " expanded columns:", ncol(X2),
    " expansion time:", round(t_exp[3], 1), "s\n")

# 3-digit collapsed matrix for the 'Enet2' baseline
d3 <- d$labels$d3
X3 <- sapply(unique(d3), function(k) as.integer(rowSums(X2.org[, d3 == k, drop = FALSE]) > 0))
colnames(X3) <- paste0("d3_", unique(d3))

metrics <- function(ytest, p) {
  auc   <- as.numeric(suppressMessages(pROC::auc(ytest, as.vector(p), quiet = TRUE)))
  auprc <- PRROC::pr.curve(scores.class0 = p[ytest == 1], scores.class1 = p[ytest == 0])$auc.integral
  top <- function(q) { k <- ceiling(q * length(p)); o <- order(-p)[1:k]
                       c(sens = sum(ytest[o]) / sum(ytest), ppv = mean(ytest[o])) }
  c(AUC = auc, AUPRC = auprc, sens5 = top(.05)[["sens"]], ppv5 = top(.05)[["ppv"]],
    sens10 = top(.10)[["sens"]], ppv10 = top(.10)[["ppv"]])
}
fit_tsla <- function(tr) suppressMessages(
  cv.TSLA(y = matrix(y[tr]), X_1 = X1[tr, , drop = FALSE], X_2 = X2[tr, ],
          treemat = tree.expand, family = "logit", penalty = "CL2", pred.loss = "AUC",
          weight = c(1, 1), nfolds = NFOLDS, control = TSLA_CONTROL, modstr = TSLA_MODSTR))
fit_enet <- function(X, tr, te) {
  Z <- cbind(X1, as.matrix(X))
  cv <- cv.glmnet(Z[tr, ], y[tr], family = "binomial", alpha = 0.5, nfolds = NFOLDS,
                  type.measure = "auc", penalty.factor = c(0, 0, rep(1, ncol(X))))  # age/sex unpenalized
  as.vector(predict(cv, Z[te, ], s = "lambda.min", type = "response"))
}

one_repeat <- function(r) {
  set.seed(SEED + r)
  sets <- unique(set_id); test_sets <- sample(sets, round(TEST_FRAC * length(sets)))
  te <- which(set_id %in% test_sets); tr <- setdiff(seq_along(y), te)   # split by matched set
  tt <- system.time(cv <- fit_tsla(tr))[3]
  X2te <- X2[te, ]; rmid <- cv$TSLA.fit$rmid                             # drop all-zero training columns
  if (length(rmid) > 0) X2te <- X2te[, -rmid, drop = FALSE]
  p_tsla <- as.vector(predict_cvTSLA(cv, X1[te, , drop = FALSE], X2te, type = "response"))
  res <- rbind(TSLA  = metrics(y[te], p_tsla),
               Enet  = metrics(y[te], fit_enet(X2.org, tr, te)),
               Enet2 = metrics(y[te], fit_enet(X3, tr, te)))
  data.frame(rep = r, method = rownames(res), res, tsla_seconds = round(tt), n_test = length(te),
             cases_test = sum(y[te]), lambda.min = cv$lambda.min, alpha.min = cv$alpha.min, row.names = NULL)
}

t0 <- Sys.time()
cores <- if (.Platform$OS.type == "windows") 1 else N_CORES
jobs <- c(as.list(seq_len(N_REPEATS)), list("full"))   # last job: fit on ALL data for interpretation (04)
out <- mclapply(jobs, function(j) {
  if (identical(j, "full")) { set.seed(SEED); fit_tsla(seq_along(y)) } else one_repeat(j)
}, mc.cores = cores)
errs <- sapply(out, inherits, "try-error"); if (any(errs)) stop(paste(out[errs], collapse = "\n"))

res <- do.call(rbind, out[seq_len(N_REPEATS)])
cvfit_full <- out[[length(out)]]
write.csv(res, file.path(OUT_DIR, "test_metrics_by_repeat.csv"), row.names = FALSE)
summ <- aggregate(cbind(AUC, AUPRC, sens5, ppv5, sens10, ppv10) ~ method, data = res, FUN = mean)
write.csv(summ, file.path(OUT_DIR, "test_metrics_summary.csv"), row.names = FALSE)
saveRDS(list(cvfit = cvfit_full, X2 = X2, tree.expand = tree.expand), file.path(OUT_DIR, "tsla_full_fit.rds"))
print(res, digits = 3)
cat("\nMean over", N_REPEATS, "repeats (prevalence in test ~", round(mean(y), 3), "= AUPRC of random guessing):\n")
print(summ, digits = 3)
cat("Total runtime:", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min\n")
