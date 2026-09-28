#' @title Finish LKJ Sensitivity Comparison (post-hoc, no refitting)
#' @description The three underlying models (lkj(1), lkj(2)=original, lkj(4))
#'   already finished sampling and are saved to disk; this script only
#'   extracts and compares the genre-level LikeOnly intercept-slope
#'   correlation, one model loaded (and dropped) at a time to keep peak
#'   memory bounded. Run as a standalone Rscript, not in a shared session.

library(brms)
library(dplyr)

dir.create("cache", showWarnings = FALSE)

extract_cor <- function(path, label) {
  cat(sprintf("[%s] Loading %s ...\n", Sys.time(), path))
  fit <- readRDS(path)
  draws <- brms::as_draws_df(fit)
  cor_col <- grep("^cor_genre_id__muLikeOnly_Intercept__muLikeOnly_child_arts$", names(draws), value = TRUE)
  if (length(cor_col) == 0) {
    cor_col <- grep("^cor_genre_id.*LikeOnly.*(Intercept.*child_arts|child_arts.*Intercept)$", names(draws), value = TRUE)
  }
  res <- if (length(cor_col) == 0) {
    data.frame(Prior = label, Column = NA, Mean = NA, SD = NA, CrI_2.5 = NA, CrI_97.5 = NA)
  } else {
    x <- draws[[cor_col[1]]]
    data.frame(
      Prior = label, Column = cor_col[1],
      Mean = round(mean(x), 3), SD = round(sd(x), 3),
      CrI_2.5 = round(quantile(x, 0.025), 3), CrI_97.5 = round(quantile(x, 0.975), 3)
    )
  }
  rm(fit, draws); gc()
  res
}

comparison <- bind_rows(
  extract_cor("rds/model_brms_slopes_lkj1.rds", "LKJ(1) - uniform"),
  extract_cor("rds/model_brms_slopes.rds", "LKJ(2) - original"),
  extract_cor("rds/model_brms_slopes_lkj4.rds", "LKJ(4) - shrink toward 0")
)

write.csv(comparison, "cache/sensitivity_lkj.csv", row.names = FALSE)
cat("\n===== GENRE-LEVEL LIKEONLY INTERCEPT-SLOPE CORRELATION ACROSS LKJ PRIORS =====\n")
print(comparison)
cat("Saved to cache/sensitivity_lkj.csv\n")
