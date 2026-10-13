version 18
clear all
set more off
capture log close

* Import and clean the Card-Krueger restaurant survey.
* The raw CSV is read-only: all transformations are saved to 02_temp.

if "$root" == "" {
    di as err "Global root is not defined. Run 0_master.do first."
    exit 198
}

log using "$output/logs/1_import_clean.log", replace text

* Import the supplied 410-store file without changing the raw file.
import delimited using "$raw/01_DID/data/public.csv", clear varnames(1) case(lower)
compress

* SHEET contains repeated identifiers; preserve every row and its import order.
gen long row_id = _n
label variable row_id "Unique row identifier in original CSV order"
isid row_id

* Preserve the source identifiers and attach readable labels to source fields.
rename sheet       store_id
rename chain       chain_code
rename co_owned    company_owned
rename state       nj
rename southj      south_nj
rename centralj    central_nj
rename northj     north_nj
rename pa1         pa_philly
rename pa2         pa_easton
rename shore       nj_shore
rename ncalls      calls_wave1
rename empft       empft1
rename emppt       emppt1
rename nmgrs       managers1
rename wage_st     wage1
rename inctime     raise_time1
rename firstinc    first_raise1
rename bonus       recruiting_bonus1
rename pctaff      pct_affiliated1
rename meals       meals1
rename open        open_code1
rename hrsopen     hours_open1
rename psoda       soda1
rename pfry        fries1
rename pentree     entree1
rename nregs       registers1
rename nregs11     registers11am1
rename type2       wave2_interview_type
rename status2     wave2_status
rename date2       wave2_date_raw
rename ncalls2     calls_wave2
rename empft2      empft2
rename emppt2      emppt2
rename nmgrs2      managers2
rename wage_st2   wage2
rename inctime2   raise_time2
rename firstin2    first_raise2
rename special2   special_program2
rename meals2     meals2
rename open2r    open_code2
rename hrsopen2  hours_open2
rename psoda2    soda2
rename pfry2     fries2
rename pentree2  entree2
rename nregs2    registers2
rename nregs112  registers11am2

label variable store_id "Original survey sheet identifier"
label variable nj "New Jersey indicator"
label variable company_owned "Company-owned store indicator"
label variable wave2_status "Second-wave store status"
label variable wage1 "Wave-1 starting wage (dollars/hour)"
label variable wage2 "Wave-2 starting wage (dollars/hour)"
label variable hours_open1 "Wave-1 weekday hours open"
label variable hours_open2 "Wave-2 weekday hours open"

label define chain_lbl 1 "Burger King" 2 "KFC" 3 "Roy Rogers" 4 "Wendy's", replace
label values chain_code chain_lbl
label define wave2_status_lbl 0 "Refused" 1 "Answered" 2 "Renovation" 3 "Permanent closure" 4 "Highway construction" 5 "Mall fire", replace
label values wave2_status wave2_status_lbl
label define meal_lbl 0 "No program reported" 1 "Free meal" 2 "Reduced-price meal" 3 "Both free and reduced-price meals", replace
label values meals1 meal_lbl
label values meals2 meal_lbl

* The source stores dates as six-digit MMDDYY numbers, e.g. 111792.
tostring wave2_date_raw, gen(wave2_date_string) format(%06.0f)
gen wave2_date = date(wave2_date_string, "MDY")
format wave2_date %td
 drop wave2_date_string

* Construct full-time-equivalent employment exactly as defined in the paper.
gen fte1 = empft1 + managers1 + 0.5*emppt1
label variable fte1 "Wave-1 FTE employment"
gen fte2_raw = empft2 + managers2 + 0.5*emppt2
label variable fte2_raw "Wave-2 FTE before closure treatment"
gen fte2 = fte2_raw

* Permanent closures count as zero employment. Temporary closures and refusals
* remain missing in the main specification, as in the paper.
replace fte2 = 0 if wave2_status == 3
replace fte2 = . if inlist(wave2_status, 0, 2, 4, 5)
label variable fte2 "Wave-2 FTE employment, permanent closures set to zero"

gen fte2_tempzero = fte2
replace fte2_tempzero = 0 if inlist(wave2_status, 2, 4, 5)
label variable fte2_tempzero "Wave-2 FTE, temporary/special closures set to zero"

* Alternative employment definitions used in Table 5.
gen fte1_nomgr = empft1 + 0.5*emppt1
gen fte2_nomgr = empft2 + 0.5*emppt2
replace fte2_nomgr = 0 if wave2_status == 3

gen fte1_pt40 = empft1 + managers1 + 0.4*emppt1
gen fte2_pt40 = empft2 + managers2 + 0.4*emppt2
replace fte2_pt40 = 0 if wave2_status == 3

gen fte1_pt60 = empft1 + managers1 + 0.6*emppt1
gen fte2_pt60 = empft2 + managers2 + 0.6*emppt2
replace fte2_pt60 = 0 if wave2_status == 3

* Main first-difference and proportional-change outcomes.
gen d_fte = fte2 - fte1
replace d_fte = . if missing(fte1, fte2)
gen d_fte_tempzero = fte2_tempzero - fte1
replace d_fte_tempzero = . if missing(fte1, fte2_tempzero)
gen pct_d_fte = d_fte/fte1 if fte1 > 0 & !missing(d_fte)

* The paper's full-time share is the number of full-time employees divided by
* FTE employment; managers are included in employment but not in EMPFT.
gen pct_fulltime1 = 100*empft1/(empft1 + emppt1) if empft1 + emppt1 > 0
gen pct_fulltime2 = 100*empft2/(empft2 + emppt2) if empft2 + emppt2 > 0
 gen d_pct_fulltime = pct_fulltime2 - pct_fulltime1

* Initial wage groups used in Table 3. The high-wage cutoff here is $5.00,
* which is distinct from the $5.05 cutoff used in GAP.
gen nj_wage425 = nj == 1 & wage1 == 4.25 if !missing(wage1)
gen nj_wagemid = nj == 1 & inrange(wage1, 4.26, 4.99) if !missing(wage1)
gen nj_wagehigh500 = nj == 1 & wage1 >= 5.00 if !missing(wage1)
label variable nj_wage425 "NJ store with wave-1 wage exactly $4.25"
label variable nj_wagemid "NJ store with wave-1 wage $4.26-$4.99"
label variable nj_wagehigh500 "NJ store with wave-1 wage at least $5.00"

* GAP is the proportional wage increase required to reach $5.05. It is zero
* for all Pennsylvania stores and NJ stores already at or above $5.05.
gen double gap = 0 if nj == 0
* Stata treats numeric missing values as greater than any real number;
* explicitly exclude missing wages so they cannot become zero-gap NJ stores.
replace gap = max(0, (5.05 - wage1)/wage1) if nj == 1 & wage1 > 0 & !missing(wage1)
label variable gap "Initial proportional wage gap to $5.05"

gen d_wage = wage2 - wage1
replace d_wage = . if missing(wage1, wage2)
gen pct_d_wage = d_wage/wage1 if wage1 > 0 & !missing(d_wage)
gen wage425_1 = wage1 == 4.25 if !missing(wage1)
gen wage505_2 = wage2 == 5.05 if !missing(wage2)

* Meal prices and the Table 7 outcome.
gen fullmeal1 = soda1 + fries1 + entree1
 gen fullmeal2 = soda2 + fries2 + entree2
 gen log_fullmeal1 = ln(fullmeal1) if fullmeal1 > 0
 gen log_fullmeal2 = ln(fullmeal2) if fullmeal2 > 0
 gen d_log_fullmeal = log_fullmeal2 - log_fullmeal1
 gen d_log_soda = ln(soda2) - ln(soda1) if soda1 > 0 & soda2 > 0
 gen d_log_fries = ln(fries2) - ln(fries1) if fries1 > 0 & fries2 > 0
 gen d_log_entree = ln(entree2) - ln(entree1) if entree1 > 0 & entree2 > 0
label variable fullmeal1 "Wave-1 full meal price"
label variable fullmeal2 "Wave-2 full meal price"
label variable d_log_fullmeal "Change in log full meal price"

* Store characteristics and other Table 6 outcomes.
gen d_hours_open = hours_open2 - hours_open1
 gen d_registers = registers2 - registers1
 gen d_registers11am = registers11am2 - registers11am1
 gen lowprice_meal1 = inlist(meals1, 2, 3) if !missing(meals1)
 gen free_meal1 = inlist(meals1, 1, 3) if !missing(meals1)
 gen lowprice_meal2 = inlist(meals2, 2, 3) if !missing(meals2)
 gen free_meal2 = inlist(meals2, 1, 3) if !missing(meals2)
 gen d_lowprice_meal = lowprice_meal2 - lowprice_meal1
 gen d_free_meal = free_meal2 - free_meal1
 gen d_meal_program = meals2 - meals1

* Region indicators are retained as supplied. The omitted region in regressions
* will be determined by Stata's factor-variable notation.
gen region_nj_north = north_nj
 gen region_nj_central = central_nj
 gen region_nj_south = south_nj
 gen region_pa_philly = pa_philly
 gen region_pa_easton = pa_easton

* Wave-2 interview week controls. DATE2 is stored as a Stata daily date above.
gen wave2_week = week(wave2_date) if !missing(wave2_date)
gen wave2_month = month(wave2_date) if !missing(wave2_date)

* Meal-program changes and wage-profile variables are only created when the
* corresponding source fields exist; the supplied file may not contain every
* questionnaire item used in the published Table 6.
capture confirm variable raise_time1
if !_rc {
    gen d_raise_time = raise_time2 - raise_time1
}
capture confirm variable first_raise1
if !_rc {
    gen d_first_raise = first_raise2 - first_raise1
    gen wage_profile_slope1 = first_raise1/raise_time1 if raise_time1 > 0
    gen wage_profile_slope2 = first_raise2/raise_time2 if raise_time2 > 0
    gen d_wage_profile_slope = wage_profile_slope2 - wage_profile_slope1
}

* Create mutually exclusive regression-control indicators. The fourth chain is
* the omitted category when all four are included with a constant.
gen chain_bk = chain_code == 1 if !missing(chain_code)
gen chain_kfc = chain_code == 2 if !missing(chain_code)
gen chain_royers = chain_code == 3 if !missing(chain_code)
gen chain_wendys = chain_code == 4 if !missing(chain_code)

* Permanent closures have no second-wave wage; retaining them is necessary
* to reproduce the published 357-store employment regression sample.
gen byte sample_balanced = !missing(fte1, fte2)
gen byte sample_reg = sample_balanced & !missing(wage1, gap) & ///
    (!missing(wage2) | wave2_status == 3)
gen byte sample_price = sample_reg & !missing(d_log_fullmeal)
label variable sample_balanced "Both waves have valid FTE employment"
label variable sample_reg "Employment regression sample, closures retained"
label variable sample_price "Valid log meal-price change in regression sample"

* Flag repeated source identifiers rather than dropping distinct survey rows.
duplicates tag store_id, generate(sheet_duplicate)
sort row_id
label variable sheet_duplicate "Number of additional rows with the same SHEET"
label variable d_fte "Change in FTE employment, wave 2 minus wave 1"
label variable d_fte_tempzero "FTE change with temporary closures assigned zero"
label variable pct_d_fte "FTE change divided by initial FTE employment"
label variable chain_code "Restaurant chain"
label variable north_nj "Northern New Jersey indicator"
label variable central_nj "Central New Jersey indicator"
label variable south_nj "Southern New Jersey indicator"
label variable pa_philly "Pennsylvania Philadelphia suburbs indicator"
label variable pa_easton "Pennsylvania Easton area indicator"
label variable wave2_date "Second-wave interview date"
foreach t in 1 2 {
    label variable empft`t' "Wave-`t' full-time nonmanagement employees"
    label variable emppt`t' "Wave-`t' part-time nonmanagement employees"
    label variable managers`t' "Wave-`t' managers and assistant managers"
}

* Fail on structural errors, but report unexplained publication differences
* without trimming observations just to match a target sample size.
assert _N == 410
isid row_id
assert fte2 == 0 if wave2_status == 3
assert missing(fte2) if inlist(wave2_status, 0, 2, 4, 5)
assert gap == 0 if nj == 0
assert missing(gap) if nj == 1 & missing(wage1)
quietly count if sample_reg
local n_reg = r(N)
quietly count if sample_price
local n_price = r(N)

preserve
clear
set obs 3
gen str32 sample = ""
gen int actual = .
gen int paper_target = .
replace sample = "All survey rows" in 1
replace actual = 410 in 1
replace paper_target = 410 in 1
replace sample = "Employment regression" in 2
replace actual = `n_reg' in 2
replace paper_target = 357 in 2
replace sample = "Price complete cases" in 3
replace actual = `n_price' in 3
replace paper_target = 315 in 3
gen byte matches_paper = actual == paper_target
export delimited using "$output/checks/sample_counts.csv", replace
list, noobs
restore
if `n_price' != 315 {
    di as error "NOTE: price sample = `n_price'; paper target = 315. No rows dropped to force agreement."
}

* Save only the transformed copy in the temporary-data directory.
save "$temp/ck1994_clean.dta", replace

* Write an audit log with counts needed before estimating any table.
quietly count
display as result "Observations: " r(N)
tab nj, missing
tab chain_code, missing
tab wave2_status, missing
tab nj_wage425, missing
tab nj_wagemid, missing
tab nj_wagehigh500, missing
summarize fte1 fte2 d_fte wage1 wage2 gap fullmeal1 fullmeal2 d_log_fullmeal
count if sample_reg
display as result "Employment regression sample (permanent closures retained): " r(N)
count if sample_price
display as result "Price regression complete cases (paper target 315): " r(N)
list row_id store_id nj chain_code if sheet_duplicate > 0, noobs
summarize d_fte if sample_reg
misstable summarize fte1 fte2 wage1 wage2 gap d_fte fullmeal1 fullmeal2 d_log_fullmeal

log close
