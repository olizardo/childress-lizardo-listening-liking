/****************************************************************************************
GENRESOBJECTS PIPELINE (CONSOLIDATED)
- Build artist1-artist10 + genre_raw1-genre_raw10 + stream_source across platforms
- Recode into genre_final1-genre_final10 + genre_method1-genre_method10
- Optional patch merge (rowid-based) if you have an externally edited patch file
- Optional artist->genre crosswalk apply (from "to inc.csv")
- FINAL: brute-force convert 21 -> missing (and also 999 -> missing, per your later steps)
****************************************************************************************/

clear all
set more off

use "C:\Users\ccchi\OneDrive\Desktop\genresobjects.dta", clear

* =============================================================================
* 0) Ensure destination vars exist
* =============================================================================
capture confirm variable stream_source
if _rc gen str20 stream_source = ""

forvalues i = 1/10 {
    capture confirm variable artist`i'
    if _rc gen strL artist`i' = ""

    capture confirm variable genre_raw`i'
    if _rc gen strL genre_raw`i' = ""
}

* =============================================================================
* 1) BUILD artist# and genre_raw# for each stream
* =============================================================================

* -----------------------------
* 1A) iTunes direct stream
* -----------------------------
replace stream_source = "itunes" if stream_source=="" & !missing(itunes_1_1)

forvalues i = 1/10 {
    replace artist`i'    = itunes_`i'_1 ///
        if artist`i'=="" & !missing(itunes_`i'_1)

    replace genre_raw`i' = itunes_`i'_3 ///
        if genre_raw`i'=="" & !missing(itunes_`i'_3)

    replace genre_raw`i' = lower(trim(itrim(genre_raw`i'))) if genre_raw`i'!=""
}

* -----------------------------
* 1B) iTunes rotation stream (treat genre as STRING, robustly)
* Artists: itunes_rotation1_#_1
* Genres:  itunes_rotation2_#  (may be numeric OR string OR mixed)
* -----------------------------
replace stream_source = "itunes_rotation" ///
    if stream_source=="" & !missing(itunes_rotation1_1_1)

forvalues i = 1/10 {

    * artists
    replace artist`i' = itunes_rotation1_`i'_1 ///
        if artist`i'=="" & !missing(itunes_rotation1_`i'_1)

    * genres (robust string handling)
    capture confirm variable itunes_rotation2_`i'
    if !_rc {

        capture confirm numeric variable itunes_rotation2_`i'
        if !_rc {
            tempvar gstr
            tostring itunes_rotation2_`i', gen(`gstr') usedisplayformat force
            replace genre_raw`i' = lower(trim(itrim(`gstr'))) ///
                if genre_raw`i'=="" & `gstr'!=""
            drop `gstr'
        }
        else {
            replace genre_raw`i' = lower(trim(itrim(itunes_rotation2_`i')) ) ///
                if genre_raw`i'=="" & !missing(itunes_rotation2_`i')
        }
    }
}

* -----------------------------
* 1C) Winamp direct (monkey)
* Artists: winamp_monkey_#_1
* Genres:  winamp_monkey_#_3
* -----------------------------
replace stream_source = "winamp" ///
    if stream_source=="" & !missing(winamp_monkey_1_1)

forvalues i = 1/10 {
    replace artist`i' = winamp_monkey_`i'_1 ///
        if artist`i'=="" & !missing(winamp_monkey_`i'_1)

    replace genre_raw`i' = winamp_monkey_`i'_3 ///
        if genre_raw`i'=="" & !missing(winamp_monkey_`i'_3)

    replace genre_raw`i' = lower(trim(itrim(genre_raw`i'))) ///
        if genre_raw`i'!=""
}

* -----------------------------
* 1D) Winamp rotation
* Artists: winamp_rotation1_#_1
* Genres:  winamp_rotation2_#
* -----------------------------
replace stream_source = "winamp_rotation" ///
    if stream_source=="" & !missing(winamp_rotation1_1_1)

forvalues i = 1/10 {

    * artists
    replace artist`i' = winamp_rotation1_`i'_1 ///
        if artist`i'=="" & !missing(winamp_rotation1_`i'_1)

    * genres (robust string handling)
    capture confirm variable winamp_rotation2_`i'
    if !_rc {

        capture confirm numeric variable winamp_rotation2_`i'
        if !_rc {
            tempvar gstr
            tostring winamp_rotation2_`i', gen(`gstr') usedisplayformat force
            replace genre_raw`i' = lower(trim(itrim(`gstr'))) ///
                if genre_raw`i'=="" & `gstr'!=""
            drop `gstr'
        }
        else {
            replace genre_raw`i' = lower(trim(itrim(winamp_rotation2_`i'))) ///
                if genre_raw`i'=="" & !missing(winamp_rotation2_`i')
        }
    }
}

* -----------------------------
* 1E) Spotify rotation (numeric-only genres; decode if labeled else numeric->string)
* Artists: spotify_rotation1_#_1
* Genres:  spotify_rotation2_#
* -----------------------------
replace stream_source = "spotify_rotation" ///
    if stream_source=="" & !missing(spotify_rotation1_1_1)

forvalues i = 1/10 {

    * artists
    capture confirm variable spotify_rotation1_`i'_1
    if !_rc {
        replace artist`i' = spotify_rotation1_`i'_1 ///
            if stream_source=="spotify_rotation" ///
            & trim(artist`i')=="" ///
            & !missing(spotify_rotation1_`i'_1)
    }

    * genres
    capture confirm variable spotify_rotation2_`i'
    if !_rc {

        capture confirm numeric variable spotify_rotation2_`i'
        if !_rc {

            capture drop __gstr
            capture decode spotify_rotation2_`i', gen(__gstr)

            if _rc==0 {
                replace genre_raw`i' = lower(trim(itrim(__gstr))) ///
                    if stream_source=="spotify_rotation" ///
                    & inlist(trim(genre_raw`i'),"", ".") ///
                    & trim(__gstr)!=""
                drop __gstr
            }
            else {
                replace genre_raw`i' = lower(trim(itrim(string(spotify_rotation2_`i')))) ///
                    if stream_source=="spotify_rotation" ///
                    & inlist(trim(genre_raw`i'),"", ".") ///
                    & !missing(spotify_rotation2_`i')
            }
        }
        else {
            tempvar gclean
            gen strL `gclean' = lower(trim(itrim(spotify_rotation2_`i')))
            replace genre_raw`i' = `gclean' ///
                if stream_source=="spotify_rotation" ///
                & inlist(trim(genre_raw`i'),"", ".") ///
                & `gclean'!=""
            drop `gclean'
        }
    }

    * normalize
    replace genre_raw`i' = "" if stream_source=="spotify_rotation" & trim(genre_raw`i')=="."
    replace genre_raw`i' = lower(trim(itrim(genre_raw`i'))) if trim(genre_raw`i')!=""
}

* -----------------------------
* 1F) Spotify comp
* Artists: spotify_comp1_#_1
* Genres:  spotify_comp2_#
* -----------------------------
replace stream_source = "spotify_comp" ///
    if stream_source=="" & !missing(spotify_comp1_1_1)

forvalues i = 1/10 {

    replace artist`i' = spotify_comp1_`i'_1 ///
        if artist`i'=="" & !missing(spotify_comp1_`i'_1)

    capture confirm variable spotify_comp2_`i'
    if !_rc {

        capture confirm numeric variable spotify_comp2_`i'
        if !_rc {

            capture drop __gstr
            capture decode spotify_comp2_`i', gen(__gstr)

            if _rc==0 {
                replace genre_raw`i' = lower(trim(itrim(__gstr))) ///
                    if genre_raw`i'=="" & __gstr!=""
                drop __gstr
            }
            else {
                replace genre_raw`i' = string(spotify_comp2_`i') ///
                    if genre_raw`i'=="" & !missing(spotify_comp2_`i')
            }
        }
        else {
            replace genre_raw`i' = lower(trim(itrim(spotify_comp2_`i'))) ///
                if genre_raw`i'=="" & !missing(spotify_comp2_`i')
        }
    }
}

* -----------------------------
* 1G) Spotify phone (numeric-only)
* Artists: spotify_phone1_#_1
* Genres:  spotify_phone2_#
* -----------------------------
replace stream_source = "spotify_phone" ///
    if stream_source=="" & ( !missing(spotify_phone1_1_1) | !missing(spotify_phone2_1) )

forvalues i = 1/10 {

    * artists
    capture confirm variable spotify_phone1_`i'_1
    if !_rc {
        replace artist`i' = spotify_phone1_`i'_1 ///
            if stream_source=="spotify_phone" ///
            & trim(artist`i')=="" ///
            & !missing(spotify_phone1_`i'_1)
    }

    * genres
    capture confirm variable spotify_phone2_`i'
    if !_rc {

        capture drop __gdec
        capture decode spotify_phone2_`i', gen(__gdec)

        if _rc==0 {
            replace genre_raw`i' = lower(trim(itrim(__gdec))) ///
                if stream_source=="spotify_phone" ///
                & inlist(trim(genre_raw`i'),"", ".") ///
                & trim(__gdec)!=""
            drop __gdec
        }
        else {
            replace genre_raw`i' = lower(trim(itrim(string(spotify_phone2_`i')))) ///
                if stream_source=="spotify_phone" ///
                & inlist(trim(genre_raw`i'),"", ".") ///
                & !missing(spotify_phone2_`i')
        }
    }

    replace genre_raw`i' = "" if stream_source=="spotify_phone" & trim(genre_raw`i')=="."
    replace genre_raw`i' = lower(trim(itrim(genre_raw`i'))) if trim(genre_raw`i')!=""
}

* -----------------------------
* 1H) Regular rotation (no platform)
* Artists: rotation1_#_1
* Genres:  rotation2_#
* -----------------------------
replace stream_source = "rotation" ///
    if stream_source=="" & !missing(rotation1_1_1)

forvalues i = 1/10 {

    replace artist`i' = rotation1_`i'_1 ///
        if artist`i'=="" & !missing(rotation1_`i'_1)

    capture confirm variable rotation2_`i'
    if !_rc {

        capture confirm numeric variable rotation2_`i'
        if !_rc {

            capture drop __gstr
            capture decode rotation2_`i', gen(__gstr)

            if _rc==0 {
                replace genre_raw`i' = lower(trim(itrim(__gstr))) ///
                    if (genre_raw`i'=="" | genre_raw`i'==".") & __gstr!=""
                drop __gstr
            }
            else {
                replace genre_raw`i' = string(rotation2_`i') ///
                    if (genre_raw`i'=="" | genre_raw`i'==".") & !missing(rotation2_`i')
            }
        }
        else {
            replace genre_raw`i' = lower(trim(itrim(rotation2_`i'))) ///
                if (genre_raw`i'=="" | genre_raw`i'==".") & !missing(rotation2_`i')
        }
    }
}

* =============================================================================
* 2) CREATE genre_final# + genre_method#
* =============================================================================
forvalues i=1/10 {
    capture confirm variable genre_final`i'
    if _rc gen byte genre_final`i' = .
    label values genre_final`i' genre20
}

forvalues i=1/10 {
    capture confirm variable genre_method`i'
    if _rc gen str12 genre_method`i' = ""
}

* =============================================================================
* 3) PHASE 1: numeric source vars -> genre_final
* =============================================================================
foreach src in spotify_rotation spotify_phone spotify_comp rotation itunes_rotation {
    forvalues i=1/10 {
        capture confirm variable `src'2_`i'
        if !_rc {
            capture confirm numeric variable `src'2_`i'
            if !_rc {
                replace genre_final`i' = `src'2_`i' ///
                    if missing(genre_final`i') ///
                    & stream_source=="`src'" ///
                    & inrange(`src'2_`i',1,21)

                replace genre_method`i' = "`src'_numeric" ///
                    if genre_method`i'=="" ///
                    & stream_source=="`src'" ///
                    & inrange(`src'2_`i',1,21)
            }
        }
    }
}

* =============================================================================
* 4) PHASE 2: genre_raw# (text) -> genre_final#
*    - fills only if missing(.) or ==21
*    - any remaining non-empty text becomes 21
* =============================================================================
forvalues i = 1/10 {

    replace genre_raw`i' = lower(trim(itrim(genre_raw`i')))
    replace genre_raw`i' = "" if inlist(trim(genre_raw`i'), "", ".")
    replace genre_raw`i' = "" if genre_raw`i'=="0"

    * numeric string 1..21
    replace genre_final`i' = real(genre_raw`i') ///
        if inlist(genre_final`i', ., 21) ///
        & regexm(genre_raw`i', "^[0-9]+$") ///
        & inrange(real(genre_raw`i'), 1, 21)

    replace genre_method`i' = "text_numeric" ///
        if genre_method`i'=="" ///
        & !missing(genre_final`i') ///
        & genre_final`i'!=21 ///
        & regexm(genre_raw`i', "^[0-9]+$") ///
        & inrange(real(genre_raw`i'), 1, 21)

    * Rap/Hip Hop (19)
    replace genre_final`i' = 19 if inlist(genre_final`i', ., 21) ///
        & ( regexm(genre_raw`i', "hip[\- ]?hop") | regexm(genre_raw`i', "(^|[[:space:]])rap($|[[:space:]])") )

    * Blues/R&B (3)
    replace genre_final`i' = 3 if inlist(genre_final`i', ., 21) ///
        & ( regexm(genre_raw`i', "r\s*&\s*b") | regexm(genre_raw`i', "r&b|rnb|rhythm") | regexm(genre_raw`i', "blues") )
    replace genre_final`i' = 3 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "soul","funk","smooth","motown oldies","r and b","r &b","r@b")

    * Jazz (13)
    replace genre_final`i' = 13 if inlist(genre_final`i', ., 21) ///
        & ( regexm(genre_raw`i', "jazz") | inlist(genre_raw`i', "jaz","jass") )

    * Classical/Symphony (5)
    replace genre_final`i' = 5 if inlist(genre_final`i', ., 21) ///
        & ( regexm(genre_raw`i', "classical") | regexm(genre_raw`i', "symph") )

    * Opera (18)
    replace genre_final`i' = 18 if inlist(genre_final`i', ., 21) ///
        & regexm(genre_raw`i', "opera")

    * Country/Western (8)
    replace genre_final`i' = 8 if inlist(genre_final`i', ., 21) ///
        & regexm(genre_raw`i', "country")
    replace genre_final`i' = 8 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "c western","c wesrern","county","bakerfield sound")

    * Folk (10)
    replace genre_final`i' = 10 if inlist(genre_final`i', ., 21) ///
        & regexm(genre_raw`i', "folk")
    replace genre_final`i' = 10 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "acoustic","singer/songwriter","irish")

    * Reggae (20)
    replace genre_final`i' = 20 if inlist(genre_final`i', ., 21) ///
        & regexm(genre_raw`i', "reggae")
    replace genre_final`i' = 20 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "dancehall","ska","ska-punk","chutney")
    replace genre_final`i' = 20 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "regaetoon","reggeaton","reggueaton","raggee")

    * Heavy Metal (12)
    replace genre_final`i' = 12 if inlist(genre_final`i', ., 21) ///
        & regexm(genre_raw`i', "metal")
    replace genre_final`i' = 12 if inlist(genre_final`i', ., 21) ///
        & genre_raw`i'=="heavy"

    * Contemporary Pop (6)
    replace genre_final`i' = 6 if inlist(genre_final`i', ., 21) ///
        & regexm(genre_raw`i', "pop")
    replace genre_final`i' = 6 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "dance","disco","house","electronic","electronica","electronically/dance")
    replace genre_final`i' = 6 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "drum & bass","future bass","idm","freestyle","uk hardcore","modern","contemporary")
    replace genre_final`i' = 6 if inlist(genre_final`i', ., 21) ///
        & genre_raw`i'=="opm"

    * Contemporary Rock (7)
    replace genre_final`i' = 7 if inlist(genre_final`i', ., 21) ///
        & regexm(genre_raw`i', "rock")
    replace genre_final`i' = 7 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "alternative","alt","indie","punk","grunge","goth","emo","newwave","psychedlic")

    * Classic Rock (4)
    replace genre_final`i' = 4 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "classic r9ck","classic rok","roock")

    * Oldies (17)
    replace genre_final`i' = 17 if inlist(genre_final`i', ., 21) ///
        & genre_raw`i'=="oldies"

    * Bluegrass (2)
    replace genre_final`i' = 2 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "bluegrass","blue grass")

    * Gospel (11)
    replace genre_final`i' = 11 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "christian","gospel","worship")
    replace genre_final`i' = 11 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "christian & gospel","gospel and religious","critsian","criysian")

    * Latin/Salsa (14)
    replace genre_final`i' = 14 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "latin","latino","salsa","mexican","mexican regional")
    replace genre_final`i' = 14 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "tejano","cumbia","cumbias","spanish","engish spanish","bossa nova")

    * Easy Listening (9)
    replace genre_final`i' = 9 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "easy listening","ballad","torch song","romantic")

    * Musicals/Showtunes (15)
    replace genre_final`i' = 15 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "musical","showtunes","soundtrack","soundtracks")
    replace genre_final`i' = 15 if inlist(genre_final`i', ., 21) ///
        & inlist(genre_raw`i', "anime soundtrack","game soundtrack","game soundtrack remix","holiday")

    * New Age (16)
    replace genre_final`i' = 16 if inlist(genre_final`i', ., 21) ///
        & genre_raw`i'=="new age"

    * Piano -> Classical (5)
    replace genre_final`i' = 5 if inlist(genre_final`i', ., 21) ///
        & genre_raw`i'=="piano"

    * method tag for mapped text (not 21)
    replace genre_method`i' = "text_map" ///
        if genre_method`i'=="" ///
        & !missing(genre_final`i') ///
        & genre_final`i'!=21 ///
        & genre_raw`i'!=""

    * catch-all: remaining non-empty text -> 21
    replace genre_final`i' = 21 if missing(genre_final`i') & genre_raw`i'!=""
}

* =============================================================================
* 5) SAVE CHECKPOINT (before any artist-patch/crosswalk work)
* =============================================================================
save "C:\Users\ccchi\OneDrive\Desktop\genresobjects_before_artist.dta", replace

* =============================================================================
* 6) OPTIONAL: merge in a patched genre_final1-10 file by rowid
*    (this is your FULL_withrowid / PATCH_genres_only workflow)
* =============================================================================
use "C:\Users\ccchi\OneDrive\Desktop\genresobjects_before_artist.dta", clear
gen long __rowid = _n
save "C:\Users\ccchi\OneDrive\Desktop\FULL_withrowid.dta", replace

capture confirm file "C:\Users\ccchi\OneDrive\Desktop\genres_patch_clean.dta"
if _rc==0 {
    use "C:\Users\ccchi\OneDrive\Desktop\genres_patch_clean.dta", clear
    gen long __rowid = _n
    keep __rowid genre_final1-genre_final10
    save "C:\Users\ccchi\OneDrive\Desktop\PATCH_genres_only.dta", replace

    use "C:\Users\ccchi\OneDrive\Desktop\FULL_withrowid.dta", clear
    merge 1:1 __rowid using "C:\Users\ccchi\OneDrive\Desktop\PATCH_genres_only.dta", ///
        nogen update replace
    drop __rowid
    save "C:\Users\ccchi\OneDrive\Desktop\genresobjects_after_artist.dta", replace
}
else {
    use "C:\Users\ccchi\OneDrive\Desktop\FULL_withrowid.dta", clear
    drop __rowid
    save "C:\Users\ccchi\OneDrive\Desktop\genresobjects_after_artist.dta", replace
}

* =============================================================================
* 7) OPTIONAL: BUILD + APPLY artist->genre20 crosswalk FROM "to inc.csv"
* =============================================================================

* ensure genre_method vars exist (they should, but keep consistent)
forvalues i=1/10 {
    capture confirm variable genre_method`i'
    if _rc gen str20 genre_method`i' = ""
}

* helper: normalize artist strings to a stable merge key
capture program drop _norm_artist_key
program define _norm_artist_key
    syntax varname, gen(name)
    gen strL `gen' = lower(itrim(strtrim(`varlist')))
    replace `gen' = subinstr(`gen', char(9), " ", .)
    replace `gen' = itrim(`gen')
    replace `gen' = subinstr(`gen', `"""', "", .)
    replace `gen' = subinstr(`gen', ".", "", .)
    replace `gen' = subinstr(`gen', ",", "", .)
    replace `gen' = subinstr(`gen', "'", "", .)
    replace `gen' = subinstr(`gen', ":", "", .)
    replace `gen' = subinstr(`gen', ";", "", .)
    replace `gen' = itrim(`gen')
end

tempfile xwalk
capture confirm file "to inc.csv"
if _rc==0 {

    preserve
        import delimited using "to inc.csv", varnames(nonames) stringcols(_all) clear
        rename v1 artist_raw
        rename v2 genre_label_raw

        replace artist_raw      = itrim(strtrim(artist_raw))
        replace genre_label_raw = itrim(strtrim(genre_label_raw))
        drop if artist_raw=="" | genre_label_raw==""

        gen str40 genre_label = lower(itrim(strtrim(genre_label_raw)))

        gen int genre_code = .
        replace genre_code = 3  if genre_label=="blues/r&b"
        replace genre_code = 4  if genre_label=="classic rock"
        replace genre_code = 5  if genre_label=="classical/symphony"
        replace genre_code = 6  if genre_label=="contemporary pop"
        replace genre_code = 7  if genre_label=="contemporary rock"
        replace genre_code = 8  if genre_label=="country/western"
        replace genre_code = 9  if genre_label=="easy listening"
        replace genre_code = 10 if genre_label=="folk"
        replace genre_code = 11 if genre_label=="gospel"
        replace genre_code = 12 if genre_label=="heavy metal"
        replace genre_code = 13 if genre_label=="jazz"
        replace genre_code = 14 if genre_label=="latin/salsa"
        replace genre_code = 15 if genre_label=="musicals/showtunes"
        replace genre_code = 16 if genre_label=="new age"
        replace genre_code = 17 if genre_label=="oldies"
        replace genre_code = 18 if genre_label=="opera"
        replace genre_code = 19 if genre_label=="rap/hip hop"
        replace genre_code = 20 if genre_label=="reggae"
        replace genre_code = 999 if genre_label=="junk"

        * normalize artist key exactly like main data
        gen strL artist_key = artist_raw
        tempvar k2
        _norm_artist_key artist_key, gen(`k2')
        gen str80 __akey80 = substr(`k2', 1, 80)

        keep __akey80 genre_code
        drop if __akey80==""

        duplicates drop __akey80, force
        compress
        save `xwalk', replace
    restore

    * apply xwalk to each slot
    forvalues s = 1/10 {

        capture drop __akey
        capture drop __akey80
        capture drop genre_code

        _norm_artist_key artist`s', gen(__akey)
        gen str80 __akey80 = substr(__akey, 1, 80)

        merge m:1 __akey80 using `xwalk', keep(match master) nogen keepusing(genre_code)

        replace genre_final`s' = genre_code ///
            if inlist(genre_final`s', ., 21) ///
            & __akey80 != "" ///
            & !missing(genre_code)

        replace genre_method`s' = "artist_map" ///
            if genre_method`s'=="" ///
            & __akey80 != "" ///
            & !missing(genre_code) ///
            & genre_final`s'==genre_code

        capture drop __akey
        capture drop __akey80
        capture drop genre_code
    }
}

* =============================================================================
* 8) FINAL CLEANUP RULES YOU RAN
* =============================================================================

* Normalize artist strings + blank punctuation-only "artists"
forvalues s=1/10 {
    replace artist`s' = subinstr(artist`s', char(9), " ", .)
    replace artist`s' = itrim(strtrim(artist`s'))
    replace artist`s' = "" if regexm(artist`s', "^[[:space:][:punct:]]*$")
}

* Blank artist + 21 => 999 (as in your later steps)
forvalues s=1/10 {
    replace genre_final`s'  = 999 if genre_final`s'==21 & itrim(strtrim(artist`s'))==""
    replace genre_method`s' = "junk_blank_artist" if genre_final`s'==999 & genre_method`s'==""
}

* CONVERT 21 -> missing (your stated last step)
forvalues s = 1/10 {
    replace genre_final`s' = . if genre_final`s' == 21
}

* also convert 999 -> missing (your later step)
forvalues s=1/10 {
    replace genre_final`s' = . if genre_final`s' == 999
}

* clear method when final missing
forvalues s=1/10 {
    replace genre_method`s' = "" if missing(genre_final`s')
}

* =============================================================================
* 9) QC: confirm no 21s remain
* =============================================================================
forvalues s = 1/10 {
    count if genre_final`s' == 21
    di "slot `s' still ==21: " r(N)
}

* =============================================================================
* 10) FINAL SAVE
* =============================================================================
save "C:\Users\ccchi\OneDrive\Desktop\analysis_time.dta", replace
save "C:\Users\ccchi\OneDrive\Desktop\genres_patch_clean.dta", replace
