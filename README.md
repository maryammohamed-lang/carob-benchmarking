# Benchmarking CIP datasets in Carob

Code for the report *"Standardising and Benchmarking Agronomic Research Data
for the Carob Open-Data Ecosystem"* (Maryam Yahya Mohamed and
Bester Tawona Mudereri, CIP, 2026).

## What is in this repository

| File | What it does |
|---|---|
| `benchmark_carob.R` | Runs all benchmarking checks and writes the results to `output/` |
| `output/` | Result tables used in the report |

The standardisation scripts themselves are in the Carob repository:
https://github.com/carob-data/carob (see the pull request numbers in Table 1 of the report).

## What the benchmarking checks

1. **Coverage scorecard**: records, countries, crops, years and sites per dataset
2. **Georeferencing**: are site points inside the correct country (GADM 4.1),
   and do sites with the same name have the same coordinates?
3. **Yield plausibility**: flags yields ≤ 0, below 1 t/ha or above 100 t/ha,
   and compares dataset median yields with FAOSTAT national yields

## How to run

1. Install R (≥ 4.3) and the packages:
   ```r
   install.packages(c("terra", "geodata"))
   ```
2. Produce the standardised Carob CSV files by running the Carob scripts
   of the datasets (see https://github.com/carob-data/carob).
3. Open `benchmark_carob.R` and set `carob_dir` to the folder with these CSV files.
4. Run the script:
   ```r
   source("benchmark_carob.R")
   ```
   An internet connection is needed to download GADM borders and FAOSTAT data.

## Output files

| File | Content |
|---|---|
| `1_coverage_scorecard.csv` | Records, variables, countries, crops, sites and years per dataset |
| `2_site_points.csv` | All site coordinates and whether they are inside the country |
| `3_same_site_different_coordinates.csv` | Sites with the same name but different coordinates |
| `4_yield_flags_by_dataset.csv` | Number of suspicious yield values per dataset |
| `5_yield_vs_faostat.csv` | Dataset median yield compared with FAOSTAT national yield |

## Data sources

- CIP Dataverse: https://data.cipotato.org
- FAOSTAT: https://www.fao.org/faostat
- GADM 4.1: https://gadm.org

## Acknowledgements

This work was carried out at the International Potato Center (CIP) and was
co-funded by AIMS Rwanda through its Work-Integrated Learning (WIL) programme.
