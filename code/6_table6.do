version 18
clear all
set more off
capture log close

* Card and Krueger (1994), Table 6: other outcomes.
* The raw survey and cleaned analytic file are never modified here.
if "$root" == "" {
    display as error "Run 0_master.do first so project paths are defined."
    exit 198
}
capture mkdir "$output/tables"
capture mkdir "$output/checks"
log using "$output/logs/6_table6.log", replace text
use "$temp/ck1994_clean.dta", clear
assert _N == 410

* Fraction full-time workers follows the paper's footnote: full-time workers
* divided by total FTE employment. Percentage-point changes are reported.
gen double t6_fulltime1 = 100*empft1/fte1 if fte1 > 0
gen double t6_fulltime2 = 100*empft2/fte2 if fte2 > 0
gen double t6_d_fulltime = t6_fulltime2 - t6_fulltime1

* Recode meal programs as mutually exclusive indicators. Missing responses
* remain missing; they are not interpreted as no program.
gen byte t6_lowmeal1 = meals1 == 2 if !missing(meals1)
gen byte t6_lowmeal2 = meals2 == 2 if !missing(meals2)
gen byte t6_freemeal1 = meals1 == 1 if !missing(meals1)
gen byte t6_freemeal2 = meals2 == 1 if !missing(meals2)
gen byte t6_bothmeal1 = meals1 == 3 if !missing(meals1)
gen byte t6_bothmeal2 = meals2 == 3 if !missing(meals2)
gen double t6_d_lowmeal = 100*(t6_lowmeal2-t6_lowmeal1)
gen double t6_d_freemeal = 100*(t6_freemeal2-t6_freemeal1)
gen double t6_d_bothmeal = 100*(t6_bothmeal2-t6_bothmeal1)

* Other store characteristics.
gen double t6_d_hours = hours_open2 - hours_open1
gen double t6_d_registers = registers2 - registers1
gen double t6_d_registers11 = registers11am2 - registers11am1

* Wage-profile measures. The source variables are in dollars and weeks. The
* slope is expressed as percentage points per week: 100 * first raise / wage /
* weeks until first raise. Only rows with all required source values enter.
gen double t6_d_raise_time = raise_time2 - raise_time1
gen double t6_d_first_raise_cents = 100*(first_raise2-first_raise1)
gen double t6_slope1 = 100*first_raise1/(wage1*raise_time1) if wage1 > 0 & raise_time1 > 0
gen double t6_slope2 = 100*first_raise2/(wage2*raise_time2) if wage2 > 0 & raise_time2 > 0
gen double t6_d_slope = t6_slope2 - t6_slope1

* The paper's regression controls: three chain indicators (Burger King is the
* omitted chain), company ownership, and four region indicators (North NJ is
* the omitted region). Each outcome uses all observations valid for that outcome.
local controls "ib1.chain_code company_owned"
local regions "central_nj south_nj pa_philly pa_easton"

* Outcome names are kept in the same order as the ten published rows.
local y1 t6_d_fulltime
local y2 t6_d_hours
local y3 t6_d_registers
local y4 t6_d_registers11
local y5 t6_d_lowmeal
local y6 t6_d_freemeal
local y7 t6_d_bothmeal
local y8 t6_d_raise_time
local y9 t6_d_first_raise_cents
local y10 t6_d_slope
local label1 "Fraction full-time workers (percentage)"
local label2 "Number of hours open per weekday"
local label3 "Number of cash registers"
local label4 "Cash registers open at 11:00 A.M."
local label5 "Low-price meal program (percentage)"
local label6 "Free meal program (percentage)"
local label7 "Combination of low-price and free meals (percentage)"
local label8 "Time to first raise (weeks)"
local label9 "Usual amount of first raise (cents)"
local label10 "Slope of wage profile (percent per week)"

tempfile results
tempname handle
postfile `handle' byte outcome str80 outcome_label str32 statistic ///
    int N double estimate se using `results', replace

forvalues j = 1/10 {
    local y `y`j''
    local label "`label`j''"
    * Mean change columns i-iii use available outcome observations only.
    quietly summarize `y' if nj == 1
    local nnj = r(N)
    local mnj = r(mean)
    local snj = r(sd)/sqrt(r(N))
    quietly summarize `y' if nj == 0
    local npa = r(N)
    local mpa = r(mean)
    local spa = r(sd)/sqrt(r(N))
    post `handle' (`j') ("`label'") ("NJ mean") (`nnj') (`mnj') (`snj')
    post `handle' (`j') ("`label'") ("PA mean") (`npa') (`mpa') (`spa')
    post `handle' (`j') ("`label'") ("NJ-PA mean") (`nnj'+`npa') ///
        (`mnj'-`mpa') (sqrt(`snj'^2+`spa'^2))

    * Columns iv-v use NJ and GAP respectively. Column vi adds region controls.
    regress `y' nj `controls' if !missing(`y', nj, chain_code, company_owned)
    post `handle' (`j') ("`label'") ("NJ coefficient") (e(N)) ///
        (_b[nj]) (_se[nj])
    regress `y' gap `controls' if !missing(`y', gap, chain_code, company_owned)
    post `handle' (`j') ("`label'") ("GAP coefficient") (e(N)) ///
        (_b[gap]) (_se[gap])
    regress `y' gap `controls' `regions' if !missing(`y', gap, chain_code, ///
        company_owned, central_nj, south_nj, pa_philly, pa_easton)
    post `handle' (`j') ("`label'") ("GAP + region coefficient") (e(N)) ///
        (_b[gap]) (_se[gap])
}
postclose `handle'

use `results', clear
* Numeric column order preserves the article's layout and target alignment.
gen byte column = .
replace column = 1 if statistic == "NJ mean"
replace column = 2 if statistic == "PA mean"
replace column = 3 if statistic == "NJ-PA mean"
replace column = 4 if statistic == "NJ coefficient"
replace column = 5 if statistic == "GAP coefficient"
replace column = 6 if statistic == "GAP + region coefficient"
sort outcome column
assert _N == 60
isid outcome column
label variable outcome "Table 6 row"
label variable outcome_label "Outcome measure"
label variable N "Observations used"
label variable estimate "Mean or regression coefficient"
label variable se "Standard error"
format estimate se %9.4f
save "$output/tables/table6_other_outcomes.dta", replace
export delimited using "$output/tables/table6_other_outcomes.csv", replace
list outcome statistic N estimate se, noobs sepby(outcome)

* Add the published values for transparent comparison. The result file retains
* estimates calculated from the current cleaned data.
gen double paper_estimate = .
gen double paper_se = .
local njmean "2.64 -0.00 -0.04 -0.03 -4.67 8.41 -4.04 3.77 -0.01 -0.10"
local pamean "-4.65 0.11 0.13 -0.20 -1.28 6.41 -5.13 1.26 -0.02 -0.11"
local did "7.29 -0.11 -0.17 0.17 -3.39 2.00 1.09 2.51 0.01 0.01"
local njcoef "7.30 -0.11 -0.18 0.17 -2.01 0.49 1.20 2.21 0.01 0.01"
local gapcoef "33.64 -0.24 -0.31 0.15 -30.31 29.90 -11.87 4.02 0.03 -0.09"
local gapreg "20.28 0.04 0.29 -0.47 -33.15 36.91 -19.19 -5.10 0.03 -0.08"
local njses "1.71 0.06 0.04 0.05 2.65 2.17 1.98 0.89 0.01 0.04"
local pases "3.80 0.08 0.10 0.08 3.86 3.33 3.11 1.97 0.02 0.09"
local didses "4.17 0.10 0.11 0.10 4.68 3.97 3.69 2.16 0.02 0.10"
local njcses "3.96 0.12 0.10 0.12 5.63 4.50 4.32 2.03 0.02 0.10"
local gapcses "20.95 0.65 0.53 0.62 29.80 23.75 22.87 10.81 0.11 0.56"
local gaprses "24.34 0.76 0.62 0.74 35.04 27.90 26.81 12.74 0.11 0.57"
forvalues j = 1/10 {
    local i1 = (`j'-1)*6+1
    local i2 = `i1'+1
    local i3 = `i1'+2
    local i4 = `i1'+3
    local i5 = `i1'+4
    local i6 = `i1'+5
    local b : word `j' of `njmean'
    local e : word `j' of `njses'
    replace paper_estimate = `b' in `i1'
    replace paper_se = `e' in `i1'
    local b : word `j' of `pamean'
    local e : word `j' of `pases'
    replace paper_estimate = `b' in `i2'
    replace paper_se = `e' in `i2'
    local b : word `j' of `did'
    local e : word `j' of `didses'
    replace paper_estimate = `b' in `i3'
    replace paper_se = `e' in `i3'
    local b : word `j' of `njcoef'
    local e : word `j' of `njcses'
    replace paper_estimate = `b' in `i4'
    replace paper_se = `e' in `i4'
    local b : word `j' of `gapcoef'
    local e : word `j' of `gapcses'
    replace paper_estimate = `b' in `i5'
    replace paper_se = `e' in `i5'
    local b : word `j' of `gapreg'
    local e : word `j' of `gaprses'
    replace paper_estimate = `b' in `i6'
    replace paper_se = `e' in `i6'
}
* The printed row-9 values are on a dollar scale despite its cents heading;
* convert those targets to cents to compare with the explicitly labelled output.
replace paper_estimate = 100*paper_estimate if outcome == 9
replace paper_se = 100*paper_se if outcome == 9
gen double estimate_difference = estimate - paper_estimate
gen double se_difference = se - paper_se
export delimited using "$output/checks/table6_comparison.csv", replace

* RTF output follows the six-column structure in the article.
tempname rtf
file open `rtf' using "$output/tables/table6_other_outcomes.rtf", write replace
file write `rtf' "{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\f0\fs17" _n
file write `rtf' "\b Table 6. Effects of Minimum-Wage Increase on Other Outcomes\b0\par" _n
file write `rtf' "Outcome\tab NJ mean\tab PA mean\tab NJ-PA\tab NJ dummy\tab Wage gap\tab Wage gap + regions\par" _n
forvalues j = 1/10 {
    local base = (`j'-1)*6
    local text = outcome_label[`base'+1]
    file write `rtf' "`text'"
    forvalues c = 1/6 {
        local idx = `base'+`c'
        local b : display %7.2f estimate[`idx']
        local e : display %7.2f se[`idx']
        file write `rtf' "\tab `b' (`e')"
    }
    file write `rtf' "\par" _n
}
file write `rtf' "\par Notes: Standard errors in parentheses. Regression models include chain dummies and company ownership.\par" _n
file write `rtf' "The comparison CSV reports deviations from the published values.\par}" _n
file close `rtf'
log close
