version 18
clear all
set more off
capture log close

* 路径由主控文件统一定义；本文件只读取清洗数据，不改写原始数据。
if "$root" == "" {
    display as error "Run 0_master.do first to define project paths."
    exit 198
}
capture mkdir "$output/figure"
log using "$output/figure/figure1.log", replace text
use "$temp/ck1994_clean.dta", clear
assert _N == 410
isid row_id
keep row_id nj wage1 wage2

* 长格式使两次调查使用同一套分组规则；各期分别纳入有效工资，不要求平衡面板。
reshape long wage, i(row_id) j(wave)
assert inlist(nj, 0, 1)
gen byte valid_wage = !missing(wage)
assert wage > 0 if valid_wage
preserve
collapse (count) total_stores=row_id (sum) valid_wages=valid_wage, by(wave nj)
gen int missing_wages = total_stores - valid_wages
assert total_stores == 79 if nj == 0
assert total_stores == 331 if nj == 1
assert valid_wages == 76 if wave == 1 & nj == 0
assert valid_wages == 314 if wave == 1 & nj == 1
assert valid_wages == 71 if wave == 2 & nj == 0
assert valid_wages == 318 if wave == 2 & nj == 1
export delimited using "$output/figure/figure1_sample_counts.csv", replace
list, noobs
restore
keep if valid_wage

* 先转成整数美分，避免浮点表示影响边界归类；保留所有有效工资及尾部观察值。
gen int wage_cents = round(wage*100)
preserve
contract wave nj wage_cents, freq(stores)
bysort wave nj: egen int valid_wages = total(stores)
gen double percent = 100*stores/valid_wages
gen double wage_dollars = wage_cents/100
sort wave nj wage_cents
export delimited using "$output/figure/figure1_exact_wage_frequencies.csv", replace
restore

* 分档用于清楚比较两州，5.05美元单列以显示政策后的集中程度；分档并非原图的精确复刻。
gen byte wage_bin = .
replace wage_bin = 1 if wage_cents <= 425
replace wage_bin = 2 if inrange(wage_cents, 426, 449)
replace wage_bin = 3 if inrange(wage_cents, 450, 474)
replace wage_bin = 4 if inrange(wage_cents, 475, 499)
replace wage_bin = 5 if inrange(wage_cents, 500, 504)
replace wage_bin = 6 if wage_cents == 505
replace wage_bin = 7 if inrange(wage_cents, 506, 524)
replace wage_bin = 8 if inrange(wage_cents, 525, 549)
replace wage_bin = 9 if inrange(wage_cents, 550, 574)
replace wage_bin = 10 if wage_cents >= 575
assert !missing(wage_bin)
label define wage_bins 1 "<=4.25" 2 "4.26-4.49" 3 "4.50-4.74" ///
    4 "4.75-4.99" 5 "5.00-5.04" 6 "5.05" 7 "5.06-5.24" ///
    8 "5.25-5.49" 9 "5.50-5.74" 10 ">=5.75"
label values wage_bin wage_bins

* 补齐零频数档位，让两个面板具有相同的横轴；百分比在州×调查期内加总为100。
contract wave nj wage_bin, freq(stores)
fillin wave nj wage_bin
replace stores = 0 if _fillin
 drop _fillin
bysort wave nj: egen int valid_wages = total(stores)
gen double percent = 100*stores/valid_wages
bysort wave nj: egen double percent_total = total(percent)
assert abs(percent_total-100) < 1e-8
assert _N == 40
assert stores == 283 if wave == 2 & nj == 1 & wage_bin == 6
assert stores == 1 if wave == 2 & nj == 1 & wage_bin == 5
assert stores == 1 if wave == 2 & nj == 0 & wage_bin == 10
drop percent_total
gen str13 state = cond(nj == 1, "New Jersey", "Pennsylvania")
gen str20 survey = cond(wave == 1, "February 1992", "November 1992")
decode wage_bin, gen(wage_range)
sort wave nj wage_bin
save "$output/figure/figure1_binned_frequencies.dta", replace
export delimited using "$output/figure/figure1_binned_frequencies.csv", replace

* 并排柱形保留各州百分比的直观可比性；统一纵轴防止面板尺度造成误导。
keep wave nj wage_bin percent
reshape wide percent, i(wave wage_bin) j(nj)
label variable percent0 "Pennsylvania"
label variable percent1 "New Jersey"
set scheme s2color
forvalues w = 1/2 {
    local panel "February 1992"
    local sample "Valid wages: PA = 76; NJ = 314"
    if `w' == 2 {
        local panel "November 1992"
        local sample "Valid wages: PA = 71; NJ = 318"
    }
    graph bar (asis) percent0 percent1 if wave == `w', ///
        over(wage_bin, label(angle(30) labsize(small))) ///
        bar(1, color(navy)) bar(2, color(maroon)) ///
        ylabel(0(20)100, angle(horizontal)) yscale(range(0 100)) ///
        ytitle("Percent of stores with observed wages") ///
        title("`panel'", size(medium)) subtitle("`sample'", size(small)) ///
        legend(order(1 "Pennsylvania" 2 "New Jersey") rows(1) size(small)) ///
        graphregion(color(white)) plotregion(color(white)) ///
        name(figure1_wave`w', replace)
}
graph combine figure1_wave1 figure1_wave2, cols(1) ycommon ///
    title("Figure 1. Distribution of Starting Wage Rates", size(medium)) ///
    note("Starting wage bins in dollars per hour. Percentages use observed wages in each state and wave." ///
         "The $5.05 category is shown separately; endpoint bins retain all wage observations.", size(vsmall)) ///
    graphregion(color(white)) xsize(10) ysize(10) name(figure1, replace)
graph save "$output/figure/figure1.gph", replace
graph export "$output/figure/figure1.png", width(2400) replace
graph export "$output/figure/figure1.pdf", replace
log close
