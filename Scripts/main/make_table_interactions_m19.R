#' @title Table of the matched-interaction terms (Model 19, paper Model 4)
#' @description Fixed-effect terms of the reported fit, in the layout of Tables
#'   2-4: mean, SD, 95% credible interval and pd for each term, by equation.
#'   Row set is the two capital indicators and their matched interactions
#'   (child_arts x popularity_c, educ2 x prestige_c). The moderator main effects
#'   and the respondent-level controls are not in this table: the moderators are
#'   genre-level constants, collinear with the genre random intercepts, and are
#'   carried only so the interactions are centred on their means.
#'
#'   Draws come from cache/m19_moderator_draws.csv (post_m19_moderator_draws.R,
#'   10,000 draws per equation), so no fit has to be loaded.
#'
#'   Stars follow the Tables 2-4 rule: * 95% CrI excludes 0 (pd >= 0.975),
#'   ** 99% (pd >= 0.995), *** 99.9% (pd >= 0.999). Starred estimates are bold.
#'
#'   Outputs: Tabs/table_interactions_m19.{csv,md}

suppressMessages(library(dplyr))

dr <- read.csv("cache/m19_moderator_draws.csv", stringsAsFactors = FALSE)
stopifnot(nrow(dr) == 30000, length(unique(dr$State)) == 3)

terms <- c(
  b_arts           = "Childhood Arts Exposure",
  b_arts_pop_int   = "Childhood Arts Exposure \u00d7 Genre Popularity",
  b_educ           = "Education",
  b_educ_ratio_int = "Education \u00d7 College Preference Ratio"
)
state_levels <- c("Overclaiming", "Underclaiming", "Consistent Engagement")

stars_for <- function(pd) {
  if (pd >= 0.999) "***" else if (pd >= 0.995) "**" else if (pd >= 0.975) "*" else ""
}

fmt_bold <- function(value, stars) {
  if (value == "-0.000") value <- "0.000"      # avoid a signed zero
  if (nzchar(stars)) paste0("**", value, stars, "**") else value
}

out <- lapply(state_levels, function(st) {
  d <- dr[dr$State == st, ]
  bind_rows(lapply(names(terms), function(cl) {
    x <- d[[cl]]
    pd_val <- round(max(mean(x > 0), mean(x < 0)), 3)
    s <- stars_for(pd_val)
    data.frame(
      Equation = st,
      Predictor = terms[[cl]],
      Mean = fmt_bold(sprintf("%.3f", mean(x)), s),
      SD = sprintf("%.3f", sd(x)),
      `CrI_2.5` = sprintf("%.3f", quantile(x, 0.025)),
      `CrI_97.5` = sprintf("%.3f", quantile(x, 0.975)),
      pd = sprintf("%.3f", pd_val),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }))
}) |>
  bind_rows() |>
  mutate(Equation = factor(Equation, levels = state_levels)) |>
  arrange(Equation, match(Predictor, terms))

write.csv(out, "Tabs/table_interactions_m19.csv", row.names = FALSE)

md <- c(
  "**Table. Matched Interaction Terms (Model 19, Restricted Slopes)**",
  "",
  "Posterior estimates from the reported fit. Moderators are centered on their genre means.",
  "",
  "| Predictor | Mean | SD | 95% CrI Low | 95% CrI High | pd |",
  "|:---|:---|:---|:---|:---|:---|"
)
for (st in state_levels) {
  md <- c(md, sprintf("| **%s** | | | | | |", st))
  d <- out[out$Equation == st, ]
  for (i in seq_len(nrow(d))) {
    md <- c(md, sprintf("| %s | %s | %s | %s | %s | %s |",
                        d$Predictor[i], d$Mean[i], d$SD[i],
                        d$CrI_2.5[i], d$CrI_97.5[i], d$pd[i]))
  }
}
md <- c(md, "",
        paste("Note. Posterior Estimates from the Restricted-Slope Model with Matched",
              "Interactions (Ref: Neither). * pd \u2265 0.975 (95% CrI excludes 0),",
              "** pd \u2265 0.995, *** pd \u2265 0.999. Moderator main effects and",
              "respondent-level controls are omitted."))
writeLines(md, "Tabs/table_interactions_m19.md")

cat("\n===== MATCHED INTERACTION TERMS, MODEL 19 =====\n")
print(as.data.frame(out), row.names = FALSE)
cat("\nSaved Tabs/table_interactions_m19.csv and .md\n")
