# 04_inspect.R -- look inside the full-data TSLA fit: object structure, selected/aggregated ICD-9 features.
source("00_config.R")
suppressPackageStartupMessages(library(TSLA))
d  <- readRDS(file.path(OUT_DIR, "analysis_data.rds"))
ff <- readRDS(file.path(OUT_DIR, "tsla_full_fit.rds"))
cv <- ff$cvfit

cat("== What cv.TSLA returns ==\n"); str(cv, max.level = 1, give.attr = FALSE)
cat("\nChosen tuning: lambda.min =", signif(cv$lambda.min, 3), " alpha.min =", cv$alpha.min,
    " (alpha = weight on the generalized-lasso/aggregation part; 1 - alpha on the group-lasso/selection part)\n")
cat("CV AUC grid (rows = lambda, cols = alpha):\n"); print(round(cv$cvm, 3))

# aggregated features at the chosen tuning values (package function)
agg <- getaggr(cv$TSLA.fit, ff$X2, as.matrix(d$X2.org), cv$lambda.min.index, cv$alpha.min.index)
if (is.null(agg) || ncol(agg) == 0) { cat("\nNo features selected at lambda.min (model = intercept + covariates).\n"); quit(save = "no") }
agg <- as.matrix(agg)

# map each aggregated column back to ICD-9 codes: it equals the OR of all leaves under some tree node
lab <- d$labels; X <- as.matrix(d$X2.org)
nodes <- rbind(
  data.frame(level = "leaf (full code)", node = lab$leaf),
  data.frame(level = "4-digit", node = unique(lab$d4)),
  data.frame(level = "3-digit", node = unique(lab$d3)),
  data.frame(level = "section", node = unique(lab$section)),
  data.frame(level = "chapter", node = "290-319"))
members <- function(level, node) switch(level,
  "leaf (full code)" = lab$leaf == node, "4-digit" = lab$d4 == node, "3-digit" = lab$d3 == node,
  "section" = lab$section == node, "chapter" = rep(TRUE, nrow(lab)))

# ICD-9 long descriptions (CMS v32, free) if 01_download.R fetched them
desc_file <- file.path(DATA_DIR, "CMS32_DESC_LONG_DX.txt")
desc <- if (file.exists(desc_file)) {
  l <- readLines(desc_file, encoding = "latin1", warn = FALSE)
  setNames(trimws(sub("^\\S+\\s+", "", l)), sub("\\s.*$", "", l)) } else character(0)

y <- d$y; rows <- list()
for (j in seq_len(ncol(agg))) {
  v <- agg[, j]
  # An aggregated feature = OR of the leaves under one tree node, EXCEPT leaves under descendant
  # nodes that TSLA split off as separate features. So: for each node (most specific first), take its
  # leaves whose patients are a subset of v; accept the node if the OR of those leaves reproduces v exactly.
  lvl <- "?"; nd <- "(no exact match)"; present <- character(0); n_under <- NA
  for (i in seq_len(nrow(nodes))) {   # nodes are ordered most specific (leaf) -> chapter
    m <- which(members(nodes$level[i], nodes$node[i]))
    sub <- m[colSums(X[, m, drop = FALSE]) > 0 & colSums(X[, m, drop = FALSE] * (1 - v)) == 0]
    if (length(sub) && all(as.integer(rowSums(X[, sub, drop = FALSE]) > 0) == v)) {
      lvl <- nodes$level[i]; nd <- nodes$node[i]; present <- lab$leaf[sub]; n_under <- length(m); break }
  }
  rows[[j]] <- data.frame(feature = j, level = lvl, node = nd, n_leaf_codes = length(present), leaves_under_node = n_under,
    leaf_codes = paste(present, collapse = " "),
    description = if (length(present) <= 3) paste(ifelse(is.na(desc[present]), "", desc[present]), collapse = " | ") else
                  paste0(ifelse(is.na(desc[present[1]]), "", desc[present[1]]), " | ... (", length(present), " codes)"),
    prev_cases = round(mean(v[y == 1]), 3), prev_controls = round(mean(v[y == 0]), 3))
}
tab <- do.call(rbind, rows)
# post-hoc (unpenalized) logistic refit on the aggregated features, for a rough direction/size of effect
Z <- data.frame(y = y, d$X1, agg); names(Z)[-(1:3)] <- paste0("f", seq_len(ncol(agg)))
refit <- suppressWarnings(glm(y ~ ., data = Z, family = binomial))
tab$refit_OR <- round(exp(coef(refit)[paste0("f", seq_len(ncol(agg)))]), 2)
write.csv(tab, file.path(OUT_DIR, "selected_aggregated_features.csv"), row.names = FALSE)
cat("\n== Selected / aggregated features at lambda.min (", ncol(agg), ") ==\n")
print(tab[, c("feature", "level", "node", "n_leaf_codes", "leaves_under_node", "prev_cases", "prev_controls", "refit_OR")], row.names = FALSE)
cat("\nFull table with codes + descriptions:", file.path(OUT_DIR, "selected_aggregated_features.csv"), "\n")
