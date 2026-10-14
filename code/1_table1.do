version 18
clear all
set more off
capture log close

* Card and Krueger (1994), Table 1: basic descriptive statistics.
* This file reads the cleaned analytic copy only; the raw survey is never changed.
if "$root" == "" {
    display as error "Run 0_master.do to define project paths first."
    exit 198
}
capture mkdir "$output/tables"
log using "$output/logs/1_table1.log", replace text

use "$temp/ck1994_clean.dta", clear
assert _N == 410
isid row_id

* 清洗数据的全职比例为非管理全职员工占非管理员工总数的百分比。
* 沿用已保存的指标，保证本表与输入数据口径一致。
* 将两期整理成长格式，以便按州和调查期分别使用各变量的有效观测。
keep row_id nj fte1 fte2 wage1 wage2 hours_open1 hours_open2 ///
    pct_fulltime1 pct_fulltime2 fullmeal1 fullmeal2
reshape long fte wage hours_open pct_fulltime fullmeal, i(row_id) j(wave)
assert inlist(wave, 1, 2)
assert inlist(nj, 0, 1)

* Use descriptive labels matching the paper's economic interpretation.
label variable fte "FTE employment"
label variable wage "Starting wage ($/hour)"
label variable hours_open "Hours open per weekday"
label variable pct_fulltime "Full-time workers (%)"
label variable fullmeal "Full meal price ($, including tax)"

* 每个变量单独排除缺失值，不限制为回归样本或两期均有回答的样本。
* Difference 是两期可用样本均值之差，不是配对餐厅变化量的均值。
tempfile results
local variables fte wage hours_open pct_fulltime fullmeal
local names fte wage_st hrsopen pct_fulltime meal_price
tempname handle
postfile `handle' byte variable_id str16 variable str60 variable_label byte nj ///
    int n_wave1 int n_wave2 double mean_wave1 double mean_wave2 double difference ///
    using `results', replace

local variable_id = 0
foreach v of local variables {
    local ++variable_id
    local variable_label : variable label `v'
    local variable_name : word `variable_id' of `names'
    foreach s in 0 1 {
        quietly summarize `v' if nj == `s' & wave == 1
        local n1 = r(N)
        local m1 = r(mean)
        quietly summarize `v' if nj == `s' & wave == 2
        local n2 = r(N)
        local m2 = r(mean)
        local d = `m2' - `m1'
        post `handle' (`variable_id') ("`variable_name'") ("`variable_label'") (`s') ///
            (`n1') (`n2') (`m1') (`m2') (`d')
    }
}
postclose `handle'

use `results', clear
assert _N == 10
sort variable_id nj
label define state_lbl 0 "Pennsylvania" 1 "New Jersey", replace
label values nj state_lbl
label variable variable_id "Variable order"
label variable variable_label "Outcome"
label variable nj "State"
label variable n_wave1 "Wave 1 observations"
label variable n_wave2 "Wave 2 observations"
label variable mean_wave1 "Wave 1 mean"
label variable mean_wave2 "Wave 2 mean"
label variable difference "Difference: wave 2 minus wave 1"
format mean_wave1 mean_wave2 difference %9.4f

* CSV preserves full precision and sample counts for auditability.
export delimited using "$output/tables/table1_summary.csv", replace
save "$output/tables/table1_summary.dta", replace
list variable_label nj n_wave1 mean_wave1 n_wave2 mean_wave2 difference, noobs sepby(variable_id) abbreviate(24)

* Write a compact RTF table with one row per state and variable. The RTF is
* generated with Stata's built-in file command, so no external package is needed.
tempname rtf
file open `rtf' using "$output/tables/table1_summary.rtf", write replace
file write `rtf' "{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\f0\fs20" _n
file write `rtf' "\b Table 1. Basic Descriptive Statistics\b0\par" _n
file write `rtf' "Variable\tab State\tab Wave 1 mean\tab Wave 2 mean\tab Difference\par" _n
* 直接读取结果行的标签，避免 levelsof 生成的嵌套引号干扰RTF写入。
forvalues i = 1/10 {
    local text = variable_label[`i']
    local s = nj[`i']
    local state : label state_lbl `s'
    local m1 : display %8.3f mean_wave1[`i']
    local m2 : display %8.3f mean_wave2[`i']
    local d : display %8.3f difference[`i']
    file write `rtf' "`text'\tab `state'\tab `m1'\tab `m2'\tab `d'\par" _n
}
file write `rtf' "\par Notes: Difference = wave 2 mean minus wave 1 mean. Means use all nonmissing observations for each state-wave-variable cell.\par" _n
file write `rtf' "FTE employment is full-time workers plus managers plus one-half of part-time workers. Full-time workers (%) is 100 times nonmanagement full-time workers divided by total nonmanagement full-time and part-time workers.\par" _n
file write `rtf' "Wave 2 permanent closures have FTE equal to zero; temporary closures remain missing. Observation counts are reported in the CSV.\par}" _n
file close `rtf'

log close
