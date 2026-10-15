version 18
clear all
set more off
capture log close

* Table 5: each row changes one feature of the baseline employment model.
* Read the verified data without overwriting either raw or cleaned files.
if "$root" == "" {
    di as error "Run 0_master.do first to define project paths."
    exit 198
}
capture mkdir "$output/tables"
capture mkdir "$output/checks"
log using "$output/logs/5_table5.log", replace text
use "$temp/ck1994_clean.dta", clear
assert _N == 410
isid row_id

* DATE2 has a two-digit year; the existing cleaned daily date is missing.
* Parse locally with an explicit century, retaining the original source value.
gen double t5_date = date(string(wave2_date_raw, "%06.0f"), "MD19Y")
format t5_date %td
* Four interview timing groups provide three dummies. This grouping is an
* explicit approximation because the markdown omits the detailed footnote.
gen byte t5_week = .
replace t5_week = 1 if inrange(t5_date, td(05nov1992), td(11nov1992))
replace t5_week = 2 if inrange(t5_date, td(12nov1992), td(18nov1992))
replace t5_week = 3 if inrange(t5_date, td(19nov1992), td(25nov1992))
replace t5_week = 4 if inrange(t5_date, td(26nov1992), td(31dec1992))
* Dates outside the documented second-wave window remain flagged, not corrected.
list row_id store_id wave2_date_raw t5_date if missing(t5_week), noobs

* Alternative outcome definitions are recomputed in double precision.
* Ordinary arithmetic propagates missing components instead of assuming zero.
gen double t5_level = fte2 - fte1
gen double t5_temp = fte2_tempzero - fte1
gen double t5_nomgr = fte2_nomgr - fte1_nomgr
gen double t5_pt40 = fte2_pt40 - fte1_pt40
gen double t5_pt60 = fte2_pt60 - fte1_pt60

* Proportional changes use initial employment as the denominator. The detailed
* proportional-change footnote is missing from paper.md; differences from the
* printed table are exported rather than concealed by changing the definition.
gen double t5_prop = t5_level/fte1 if fte1 > 0 & !missing(fte1)
gen double t5_prop_temp = t5_temp/fte1 if fte1 > 0 & !missing(fte1)
gen double t5_prop_nomgr = t5_nomgr/fte1_nomgr if fte1_nomgr > 0 & !missing(fte1_nomgr)
gen double t5_prop_pt40 = t5_pt40/fte1_pt40 if fte1_pt40 > 0 & !missing(fte1_pt40)
gen double t5_prop_pt60 = t5_pt60/fte1_pt60 if fte1_pt60 > 0 & !missing(fte1_pt60)

* Add the four temporary/special closures to the baseline while retaining
* its wage-data restriction for operating stores (357 + 4 observations).
gen byte t5_sample_temp = sample_reg == 1 | ///
    (inlist(wave2_status, 2, 4, 5) & !missing(fte1, fte2_tempzero, wage1, gap))
* For the PA placebo, the wage-gap measure ignores the state treatment rule.
gen double t5_placebo_gap = max(0, (5.05-wage1)/wage1) if wage1 > 0 & !missing(wage1)

local title1 "Base specification"
local title2 "Temporary closures assigned zero"
local title3 "Exclude managers"
local title4 "Part-time weight 0.4"
local title5 "Part-time weight 0.6"
local title6 "Exclude NJ shore stores"
local title7 "Interview timing controls (approximate)"
local title8 "Exclude wave-1 calls greater than two"
local title9 "Weight proportional change by initial employment"
local title10 "Newark towns: ZIP data unavailable"
local title11 "Camden towns: ZIP data unavailable"
local title12 "Pennsylvania placebo wage gap"

tempfile results
tempname handle
postfile `handle' byte specification column str80 description str120 status ///
    int N double coefficient se p_value using `results', replace
forvalues s = 1/12 {
    local level t5_level
    local prop t5_prop
    local sample "sample_reg == 1"
    local extra ""
    local weight ""
    local note "estimated"
    if `s' == 2 {
        local level t5_temp
        local prop t5_prop_temp
        local sample "t5_sample_temp == 1"
    }
    if `s' == 3 {
        local level t5_nomgr
        local prop t5_prop_nomgr
    }
    if `s' == 4 {
        local level t5_pt40
        local prop t5_prop_pt40
    }
    if `s' == 5 {
        local level t5_pt60
        local prop t5_prop_pt60
    }
    if `s' == 6 local sample "sample_reg == 1 & nj_shore == 0"
    if `s' == 7 {
        local extra "ib1.t5_week"
        local note "approximate interview grouping; invalid dates excluded"
    }
    if `s' == 8 local sample "sample_reg == 1 & calls_wave1 <= 2"
    if `s' == 9 local weight "[aw=fte1]"
    if `s' == 12 local sample "sample_reg == 1 & nj == 0"

    forvalues c = 1/4 {
        local status "`note'"
        if inlist(`s', 10, 11) {
            local status "unavailable: no verified ZIP or town mapping"
            post `handle' (`s') (`c') ("`title`s''") ("`status'") (.) (.) (.) (.)
            continue
        }
        if (`s' == 9 & `c' <= 2) | (`s' == 12 & inlist(`c', 1, 3)) {
            post `handle' (`s') (`c') ("`title`s''") ("not reported in paper") (.) (.) (.) (.)
            continue
        }
        if `c' <= 2 local y `level'
        else local y `prop'
        if inlist(`c', 1, 3) local x nj
        else local x gap
        if `s' == 12 local x t5_placebo_gap
        di as text "Table 5 specification `s', column `c'"
        regress `y' `x' ib1.chain_code company_owned `extra' `weight' if `sample'
        local b = _b[`x']
        local se = _se[`x']
        local n = e(N)
        local p = 2*ttail(e(df_r), abs(`b'/`se'))
        post `handle' (`s') (`c') ("`title`s''") ("`status'") (`n') (`b') (`se') (`p')
    }
}
postclose `handle'
use `results', clear
sort specification column
assert _N == 48
isid specification column
label variable coefficient "NJ or GAP coefficient"
label variable se "Conventional OLS standard error"
label variable N "Actual regression sample size"
format coefficient se %9.4f
save "$output/tables/table5_robustness.dta", replace
export delimited using "$output/tables/table5_robustness.csv", replace
list specification column N coefficient se status, noobs sepby(specification)

* Compare every estimated cell with the published value; blanks remain blanks.
gen double paper_b = .
gen double paper_se = .
local b1 "2.30 14.92 0.05 0.34"
local b2 "2.20 14.42 0.04 0.34"
local b3 "2.34 14.69 0.05 0.28"
local b4 "2.34 15.23 0.06 0.30"
local b5 "2.27 14.60 0.04 0.17"
local b6 "2.58 16.88 0.06 0.42"
local b7 "2.27 15.79 0.05 0.40"
local b8 "2.41 14.08 0.05 0.31"
local b9 ". . 0.13 0.81"
local b10 ". 33.75 . 0.90"
local b11 ". 10.91 . 0.21"
local b12 ". -0.30 . -0.33"
local e1 "1.19 6.21 0.05 0.26"
local e2 "1.21 6.31 0.05 0.27"
local e3 "1.17 6.05 0.07 0.34"
local e4 "1.20 6.23 0.06 0.33"
local e5 "1.21 6.26 0.06 0.29"
local e6 "1.19 6.36 0.05 0.27"
local e7 "1.20 6.24 0.05 0.26"
local e8 "1.28 7.11 0.05 0.29"
local e9 ". . 0.05 0.26"
local e10 ". 16.75 . 0.74"
local e11 ". 14.09 . 0.70"
local e12 ". 22.00 . 0.74"
forvalues s = 1/12 {
    forvalues c = 1/4 {
        local b : word `c' of `b`s''
        local e : word `c' of `e`s''
        replace paper_b = `b' if specification == `s' & column == `c'
        replace paper_se = `e' if specification == `s' & column == `c'
    }
}
gen double coefficient_difference = coefficient - paper_b
gen double se_difference = se - paper_se
export delimited using "$output/checks/table5_comparison.csv", replace

tempname rtf
file open `rtf' using "$output/tables/table5_robustness.rtf", write replace
file write `rtf' "{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\f0\fs18" _n
file write `rtf' "\b Table 5. Specification Tests of Employment Models\b0\par" _n
file write `rtf' "Specification\tab Level: NJ\tab Level: GAP\tab Proportion: NJ\tab Proportion: GAP\par" _n
forvalues s = 1/12 {
    local index = (`s'-1)*4+1
    local text = description[`index']
    file write `rtf' "`s'. `text'"
    forvalues c = 1/4 {
        local index = (`s'-1)*4+`c'
        local cell "--"
        if !missing(coefficient[`index']) {
            local b : display %7.2f coefficient[`index']
            local e : display %7.2f se[`index']
            local cell "`b' (`e')"
        }
        if inlist(`s',10,11) local cell "Unavailable"
        file write `rtf' "\tab `cell'"
    }
    file write `rtf' "\par" _n
}
file write `rtf' "\par All models include chain and ownership controls and a constant. Conventional OLS SEs in parentheses.\par" _n
file write `rtf' "Proportional changes use initial employment as denominator; detailed source footnote unavailable.\par" _n
file write `rtf' "Row 7 uses an approximate four-group interview timing control. Rows 10-11 require ZIP data.\par" _n
file write `rtf' "The comparison CSV records departures from the published results.\par}" _n
file close `rtf'
log close
