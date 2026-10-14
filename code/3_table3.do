version 18
clear all
set more off
capture log close

* Card and Krueger (1994), Table 3: average FTE employment per store.
if "$root" == "" {
    display as error "Run 0_master.do first so project paths are defined."
    exit 198
}
capture mkdir "$output/tables"
log using "$output/logs/3_table3.log", replace text
use "$temp/ck1994_clean.dta", clear
assert _N == 410

* The paper reports all available observations in rows 1-3, the balanced
* employment sample in row 4, and balanced observations with four temporary or
* special closures set to zero in row 5.
gen byte table3_balanced = !missing(fte1, fte2)
gen byte table3_tempzero_balanced = !missing(fte1, fte2_tempzero)

* Check the three NJ initial-wage cells reported in the paper.
count if nj == 1 & nj_wage425 == 1
assert r(N) == 101
count if nj == 1 & nj_wagemid == 1
assert r(N) == 140
count if nj == 1 & nj_wagehigh500 == 1
assert r(N) == 73

gen byte table3_group = .
replace table3_group = 1 if nj == 0
replace table3_group = 2 if nj == 1
replace table3_group = 4 if nj_wage425 == 1
replace table3_group = 5 if nj_wagemid == 1
replace table3_group = 6 if nj_wagehigh500 == 1

* Results are stored in long form: table row, displayed column, estimate, SE.
tempfile results
tempname handle
postfile `handle' byte table_row byte table_col str80 description ///
    int N double estimate standard_error using `results', replace

local d1 "FTE employment before, all available observations"
local d2 "FTE employment after, all available observations"
local d3 "Change in mean FTE employment"
local d4 "Change in mean FTE employment, balanced sample"
local d5 "Change in mean FTE employment, temporary closures set to zero"

forvalues row = 1/5 {
    if `row' == 1 local sample ""
    if `row' == 2 local sample ""
    if `row' == 3 local sample ""
    if `row' == 4 local sample "& table3_balanced"
    if `row' == 5 local sample "& table3_tempzero_balanced"

    * Calculate the five primitive cells: PA, NJ, low-wage NJ, midrange NJ,
    * and high-wage NJ. Row 3 is wave-2 mean minus wave-1 mean, allowing
    * different valid observations in the two waves exactly as in the paper.
    foreach g in 1 2 4 5 6 {
        if `g' == 1 local condition "nj == 0"
        if `g' == 2 local condition "nj == 1"
        if `g' == 4 local condition "nj_wage425 == 1"
        if `g' == 5 local condition "nj_wagemid == 1"
        if `g' == 6 local condition "nj_wagehigh500 == 1"
        if `row' == 1 local v1 fte1
        if `row' == 2 local v1 fte2
        if `row' == 4 local v1 d_fte
        if `row' == 5 local v1 d_fte_tempzero
        if `row' != 3 {
            quietly summarize `v1' if `condition' `sample'
            local n`g' = r(N)
            local m`g' = r(mean)
            if r(N) > 1 local s`g' = r(sd)/sqrt(r(N))
            else local s`g' = .
        }
        else {
            quietly summarize fte1 if `condition'
            local n1_`g' = r(N)
            local m1_`g' = r(mean)
            if r(N) > 1 local s1_`g' = r(sd)/sqrt(r(N))
            else local s1_`g' = .
            quietly summarize fte2 if `condition'
            local n2_`g' = r(N)
            local m2_`g' = r(mean)
            if r(N) > 1 local s2_`g' = r(sd)/sqrt(r(N))
            else local s2_`g' = .
            * 行3的N报告两轮至少一轮就业有效的不同门店数。
            quietly count if `condition' & (!missing(fte1) | !missing(fte2))
            local n`g' = r(N)
            local m`g' = `m2_`g'' - `m1_`g''
            * 两轮存在重叠门店，均值变化的方差需减去协方差项。
            * 配对协方差乘以重叠样本数，再除以两轮各自样本数。
            quietly correlate fte1 fte2 if `condition', covariance
            local overlap = r(N)
            local covariance = r(cov_12)
            local s`g' = sqrt(`s1_`g''^2 + `s2_`g''^2 - ///
                2*`overlap'*`covariance'/(`n1_`g''*`n2_`g''))
        }
    }

    * Direct columns: PA (1), NJ (2), wage=$4.25 (4), midrange (5), high (6).
    foreach g in 1 2 4 5 6 {
        post `handle' (`row') (`g') ("`d`row''") ///
            (`n`g'') (`m`g'') (`s`g'')
    }

    * Difference columns: NJ-PA, low-high, and midrange-high.
    local est = `m2' - `m1'
    local se = sqrt(`s2'^2 + `s1'^2)
    local n_diff = `n2' + `n1'
    post `handle' (`row') (3) ("`d`row''") (`n_diff') (`est') (`se')
    local est = `m4' - `m6'
    local se = sqrt(`s4'^2 + `s6'^2)
    quietly count if (nj_wage425 == 1 | nj_wagehigh500 == 1) `sample'
    local n_diff = r(N)
    post `handle' (`row') (7) ("`d`row''") (`n_diff') (`est') (`se')
    local est = `m5' - `m6'
    local se = sqrt(`s5'^2 + `s6'^2)
    quietly count if (nj_wagemid == 1 | nj_wagehigh500 == 1) `sample'
    local n_diff = r(N)
    post `handle' (`row') (8) ("`d`row''") (`n_diff') (`est') (`se')
}
postclose `handle'

use `results', clear
sort table_row table_col
label variable table_row "Table 3 row"
label variable table_col "Table 3 column"
label variable estimate "Mean or difference"
label variable standard_error "Standard error"
label variable N "Observations used"
format estimate standard_error %9.3f
save "$output/tables/table3_employment.dta", replace
export delimited using "$output/tables/table3_employment.csv", replace
list table_row table_col estimate standard_error N, noobs sepby(table_row)

* Write an RTF version with the eight columns of the published table.
tempname rtf
file open `rtf' using "$output/tables/table3_employment.rtf", write replace
file write `rtf' "{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\f0\fs18" _n
file write `rtf' "\b Table 3. Average Employment per Store Before and After\b0\par" _n
file write `rtf' "Variable\tab PA\tab NJ\tab NJ-PA\tab Wage 4.25\tab Wage 4.26-4.99\tab Wage >=5.00\tab Low-high\tab Mid-high\par" _n
forvalues r = 1/5 {
    local base = (`r' - 1)*8
    local title = description[`base' + 1]
    file write `rtf' "`title'\tab" _n
    forvalues c = 1/8 {
        local idx = `base' + `c'
        local est : display %6.2f estimate[`idx']
        local se : display %6.2f standard_error[`idx']
        file write `rtf' "`est' (`se')"
        if `c' < 8 file write `rtf' "\tab"
        else file write `rtf' "\par" _n
    }
}
file write `rtf' "\par Standard errors in parentheses. FTE includes managers plus one-half of part-time workers.\par" _n
file write `rtf' "Permanent closures are set to zero; temporary closures are missing except in row 5.\par}" _n
file close `rtf'
log close
