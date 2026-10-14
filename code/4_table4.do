version 18
clear all
set more off
capture log close

* Card and Krueger (1994), Table 4: reduced-form employment-change models.
* All regressions use the same verified 357-store sample. Permanent closures
* remain in the sample with wave-2 FTE=0 and no imputed second-wave wage.
if "$root" == "" {
    display as error "Run 0_master.do first so project paths are defined."
    exit 198
}
capture mkdir "$output/tables"
capture mkdir "$output/checks"
log using "$output/logs/4_table4.log", replace text
use "$temp/ck1994_clean.dta", clear
assert _N == 410
count if sample_reg == 1
assert r(N) == 357
assert !missing(d_fte, nj, gap, chain_code, company_owned) if sample_reg == 1
assert !missing(north_nj, central_nj, south_nj, pa_philly, pa_easton) if sample_reg == 1

* Burger King is the chain reference category. North NJ is the region reference
* category, so the model includes two NJ and both PA region indicators.
* A constant and the omitted categories prevent perfect collinearity.
local ownership_chain "ib1.chain_code company_owned"
local regions "central_nj south_nj pa_philly pa_easton"

* Conventional OLS standard errors reproduce the original table. Robust or
* state-clustered errors are not substituted for the published calculation.
tempname output
 tempfile results
postfile `output' byte model str16 exposure double coefficient se ///
    int N double rmse controls_p r_squared ///
    byte chain_ownership region_controls using `results', replace

forvalues m = 1/5 {
    if `m' == 1 {
        local treatment nj
        local controls ""
        local own = 0
        local reg = 0
    }
    if `m' == 2 {
        local treatment nj
        local controls "`ownership_chain'"
        local own = 1
        local reg = 0
    }
    if `m' == 3 {
        local treatment gap
        local controls ""
        local own = 0
        local reg = 0
    }
    if `m' == 4 {
        local treatment gap
        local controls "`ownership_chain'"
        local own = 1
        local reg = 0
    }
    if `m' == 5 {
        local treatment gap
        local controls "`ownership_chain' `regions'"
        local own = 1
        local reg = 1
    }

    regress d_fte `treatment' `controls' if sample_reg == 1
    estimates store table4_m`m'
    estimates save "$output/tables/table4_model`m'.ster", replace
    assert e(N) == 357
    local coef = _b[`treatment']
    local se = _se[`treatment']
    local n = e(N)
    local rmse = e(rmse)
    local r2 = e(r2)
    local p = .
    * Row 6 tests exclusion of all included control variables jointly.
    if `own' == 1 {
        if `reg' == 0 testparm i.chain_code company_owned
        else testparm i.chain_code company_owned `regions'
        local p = r(p)
    }
    post `output' (`m') ("`treatment'") (`coef') (`se') (`n') ///
        (`rmse') (`p') (`r2') (`own') (`reg')
}
postclose `output'

* Report the dependent-variable moments to check the paper's mean=-0.237 and
* standard deviation=8.825, rather than merely matching the regression N.
summarize d_fte if sample_reg == 1
local outcome_mean = r(mean)
local outcome_sd = r(sd)

use `results', clear
label variable coefficient "Policy exposure coefficient"
label variable se "Conventional OLS standard error"
label variable N "Regression sample size"
label variable rmse "Standard error of regression"
label variable controls_p "Joint F-test p-value for all controls"
label variable r_squared "R-squared"
format coefficient se rmse %9.3f
format controls_p r_squared %9.4f
save "$output/tables/table4_regressions.dta", replace
export delimited using "$output/tables/table4_regressions.csv", replace
list, noobs abbreviate(20)

* Add published targets and numerical deviations in a separate checking file;
* retain estimates from the supplied data even if rounding differs slightly.
gen double paper_coefficient = .
gen double paper_se = .
gen double paper_rmse = .
gen double paper_controls_p = .
local paper_b "2.33 2.30 15.65 14.92 11.91"
local paper_s "1.19 1.20 6.08 6.21 7.39"
local paper_r "8.79 8.78 8.76 8.76 8.75"
forvalues m = 1/5 {
    local b : word `m' of `paper_b'
    local s : word `m' of `paper_s'
    local r : word `m' of `paper_r'
    replace paper_coefficient = `b' in `m'
    replace paper_se = `s' in `m'
    replace paper_rmse = `r' in `m'
}
replace paper_controls_p = 0.34 in 2
replace paper_controls_p = 0.44 in 4
replace paper_controls_p = 0.40 in 5
gen double coefficient_difference = coefficient - paper_coefficient
gen double se_difference = se - paper_se
gen double rmse_difference = rmse - paper_rmse
gen double controls_p_difference = controls_p - paper_controls_p
export delimited using "$output/checks/table4_comparison.csv", replace

* Write the six published rows with five model columns using built-in file
* commands, so no external Stata packages are required.
tempname rtf
file open `rtf' using "$output/tables/table4_regressions.rtf", write replace
file write `rtf' "{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\f0\fs20" _n
file write `rtf' "\b Table 4. Reduced-Form Models for Change in Employment\b0\par" _n
file write `rtf' "Variable\tab (i)\tab (ii)\tab (iii)\tab (iv)\tab (v)\par" _n
forvalues row = 1/6 {
    if `row' == 1 local title "1. New Jersey dummy"
    if `row' == 2 local title "2. Initial wage gap"
    if `row' == 3 local title "3. Chain and ownership controls"
    if `row' == 4 local title "4. Region controls"
    if `row' == 5 local title "5. Standard error of regression"
    if `row' == 6 local title "6. Joint control F-test p-value"
    file write `rtf' "`title'"
    forvalues m = 1/5 {
        local cell "--"
        if (`row' == 1 & `m' <= 2) | (`row' == 2 & `m' >= 3) {
            local b : display %6.2f coefficient[`m']
            local s : display %6.2f se[`m']
            local cell "`b' (`s')"
        }
        if `row' == 3 {
            if chain_ownership[`m'] == 1 local cell "yes"
            else local cell "no"
        }
        if `row' == 4 {
            if region_controls[`m'] == 1 local cell "yes"
            else local cell "no"
        }
        if `row' == 5 local cell : display %6.2f rmse[`m']
        if `row' == 6 & !missing(controls_p[`m']) {
            local cell : display %5.2f controls_p[`m']
        }
        file write `rtf' "\tab `cell'"
    }
    file write `rtf' "\par" _n
}
file write `rtf' "\par Notes: Conventional OLS standard errors in parentheses. All models include a constant.\par" _n
file write `rtf' "Sample: 357 stores, including permanent closures with wave-2 FTE employment set to zero.\par" _n
local mean_text : display %7.3f `outcome_mean'
local sd_text : display %7.3f `outcome_sd'
file write `rtf' "Dependent variable: wave-2 minus wave-1 FTE employment; mean `mean_text', SD `sd_text'.\par" _n
file write `rtf' "Chain reference: Burger King. Region reference: North NJ.\par" _n
file write `rtf' "GAP is zero for PA; for NJ it is max(0, (5.05 - initial wage)/initial wage).\par}" _n
file close `rtf'
log close
