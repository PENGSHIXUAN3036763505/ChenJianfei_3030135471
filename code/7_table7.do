version 18
clear all
set more off
capture log close

* 所有路径沿用主控文件；只读取清洗数据，不改写原始或清洗文件。
if "$root" == "" {
    display as error "Run 0_master.do first to define project paths."
    exit 198
}
capture mkdir "$output/tables"
capture mkdir "$output/checks"
log using "$output/logs/7_table7.log", replace text
use "$temp/ck1994_clean.dta", clear
assert _N == 410

* 套餐为中杯汽水、小薯条和主菜的含税价格之和。
* 任一价格缺失时套餐也缺失，不能用忽略缺失值的行求和。
gen double t7_price1 = soda1 + fries1 + entree1
gen double t7_price2 = soda2 + fries2 + entree2
gen double t7_dlog = ln(t7_price2) - ln(t7_price1) ///
    if t7_price1 > 0 & t7_price2 > 0 & !missing(t7_price1, t7_price2)
label variable t7_dlog "Change in log after-tax full-meal price"

* 五个模型使用同一样本，以便系数变化只反映控制变量的加入。
* 当前公开数据产生317个完整观察值；不为匹配论文315而人为删店。
gen byte t7_sample = sample_reg == 1 & !missing(t7_dlog)
assert t7_sample == sample_price
count if t7_sample
local sample_n = r(N)
assert `sample_n' == 317
assert !missing(nj, gap, chain_code, company_owned, central_nj, ///
    south_nj, pa_philly, pa_easton) if t7_sample
summarize t7_dlog if t7_sample
local outcome_mean = r(mean)
local outcome_sd = r(sd)

* Burger King和北部NJ分别作为连锁与地区基准。
* 普通OLS标准误对应论文，表内价格为含税价格，不另作税率调整。
local chain_controls "ib1.chain_code company_owned"
local region_controls "central_nj south_nj pa_philly pa_easton"
tempfile results
tempname handle
postfile `handle' byte model str8 exposure int N ///
    double coefficient se p_value rmse r_squared ///
    byte chain_ownership regions using `results', replace
forvalues m = 1/5 {
    local controls ""
    local chain = 0
    local region = 0
    if `m' <= 2 local exposure nj
    else local exposure gap
    if inlist(`m', 2, 4, 5) {
        local controls "`chain_controls'"
        local chain = 1
    }
    if `m' == 5 {
        local controls "`controls' `region_controls'"
        local region = 1
    }
    regress t7_dlog `exposure' `controls' if t7_sample
    assert e(N) == `sample_n'
    estimates store table7_m`m'
    estimates save "$output/tables/table7_model`m'.ster", replace
    local p = 2*ttail(e(df_r), abs(_b[`exposure']/_se[`exposure']))
    post `handle' (`m') ("`exposure'") (e(N)) ///
        (_b[`exposure']) (_se[`exposure']) (`p') (e(rmse)) ///
        (e(r2)) (`chain') (`region')
}
postclose `handle'

* 原始精度的估计及样本统计单独保存，便于后续检查。
use `results', clear
sort model
assert _N == 5
isid model
gen double outcome_mean = `outcome_mean'
gen double outcome_sd = `outcome_sd'
label variable se "Conventional OLS standard error"
label variable rmse "Standard error of regression"
format coefficient se rmse outcome_mean outcome_sd %9.4f
save "$output/tables/table7_prices.dta", replace
export delimited using "$output/tables/table7_prices.csv", replace
list model exposure N coefficient se rmse, noobs

* 论文目标仅用于比较，绝不替换实际估计。
local published_b "0.033 0.037 0.077 0.146 0.063"
local published_se "0.014 0.014 0.075 0.074 0.089"
local published_rmse "0.101 0.097 0.102 0.098 0.097"
gen double paper_b = .
gen double paper_se = .
gen double paper_rmse = .
forvalues m = 1/5 {
    local b : word `m' of `published_b'
    local s : word `m' of `published_se'
    local r : word `m' of `published_rmse'
    replace paper_b = `b' in `m'
    replace paper_se = `s' in `m'
    replace paper_rmse = `r' in `m'
}
gen int paper_N = 315
gen double paper_outcome_mean = 0.0173
gen double paper_outcome_sd = 0.1017
gen double coefficient_difference = coefficient - paper_b
gen double se_difference = se - paper_se
gen double rmse_difference = rmse - paper_rmse
export delimited using "$output/checks/table7_comparison.csv", replace

* 使用Stata内置文件命令生成RTF，无需安装外部包。
* 横向页面及明确制表位便于呈现五个模型列。
tempname rtf
file open `rtf' using "$output/tables/table7_prices.rtf", write replace
file write `rtf' "{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\landscape\paperw16840\paperh11907\margl720\margr720\f0\fs20" _n
file write `rtf' "\b Table 7. Reduced-Form Models for Change in the Price of a Full Meal\b0\par" _n
file write `rtf' "\tx6500\tx8100\tx9700\tx11300\tx12900 Variable\tab (i)\tab (ii)\tab (iii)\tab (iv)\tab (v)\par" _n
forvalues row = 1/5 {
    if `row' == 1 local title "1. New Jersey dummy"
    if `row' == 2 local title "2. Initial wage gap"
    if `row' == 3 local title "3. Chain and ownership controls"
    if `row' == 4 local title "4. Region controls"
    if `row' == 5 local title "5. Standard error of regression"
    file write `rtf' "`title'"
    forvalues m = 1/5 {
        local cell "--"
        if (`row' == 1 & `m' <= 2) | (`row' == 2 & `m' >= 3) {
            local b : display %6.3f coefficient[`m']
            local s : display %6.3f se[`m']
            local cell "`b' (`s')"
        }
        if `row' == 3 {
            if chain_ownership[`m'] local cell "yes"
            else local cell "no"
        }
        if `row' == 4 {
            if regions[`m'] local cell "yes"
            else local cell "no"
        }
        if `row' == 5 local cell : display %6.3f rmse[`m']
        file write `rtf' "\tab `cell'"
    }
    file write `rtf' "\par" _n
}
local mean_text : display %7.4f `outcome_mean'
local sd_text : display %7.4f `outcome_sd'
file write `rtf' "\par Notes: Conventional OLS standard errors in parentheses. All models include a constant.\par" _n
file write `rtf' "Dependent variable: ln(full-meal price in wave 2) minus ln(full-meal price in wave 1). Prices include tax.\par" _n
file write `rtf' "Actual sample: `sample_n' stores (paper: 315). Outcome mean: `mean_text'; SD: `sd_text'.\par" _n
file write `rtf' "Chain reference: Burger King. Region reference: North NJ.\par}" _n
file close `rtf'
log close
