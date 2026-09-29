# 01_download.R -- download CMS DE-SynPUF files (+ ICD-9 descriptions) and unzip them.
source("00_config.R")
options(timeout = 3600)   # large files; default 60 s timeout is too short
# cms.gov sometimes answers 403 Forbidden to R's default user agent; identify as a browser
options(HTTPUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36")

base <- "https://www.cms.gov/research-statistics-data-and-systems/downloadable-public-use-files/synpufs/downloads/"
urls_for_sample <- function(s) {
  u <- c(
    paste0(base, "de1_0_2008_beneficiary_summary_file_sample_", s, ".zip"),
    paste0(base, "de1_0_2009_beneficiary_summary_file_sample_", s, ".zip"),
    paste0(base, "de1_0_2010_beneficiary_summary_file_sample_", s, ".zip"),
    paste0(base, "de1_0_2008_to_2010_inpatient_claims_sample_", s, ".zip"),
    paste0(base, "de1_0_2008_to_2010_outpatient_claims_sample_", s, ".zip"))
  # CMS quirk (verified 2026-09-28): the Sample 1 page mis-links the 2010 beneficiary file;
  # the working Sample 1 2010 URL is:
  if (s == 1) u[3] <- "https://www.cms.gov/sites/default/files/2020-09/DE1_0_2010_Beneficiary_Summary_File_Sample_1.zip"
  if (INCLUDE_CARRIER) u <- c(u,
    paste0("https://downloads.cms.gov/files/DE1_0_2008_to_2010_Carrier_Claims_Sample_", s, "A.zip"),
    paste0("https://downloads.cms.gov/files/DE1_0_2008_to_2010_Carrier_Claims_Sample_", s, "B.zip"))
  u
}
# NOTE: URLs verified for sample 1 (and 2). For some other samples CMS uses a different folder;
# if a download 404s, open the sample's page (linked from the DE-SynPUF hub page) and copy the link.

urls <- c(unlist(lapply(SAMPLES, urls_for_sample)),
          "https://www.cms.gov/medicare/coding/icd9providerdiagnosticcodes/downloads/icd-9-cm-v32-master-descriptions.zip")

for (u in urls) {
  dest <- file.path(DATA_DIR, basename(u))
  if (file.exists(dest) && file.size(dest) < 1000) file.remove(dest)  # drop empty/failed downloads
  if (!file.exists(dest)) {
    message("Downloading ", u)
    download.file(u, dest, mode = "wb")    # mode="wb" matters on Windows for zip files
  }
  unzip(dest, exdir = DATA_DIR, overwrite = TRUE)
}
# sanity check: each sample's CSVs must carry the right sample number in their names
print(list.files(DATA_DIR, pattern = "\\.(csv|txt)$"))
