version 18
clear all
set more off
capture log close

* 请先运行 0_master.do 定义路径；本文件只读取清洗数据。
if "$root" == "" {
    display as error "Run 0_master.do to define project paths first."
    exit 198
}
capture mkdir "$output/tables"
log using "$output/logs/2_descriptive.log", replace text
use "$temp/ck1994_clean.dta", clear
assert _N == 410

* Table 2 按每个变量的非缺失样本统计，而非限制在357家回归样本。
* EMPFT 不含经理；论文全职比例的分母为含经理的FTE就业。
* 局部重算此指标，避免清洗文件中原有比例口径影响本表。
gen double table2_fulltime1 = 100*empft1/fte1 if fte1 > 0 & !missing(fte1)
gen double table2_fulltime2 = 100*empft2/fte2 if fte2 > 0 & !missing(fte2)

* 以百分数呈现连锁构成、所有权、工资集中度与招聘奖金。
* 浮点工资转换为美分再比较，避免4.25或5.05的存储精度差异。
foreach c in bk kfc royers wendys {
    gen double table2_`c' = 100*chain_`c'
}
gen double table2_owned = 100*company_owned
* 原表工资集中度以各州全部门店为分母（NJ=331、PA=79）；
* 缺失工资不计入指定工资水平的分子，工资均值仍排除缺失。
gen double table2_w425_1 = 100*(round(wage1*100) == 425)
gen double table2_w425_2 = 100*(round(wage2*100) == 425)
gen double table2_w505_2 = 100*(round(wage2*100) == 505)
gen double table2_bonus1 = 100*recruiting_bonus1
* 第二轮问卷中的 SPECIAL2 对应本表第二轮招聘计划指标。
gen double table2_bonus2 = 100*special_program2

label variable table2_bk "Burger King (%)"
label variable table2_kfc "KFC (%)"
label variable table2_royers "Roy Rogers (%)"
label variable table2_wendys "Wendy's (%)"
label variable table2_owned "Company-owned (%)"
foreach w in 1 2 {
    label variable fte`w' "FTE employment"
    label variable table2_fulltime`w' "Full-time employees (%)"
    label variable wage`w' "Starting wage ($/hour)"
    label variable table2_w425_`w' "Wage = $4.25 (%)"
    label variable fullmeal`w' "Full meal price ($, including tax)"
    label variable hours_open`w' "Hours open per weekday"
    label variable table2_bonus`w' "Recruiting bonus (%)"
}
label variable table2_w505_2 "Wage = $5.05 (%)"

local types table2_bk table2_kfc table2_royers table2_wendys table2_owned
local wave1 fte1 table2_fulltime1 wage1 table2_w425_1 fullmeal1 hours_open1 table2_bonus1
local wave2 fte2 table2_fulltime2 wage2 table2_w425_2 table2_w505_2 fullmeal2 hours_open2 table2_bonus2

* 保留未四舍五入的统计结果，便于核查均值、标准误和样本量。
* 两组方差分别估计；t的符号统一为NJ减PA，与论文一致。
tempfile table2_results
tempname results
postfile `results' byte panel row str60 outcome int n_nj n_pa ///
    double mean_nj se_nj mean_pa se_pa diff t_stat ///
    using `table2_results', replace
local row = 0
forvalues panel = 1/3 {
    if `panel' == 1 local variables `types'
    if `panel' == 2 local variables `wave1'
    if `panel' == 3 local variables `wave2'
    foreach v of local variables {
        local ++row
        local outcome : variable label `v'
        quietly summarize `v' if nj == 1
        local n_nj = r(N)
        local mean_nj = r(mean)
        local se_nj = r(sd)/sqrt(r(N))
        quietly summarize `v' if nj == 0
        local n_pa = r(N)
        local mean_pa = r(mean)
        local se_pa = r(sd)/sqrt(r(N))
        local diff = `mean_nj' - `mean_pa'
        local t = `diff'/sqrt(`se_nj'^2 + `se_pa'^2)
        * 原表第二轮$4.25工资行未报告t，保留相同展示规则。
        if "`v'" == "table2_w425_2" local t = .
        post `results' (`panel') (`row') ("`outcome'") ///
            (`n_nj') (`n_pa') (`mean_nj') (`se_nj') ///
            (`mean_pa') (`se_pa') (`diff') (`t')
    }
}
postclose `results'

* 统计输出在独立结果数据中完成，不覆盖ck1994_clean.dta。
preserve
use `table2_results', clear
label define panels 1 "Distribution of store types" 2 "Means in wave 1" 3 "Means in wave 2"
label values panel panels
format mean_nj mean_pa se_nj se_pa diff %9.3f
format t_stat %9.1f
export delimited using "$output/tables/table2_descriptive.csv", replace
save "$output/tables/table2_descriptive.dta", replace
list panel outcome n_nj mean_nj se_nj n_pa mean_pa se_pa t_stat, noobs sepby(panel) abbreviate(24)

* RTF采用内置file命令，无需安装外部包；Word可直接打开。
* 店铺构成按论文仅展示均值；其余行同时展示均值和标准误。
tempname rtf
file open `rtf' using "$output/tables/table2_descriptive.rtf", write replace
file write `rtf' "{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\f0\fs20" _n
file write `rtf' "\b Table 2. Means of Key Variables\b0\par" _n
file write `rtf' "Variable\tab NJ\tab PA\tab t (NJ - PA)\par" _n
forvalues i = 1/20 {
    if `i' == 1 file write `rtf' "\b 1. Distribution of store types (%)\b0\par" _n
    if `i' == 6 file write `rtf' "\b 2. Means in wave 1\b0\par" _n
    if `i' == 13 file write `rtf' "\b 3. Means in wave 2\b0\par" _n
    local text = outcome[`i']
    local njmean : display %6.2f mean_nj[`i']
    local pamean : display %6.2f mean_pa[`i']
    local njse : display %6.2f se_nj[`i']
    local pase : display %6.2f se_pa[`i']
    local t : display %5.1f t_stat[`i']
    if missing(t_stat[`i']) local t "--"
    if `i' <= 5 {
        file write `rtf' "`text'\tab `njmean'\tab `pamean'\tab `t'\par" _n
    }
    else {
        file write `rtf' "`text'\tab `njmean' (`njse')\tab `pamean' (`pase')\tab `t'\par" _n
    }
}
file write `rtf' "\par Standard errors in parentheses. Each row uses all available observations.\par" _n
file write `rtf' "Permanent closures: wave-2 FTE = 0. Temporary closures: wave-2 FTE missing.\par" _n
file write `rtf' "Full-time percentage = 100 x nonmanagement full-time workers / FTE employment.\par" _n
file write `rtf' "NJ - PA t statistics use separate group variance estimates. Sample sizes are in the CSV.\par}" _n
file close `rtf'
restore
log close
