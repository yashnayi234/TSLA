# tsla-desynpuf-reproduction

Reproducing **TSLA** (tree-guided rare feature selection and logic aggregation; Chen, Aseltine, Wang & Chen, *JASA* 2024) and applying it to the public, synthetic CMS DE-SynPUF Medicare claims file.

> **Status: in progress.** Part B (DE-SynPUF) has been run and its results are below. Part A (simulation reproduction) has not been run yet, and its table is still a placeholder.

## Overview

TSLA handles regression with many rare binary features that sit on a known hierarchy, such as ICD diagnosis codes. It merges sibling features with a logical "or" when that fits the data, and keeps them separate when their effects differ. This is posed as a convex, linearly constrained regularized regression and solved with a smoothing proximal gradient algorithm.

This repository has two parts:

- **Part A: simulation reproduction.** Re-run the paper's simulation studies (regression Cases 1–3; classification Cases 1 and 4) with the authors' R package and compare against the published tables.
- **Part B: application to CMS DE-SynPUF.** Build ICD-9-CM diagnosis features from synthetic Medicare claims, fit TSLA to predict self-harm (first claim with ICD-9 E950–E959) in a 1:10 nested case-control design, and compare it with elastic-net baselines on full and 3-digit codes.

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
- CMS releases the file in 20 samples, each roughly a 0.25% sample. This project uses sample 1 (set `SAMPLES` in `00_config.R` to pool more).
- File types used: Beneficiary Summary (2008, 2009, 2010), Inpatient claims, Outpatient claims, and the CMS ICD-9-CM v32 diagnosis descriptions. Carrier claims are optional and off by default.

**Synthetic-data caveat, in CMS's words:** "Although the DE-SynPUF has very limited inferential research value to draw conclusions about Medicare beneficiaries due to the synthetic processes used to create the file, the Medicare DE-SynPUF does increase access to a realistic Medicare claims data file…" Nothing in this repository should be read as a finding about real patients or real risk factors.

## How to run

**Requirements**

- R 4.x (verified with R 4.5.0)
- Packages: `TSLA` 0.1.2, plus `data.table`, `glmnet`, `pROC`, `PRROC`
- Disk space: about 300 MB for sample 1 (45 MB zipped, 220 MB unzipped); memory: 1–2 GB

**Install**

```r
install.packages(c("TSLA", "data.table", "glmnet", "pROC", "PRROC"))
```

**Run in order** (from the repository root):

```bash
Rscript 01_download.R     # fetch DE-SynPUF sample 1 + ICD-9 descriptions from CMS into data/ (not committed)
Rscript 02_preprocess.R   # cases, 1:10 matched controls, ICD-9 binary features, ICD tree -> output/analysis_data.rds
Rscript 03_fit.R          # TSLA, Enet, Enet2 over 3 train/test splits -> output/test_metrics_*.csv
Rscript 04_inspect.R      # selected/aggregated ICD-9 codes -> output/selected_aggregated_features.csv
```

Settings live in `00_config.R`. See `GUIDE.md` for a step-by-step walkthrough. The Part A simulation script is not written yet.

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

Design: 196 self-harm cases, each with 10 matched controls (2,156 records, 9.1% cases). Features are 101 prior ICD-9 mental-disorder codes (290–319) arranged in a 5-level tree (101 leaves, 56 four-digit nodes, 22 three-digit nodes, 4 sections, 1 chapter). Age and sex are unpenalized.

Mean test results over 3 random 70/30 splits by matched set (649 test records and 59 test cases per split; random guessing gives AUPRC ≈ 0.091):

| Method | AUC | AUPRC | Sens @ top 5% | PPV @ top 5% | Sens @ top 10% | PPV @ top 10% |
|---|---|---|---|---|---|---|
| TSLA | 0.576 | 0.131 | 0.085 | 0.152 | 0.158 | 0.144 |
| Enet (full codes) | 0.555 | 0.131 | 0.107 | 0.192 | 0.198 | 0.179 |
| Enet2 (3-digit codes) | 0.594 | 0.158 | 0.136 | 0.242 | 0.203 | 0.185 |

Per-split test AUC:

| Split | TSLA | Enet | Enet2 |
|---|---|---|---|
| 1 | 0.594 | 0.588 | 0.589 |
| 2 | 0.496 | 0.541 | 0.576 |
| 3 | 0.638 | 0.535 | 0.618 |

All three methods are only slightly better than chance, and the differences between them are within split-to-split noise (TSLA ranges from 0.496 to 0.638). This is expected on synthetic data. The more informative result is the aggregation pattern. The full-data TSLA fit kept 34 features. It kept many schizophrenia (295.x) and bipolar (296.6x, 296.8x) codes separate, pooled the other 30 codes under 296 into one flag (22.4% of cases vs 8.1% of controls), and pooled 290–294 and 20 of the 29 codes in 300–316. The full table is in `output/selected_aggregated_features.csv`.

## Deviations from the original paper

1. **ICD-9-CM instead of ICD-10-CM.** DE-SynPUF covers 2008–2010, before the US moved to ICD-10-CM, so the feature tree is the ICD-9-CM hierarchy built from the code strings (full code, 4-digit, 3-digit, section, chapter) for codes 290–319, not the official tabular list. The paper used ICD-10-CM F-chapter codes.
2. **Different population and outcome.** The data are Medicare beneficiaries (a largely 65+ population), not the paper's 18–64 EHR cohort, and the outcome is self-harm defined only by E950–E959, not the paper's suicide-attempt definition with extra code combinations. The paper's nested case-control design is followed: 1:10 risk-set controls matched on sex and birth year, with a claim within ±30 days of the case's index date and prior history.
3. **Synthetic data.** DE-SynPUF is generated with disclosure-protection processes. CMS states that it "has very limited inferential research value to draw conclusions about Medicare beneficiaries." Code–outcome relationships may not be realistic.
4. **Implementation details.** A small tuning grid (6 lambda values, alpha in {0, 0.5, 1}, 3-fold CV, maxit 500) and 3 train/test repeats keep the runtime to minutes. Codes seen in fewer than 5 records are dropped (the paper's 0.04% screen). RFS-Sum was not run. The paper's thresholding rule (Eq. 13) was not applied.

## Repository layout

```
tsla-desynpuf-reproduction/
├── README.md
├── GUIDE.md            # step-by-step walkthrough
├── 00_config.R         # shared settings
├── 01_download.R       # fetch DE-SynPUF from CMS (data not committed)
├── 02_preprocess.R     # outcome, ICD-9 features, ICD tree
├── 03_fit.R            # TSLA / Enet / Enet2, repeated train/test splits
├── 04_inspect.R        # selected/aggregated codes with descriptions
├── data/               # raw downloads (git-ignored)
└── output/             # analysis data, fits (.rds, git-ignored), result CSVs
```

## Reproducibility

- Seed: `SEED <- 2024` in `00_config.R`, used for control sampling, splits and CV.
- Software versions: R 4.5.0, TSLA 0.1.2. Save `sessionInfo()` to `sessionInfo.txt` after the final run.
- Runtime: about 3–7 minutes for `03_fit.R` on a laptop (7.3 min on the author's machine); the other scripts take seconds.
- All reported numbers are regenerated by running the four scripts in order. Nothing in `output/` is edited by hand.

## License

Code: **[YASH TO FILL: e.g., MIT]**. See `LICENSE`. Data are not included; see the CMS terms above. The TSLA method and package belong to their authors; cite the original paper if you use this work.

## Contact

Yash Nayi · https://yashnayi09.netlify.app · https://github.com/yashnayi234 · https://www.linkedin.com/in/yashnayi
