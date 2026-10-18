# Card & Krueger (1994) Minimum Wage Replication Project

## Project Overview

This project replicates the classic difference-in-differences study by Card and Krueger (1994) on the effects of the New Jersey minimum-wage increase on employment and wages in fast-food restaurants. Using fast-food restaurant survey data from New Jersey (the treatment group) and Pennsylvania (the control group), the project reconstructs the data-cleaning process, descriptive statistics, employment and wage regressions, robustness analyses, and related figures.

In addition to the paper's core results, the project includes an independent extension that studies heterogeneity by restaurant ownership. It distinguishes company-owned restaurants from franchised restaurants, compares employment and starting-wage changes across the two ownership groups, and estimates a heterogeneity DID model with the triple interaction `treat × post × co_owned`.

## Directory Structure

```text
ECON6067/
├── 00_raw_data/   Raw data files and data dictionaries; source files are not modified
├── 01_code/       Stata do-files, including the master script and analysis scripts
├── 02_temp/       Cleaned analytical data and intermediate files
├── 03_output/     Tables, figures, validation files, and execution logs
└── paper.md       Markdown version of the paper used for the replication
```

Main code files:

- `0_master.do`: Master script that calls all replication steps in sequence.
- `1_import_clean.do`: Imports and cleans the raw data and creates `02_temp/ck1994_clean.dta`.
- `1_table1.do`: Produces Table 1 basic descriptive statistics.
- `2_descriptive.do`: Produces Table 2 descriptive statistics.
- `3_table3.do`: Produces Table 3 employment results.
- `4_table4.do`: Produces Table 4 baseline employment regressions.
- `5_table5.do`: Produces Table 5 robustness results.
- `6_table6.do`: Produces Table 6 results for other outcomes.
- `7_table7.do`: Produces Table 7 wage and price results.
- `9_figure1.do`: Produces the starting-wage distribution figure.
- `10_extension_heterogeneity.do`: Performs the company-owned versus franchised restaurant heterogeneity analysis.

The external state-level data required for Table 8 are unavailable. Table 8 has therefore been removed from the one-click workflow in `0_master.do` and is not part of the current replication sequence.

## Replication Procedure

### 1. Prepare the environment

Open the project in Stata 18. Some regression scripts may require external Stata commands, such as `reghdfe`, `estout`, or `esttab`. If Stata reports that a command is not installed, connect to the internet and install the relevant package, for example:

```stata
ssc install reghdfe
ssc install estout
```

If the commands are already installed, no further installation is needed.

### 2. Set the project path

Open:

```text
01_code/0_master.do
```

Check and modify the project root according to the local machine:

```stata
global root "C:/Users/XUAN/Desktop/ECON6067"
```

`global root` must point to the project directory containing `00_raw_data`, `01_code`, `02_temp`, and `03_output`. The remaining paths are set automatically by the master script:

```stata
global raw    "$root/00_raw_data"
global code   "$root/01_code"
global temp   "$root/02_temp"
global output "$root/03_output"
```

### 3. Run the complete replication

Run the following command directly in Stata:

```stata
do "C:/Users/XUAN/Desktop/ECON6067/01_code/0_master.do"
```

Alternatively, set the working directory to the project root and run:

```stata
do "01_code/0_master.do"
```

The master script executes the following steps:

1. Clean the raw data and create the analytical dataset.
2. Produce Table 1 and Table 2.
3. Produce Figure 1.
4. Produce Tables 3 through 7.
5. Run the ownership heterogeneity extension for company-owned and franchised restaurants.

## Output Files

All results are saved under `03_output/` by default:

```text
03_output/
├── tables/       Stata datasets, CSV files, and RTF tables
├── figure/       Figure 1 PNG, PDF, GPH, frequency data, and log
├── logs/         Stata logs from the master script and individual do-files
└── checks/       Sample-size checks, comparison files, and validation results
```

Main outputs include:

- `tables/table1_summary.*`: Table 1 descriptive statistics.
- `tables/table2_descriptive.*`: Table 2 descriptive statistics.
- `tables/table3_employment.*`: Table 3 employment results.
- `tables/table4_regressions.*`: Table 4 baseline regressions and related model files.
- `tables/table5_robustness.*`: Table 5 robustness results.
- `tables/table6_other_outcomes.*`: Table 6 results for other outcomes.
- `tables/table7_prices.*`: Table 7 wage and price results.
- `tables/extension_heterogeneity_summary.*`: FTE and starting-wage descriptive statistics by ownership group, state, and survey wave.
- `tables/extension_heterogeneity_did.*`: Ownership heterogeneity DID regression results.
- `figure/figure1.*`: Figure 1 and its associated data files.
- `logs/0_master_cleaning.log`: Master-script execution log.
- `checks/sample_counts.csv`: Key sample-size validation results.

The `.*` notation indicates that the same result may be available in multiple formats, including `.dta`, `.csv`, and `.rtf`.

## Data and Sample Notes

- Raw data are stored in `00_raw_data/`; the source files are not overwritten or modified during execution.
- The cleaned analytical dataset is saved as `02_temp/ck1994_clean.dta`.
- New Jersey is the treatment group, and Pennsylvania is the control group.
- FTE is constructed as full-time workers plus managers plus one-half of part-time workers.
- For second-wave restaurants that permanently closed, FTE is set to zero. Restaurants with temporary closures, refusals, or other unresolved employment statuses remain missing where appropriate.
- The main employment regression sample is created by the cleaning script and used by the regression scripts.

## Important Notes

- If Stata reports an `r(608)` file-in-use error, the target log, data, or output file is usually still open in Stata or another application. Close the relevant file and rerun the script later. If necessary, close the active Stata log before rerunning.
- Confirm that `global root` points to the correct project directory before running the master script. Otherwise, downstream scripts may not find the raw data or output folders.
- Installing external commands requires an internet connection. Without internet access, scripts that depend on unavailable external commands may fail; results produced by scripts using built-in Stata commands can still be inspected separately.
- Rerunning the master script may overwrite existing output files so that the results remain synchronized with the current data and code.
- Table 8 is outside the current master workflow because the state-level external data required for that part of the paper are unavailable.
