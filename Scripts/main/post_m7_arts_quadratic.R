#' @title Finish Model 7: WAIC and the H2B quadratic summary (no refitting)
#' @description The M7 job sampled successfully and saved the fit, then was
#'   OOM-killed while computing WAIC. Both remaining outputs (rds/waic_m7_artsquad.rds
#'   and cache/h2b_quadratic_arts.csv) are written after that point in the fit
#'   script, so neither exists. This script rebuilds both from the saved fit.
#'   It does NOT write back to the fit file.
#'
#'   Input:  rds/model_brms_m7_artsquad.rds
#'   Output: rds/waic_m7_artsquad.rds, cache/h2b_quadratic_arts.csv

suppressMessages({
  library(cmdstanr)
  library(brms)
  library(dplyr)
})

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

cat("Loading saved M7 fit...\n")
fit <- readRDS("rds/model_brms_m7_artsquad.rds")
dr <- brms::as_draws_df(fit)
cat("Draws:", nrow(dr), "\n")

# Centering constant used when the fit was built: arts_c = child_arts - arts_mean
arts_mean <- if (!is.null(fit$data) && "child_arts" %in% names(fit$data)) {
  mean(fit$data$child_arts)
} else {
  message("fit$data unavailable; recomputing the centering constant from the model input")
  mean(haven::read_dta("dta/analysis_model_input.dta")$child_arts)
}
cat("arts_mean:", round(arts_mean, 4), "\n")

cat("Computing WAIC...\n")
waic_res <- brms::waic(fit)
saveRDS(waic_res, "rds/waic_m7_artsquad.rds")
cat("\n===== WAIC: m7_artsquad =====\n")
print(waic_res)

# H2B verdict: sign and credibility of the curvature, plus the vertex in the
# original 1-7 metric.
h2b <- dplyr::bind_rows(lapply(c("muListenOnly", "muLikeOnly", "muBoth"), function(s) {
  b1 <- dr[[paste0("b_", s, "_arts_c")]]
  b2 <- dr[[paste0("b_", s, "_arts_c2")]]
  vx <- arts_mean - b1 / (2 * b2)
  data.frame(
    State = gsub("^mu", "", s),
    b_linear = round(mean(b1), 3),
    b_quadratic = round(mean(b2), 3),
    quad_CrI_2.5 = round(quantile(b2, 0.025), 3),
    quad_CrI_97.5 = round(quantile(b2, 0.975), 3),
    p_quad = round(2 * min(mean(b2 <= 0), mean(b2 >= 0)), 4),
    vertex = round(median(vx), 2),
    vertex_CrI_2.5 = round(quantile(vx, 0.025), 2),
    vertex_CrI_97.5 = round(quantile(vx, 0.975), 2),
    vertex_in_range = round(mean(vx > 1 & vx < 7), 3)
  )
}))

dir.create("cache", showWarnings = FALSE)
write.csv(h2b, "cache/h2b_quadratic_arts.csv", row.names = FALSE)
cat("\n===== H2B: QUADRATIC ARTS EXPOSURE =====\n")
print(h2b)
cat("Saved cache/h2b_quadratic_arts.csv\n")
