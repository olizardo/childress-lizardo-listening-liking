clear all
use "C:\Users\ccchi\OneDrive\Desktop\Dropbox\02 This Week\Omni_Music\analysis_time_CCC.dta" 

drop startdate - info

drop hours_movies - like_movies_genres_23

drop hours_tv - like_tv_192

drop itunes_sort - rotation2_10
drop genre_raw10

*****MIGHT WANT SOME OF THESE AGAIN -- lots of practice variables
drop tv_practice_107 - practice_sports_119

****cosmo
drop cosmo_1_1 - cosmo_3_7

****THIS IS VOLUME!!!! mu_genrelike_count

drop mu_swing_l - mu_metal_l
drop mu_rh_lb_icp - mu_c_hb_jcash
drop mcaarts - leisure_opera_l
drop artist1-artist10
drop genre_method1 - genre_method10
drop allcountries_f2f1diff_unrotated - sports_golf


***GONNA NEED TO FIX THESE 
drop mu_hb_lb_genrecount_diff zgenrecomposition

**NETWORSK AND THEN DROP

*factor network_1 network_2 network_3 network_4 network_5 network_6 network_7 network_8 network_9 network_10 network_11 network_12 network_13 network_14 network_15 network_16 network_17 network_18 network_19 network_20 network_21 network_22 network_23 network_24 network_25 network_26 network_27 network_28 network_29 network_30, pcf


*screeplot, yline(1) (3)
**.9574 Marvelous
*estat kmo

factor network_1 network_2 network_3 network_4 network_5 network_6 network_7 network_8 network_9 network_10 network_11 network_12 network_13 network_14 network_15 network_16 network_17 network_18 network_19 network_20 network_21 network_22 network_23 network_24 network_25 network_26 network_27 network_28 network_29 network_30, pcf factors(3)

rotate, varimax

predict network_working_class_variety  network_pmc  network_public_sector

label var network_working_class_variety "working class variety"
label var network_pmc  "Elite Professional Class"
label var network_public_sector "Public Sector Employees"

drop network_1- network_30






*******************************************************************
* CORRECTED STATA CODE WITH PROPER GENRE MAPPINGS
*******************************************************************

* GENRE MAPPING REFERENCE:
* like_music_genres_21 = Big band / swing (1)
* like_music_genres_22 = Bluegrass (2)
* like_music_genres_23 = Country / western (8)
* like_music_genres_24 = Blues / R&B (3)
* like_music_genres_25 = Musicals / showtunes (15)
* like_music_genres_26 = Classical / symphony (5)
* like_music_genres_27 = Folk (10)
* like_music_genres_28 = Gospel / Christian (11)
* like_music_genres_29 = Jazz (13)
* like_music_genres_30 = Latin / salsa (14)
* like_music_genres_31 = Easy listening (9)
* like_music_genres_32 = New age (16)
* like_music_genres_33 = Opera (18)
* like_music_genres_34 = Rap / hip hop (19)
* like_music_genres_35 = Reggae (20)
* like_music_genres_36 = Contemporary pop (6)
* like_music_genres_37 = Contemporary rock / alt / punk (7)
* like_music_genres_38 = Oldies (17)
* like_music_genres_39 = Classic rock (4)
* like_music_genres_40 = Heavy metal (12)

*******************************************************************
* 1) Define the value label set
label define genre_lbl ///
    1  "Big band / swing" ///
    2  "Bluegrass" ///
    3  "Blues / R&B" ///
    4  "Classic rock" ///
    5  "Classical / symphony" ///
    6  "Contemporary pop" ///
    7  "Contemporary rock / alt / punk" ///
    8  "Country / western" ///
    9  "Easy listening" ///
    10 "Folk" ///
    11 "Gospel / Christian" ///
    12 "Heavy metal" ///
    13 "Jazz" ///
    14 "Latin / salsa" ///
    15 "Musicals / showtunes" ///
    16 "New age" ///
    17 "Oldies" ///
    18 "Opera" ///
    19 "Rap / hip hop" ///
    20 "Reggae", replace

* 2) Attach the value labels to your variables
label values genre_final1-genre_final10 genre_lbl

* 3) Add variable labels + sanity-check range
forvalues i = 1/10 {
    label var genre_final`i' "Music genre (slot `i')"
    assert missing(genre_final`i') | inrange(genre_final`i', 1, 20)
}

* 4) Confirm the label is attached (should show "Value label: genre_lbl")
describe genre_final1-genre_final10

* 5) Show that labels display (note the ", nolabel" comparison)
tab genre_final1, missing
tab genre_final1, missing nolabel

* 6) Browse with labels turned on
browse genre_final1-genre_final10

*************************************************************
***VOLUME

* counts of DISTINCT (non-redundant) genres across genre_final1-genre_final10
* create ID and count how many slots are filled
tempvar _id _nfilled
gen long `_id' = _n
egen byte `_nfilled' = rownonmiss(genre_final1-genre_final10)

preserve
keep `_id' `_nfilled' genre_final1-genre_final10

* reshape to long
reshape long genre_final, i(`_id') j(_slot)

* tag first occurrence of each genre per person
bysort `_id' genre_final: gen byte _tag = (_n == 1)

* count distinct genres
bysort `_id': egen volume_listen_all = total(_tag)
bysort `_id': egen volume_listen_ten = total(_tag) if `_nfilled' == 10

* collapse back to one row per person
bysort `_id': keep if _n == 1
keep `_id' volume_listen_all volume_listen_ten

tempfile _vols
save `_vols', replace
restore

* merge back
merge 1:1 `_id' using `_vols', nogenerate
drop `_id'

* label variables
label var volume_listen_all "not all ten needed"
label var volume_listen_ten "if listed ten"

******
encode stream_source, gen(stream_source_num)
label var stream_source_num "Stream source"

********************************************TEST
* create 0/1 indicators for "7"
forvalues i = 21/40 {
    gen byte _love`i' = (like_music_genres_`i' == 7) if !missing(like_music_genres_`i')
    replace _love`i' = 0 if missing(_love`i')
}

* sum across indicators
egen love_volume = rowtotal(_love21-_love40)

* clean up
drop _love21-_love40

label var love_volume "Number of music genres rated 7 (love)"


*****************************************************
**COMPOSITION

* count how many genre slots are filled
egen _nfilled = rownonmiss(genre_final1-genre_final10)

* initialize variables
gen composition_listen_all = 0
gen composition_listen_ten = .

* loop over the 10 genre slots
forvalues i = 1/10 {

    * add +1 for "highbrow / consecrated" genres
    replace composition_listen_all = composition_listen_all + 1 ///
        if inlist(genre_final`i', 5, 18, 13, 4, 3)

    * subtract -1 for "lowbrow / deconsecrated" genres
    replace composition_listen_all = composition_listen_all - 1 ///
        if inlist(genre_final`i', 12, 19, 16, 9, 20)
}

* restrict second variable to respondents with all ten listed
replace composition_listen_ten = composition_listen_all if _nfilled == 10

* labels
label var composition_listen_all "not all ten needed"
label var composition_listen_ten "if listed ten"

* cleanup
drop _nfilled

****************************************************
*VOLUME GAP

egen z_volume_listen_ten = std(volume_listen_ten)
egen z_mu_genrelike_count = std(mu_genrelike_count)

gen gap_volume_listen_like = z_volume_listen_ten - z_mu_genrelike_count
label var gap_volume_listen_like "Listening–liking gap (z-score difference)"

***OR 
regress volume_listen_ten mu_genrelike_count
predict gap_resid, resid
label var gap_resid "Listening–liking gap (residualized)"


******************************************************
******************************************************
* RACE-CODED LISTENING vs LIKING GAPS
* Two versions: exclude pop (6) and include pop (6=white)
******************************************************
******************************************************

*====================================================
* (A) LIKING SETS (ratings 1–7)
* CORRECTED MAPPING
*====================================================

*-----------------------------
* EXCLUDING POP
*-----------------------------

egen like_expop_white = rowmean( ///
    like_music_genres_21 /// Big band (1)
    like_music_genres_22 /// Bluegrass (2)
    like_music_genres_39 /// Classic rock (4)
    like_music_genres_26 /// Classical (5)
    like_music_genres_37 /// Alt/rock/punk (7)
    like_music_genres_23 /// Country (8)
    like_music_genres_31 /// Easy listening (9)
    like_music_genres_27 /// Folk (10)
    like_music_genres_40 /// Heavy metal (12)
    like_music_genres_25 /// Musicals (15)
    like_music_genres_32 /// New age (16)
    like_music_genres_38 /// Oldies (17)
    like_music_genres_33 /// Opera (18)
)

egen like_expop_nonwhite = rowmean( ///
    like_music_genres_24 /// Blues/R&B (3)
    like_music_genres_28 /// Gospel (11)
    like_music_genres_29 /// Jazz (13)
    like_music_genres_30 /// Latin/salsa (14)
    like_music_genres_34 /// Rap/hip hop (19)
    like_music_genres_35 /// Reggae (20)
)

gen like_expop_diff = like_expop_nonwhite - like_expop_white

label var like_expop_white    "Mean liking: white genres (exclude pop)"
label var like_expop_nonwhite "Mean liking: nonwhite genres (exclude pop)"
label var like_expop_diff     "Liking diff (nonwhite - white), exclude pop"


*-----------------------------
* INCLUDING POP (genre 6 as white)
*-----------------------------

egen like_incpop_white = rowmean( ///
    like_music_genres_21 /// Big band (1)
    like_music_genres_22 /// Bluegrass (2)
    like_music_genres_39 /// Classic rock (4)
    like_music_genres_26 /// Classical (5)
    like_music_genres_36 /// Contemporary pop (6) **** POP
    like_music_genres_37 /// Alt/rock/punk (7)
    like_music_genres_23 /// Country (8)
    like_music_genres_31 /// Easy listening (9)
    like_music_genres_27 /// Folk (10)
    like_music_genres_40 /// Heavy metal (12)
    like_music_genres_25 /// Musicals (15)
    like_music_genres_32 /// New age (16)
    like_music_genres_38 /// Oldies (17)
    like_music_genres_33 /// Opera (18)
)

gen like_incpop_nonwhite = like_expop_nonwhite
gen like_incpop_diff = like_incpop_nonwhite - like_incpop_white

label var like_incpop_white    "Mean liking: white genres (include pop)"
label var like_incpop_nonwhite "Mean liking: nonwhite genres (include pop)"
label var like_incpop_diff     "Liking diff (nonwhite - white), include pop"


*====================================================
* (B) LISTENING SETS (genre_final1–10)
*====================================================

egen _nfilled_listen = rownonmiss(genre_final1-genre_final10)

gen listen_expop_white    = 0
gen listen_expop_nonwhite = 0
gen listen_incpop_white    = 0
gen listen_incpop_nonwhite = 0

forvalues i = 1/10 {

    * NONWHITE listening
    replace listen_expop_nonwhite = listen_expop_nonwhite + 1 ///
        if inlist(genre_final`i', 3,11,13,14,19,20)
    replace listen_incpop_nonwhite = listen_incpop_nonwhite + 1 ///
        if inlist(genre_final`i', 3,11,13,14,19,20)

    * WHITE listening (exclude pop)
    replace listen_expop_white = listen_expop_white + 1 ///
        if inlist(genre_final`i', 1,2,4,5,7,8,9,10,12,15,16,17,18)

    * WHITE listening (include pop)
    replace listen_incpop_white = listen_incpop_white + 1 ///
        if inlist(genre_final`i', 1,2,4,5,6,7,8,9,10,12,15,16,17,18)
}

gen listen_expop_diff = listen_expop_nonwhite - listen_expop_white
gen listen_incpop_diff = listen_incpop_nonwhite - listen_incpop_white

label var listen_expop_white    "Listening count: white genres (exclude pop)"
label var listen_expop_nonwhite "Listening count: nonwhite genres (exclude pop)"
label var listen_expop_diff     "Listening diff (nonwhite - white), exclude pop"

label var listen_incpop_white    "Listening count: white genres (include pop)"
label var listen_incpop_nonwhite "Listening count: nonwhite genres (include pop)"
label var listen_incpop_diff     "Listening diff (nonwhite - white), include pop"


* Ten-only versions
gen listen_expop_diff_ten = listen_expop_diff if _nfilled_listen == 10
gen listen_incpop_diff_ten = listen_incpop_diff if _nfilled_listen == 10

label var listen_expop_diff_ten "Listening diff if listed ten, exclude pop"
label var listen_incpop_diff_ten "Listening diff if listed ten, include pop"


*====================================================
* (C) STANDARDIZED RACE GAPS
*====================================================

egen z_like_expop_diff   = std(like_expop_diff)
egen z_listen_expop_diff = std(listen_expop_diff)
gen racegap_expop = z_listen_expop_diff - z_like_expop_diff
label var racegap_expop "Race enactment gap (z listen - z like), exclude pop"

egen z_like_incpop_diff   = std(like_incpop_diff)
egen z_listen_incpop_diff = std(listen_incpop_diff)
gen racegap_incpop = z_listen_incpop_diff - z_like_incpop_diff
label var racegap_incpop "Race enactment gap (z listen - z like), include pop"


* Ten-only race gaps
gen racegap_expop_ten = racegap_expop if _nfilled_listen == 10
gen racegap_incpop_ten = racegap_incpop if _nfilled_listen == 10

label var racegap_expop_ten "Race enactment gap if listed ten, exclude pop"
label var racegap_incpop_ten "Race enactment gap if listed ten, include pop"


*====================================================
* (D) RESIDUALIZED RACE GAPS (gold standard)
*====================================================

regress listen_expop_diff like_expop_diff
predict racegap_expop_resid, resid
label var racegap_expop_resid "Race enactment gap (residual), exclude pop"

regress listen_incpop_diff like_incpop_diff
predict racegap_incpop_resid, resid
label var racegap_incpop_resid "Race enactment gap (residual), include pop"


* Cleanup
drop _nfilled_listen

************************************************************************************

*==============================
* HIGH vs LOW LIKING (ratings)
*==============================

egen like_high = rowmean( ///
    like_music_genres_26 /// Classical (5)
    like_music_genres_33 /// Opera (18)
    like_music_genres_29 /// Jazz (13)
    like_music_genres_39 /// Classic rock (4)
    like_music_genres_24 /// Blues/R&B (3)
)

egen like_low = rowmean( ///
    like_music_genres_40 /// Heavy metal (12)
    like_music_genres_34 /// Rap/hip hop (19)
    like_music_genres_32 /// New age (16)
    like_music_genres_31 /// Easy listening (9)
    like_music_genres_35 /// Reggae (20)
)

gen like_high_low_diff = like_high - like_low
label var like_high_low_diff "Liking diff (highbrow - lowbrow)"

*==============================
* HIGH vs LOW LISTENING
*==============================

gen listen_high = 0
gen listen_low  = 0

forvalues i = 1/10 {

    replace listen_high = listen_high + 1 if ///
        inlist(genre_final`i', 5,18,13,4,3)

    replace listen_low = listen_low + 1 if ///
        inlist(genre_final`i', 12,19,16,9,20)
}

gen listen_high_low_diff = listen_high - listen_low
label var listen_high_low_diff "Listening diff (highbrow - lowbrow)"



*==============================
* HIGH–LOW CLAIM GAP
*==============================

egen z_like_high_low   = std(like_high_low_diff)
egen z_listen_high_low = std(listen_high_low_diff)

gen high_low_claim_gap = z_listen_high_low - z_like_high_low
label var high_low_claim_gap ///
    "High–low enactment gap (z listen - z like)"
	
egen _nfilled_listen = rownonmiss(genre_final1-genre_final10)

gen high_low_claim_gap_ten = high_low_claim_gap if _nfilled_listen == 10
label var high_low_claim_gap_ten ///
    "High–low enactment gap if listed ten"

drop _nfilled_listen

regress listen_high_low_diff like_high_low_diff
predict high_low_claim_gap_resid, resid
label var high_low_claim_gap_resid ///
    "High–low enactment gap (residualized)"

*******************************************************************************************
*============================================================
* GENRE-LEVEL OVERCLAIMING ANALYSIS
* Overclaim = Pr(likes genre [5–7]) − Pr(listens to genre)
*============================================================
*-----------------------------
* STEP 1: Binary liking indicators (5–7 = likes)
* CORRECTED MAPPING
*-----------------------------
gen like_g1  = inrange(like_music_genres_21, 5, 7)  // Big band
gen like_g2  = inrange(like_music_genres_22, 5, 7)  // Bluegrass
gen like_g3  = inrange(like_music_genres_24, 5, 7)  // Blues/R&B
gen like_g4  = inrange(like_music_genres_39, 5, 7)  // Classic rock
gen like_g5  = inrange(like_music_genres_26, 5, 7)  // Classical
gen like_g6  = inrange(like_music_genres_36, 5, 7)  // Contemporary pop
gen like_g7  = inrange(like_music_genres_37, 5, 7)  // Alt/rock/punk
gen like_g8  = inrange(like_music_genres_23, 5, 7)  // Country
gen like_g9  = inrange(like_music_genres_31, 5, 7)  // Easy listening
gen like_g10 = inrange(like_music_genres_27, 5, 7)  // Folk
gen like_g11 = inrange(like_music_genres_28, 5, 7)  // Gospel
gen like_g12 = inrange(like_music_genres_40, 5, 7)  // Heavy metal
gen like_g13 = inrange(like_music_genres_29, 5, 7)  // Jazz
gen like_g14 = inrange(like_music_genres_30, 5, 7)  // Latin/salsa
gen like_g15 = inrange(like_music_genres_25, 5, 7)  // Musicals
gen like_g16 = inrange(like_music_genres_32, 5, 7)  // New age
gen like_g17 = inrange(like_music_genres_38, 5, 7)  // Oldies
gen like_g18 = inrange(like_music_genres_33, 5, 7)  // Opera
gen like_g19 = inrange(like_music_genres_34, 5, 7)  // Rap/hip hop
gen like_g20 = inrange(like_music_genres_35, 5, 7)  // Reggae

forvalues g = 1/20 {
    label var like_g`g' "Likes genre `g' (rating 5–7)"
}

*-----------------------------
* STEP 2: Binary listening indicators
* Appears at least once in genre_final1–10
*-----------------------------
forvalues g = 1/20 {
    gen listen_g`g' = 0
    forvalues i = 1/10 {
        replace listen_g`g' = 1 if genre_final`i' == `g'
    }
    label var listen_g`g' "Listens to genre `g'"
}

*-----------------------------
* STEP 3: Collapse to genre level
*-----------------------------
preserve

keep like_g* listen_g*
gen id = _n

reshape long like_g listen_g, i(id) j(genre)

collapse ///
    (mean) p_like   = like_g ///
    (mean) p_listen = listen_g, ///
    by(genre)

gen overclaim = p_like - p_listen

label var p_like    "Pr(likes genre: rating 5–7)"
label var p_listen  "Pr(listens to genre)"
label var overclaim "Overclaim index (likes − listens)"

*-----------------------------
* STEP 4: Apply genre labels (safe if already defined)
*-----------------------------
label define genre_lbl ///
    1  "Big band / swing" ///
    2  "Bluegrass" ///
    3  "Blues / R&B" ///
    4  "Classic rock" ///
    5  "Classical / symphony" ///
    6  "Contemporary pop" ///
    7  "Contemporary rock / alt / punk" ///
    8  "Country / western" ///
    9  "Easy listening" ///
    10 "Folk" ///
    11 "Gospel / Christian" ///
    12 "Heavy metal" ///
    13 "Jazz" ///
    14 "Latin / salsa" ///
    15 "Musicals / showtunes" ///
    16 "New age" ///
    17 "Oldies" ///
    18 "Opera" ///
    19 "Rap / hip hop" ///
    20 "Reggae", replace

label values genre genre_lbl

*-----------------------------
* STEP 5: Rank genres by overclaiming
*-----------------------------
gsort -overclaim
list genre p_like p_listen overclaim, noobs sep(0)

restore


*----------------------------------------
* Ranked dot plot of genre overclaiming
*----------------------------------------

*============================================================
* GENRE OVERCLAIM DOT PLOT WITH GENRE NAMES ON Y-AXIS
*============================================================
preserve

keep like_g* listen_g*
gen id = _n

reshape long like_g listen_g, i(id) j(genre)

collapse ///
    (mean) p_like   = like_g ///
    (mean) p_listen = listen_g, ///
    by(genre)

gen overclaim = p_like - p_listen

*-----------------------------
* Create string genre names (no value-label dependency)
*-----------------------------
gen str40 genre_name = ""
replace genre_name = "Big band / swing"               if genre == 1
replace genre_name = "Bluegrass"                       if genre == 2
replace genre_name = "Blues / R&B"                     if genre == 3
replace genre_name = "Classic rock"                    if genre == 4
replace genre_name = "Classical / symphony"            if genre == 5
replace genre_name = "Contemporary pop"                if genre == 6
replace genre_name = "Contemporary rock / alt / punk"  if genre == 7
replace genre_name = "Country / western"               if genre == 8
replace genre_name = "Easy listening"                  if genre == 9
replace genre_name = "Folk"                            if genre == 10
replace genre_name = "Gospel / Christian"              if genre == 11
replace genre_name = "Heavy metal"                     if genre == 12
replace genre_name = "Jazz"                            if genre == 13
replace genre_name = "Latin / salsa"                   if genre == 14
replace genre_name = "Musicals / showtunes"            if genre == 15
replace genre_name = "New age"                         if genre == 16
replace genre_name = "Oldies"                          if genre == 17
replace genre_name = "Opera"                           if genre == 18
replace genre_name = "Rap / hip hop"                   if genre == 19
replace genre_name = "Reggae"                          if genre == 20

*-----------------------------
* Rank by overclaim and label the rank positions
*-----------------------------
gsort -overclaim
gen genre_order = _n

capture label drop order_lbl

forvalues k = 1/20 {
    local nm = genre_name[`k']
    if `k' == 1 label define order_lbl 1 "`nm'", replace
    else        label define order_lbl `k' "`nm'", add
}

label values genre_order order_lbl

*-----------------------------
* Plot: y-axis shows genre names
*-----------------------------
twoway ///
    (scatter genre_order overclaim, msymbol(circle) msize(medlarge)) ///
    , ///
    yscale(reverse) ///
    ylabel(1/20, valuelabel angle(0) labsize(small)) ///
    xline(0, lpattern(dash) lcolor(gs8)) ///
    xtitle("Overclaim index: Pr(likes 5–7) − Pr(listens)") ///
    ytitle("") ///
    title("Which Genres Are Most Overclaimed?") ///
    subtitle("Difference between liking (ratings 5–7) and top-10 listening") ///
    legend(off)

restore


	

	
*********************************************************************************

***REGRESSIONS


*************RACE GAPS BLACK AND HISPANIC SMALLER GAPS*****NEED TO BREAK OUT MIXED/OTHER
regress racegap_incpop educ2 child_arts agecat income female urban_rural2  i.race5 social,  vce(robust)

regress racegap_incpop educ2 child_arts agecat income female urban_rural2  i.race5 social,  vce(robust)

regress racegap_incpop_ten educ2 child_arts agecat income female urban_rural2  i.race5 social,  vce(robust)

regress racegap_expop_ten educ2 child_arts agecat income female urban_rural2  i.race5 social,  vce(robust)


***PART OF THIS IS ABOUT BLACK PEOPLE LIKING AND LISTENING TO BLACK MUSIC
regress like_incpop_diff educ2 child_arts agecat income female urban_rural2 i.race5 social, vce(robust)
regress listen_incpop_diff educ2 child_arts agecat income female urban_rural2 i.race5 social, vce(robust)
********************************



regress gap_volume_listen_like educ2 child_arts agecat income female urban_rural2  i.race5,  vce(robust)

regress composition_listen_ten  educ2 child_arts agecat income female urban_rural2  i.race5,  vce(robust)

regress composition_listen_ten mu_genrelike_count educ2 child_arts agecat income female urban_rural2  i.race5,  vce(robust)

regress racegap_incpop educ2 child_arts agecat income female urban_rural2  i.race5 social,  vce(robust)

regress racegap_incpop educ2 child_arts agecat income female urban_rural2  i.race5 social,  vce(robust)

regress composition_listen_ten  like_high_low_diff  educ2 child_arts agecat income female urban_rural2  i.race5,  vce(robust)

regress mu_genrelike_count educ2 child_arts agecat income female urban_rural2  i.race5  social, vce(robust)

regress mu_genrelike_count educ2 child_arts agecat income female urban_rural2  i.race5  social network_working_class_variety network_pmc network_public_sector , vce(robust)

regress mu_genrelike_count educ2 child_arts agecat income female urban_rural2  i.race5  social hours_music, vce(robust)







*****************************************OVERCLAIM TEST
*******************************************************************
* ABSOLUTE OVERCLAIMING TEST
* Separate measures for nonwhite and white genre overclaiming
*******************************************************************

*====================================================
* PART 1: NONWHITE GENRE OVERCLAIMING
* Do people claim to like nonwhite genres more than they listen?
*====================================================

*-----------------------------
* Step 1: Mean liking of nonwhite genres (already exists)
*-----------------------------
* like_incpop_nonwhite already created (mean rating of 6 nonwhite genres)

*-----------------------------
* Step 2: Proportion of top-10 that are nonwhite
*-----------------------------
gen prop_listen_nonwhite = listen_incpop_nonwhite / 10
label var prop_listen_nonwhite "Proportion of top-10 that are nonwhite genres"

*-----------------------------
* Step 3: Rescale liking to 0-1 scale (matching proportion)
*-----------------------------
* Ratings are 1-7, so rescale to 0-1
gen like_nonwhite_01 = (like_incpop_nonwhite - 1) / 6
label var like_nonwhite_01 "Mean liking of nonwhite genres (0-1 scale)"

*-----------------------------
* Step 4: Calculate overclaim for NONWHITE genres
*-----------------------------
gen overclaim_nonwhite = like_nonwhite_01 - prop_listen_nonwhite
label var overclaim_nonwhite "Overclaim nonwhite: liking - listening proportion"

* Standardized version
egen z_overclaim_nonwhite = std(overclaim_nonwhite)
label var z_overclaim_nonwhite "Overclaim nonwhite (standardized)"


*====================================================
* PART 2: WHITE GENRE OVERCLAIMING
* Do people claim to like white genres more than they listen?
*====================================================

*-----------------------------
* Step 1: Mean liking of white genres (already exists)
*-----------------------------
* like_incpop_white already created (mean rating of 14 white genres)

*-----------------------------
* Step 2: Proportion of top-10 that are white
*-----------------------------
gen prop_listen_white = listen_incpop_white / 10
label var prop_listen_white "Proportion of top-10 that are white genres"

*-----------------------------
* Step 3: Rescale liking to 0-1 scale
*-----------------------------
gen like_white_01 = (like_incpop_white - 1) / 6
label var like_white_01 "Mean liking of white genres (0-1 scale)"

*-----------------------------
* Step 4: Calculate overclaim for WHITE genres
*-----------------------------
gen overclaim_white = like_white_01 - prop_listen_white
label var overclaim_white "Overclaim white: liking - listening proportion"

* Standardized version
egen z_overclaim_white = std(overclaim_white)
label var z_overclaim_white "Overclaim white (standardized)"


*====================================================
* PART 3: INTERACTION - Who overclaims which type?
*====================================================

gen overclaim_diff = overclaim_nonwhite - overclaim_white
label var overclaim_diff "Differential overclaim (nonwhite - white)"


*====================================================
* PART 4: REGRESSION TESTS
*====================================================

* Test 1: Do White respondents overclaim NONWHITE genres?
* Positive constant = overclaiming on average
* Black/Hispanic coefficients tell us if they overclaim MORE or LESS
regress overclaim_nonwhite educ2 child_arts agecat income female ///
    urban_rural2 i.race5 social, vce(robust)

* Test 2: Do White respondents overclaim WHITE genres?
regress overclaim_white educ2 child_arts agecat income female ///
    urban_rural2 i.race5 social, vce(robust)

* Test 3: Differential overclaiming - who overclaims which type more?
regress overclaim_diff educ2 child_arts agecat income female ///
    urban_rural2 i.race5 social, vce(robust)


*====================================================
* PART 5: DESCRIPTIVE STATS BY RACE
*====================================================

* Show mean overclaiming by race
bysort race5: summarize overclaim_nonwhite overclaim_white overclaim_diff

* Formal test of whether each group overclaims (is mean > 0?)
foreach race in 1 2 3 4 5 {
    display "========================================="
    if `race' == 1 display "WHITE RESPONDENTS"
    if `race' == 2 display "BLACK RESPONDENTS"
    if `race' == 3 display "HISPANIC RESPONDENTS"
    if `race' == 4 display "ASIAN RESPONDENTS"
    if `race' == 5 display "OTHER RACE RESPONDENTS"
    display "========================================="
    
    ttest overclaim_nonwhite == 0 if race5 == `race'
    display " "
    ttest overclaim_white == 0 if race5 == `race'
    display " "
    display " "
}


*====================================================
* ALTERNATIVE: BINARY LISTENING MEASURES
* More conservative - did they listen AT ALL vs how much they like
*====================================================

* Create binary "listened to at least one" indicators
gen any_listen_nonwhite = (listen_incpop_nonwhite > 0)
gen any_listen_white = (listen_incpop_white > 0)

* Overclaim = rated above midpoint (4) but didn't listen to any
gen overclaim_nonwhite_binary = (like_incpop_nonwhite > 4) & (any_listen_nonwhite == 0)
gen overclaim_white_binary = (like_incpop_white > 4) & (any_listen_white == 0)

label var overclaim_nonwhite_binary "Claims to like nonwhite genres but listens to none"
label var overclaim_white_binary "Claims to like white genres but listens to none"

* Test these
logit overclaim_nonwhite_binary educ2 child_arts agecat income female ///
    urban_rural2 i.race5 social, vce(robust)

logit overclaim_white_binary educ2 child_arts agecat income female ///
    urban_rural2 i.race5 social, vce(robust)


