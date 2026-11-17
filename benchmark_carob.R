# =============================================================================
# Benchmarking CIP datasets standardised for Carob
# Author: Maryam Yahya Mohamed (CIP )
# Date:   November 2026
#
# What this script does:
#   1. Reads the standardised Carob outputs (CSV) of the datasets in the report
#   2. Coverage scorecard: records, countries, crops, years, sites
#   3. Georeferencing check: are site points inside the right country?
#      and do sites with the same name have the same coordinates?
#   4. Yield plausibility: flags suspicious values and compares dataset
#      median yields with FAOSTAT national yields
#   Results are written to the folder "output/"
# =============================================================================

## ---- 0. Settings -----------------------------------------------------------
# Folder that contains the standardised Carob CSV files
# (the output of carobiner::write_files() for each dataset)
carob_dir <- "path/to/carob/data/clean"     # <-- change this
out_dir   <- "output"
dir.create(out_dir, showWarnings = FALSE)

# Packages: terra and geodata (install once with install.packages())
library(terra)
library(geodata)

## ---- 1. Datasets included (41 active in Carob, see report Table 1) --------
ids <- c("P3_PN2RGR","P3_HJLUJZ","AURP2P","P3_IC6ZEY","D9AOAZ","FOZT2L",
  "GKZ7EH","N7ERPI","QLAM5E","NDW1KB","P3_JJJQV0","J9NLVP","P3_9VMENB",
  "WQMMSN","BW8LWJ","B7HWWH","P3_SKYDRT","P3_P78GMU","P3_KZWGT8","CQUBLX",
  "P3_2WCUAE","P3_XVRHST","P3_EKOYZ1","E1GOGT","2D2NAV","FO7KPO","5TQSRM",
  "BJECYK","G3JK72","HDAREL","H8E8KL","P3_RVCHKV","FF5CZT","F6ZZJH",
  "ZTPO9T","RKTBNX","P3_QXIM59","P3_RWIMFO","P3_QJ10B7","MXKUIK","FBZ6JS")

## ---- 2. Read the files ------------------------------------------------------
# find the main data file of each dataset (not _meta, _long or _wth files)
ff <- list.files(carob_dir, pattern = "^doi_10.21223_.*\\.csv$",
                 recursive = TRUE, full.names = TRUE)
ff <- ff[!grepl("_meta|_long|_wth", ff)]
fid <- sub("doi_10.21223_", "", sub("\\.csv$", "", basename(ff)))
ff <- ff[fid %in% ids]
fid <- fid[fid %in% ids]

# if a dataset has more than one file, keep the newest one
o <- order(fid, -as.numeric(file.mtime(ff)))
ff <- ff[o]
fid <- fid[o]
keep <- !duplicated(fid)
ff <- ff[keep]
fid <- fid[keep]

cat("Datasets found:", length(fid), "of", length(ids), "\n")
if (length(setdiff(ids, fid)) > 0) cat("Missing:", setdiff(ids, fid), "\n")

data <- lapply(ff, read.csv)
names(data) <- fid

## ---- 3. Coverage scorecard --------------------------------------------------
num <- function(x) suppressWarnings(as.numeric(x))

coverage <- do.call(rbind, lapply(fid, function(i) {
  d <- data[[i]]
  y <- if (is.null(d$yield)) numeric(0) else num(d$yield)
  yr <- suppressWarnings(as.integer(substr(d$planting_date, 1, 4)))
  data.frame(
    dataset    = i,
    records    = nrow(d),
    variables  = ncol(d),
    country    = paste(unique(d$country), collapse = ";"),
    crop       = paste(unique(d$crop), collapse = ";"),
    sites      = nrow(unique(d[, c("longitude", "latitude")])),
    first_year = if (all(is.na(yr))) NA else min(yr, na.rm = TRUE),
    last_year  = if (all(is.na(yr))) NA else max(yr, na.rm = TRUE),
    yield_records = sum(!is.na(y))
  )
}))
write.csv(coverage, file.path(out_dir, "1_coverage_scorecard.csv"), row.names = FALSE)
cat("Total records:", sum(coverage$records),
    "| with yield:", sum(coverage$yield_records), "\n")

## ---- 4. Georeferencing check -----------------------------------------------
# 4a. unique site points of all datasets
sites <- do.call(rbind, lapply(fid, function(i) {
  d <- data[[i]]
  if (is.null(d$location)) d$location <- NA
  s <- unique(d[, c("country", "location", "longitude", "latitude")])
  s$dataset <- i
  s
}))
sites <- sites[!is.na(sites$longitude) & !is.na(sites$latitude), ]

# 4b. is each point inside its country? (GADM 4.1 country borders)
iso <- c(Peru = "PER", Kenya = "KEN", Tanzania = "TZA", Uganda = "UGA",
         Ethiopia = "ETH", China = "CHN")
sites$inside_country <- NA
for (cn in unique(sites$country)) {
  if (is.na(iso[cn])) next
  border <- geodata::gadm(iso[cn], level = 0, path = tempdir(), resolution = 2)
  k <- sites$country == cn
  pts <- terra::vect(sites[k, ], geom = c("longitude", "latitude"), crs = "+proj=longlat")
  sites$inside_country[k] <- !is.na(terra::extract(border, pts)[, 2])
}
cat("Site points:", nrow(sites), "| inside country:", sum(sites$inside_country, na.rm = TRUE), "\n")
write.csv(sites, file.path(out_dir, "2_site_points.csv"), row.names = FALSE)

# 4c. sites with the same name but different coordinates
sites$name <- tolower(trimws(sites$location))
same_name <- do.call(rbind, lapply(split(sites, sites$name), function(x) {
  xy <- unique(round(x[, c("longitude", "latitude")], 4))
  if (nrow(xy) < 2) return(NULL)
  max_km <- max(terra::distance(as.matrix(xy), lonlat = TRUE)) / 1000
  data.frame(site = x$location[1], n_coordinates = nrow(xy),
             max_distance_km = round(max_km, 1),
             datasets = paste(unique(x$dataset), collapse = ", "))
}))
same_name <- same_name[order(-same_name$max_distance_km), ]
write.csv(same_name, file.path(out_dir, "3_same_site_different_coordinates.csv"), row.names = FALSE)

## ---- 5. Yield plausibility --------------------------------------------------
# 5a. all yield records (fresh yield, kg/ha)
yld <- do.call(rbind, lapply(fid, function(i) {
  d <- data[[i]]
  if (is.null(d$yield)) return(NULL)
  data.frame(dataset = i, country = d$country, crop = d$crop,
             year = suppressWarnings(as.integer(substr(d$planting_date, 1, 4))),
             yield = num(d$yield))
}))
yld <- yld[!is.na(yld$yield), ]

# 5b. flag suspicious values
yld$flag <- "ok"
yld$flag[yld$yield < 1000]   <- "below 1 t/ha"
yld$flag[yld$yield > 100000] <- "above 100 t/ha"
yld$flag[yld$yield <= 0]     <- "zero or negative"
flags <- as.data.frame.matrix(table(yld$dataset, yld$flag))
write.csv(flags, file.path(out_dir, "4_yield_flags_by_dataset.csv"))
cat("Plausible yield records:", round(100 * mean(yld$flag == "ok"), 1), "%\n")

# 5c. FAOSTAT national yields (kg/ha), downloaded from the FAOSTAT bulk files
fao_file <- function(region) {
  z <- file.path(tempdir(), paste0(region, ".zip"))
  if (!file.exists(z)) download.file(paste0(
    "https://bulks-faostat.fao.org/production/Production_Crops_Livestock_E_",
    region, ".zip"), z, mode = "wb")
  read.csv(unz(z, paste0("Production_Crops_Livestock_E_", region, "_NOFLAG.csv")),
           check.names = FALSE)
}
fao <- rbind(fao_file("Americas"), fao_file("Africa"))
fao <- fao[fao$Item %in% c("Potatoes", "Sweet potatoes") & fao$Element == "Yield", ]
ycols <- grep("^Y[0-9]{4}$", names(fao), value = TRUE)
fao <- reshape(fao[, c("Area", "Item", ycols)], varying = ycols, v.names = "fao_yield",
               timevar = "year", times = as.integer(sub("Y", "", ycols)), direction = "long")
fao$country <- sub("United Republic of Tanzania", "Tanzania", fao$Area)
fao$crop <- ifelse(fao$Item == "Potatoes", "potato", "sweetpotato")
fao <- fao[, c("country", "crop", "year", "fao_yield")]

# 5d. compare dataset median yield with FAOSTAT (same country, crop, year)
med <- aggregate(yield ~ dataset + country + crop + year, data = yld, FUN = median)
cmp <- merge(med, fao, all.x = TRUE)
cmp$ratio <- round(cmp$yield / cmp$fao_yield, 2)
write.csv(cmp, file.path(out_dir, "5_yield_vs_faostat.csv"), row.names = FALSE)
cat("Median ratio trial / national yield:", median(cmp$ratio, na.rm = TRUE), "\n")

cat("\nDone. Results are in the folder:", out_dir, "\n")
