version 17
set more off
clear all
capture log close
log using "log_build.log", replace text

* Builds the distraction measure D(f,q) from raw 13F holdings and FF12 industry returns

use "ff_return.dta", clear
rename qrt quarter
keep ff12 quarter extreme
save "ff_return_clean.dta", replace

use "assignement13f.dta", clear
drop if cusip == "" | shares == . | prc == . | shrout1 == .
drop if prc <= 0 | shrout1 <= 0 | shares <= 0
gen cusip8  = substr(cusip, 1, 8)
gen M       = prc * shares
gen quarter = qofd(fdate) + 1
format quarter %tq
keep cusip8 fdate quarter mgrno shares shrout1 M
save "13f_clean.dta", replace

* D(f,q) computed quarter by quarter following KMS eq.1

levelsof fdate, local(fdates)
local first    = 1
local filelist = ""

foreach fd of local fdates {

	local qnum = qofd(`fd') + 1
	local qlab = string(`qnum')

	use "13f_clean.dta" if fdate == `fd', clear
	if _N == 0 { continue }

	merge m:1 cusip8 quarter using "compustat_map_new.dta", keepusing(ff12) keep(3) nogen
	if _N == 0 { continue }
	save "fileraw_temp.dta", replace

	gcollapse (sum) M, by(mgrno fdate quarter ff12)
	gegen sM   = sum(M), by(mgrno fdate)
	gen w_ind  = M / sM
	merge m:1 ff12 quarter using "ff_return_clean.dta", keepusing(extreme) keep(1 3) nogen
	replace extreme = 0 if extreme == .
	gen Y      = w_ind * extreme
	gegen Ysum = sum(Y), by(mgrno fdate)
	keep mgrno fdate quarter ff12 Y Ysum
	save "filesum_temp.dta", replace

	use "fileraw_temp.dta", clear
	gegen sMi       = sum(M), by(mgrno fdate)
	gen pfweight    = M / sMi
	gen percown     = shares / (shrout1 * 1000000)
	replace percown = 0 if percown < 0
	replace percown = 1 if percown > 1 & percown != .
	gquantiles qpfweight = pfweight, xtile nquantiles(5) by(mgrno fdate)
	gquantiles qpercown  = percown,  xtile nquantiles(5) by(cusip8 fdate)
	gen pw_po       = qpfweight + qpercown
	gegen sum_pw_po = sum(pw_po), by(cusip8 fdate)
	gen w           = pw_po / sum_pw_po
	keep mgrno fdate quarter cusip8 ff12 w
	save "fileraw_weights_temp.dta", replace

	use "fileraw_weights_temp.dta", clear
	merge m:1 ff12 mgrno fdate using "filesum_temp.dta", keep(1 3) nogen
	gen Yind = Ysum - Y
	replace Yind = 0 if Yind == . | Yind < 0
	gen D    = w * Yind
	gcollapse (sum) D, by(cusip8 fdate quarter)
	rename D D_fq
	save "dist_q`qlab'.dta", replace

	if `first' == 1 {
		local filelist = "dist_q`qlab'.dta"
		local first    = 0
	}
	else {
		local filelist = "`filelist' dist_q`qlab'.dta"
	}

	clear
	mata: mata clear
}

* Append all quarters into final distraction file

local file1 : word 1 of `filelist'
use "`file1'", clear
local nfiles : word count `filelist'
forvalues j = 2/`nfiles' {
	local fj : word `j' of `filelist'
	append using "`fj'"
}
sort cusip8 quarter
save "DISTRACTION_FINAL.dta", replace

di "DISTRACTION_FINAL.dta saved: " _N " observations"

capture erase "fileraw_temp.dta"
capture erase "filesum_temp.dta"
capture erase "fileraw_weights_temp.dta"
capture erase "ff_return_clean.dta"
capture erase "13f_clean.dta"
foreach f of local filelist {
	capture erase "`f'"
}

capture log close
