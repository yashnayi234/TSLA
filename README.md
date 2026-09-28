# tsla-desynpuf-reproduction

Reproducing **TSLA** (tree-guided rare feature selection and logic aggregation; Chen, Aseltine, Wang & Chen, *JASA* 2024) and applying it to the public, synthetic CMS DE-SynPUF Medicare claims file.

> **Status: in progress.** No results are reported yet. Result tables below are placeholders until the runs are complete.

## Overview

TSLA handles regression with many rare binary features that sit on a known hierarchy, such as ICD diagnosis codes. It merges sibling features with a logical "or" when that fits the data, and keeps them separate when their effects differ. This is posed as a convex, linearly constrained regularized regression and solved with a smoothing proximal gradient algorithm.

This repository has two parts:

- **Part A: simulation reproduction.** Re-run the paper's simulation studies (regression Cases 1–3; classification Cases 1 and 4) with the authors' R package and compare against the published tables.
- **Part B: application to CMS DE-SynPUF.** Build ICD-9-CM diagnosis features from synthetic Medicare claims, fit TSLA to predict **[YASH TO FILL: outcome and label definition]**, and compare against lasso and XGBoost.

Part B is **not** a reproduction of the paper's real-data results. The original suicide-risk study used non-public EHR data (Kansas Health Information Network) and ICD-10-CM codes.

## Original work

Chen, J., Aseltine, R. H., Wang, F., & Chen, K. (2024). Tree-guided rare feature selection and logic aggregation with electronic health records data. *Journal of the American Statistical Association*, 119(547), 1765–1777. https://doi.org/10.1080/01621459.2024.2326621. Preprint: https://arxiv.org/abs/2206.09107

Software: `TSLA`: Tree-Guided Rare Feature Selection and Logic Aggregation. R package on CRAN (maintainer: Jianmin Chen). https://cran.r-project.org/package=TSLA

```bibtex
@article{chen2024tsla,
  title   = {Tree-Guided Rare Feature Selection and Logic Aggregation with Electronic Health Records Data},
  author  = {Chen, Jianmin and Aseltine, Robert H. and Wang, Fei and Chen, Kun},
  journal = {Journal of the American Statistical Association},
  volume  = {119},
  number  = {547},
  pages   = {1765--1777},
  year    = {2024},
  doi     = {10.1080/01621459.2024.2326621}
}
```

This repository is an independent reproduction. It is not affiliated with or endorsed by the original authors.

## Data

**Source:** CMS 2008–2010 Data Entrepreneurs' Synthetic Public Use File (DE-SynPUF), published by the Centers for Medicare & Medicaid Services:
https://www.cms.gov/data-research/statistics-trends-and-reports/medicare-claims-synthetic-public-use-files/cms-2008-2010-data-entrepreneurs-synthetic-public-use-file-de-synpuf

- **The data are not redistributed here.** `01_download` fetches the files directly from CMS. Use of the data is subject to the terms on the CMS page and in the DE 1.0 Data Users Document.
- CMS releases the file in 20 samples, each roughly a 0.25% sample. This project uses **[YASH TO FILL: which samples]**.
- File types used: **[YASH TO FILL: e.g., Beneficiary Summary, Inpatient, Outpatient, Carrier claims]**.

**Synthetic-data caveat, in CMS's words:** "Although the DE-SynPUF has very limited inferential research value to draw conclusions about Medicare beneficiaries due to the synthetic processes used to create the file, the Medicare DE-SynPUF does increase access to a realistic Medicare claims data file…" Nothing in this repository should be read as a finding about real patients or real risk factors.

## How to run

**Requirements**

- R **[YASH TO FILL: version, e.g., 4.x.y]**
- Packages: `TSLA` **[YASH TO FILL: version]**, plus **[YASH TO FILL: e.g., glmnet, xgboost, data.table, pROC, PRROC]**
- Disk space: **[YASH TO FILL]**; memory: **[YASH TO FILL]**

**Install**

```r
install.packages("TSLA")
# install.packages(c(...))  # [YASH TO FILL: other packages, e.g., glmnet, xgboost]
```

**Run in order** (from the repository root):

```bash
Rscript 01_download.R     # fetch DE-SynPUF samples from CMS into data/raw/ (not committed)
Rscript 02_preprocess.R   # build beneficiary/claim-level outcome, ICD-9 binary features, and the ICD tree
Rscript 03_fit.R          # fit TSLA, lasso, XGBoost with cross-validation; write results/
Rscript 04_inspect.R      # tables, selected/aggregated ICD-9 codes, figures
```

See `GUIDE.md` for a step-by-step walkthrough, including the Part A simulation runs. **[YASH TO FILL: confirm file names and extensions, and where the Part A simulation script lives.]**

## Results

### Part A: simulation reproduction

Original values are from arXiv:2206.09107v2 (Tables 1 and 2), reported as mean (SE) over 100 replications.

Regression, test MSE:

| Case | Method | Original | This repo |
|---|---|---|---|
| 1 | TSLA | 10.360 (0.145) | [YASH TO FILL] |
| 1 | RFS-Sum | 10.635 (0.143) | [YASH TO FILL] |
| 1 | Enet | 10.760 (0.148) | [YASH TO FILL] |
| 2 | TSLA | 2.676 (0.037) | [YASH TO FILL] |
| 2 | RFS-Sum | 2.965 (0.037) | [YASH TO FILL] |
| 2 | Enet | 3.010 (0.037) | [YASH TO FILL] |
| 3 | TSLA | 2.981 (0.038) | [YASH TO FILL] |
| 3 | RFS-Sum | 3.192 (0.038) | [YASH TO FILL] |
| 3 | Enet | 3.208 (0.042) | [YASH TO FILL] |

Classification, test AUC:

| Case | Method | Original | This repo |
|---|---|---|---|
| 1 | TSLA | 0.904 (0.002) | [YASH TO FILL] |
| 1 | RFS-Sum | 0.887 (0.003) | [YASH TO FILL] |
| 1 | Enet | 0.870 (0.003) | [YASH TO FILL] |
| 4 | TSLA | 0.893 (0.003) | [YASH TO FILL] |
| 4 | RFS-Sum | 0.881 (0.003) | [YASH TO FILL] |
| 4 | Enet | 0.795 (0.007) | [YASH TO FILL] |

(Add ORE, Enet2 and the other metrics if they were run. If RFS-Sum was not run, write "not run".)

### Part B: DE-SynPUF

| Method | AUC | AUPRC | Sensitivity @ top 10% | PPV @ top 10% | # features (aggregated) |
|---|---|---|---|---|---|
| Lasso (full-digit codes) | [YASH TO FILL] | [YASH TO FILL] | [YASH TO FILL] | [YASH TO FILL] | [YASH TO FILL] |
| Lasso (3-digit collapsed) | [YASH TO FILL] | [YASH TO FILL] | [YASH TO FILL] | [YASH TO FILL] | [YASH TO FILL] |
| XGBoost | [YASH TO FILL] | [YASH TO FILL] | [YASH TO FILL] | [YASH TO FILL] | [YASH TO FILL] |
| TSLA | [YASH TO FILL] | [YASH TO FILL] | [YASH TO FILL] | [YASH TO FILL] | [YASH TO FILL] |

Mean (SE) over **[YASH TO FILL: k]** folds, split by beneficiary. The aggregation-pattern figure is in `figures/` **[YASH TO FILL]**.

## Deviations from the original paper

1. **ICD-9-CM instead of ICD-10-CM.** DE-SynPUF covers 2008–2010, before the US moved to ICD-10-CM, so the feature tree is the ICD-9-CM hierarchy (**[YASH TO FILL: source of hierarchy and code subset]**). The paper used ICD-10-CM F-chapter codes.
2. **Different population and outcome.** The data are Medicare beneficiaries (a largely 65+ population), not the paper's 18–64 EHR cohort, and the outcome is **[YASH TO FILL]**, not suicide attempt. The paper's nested case-control design is not replicated. **[YASH TO FILL: design used.]**
3. **Synthetic data.** DE-SynPUF is generated with disclosure-protection processes. CMS states that it "has very limited inferential research value to draw conclusions about Medicare beneficiaries." Code–outcome relationships may not be realistic.
4. **Implementation details.** **[YASH TO FILL: tuning grids, number of replications, thresholding rule (paper Eq. 13) used or not, any package defaults changed.]**

## Repository layout

```
tsla-desynpuf-reproduction/
├── README.md
├── GUIDE.md            # step-by-step walkthrough
├── 01_download.R       # fetch DE-SynPUF from CMS (data not committed)
├── 02_preprocess.R     # outcome, ICD-9 features, ICD tree
├── 03_fit.R            # TSLA / lasso / XGBoost with CV
├── 04_inspect.R        # tables, selected/aggregated codes, figures
├── data/               # raw/ and processed/ (git-ignored)
├── results/            # small CSV result tables
├── figures/            # aggregation-pattern plots
└── sessionInfo.txt     # R session info from the final run
```

**[YASH TO FILL: adjust to the actual folder contents.]**

## Reproducibility

- Seeds: **[YASH TO FILL: `set.seed(...)` values and where they are set]**
- Software versions: `sessionInfo()` output from the final run is saved to `sessionInfo.txt`.
- Hardware and runtime: **[YASH TO FILL]**
- All reported numbers are regenerated by running the four scripts in order. Nothing in `results/` is edited by hand.

## License

Code: **[YASH TO FILL: e.g., MIT]**. See `LICENSE`. Data are not included; see the CMS terms above. The TSLA method and package belong to their authors; cite the original paper if you use this work.

## Contact

Yash Nayi · https://yashnayi09.netlify.app · https://github.com/yashnayi234 · https://www.linkedin.com/in/yashnayi
