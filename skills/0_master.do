version 18
clear all
set more off
capture log close

* Card and Krueger (1994) replication master file.
* Execute the analysis in the requested order: clean data, descriptive statistics,
* Figure 1, core replication tables, and the independent extension.

* Set the project root explicitly at the top-level entry point. This is the
* only machine-specific line; every downstream data reference uses these macros.
global root   "C:/Users/XUAN/Desktop/ECON6067"
global raw    "$root/00_raw_data"
global code   "$root/01_code"
global temp   "$root/02_temp"
global output "$root/03_output"

capture mkdir "$temp"
capture mkdir "$output"
capture mkdir "$output/logs"
capture mkdir "$output/checks"
capture mkdir "$output/tables"
capture mkdir "$output/figures"

log using "$output/logs/0_master_cleaning.log", replace text

di as text "Project root: $root"

* 1. Clean the raw survey and save the analytic copy.
do "$code/1_import_clean.do"

* 2. Descriptive statistics: Table 1 and Table 2.
do "$code/1_table1.do"
do "$code/2_descriptive.do"

* 3. Wage-distribution figure.
do "$code/9_figure1.do"

* 4. Core replication regressions: Tables 3 through 7.
do "$code/3_table3.do"
do "$code/4_table4.do"
do "$code/5_table5.do"
do "$code/6_table6.do"
do "$code/7_table7.do"

* 5. Independent ownership heterogeneity extension.
do "$code/10_extension_heterogeneity.do"

capture log close
