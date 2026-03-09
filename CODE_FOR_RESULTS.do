version 17
set more off
clear all
capture log close
log using "log_tables.log", replace text

* Replication code — loads DATASET_FINALE_V4.dta and produces all tables in the report

use "DATASET_FINALE_V4.dta", clear

cap drop ind_quarter_main
egen ind_quarter_main = group(ff12_n quarter)

bysort quarter: egen mc_p20 = pctile(market_cap), p(20)
keep if market_cap >= mc_p20
drop mc_p20

cap drop year
gen year = yofd(dofq(quarter))
keep if inrange(year, 1980, 2025)

cap drop n_quarters
bysort cusip_n: gen n_quarters = _N
keep if n_quarters >= 20
drop n_quarters

drop if D_fq == . | log_size == . | IO == .

xtset cusip_n quarter

local controls "log_size tobinq cashflow cashhold IO top5share momentum"

sort cusip_n quarter
by cusip_n: gen D_ma3 = (D_fq + L.D_fq + L2.D_fq) / 3


* Table 1 — Summary statistics

local vars "merger diversifying within_industry D_fq log_size tobinq cashflow cashhold IO top5share"

estpost tabstat `vars', stats(mean sd p25 p50 p75 n) columns(statistics)
esttab using "Table1_descriptives.csv", ///
	cells("mean(fmt(%9.4f)) sd(fmt(%9.4f)) p25(fmt(%9.4f)) p50(fmt(%9.4f)) p75(fmt(%9.4f)) count(fmt(%9.0fc))") ///
	noobs replace label title("Table 1: Summary Statistics")


* Table 2 Panel A — contemporaneous distraction, full sample 1980-2025

foreach depvar in merger diversifying within_industry {
	reghdfe `depvar' D_fq `controls', absorb(ind_quarter_main) vce(cluster cusip_n)
	if "`depvar'" == "merger"          est store pa_col1
	if "`depvar'" == "diversifying"    est store pa_col2
	if "`depvar'" == "within_industry" est store pa_col3
}

foreach depvar in merger diversifying within_industry {
	reghdfe `depvar' D_fq `controls', absorb(ind_quarter_main cusip_n) vce(cluster cusip_n)
	if "`depvar'" == "merger"          est store pa_col4
	if "`depvar'" == "diversifying"    est store pa_col5
	if "`depvar'" == "within_industry" est store pa_col6
}

esttab pa_col1 pa_col2 pa_col3 pa_col4 pa_col5 pa_col6, ///
	keep(D_fq IO top5share) b(3) t(2) star(* 0.10 ** 0.05 *** 0.01) ///
	stats(N r2_within r2, fmt(%9.0fc %9.3f %9.3f) labels("N" "Within R2" "R2")) ///
	mtitles("All" "Diversifying" "Within-ind." "All FE" "Div FE" "Within FE") ///
	title("Table 2 Panel A") ///
	note("IQ FE in all columns. Firm FE in (4)-(6). SE clustered at firm level.")

sum merger
local base = r(mean)
est restore pa_col1
local coef = _b[D_fq]
sum D_fq
local sd = r(sd)
di "1-SD distraction: merger prob +=" %5.1f (`coef'*`sd'/`base'*100) "% (KMS benchmark: 29%)"


* Table 2 Panel B — three-quarter moving average distraction MA(-2,0)

foreach depvar in merger diversifying within_industry {
	reghdfe `depvar' D_ma3 `controls', absorb(ind_quarter_main) vce(cluster cusip_n)
	if "`depvar'" == "merger"          est store pb_col1
	if "`depvar'" == "diversifying"    est store pb_col2
	if "`depvar'" == "within_industry" est store pb_col3
}

foreach depvar in merger diversifying within_industry {
	reghdfe `depvar' D_ma3 `controls', absorb(ind_quarter_main cusip_n) vce(cluster cusip_n)
	if "`depvar'" == "merger"          est store pb_col4
	if "`depvar'" == "diversifying"    est store pb_col5
	if "`depvar'" == "within_industry" est store pb_col6
}

esttab pb_col1 pb_col2 pb_col3 pb_col4 pb_col5 pb_col6, ///
	keep(D_ma3 IO top5share) b(3) t(2) star(* 0.10 ** 0.05 *** 0.01) ///
	stats(N r2_within r2, fmt(%9.0fc %9.3f %9.3f) labels("N" "Within R2" "R2")) ///
	mtitles("All" "Diversifying" "Within-ind." "All FE" "Div FE" "Within FE") ///
	title("Table 2 Panel B — Moving average MA(-2,0)") ///
	note("D_ma3 = (D_q + D_{q-1} + D_{q-2})/3. IQ FE in all. Firm FE in (4)-(6). SE clustered at firm level.")


* Identification checks — lag structure and placebo test (reported in text section 3.2)

gen D_lag1 = L.D_fq
gen D_lag2 = L2.D_fq
gen D_lag3 = L3.D_fq
gen D_lag4 = L4.D_fq

reghdfe merger D_fq D_lag1 D_lag2 D_lag3 D_lag4 `controls', ///
	absorb(ind_quarter_main cusip_n) vce(cluster cusip_n)

di "Lag structure:"
foreach v in D_fq D_lag1 D_lag2 D_lag3 D_lag4 {
	di "  `v':  b = " %7.4f _b[`v'] "  t = " %6.2f _b[`v']/_se[`v']
}

test (D_lag3 = 0) (D_lag4 = 0)
di "Joint test D_lag3=D_lag4=0:  F = " %6.3f r(F) "  p = " %6.4f r(p)

gen D_lead4 = F4.D_fq
quietly reghdfe merger D_fq D_lead4 `controls', absorb(ind_quarter_main cusip_n) vce(cluster cusip_n)
quietly test D_lead4 = 0
di "Placebo D_lead4:  F = " %6.3f r(F) "  p = " %6.4f r(p)

drop D_lead4 D_lag1 D_lag2 D_lag3 D_lag4


* Table 3 — substitution by alternative monitors

xtile size_tercile = log_size, nquantiles(3)
gen small_firm     = (size_tercile == 1)
gen large_firm     = (size_tercile == 3)
quietly sum IO, detail
gen low_IO_breadth = (IO < r(p50))

local controls_sub "tobinq cashflow cashhold IO top5share momentum"

reghdfe merger c.D_fq##i.small_firm `controls_sub', absorb(ind_quarter_main) vce(cluster cusip_n)
est store sub_m1
quietly lincom D_fq + 1.small_firm#c.D_fq
local te_small = r(estimate)
local tp_small = 2*ttail(r(df), abs(r(estimate)/r(se)))

reghdfe merger c.D_fq##i.large_firm `controls_sub', absorb(ind_quarter_main) vce(cluster cusip_n)
est store sub_m2

reghdfe diversifying c.D_fq##i.small_firm `controls_sub', absorb(ind_quarter_main) vce(cluster cusip_n)
est store sub_m3

reghdfe merger c.D_fq##i.low_IO_breadth `controls_sub', absorb(ind_quarter_main) vce(cluster cusip_n)
est store sub_m4
quietly lincom D_fq + 1.low_IO_breadth#c.D_fq
local te_lowIO = r(estimate)
local tp_lowIO = 2*ttail(r(df), abs(r(estimate)/r(se)))

reghdfe merger c.D_fq##i.low_IO_breadth `controls_sub', absorb(ind_quarter_main cusip_n) vce(cluster cusip_n)
est store sub_m5

esttab sub_m1 sub_m2 sub_m3 sub_m4 sub_m5, ///
	keep(D_fq 1.small_firm 1.small_firm#c.D_fq ///
	     1.large_firm 1.large_firm#c.D_fq ///
	     1.low_IO_breadth 1.low_IO_breadth#c.D_fq) ///
	b(3) t(2) star(* 0.10 ** 0.05 *** 0.01) ///
	stats(N r2, fmt(%9.0fc %9.3f) labels("N" "R2")) ///
	mtitles("All x Small" "All x Large" "Div x Small" "All x LowIO" "All x LowIO FE") ///
	title("Table 3: Substitution by Alternative Monitors") ///
	note("Small/Large: bottom/top tercile log size. Low IO: below median IO. IQ FE in all. Firm FE in (5). SE clustered at firm level.")

di "Total effect small firms:  b = " %6.4f `te_small' "  p = " %5.3f `tp_small'
di "Total effect low-IO firms: b = " %6.4f `te_lowIO' "  p = " %5.3f `tp_lowIO'

drop small_firm large_firm low_IO_breadth size_tercile


* Table 4 — agency frictions and the distraction effect

drop if top5share == . | cashflow == . | D_fq == .

quietly sum top5share, detail
gen low_top5 = (top5share < r(p50))

quietly sum cashflow, detail
gen high_fcf = (cashflow > r(p50)) & !mi(cashflow)

local controls_top5 "log_size IO cashflow"
local controls_fcf  "log_size IO top5share"

reghdfe merger c.D_fq##i.low_top5 `controls_top5', absorb(ind_quarter_main) vce(cluster cusip_n)
est store m1_t5

reghdfe within_industry c.D_fq##i.low_top5 `controls_top5', absorb(ind_quarter_main) vce(cluster cusip_n)
est store m2_t5

reghdfe merger c.D_fq##i.high_fcf `controls_fcf', absorb(ind_quarter_main) vce(cluster cusip_n)
est store m3_fcf

reghdfe within_industry c.D_fq##i.high_fcf `controls_fcf', absorb(ind_quarter_main) vce(cluster cusip_n)
est store m4_fcf

esttab m1_t5 m2_t5 m3_fcf m4_fcf, ///
	keep(D_fq 1.low_top5 1.low_top5#c.D_fq 1.high_fcf 1.high_fcf#c.D_fq) ///
	b(3) t(2) star(* 0.10 ** 0.05 *** 0.01) ///
	stats(N r2, fmt(%9.0fc %9.3f) labels("N" "R2")) ///
	mtitles("All (Top-5)" "Within (Top-5)" "All (FCF)" "Within (FCF)") ///
	title("Table 4: Agency Frictions and the Distraction Effect") ///
	note("Low top-5: top-5 IO below median. High FCF: cashflow above median. IQ FE in all. SE clustered at firm level.")

est restore m1_t5
quietly lincom D_fq + 1.low_top5#c.D_fq
di "Total effect low top-5 firms:  b = " %6.4f r(estimate)

est restore m3_fcf
quietly lincom D_fq + 1.high_fcf#c.D_fq
di "Total effect high FCF firms:   b = " %6.4f r(estimate)

drop low_top5 high_fcf

capture log close
