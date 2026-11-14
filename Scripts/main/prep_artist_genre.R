# ==============================================================================
# prep_artistgenre.R
#
# R port of do/cleaned_artistgenre_do.do: rebuilds artist1-10, genre_raw1-10,
# genre_final1-10, genre_method1-10 and stream_source from the raw stream data
# in dta/genresobjects.dta, and writes dta/genresobjects_processed.dta.
#
# Port decisions (documented deviations from the Stata original):
#   * The Stata script's optional "patch merge" (sections 5-6, merging an
#     externally hand-edited genres_patch_clean.dta back by row position) is
#     NOT reproduced. It depended on a local file outside the repository and is
#     the suspected source of cross-respondent shuffling of genre_final values
#     (see 2026-11-11 audit).genre codes here come only from Phases 1-2 and the
#     artist crosswalk.
#   * The Stata exploratory QC output (count/browse/list) is replaced by a
#     summary printed at the end.
#
# Genre code scheme (genre20):
#   1 Big band/swing, 2 Bluegrass, 3 Blues/R&B, 4 Classic rock,
#   5 Classical/symphony, 6 Contemporary pop, 7 Contemporary rock/alt/punk,
#   8 Country/western, 9 Easy listening, 10 Folk, 11 Gospel/Christian,
#   12 Heavy metal, 13 Jazz, 14 Latin/salsa, 15 Musicals/showtunes,
#   16 New age, 17 Oldies, 18 Opera, 19 Rap/hip hop, 20 Reggae
#   (21 = uncoded text, 999 = junk; both set to missing in the final step)
# ==============================================================================

library(haven)

stopifnot(file.exists("dta/genresobjects.dta"))

d <- read_dta("dta/genresobjects.dta")
nms <- names(d)

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
# Stata-style trim: remove leading/trailing whitespace and collapse internal runs
strim <- function(x) {
  x <- gsub("[\t\n\r]", " ", x)
  x <- trimws(x)
  gsub("\\s+", " ", x)
}
# blank when "" or "." or "0"
is_blank <- function(x) is.na(x) | x == "" | x == "." | x == "0"
# numeric variable without value labels decodes to its string form (Stata
# decode() fails, string() fallback in the original)
num_to_str <- function(x) {
  out <- as.character(x)
  out[is.na(x)] <- NA
  out
}
# artist merge-key normalization (Stata _norm_artist_key)
norm_artist_key <- function(x) {
  x <- ifelse(is.na(x), "", x)
  x <- tolower(strim(x))
  x <- gsub("\t", " ", x, fixed = TRUE)
  x <- trimws(x)
  for (p in c('"', ".", ",", "'", ":", ";")) x <- gsub(p, "", x, fixed = TRUE)
  strim(x)
}

genre_raw_cols <- paste0("genre_raw", 1:10)
artist_cols <- paste0("artist", 1:10)
gf_cols <- paste0("genre_final", 1:10)
gm_cols <- paste0("genre_method", 1:10)

for (v in c(genre_raw_cols, artist_cols)) d[[v]] <- ""
d[gf_cols] <- NA_integer_
for (v in gm_cols) d[[v]] <- ""

d$stream_source <- ""
src_is_na <- function(v) is.na(d[[v]]) | (is.character(d[[v]]) & d[[v]] == "")

# ------------------------------------------------------------------------------
# 1) Build artist# and genre_raw# for each stream, in the do-file's order
# ------------------------------------------------------------------------------
# 1A) iTunes direct
d$stream_source <- ifelse(is_blank(d$stream_source) & !src_is_na("itunes_1_1"),
                          "itunes", d$stream_source)
for (i in 1:10) {
  fill_a <- is_blank(d[[artist_cols[i]]]) & !src_is_na(paste0("itunes_", i, "_1"))
  d[[artist_cols[i]]][fill_a] <- d[[paste0("itunes_", i, "_1")]][fill_a]
  fill_g <- is_blank(d[[genre_raw_cols[i]]]) & !src_is_na(paste0("itunes_", i, "_3"))
  d[[genre_raw_cols[i]]][fill_g] <- tolower(strim(d[[paste0("itunes_", i, "_3")]][fill_g]))
}

# 1B) iTunes rotation
d$stream_source <- ifelse(is_blank(d$stream_source) & !src_is_na("itunes_rotation1_1_1"),
                          "itunes_rotation", d$stream_source)
for (i in 1:10) {
  fill_a <- is_blank(d[[artist_cols[i]]]) & !src_is_na(paste0("itunes_rotation1_", i, "_1"))
  d[[artist_cols[i]]][fill_a] <- d[[paste0("itunes_rotation1_", i, "_1")]][fill_a]
  v <- paste0("itunes_rotation2_", i)
  if (v %in% nms && !is.numeric(d[[v]])) {
    fill_g <- is_blank(d[[genre_raw_cols[i]]]) & !is.na(d[[v]]) & d[[v]] != ""
    d[[genre_raw_cols[i]]][fill_g] <- tolower(strim(d[[v]][fill_g]))
  }
}

# 1C) Winamp direct (monkey)
d$stream_source <- ifelse(is_blank(d$stream_source) & !src_is_na("winamp_monkey_1_1"),
                          "winamp", d$stream_source)
for (i in 1:10) {
  fill_a <- is_blank(d[[artist_cols[i]]]) & !src_is_na(paste0("winamp_monkey_", i, "_1"))
  d[[artist_cols[i]]][fill_a] <- d[[paste0("winamp_monkey_", i, "_1")]][fill_a]
  fill_g <- is_blank(d[[genre_raw_cols[i]]]) & !src_is_na(paste0("winamp_monkey_", i, "_3"))
  d[[genre_raw_cols[i]]][fill_g] <- tolower(strim(d[[paste0("winamp_monkey_", i, "_3")]][fill_g]))
}

# 1D) Winamp rotation
d$stream_source <- ifelse(is_blank(d$stream_source) & !src_is_na("winamp_rotation1_1_1"),
                          "winamp_rotation", d$stream_source)
for (i in 1:10) {
  fill_a <- is_blank(d[[artist_cols[i]]]) & !src_is_na(paste0("winamp_rotation1_", i, "_1"))
  d[[artist_cols[i]]][fill_a] <- d[[paste0("winamp_rotation1_", i, "_1")]][fill_a]
  v <- paste0("winamp_rotation2_", i)
  if (v %in% nms && is.numeric(d[[v]])) {
    g <- num_to_str(d[[v]])
    fill_g <- is_blank(d[[genre_raw_cols[i]]]) & !is.na(g) & g != ""
    d[[genre_raw_cols[i]]][fill_g] <- tolower(strim(g[fill_g]))
  }
}

# 1E) Spotify rotation (numeric genres, unlabeled -> numeric string)
d$stream_source <- ifelse(is_blank(d$stream_source) & !src_is_na("spotify_rotation1_1_1"),
                          "spotify_rotation", d$stream_source)
for (i in 1:10) {
  v <- paste0("spotify_rotation1_", i, "_1")
  if (v %in% nms) {
    fill_a <- is_blank(d[[artist_cols[i]]]) & d$stream_source == "spotify_rotation" &
      !src_is_na(v)
    d[[artist_cols[i]]][fill_a] <- d[[v]][fill_a]
  }
  v <- paste0("spotify_rotation2_", i)
  if (v %in% nms && is.numeric(d[[v]])) {
    g <- num_to_str(d[[v]])
    fill_g <- d$stream_source == "spotify_rotation" & is_blank(d[[genre_raw_cols[i]]]) &
      !is.na(g) & g != ""
    d[[genre_raw_cols[i]]][fill_g] <- tolower(strim(g[fill_g]))
  }
  d[[genre_raw_cols[i]]] <- ifelse(d$stream_source == "spotify_rotation" &
                                     strim(d[[genre_raw_cols[i]]]) == ".",
                                   "", d[[genre_raw_cols[i]]])
}

# 1F) Spotify comp
d$stream_source <- ifelse(is_blank(d$stream_source) & !src_is_na("spotify_comp1_1_1"),
                          "spotify_comp", d$stream_source)
for (i in 1:10) {
  fill_a <- is_blank(d[[artist_cols[i]]]) & !src_is_na(paste0("spotify_comp1_", i, "_1"))
  d[[artist_cols[i]]][fill_a] <- d[[paste0("spotify_comp1_", i, "_1")]][fill_a]
  v <- paste0("spotify_comp2_", i)
  if (v %in% nms && is.numeric(d[[v]])) {
    g <- num_to_str(d[[v]])
    fill_g <- is_blank(d[[genre_raw_cols[i]]]) & !is.na(g) & g != ""
    d[[genre_raw_cols[i]]][fill_g] <- g[fill_g]
  }
}

# 1G) Spotify phone (numeric-only)
d$stream_source <- ifelse(
  is_blank(d$stream_source) &
    (!src_is_na("spotify_phone1_1_1") | !src_is_na("spotify_phone2_1")),
  "spotify_phone", d$stream_source)
for (i in 1:10) {
  v <- paste0("spotify_phone1_", i, "_1")
  if (v %in% nms) {
    fill_a <- is_blank(d[[artist_cols[i]]]) & d$stream_source == "spotify_phone" &
      !src_is_na(v)
    d[[artist_cols[i]]][fill_a] <- d[[v]][fill_a]
  }
  v <- paste0("spotify_phone2_", i)
  if (v %in% nms && is.numeric(d[[v]])) {
    g <- num_to_str(d[[v]])
    fill_g <- d$stream_source == "spotify_phone" & is_blank(d[[genre_raw_cols[i]]]) &
      !is.na(g) & g != ""
    d[[genre_raw_cols[i]]][fill_g] <- tolower(strim(g[fill_g]))
  }
  d[[genre_raw_cols[i]]] <- ifelse(d$stream_source == "spotify_phone" &
                                     strim(d[[genre_raw_cols[i]]]) == ".",
                                   "", d[[genre_raw_cols[i]]])
}

# 1H) Regular rotation (no platform)
d$stream_source <- ifelse(is_blank(d$stream_source) & !src_is_na("rotation1_1_1"),
                          "rotation", d$stream_source)
for (i in 1:10) {
  fill_a <- is_blank(d[[artist_cols[i]]]) & !src_is_na(paste0("rotation1_", i, "_1"))
  d[[artist_cols[i]]][fill_a] <- d[[paste0("rotation1_", i, "_1")]][fill_a]
  v <- paste0("rotation2_", i)
  if (v %in% nms && is.numeric(d[[v]])) {
    g <- num_to_str(d[[v]])
    fill_g <- is_blank(d[[genre_raw_cols[i]]]) & !is.na(g) & g != ""
    d[[genre_raw_cols[i]]][fill_g] <- g[fill_g]
  }
}

# ------------------------------------------------------------------------------
# 3) PHASE 1: numeric source variables -> genre_final (codes 1-21)
# ------------------------------------------------------------------------------
phase1_sources <- c("spotify_rotation", "spotify_phone", "spotify_comp",
                    "rotation", "itunes_rotation")
for (src in phase1_sources) {
  for (i in 1:10) {
    v <- paste0(src, "2_", i)
    if (!(v %in% nms) || !is.numeric(d[[v]])) next
    ok <- is.na(d[[gf_cols[i]]]) & d$stream_source == src &
      !is.na(d[[v]]) & d[[v]] >= 1 & d[[v]] <= 21
    d[[gf_cols[i]]][ok] <- as.integer(d[[v]][ok])
    d[[gm_cols[i]]] <- ifelse(d[[gm_cols[i]]] == "" & ok, paste0(src, "_numeric"),
                              d[[gm_cols[i]]])
  }
}

# ------------------------------------------------------------------------------
# 4) PHASE 2: genre_raw text -> genre_final
#    Fills only missing or 21; remaining non-empty text becomes 21.
#    Rule order matches the do-file exactly (first match wins).
# ------------------------------------------------------------------------------
# normalize text once
for (i in 1:10) {
  g <- strim(tolower(d[[genre_raw_cols[i]]]))
  g[is.na(g)] <- ""
  g[g == "." | g == "0"] <- ""
  d[[genre_raw_cols[i]]] <- g
}

fill <- function(i, code, ...) {
  # ...: vectorized logical condition on genre_raw text (NA-safe)
  cond <- Reduce(`|`, list(...))
  ok <- (is.na(d[[gf_cols[i]]]) | d[[gf_cols[i]]] == 21) & !is.na(cond) & cond
  d[[gf_cols[i]]][ok] <<- code
  invisible(NULL)
}
rx <- function(g, pattern) grepl(pattern, g)  # Stata regexm: unanchored, POSIX ERE

for (i in 1:10) {
  g <- d[[genre_raw_cols[i]]]
  inrange <- function(lo, hi) {
    is_num <- grepl("^[0-9]+$", g)
    val <- suppressWarnings(as.numeric(g))
    is_num & val >= lo & val <= hi
  }
  # numeric string 1..21
  ok_num <- (is.na(d[[gf_cols[i]]]) | d[[gf_cols[i]]] == 21) & inrange(1, 21)
  d[[gf_cols[i]]][ok_num] <- as.integer(suppressWarnings(as.numeric(g[ok_num])))
  d[[gm_cols[i]]] <- ifelse(
    d[[gm_cols[i]]] == "" & ok_num & !is.na(d[[gf_cols[i]]]) &
      d[[gf_cols[i]]] != 21, "text_numeric", d[[gm_cols[i]]])

  fill(i, 19L, rx(g, "hip[- ]?hop"), rx(g, "(^|[[:space:]])rap($|[[:space:]])"))
  fill(i, 3L, rx(g, "r\\s*&\\s*b"), rx(g, "r&b|rnb|rhythm"), rx(g, "blues"))
  fill(i, 3L, g %in% c("soul", "funk", "smooth", "motown oldies",
                       "r and b", "r &b", "r@b"))
  fill(i, 13L, rx(g, "jazz"), g %in% c("jaz", "jass"))
  fill(i, 5L, rx(g, "classical"), rx(g, "symph"))
  fill(i, 18L, rx(g, "opera"))
  fill(i, 8L, rx(g, "country"))
  fill(i, 8L, g %in% c("c western", "c wesrern", "county", "bakerfield sound"))
  fill(i, 10L, rx(g, "folk"))
  fill(i, 10L, g %in% c("acoustic", "singer/songwriter", "irish"))
  fill(i, 20L, rx(g, "reggae"))
  fill(i, 20L, g %in% c("dancehall", "ska", "ska-punk", "chutney"))
  fill(i, 20L, g %in% c("regaetoon", "reggeaton", "reggueaton", "raggee"))
  fill(i, 12L, rx(g, "metal"))
  fill(i, 12L, g == "heavy")
  fill(i, 6L, rx(g, "pop"))
  fill(i, 6L, g %in% c("dance", "disco", "house", "electronic", "electronica",
                       "electronically/dance"))
  fill(i, 6L, g %in% c("drum & bass", "future bass", "idm", "freestyle",
                       "uk hardcore", "modern", "contemporary"))
  fill(i, 6L, g == "opm")
  fill(i, 7L, rx(g, "rock"))
  fill(i, 7L, g %in% c("alternative", "alt", "indie", "punk", "grunge",
                       "goth", "emo", "newwave", "psychedlic"))
  fill(i, 4L, g %in% c("classic r9ck", "classic rok", "roock"))
  fill(i, 17L, g == "oldies")
  fill(i, 2L, g %in% c("bluegrass", "blue grass"))
  fill(i, 11L, g %in% c("christian", "gospel", "worship"))
  fill(i, 11L, g %in% c("christian & gospel", "gospel and religious",
                        "critsian", "criysian"))
  fill(i, 14L, g %in% c("latin", "latino", "salsa", "mexican", "mexican regional"))
  fill(i, 14L, g %in% c("tejano", "cumbia", "cumbias", "spanish",
                        "engish spanish", "bossa nova"))
  fill(i, 9L, g %in% c("easy listening", "ballad", "torch song", "romantic"))
  fill(i, 15L, g %in% c("musical", "showtunes", "soundtrack", "soundtracks"))
  fill(i, 15L, g %in% c("anime soundtrack", "game soundtrack",
                        "game soundtrack remix", "holiday"))
  fill(i, 16L, g == "new age")
  fill(i, 5L, g == "piano")

  # method tag for mapped text
  d[[gm_cols[i]]] <- ifelse(
    d[[gm_cols[i]]] == "" & !is.na(d[[gf_cols[i]]]) & d[[gf_cols[i]]] != 21 & g != "",
    "text_map", d[[gm_cols[i]]])
  # catch-all: remaining non-empty text -> 21
  d[[gf_cols[i]]] <- ifelse(is.na(d[[gf_cols[i]]]) & g != "", 21L, d[[gf_cols[i]]])
}

# ------------------------------------------------------------------------------
# 7) Build + apply artist -> genre20 crosswalk from csv/to inc.csv
#    (Stata `duplicates drop, force` keeps the first row per key)
# ------------------------------------------------------------------------------
xw <- read.csv("csv/to inc.csv", header = FALSE, col.names = c("artist_raw", "genre_label_raw"),
               colClasses = "character")
xw$artist_raw <- strim(xw$artist_raw)
xw$genre_label_raw <- strim(xw$genre_label_raw)
xw <- xw[xw$artist_raw != "" & xw$genre_label_raw != "", ]
xw$genre_label <- tolower(strim(xw$genre_label_raw))

label_map <- c("blues/r&b" = 3L, "classic rock" = 4L, "classical/symphony" = 5L,
               "contemporary pop" = 6L, "contemporary rock" = 7L,
               "country/western" = 8L, "easy listening" = 9L, "folk" = 10L,
               "gospel" = 11L, "heavy metal" = 12L, "jazz" = 13L,
               "latin/salsa" = 14L, "musicals/showtunes" = 15L, "new age" = 16L,
               "oldies" = 17L, "opera" = 18L, "rap/hip hop" = 19L,
               "reggae" = 20L, "junk" = 999L)
xw$genre_code <- unname(label_map[xw$genre_label])
xw <- xw[!is.na(xw$genre_code), ]
xw$artist_key80 <- substr(norm_artist_key(xw$artist_raw), 1, 80)
xw <- xw[xw$artist_key80 != "", ]
xw <- xw[!duplicated(xw$artist_key80), ]
xw_map <- setNames(xw$genre_code, xw$artist_key80)

for (s in 1:10) {
  key80 <- substr(norm_artist_key(d[[artist_cols[s]]]), 1, 80)
  gc <- unname(xw_map[key80])
  gc[is.na(key80) | key80 == ""] <- NA
  ok <- (is.na(d[[gf_cols[s]]]) | d[[gf_cols[s]]] == 21) & !is.na(gc)
  d[[gf_cols[s]]][ok] <- gc[ok]
  changed <- ok & !is.na(d[[gf_cols[s]]][ok]) & d[[gf_cols[s]]][ok] == gc[ok]
  ok_changed <- which(ok)[changed]
  d[[gm_cols[s]]] <- ifelse(d[[gm_cols[s]]] == "" & seq_len(nrow(d)) %in% ok_changed,
                            "artist_map", d[[gm_cols[s]]])
}

# ------------------------------------------------------------------------------
# 8) Final cleanup rules
# ------------------------------------------------------------------------------
# normalize artist strings; blank punctuation-only entries
for (s in 1:10) {
  a <- d[[artist_cols[s]]]
  a <- ifelse(is.na(a), "", a)
  a <- strim(a)
  a <- ifelse(grepl("^[[:space:][:punct:]]*$", a) & a != "", "", a)
  a[a == ""] <- NA
  d[[artist_cols[s]]] <- a
}
# blank artist + 21 => 999 => missing
for (s in 1:10) {
  d[[gf_cols[s]]] <- ifelse(d[[gf_cols[s]]] == 21 &
                              (is.na(d[[artist_cols[s]]]) | d[[artist_cols[s]]] == ""),
                            999L, d[[gf_cols[s]]])
  d[[gm_cols[s]]] <- ifelse(d[[gf_cols[s]]] == 999 & d[[gm_cols[s]]] == "",
                            "junk_blank_artist", d[[gm_cols[s]]])
  # 21 -> missing, 999 -> missing
  d[[gf_cols[s]]] <- ifelse(d[[gf_cols[s]]] %in% c(21L, 999L), NA_integer_,
                            d[[gf_cols[s]]])
  # clear method when final missing
  d[[gm_cols[s]]] <- ifelse(is.na(d[[gf_cols[s]]]), "", d[[gm_cols[s]]])
}

# ------------------------------------------------------------------------------
# 10) Save
# ------------------------------------------------------------------------------
genre_labels <- c("Big band / swing", "Bluegrass", "Blues / R&B", "Classic rock",
                  "Classical / symphony", "Contemporary pop",
                  "Contemporary rock / alt / punk", "Country / western",
                  "Easy listening", "Folk", "Gospel / Christian", "Heavy metal",
                  "Jazz", "Latin / salsa", "Musicals / showtunes", "New age",
                  "Oldies", "Opera", "Rap / hip hop", "Reggae")
keep <- c("responseid", "stream_source", artist_cols, genre_raw_cols,
          gf_cols, gm_cols)
out <- d[keep]
for (s in 1:10) {
  out[[gf_cols[s]]] <- labelled(out[[gf_cols[s]]], setNames(1:20, genre_labels))
}
write_dta(out, "dta/genresobjects_processed.dta")

# QC summary
cat("rows:", nrow(out), "\n")
cat("stream_source:\n")
print(table(out$stream_source, useNA = "ifany"))
cat("\nnon-missing genre_final per slot:\n")
print(colSums(!is.na(out[gf_cols])))
cat("\ndistribution of genre_method across filled slots:\n")
mv <- unlist(out[gm_cols])
mv <- mv[mv != ""]
print(sort(table(mv), decreasing = TRUE))
