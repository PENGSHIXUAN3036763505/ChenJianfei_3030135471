version 18
clear all
set more off
capture log close

* Independent extension: heterogeneity by company ownership.
* The supplied cleaned file names the requested co_owned variable company_owned.
* A co_owned alias is created in memory only; no source or cleaned file is changed.
if "$root" == "" {
    display as error "Run 0_master.do first so project paths are defined."
    exit 198
}
capture mkdir "$output/tables"
log using "$output/logs/10_extension_heterogeneity.log", replace text

use "$temp/ck1994_clean.dta", clear
assert _N == 410
isid row_id

* Validate the ownership field at the data boundary.
capture confirm variable co_owned
if _rc {
    capture confirm variable company_owned
    if _rc {
        display as error "Neither co_owned nor company_owned exists in the cleaned data."
        exit 111
    }
    gen byte co_owned = company_owned
}
confirm numeric variable co_owned
assert inlist(co_owned, 0, 1) if !missing(co_owned)
assert !missing(co_owned)
label define ownership_lbl 0 "Franchised" 1 "Company-owned", replace
label values co_owned ownership_lbl
label variable co_owned "Company-owned store indicator"
tab co_owned, missing

* Descriptive changes use all available observations within each state,
* ownership group, and wave. The change is wave-2 mean minus wave-1 mean;
* therefore it is a repeated-cross-section comparison, not a paired change.
preserve
keep row_id nj co_owned fte1 fte2 wage1 wage2
reshape long fte wage, i(row_id) j(wave)
assert inlist(wave, 1, 2)
assert inlist(nj, 0, 1)

label variable fte "FTE employment"
label variable wage "Starting wage ($/hour)"
tempfile summary
collapse (count) n_fte=fte n_wage=wage (mean) mean_fte=fte mean_wage=wage, ///
    by(co_owned nj wave)
sort co_owned nj wave
reshape wide n_fte n_wage mean_fte mean_wage, i(co_owned nj) j(wave)
gen double fte_difference = mean_fte2 - mean_fte1
gen double wage_difference = mean_wage2 - mean_wage1
label variable nj "New Jersey treatment indicator"
label variable co_owned "Company-owned store indicator"
label variable n_fte1 "Wave 1 nonmissing FTE count"
label variable n_fte2 "Wave 2 nonmissing FTE count"
label variable n_wage1 "Wave 1 nonmissing wage count"
label variable n_wage2 "Wave 2 nonmissing wage count"
label variable mean_fte1 "Wave 1 mean FTE"
label variable mean_fte2 "Wave 2 mean FTE"
label variable fte_difference "FTE difference: wave 2 minus wave 1"
label variable mean_wage1 "Wave 1 mean starting wage"
label variable mean_wage2 "Wave 2 mean starting wage"
label variable wage_difference "Wage difference: wave 2 minus wave 1"
format mean_fte1 mean_fte2 fte_difference mean_wage1 mean_wage2 wage_difference %9.4f
save "$output/tables/extension_heterogeneity_summary.dta", replace
export delimited using "$output/tables/extension_heterogeneity_summary.csv", replace
list, noobs sepby(co_owned)

* Save the descriptive statistics as a standalone RTF for direct reporting.
tempname summary_rtf
file open `summary_rtf' using "$output/tables/extension_heterogeneity_summary.rtf", write replace
file write `summary_rtf' "{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\f0\fs20" _n
file write `summary_rtf' "\b Ownership Heterogeneity: Descriptive Statistics\b0\par" _n
file write `summary_rtf' "Ownership\tab State\tab FTE wave 1\tab FTE wave 2\tab FTE difference\tab Wage wave 1\tab Wage wave 2\tab Wage difference\par" _n
forvalues own = 0/1 {
    forvalues state = 0/1 {
        quietly summarize mean_fte1 if co_owned == `own' & nj == `state'
        local f1 : display %7.3f r(mean)
        quietly summarize mean_fte2 if co_owned == `own' & nj == `state'
        local f2 : display %7.3f r(mean)
        quietly summarize fte_difference if co_owned == `own' & nj == `state'
        local fd : display %7.3f r(mean)
        quietly summarize mean_wage1 if co_owned == `own' & nj == `state'
        local w1 : display %7.3f r(mean)
        quietly summarize mean_wage2 if co_owned == `own' & nj == `state'
        local w2 : display %7.3f r(mean)
        quietly summarize wage_difference if co_owned == `own' & nj == `state'
        local wd : display %7.3f r(mean)
        local own_text : label ownership_lbl `own'
        if `state' == 1 local state_text "New Jersey"
        else local state_text "Pennsylvania"
        file write `summary_rtf' "`own_text'\tab `state_text'\tab `f1'\tab `f2'\tab `fd'\tab `w1'\tab `w2'\tab `wd'\par" _n
    }
}
file write `summary_rtf' "\par Notes: Differences equal wave 2 mean minus wave 1 mean and use all nonmissing observations in each cell. Company-owned = 1 denotes a company-owned store; 0 denotes a franchised store.\par}" _n
file close `summary_rtf'
restore

* The FTE DID uses the verified 357-store employment sample. Permanent closures
* remain in the sample with wave-2 FTE equal to zero, as in the baseline design.
keep if sample_reg == 1
assert _N == 357
assert !missing(fte1, fte2, nj, co_owned, chain_code)
keep row_id nj co_owned chain_code fte1 fte2
reshape long fte, i(row_id) j(wave)
gen byte post = wave == 2
gen byte treat = nj == 1
assert inlist(post, 0, 1)
assert inlist(treat, 0, 1)

* Triple interaction: the additional post-policy FTE change for company-owned
* NJ stores relative to the corresponding franchised-store DID.
regress fte i.treat##i.post##i.co_owned i.chain_code, vce(robust)
local triple = _b[1.treat#1.post#1.co_owned]
local triple_se = _se[1.treat#1.post#1.co_owned]
local triple_p = 2*ttail(e(df_r), abs(`triple'/`triple_se'))
local triple_n = e(N)
local triple_rmse = e(rmse)
local triple_r2 = e(r2)

* Save the complete coefficient vector for the reported DID terms and controls.
tempname handle
tempfile did_results
postfile `handle' str32 term double coefficient robust_se p_value int N ///
    double rmse r_squared using `did_results', replace
foreach term in 1.treat 1.post 1.co_owned 1.treat#1.post 1.treat#1.co_owned ///
    1.post#1.co_owned 1.treat#1.post#1.co_owned {
    local b = _b[`term']
    local s = _se[`term']
    local p = 2*ttail(e(df_r), abs(`b'/`s'))
    post `handle' ("`term'") (`b') (`s') (`p') (e(N)) (e(rmse)) (e(r2))
}
postclose `handle'
use `did_results', clear
label variable term "Regression term"
label variable coefficient "Coefficient"
label variable robust_se "Robust standard error"
label variable p_value "Two-sided p-value"
label variable N "Observations"
label variable rmse "Root mean squared error"
label variable r_squared "R-squared"
format coefficient robust_se p_value rmse r_squared %9.4f
save "$output/tables/extension_heterogeneity_did.dta", replace
export delimited using "$output/tables/extension_heterogeneity_did.csv", replace
list, noobs

* One RTF reports both the ownership-by-state descriptive changes and the
* triple-interaction DID regression. RTF is generated with built-in commands.
tempname rtf
file open `rtf' using "$output/tables/extension_heterogeneity_did.rtf", write replace
file write `rtf' "{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\f0\fs20" _n
file write `rtf' "\b Independent Extension: Heterogeneity by Store Ownership\b0\par" _n
file write `rtf' "\b Panel A. State and ownership descriptive statistics\b0\par" _n
file write `rtf' "Ownership\tab State\tab FTE wave 1\tab FTE wave 2\tab FTE diff.\tab Wage wave 1\tab Wage wave 2\tab Wage diff.\par" _n

use "$output/tables/extension_heterogeneity_summary.dta", clear
forvalues own = 0/1 {
    forvalues state = 0/1 {
        quietly summarize mean_fte1 if co_owned == `own' & nj == `state'
        local f1 : display %7.3f r(mean)
        quietly summarize mean_fte2 if co_owned == `own' & nj == `state'
        local f2 : display %7.3f r(mean)
        quietly summarize fte_difference if co_owned == `own' & nj == `state'
        local fd : display %7.3f r(mean)
        quietly summarize mean_wage1 if co_owned == `own' & nj == `state'
        local w1 : display %7.3f r(mean)
        quietly summarize mean_wage2 if co_owned == `own' & nj == `state'
        local w2 : display %7.3f r(mean)
        quietly summarize wage_difference if co_owned == `own' & nj == `state'
        local wd : display %7.3f r(mean)
        local own_text : label ownership_lbl `own'
        if `state' == 1 local state_text "New Jersey"
        else local state_text "Pennsylvania"
        file write `rtf' "`own_text'\tab `state_text'\tab `f1'\tab `f2'\tab `fd'\tab `w1'\tab `w2'\tab `wd'\par" _n
    }
}

use "$output/tables/extension_heterogeneity_did.dta", clear
file write `rtf' "\par\b Panel B. Triple-interaction FTE DID regression\b0\par" _n
file write `rtf' "Term\tab Coefficient\tab Robust SE\tab p-value\par" _n
forvalues i = 1/7 {
    local term = term[`i']
    local b : display %8.3f coefficient[`i']
    local s : display %8.3f robust_se[`i']
    local p : display %8.3f p_value[`i']
    file write `rtf' "`term'\tab `b'\tab `s'\tab `p'\par" _n
}
file write `rtf' "\par Notes: The model is FTE = treatment, post, and ownership indicators plus all two-way and three-way interactions, with chain fixed effects and robust standard errors.\par" _n
file write `rtf' "The triple interaction 1.treat#1.post#1.co_owned is the differential policy effect for company-owned NJ stores relative to franchised NJ stores. Sample: 357 stores x 2 waves = 714 observations.\par" _n
file write `rtf' "Panel A uses all available outcome-specific observations; Panel B uses sample_reg = 1. Their estimates are not directly comparable because the samples differ. Robust SEs are heteroskedasticity-robust, not clustered by store.\par}" _n
file close `rtf'

log close
