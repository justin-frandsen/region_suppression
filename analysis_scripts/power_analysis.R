#-------------------------------------------------------------------------
# Script: power_analysis.R
# Description: How many subjects would be needed to detect a High vs Low
#              difference? Uses the between-subject variability of the
#              paired High - Low differences in the current data.
#   - "observed" rows: sample size needed if the true effect equals the one
#     observed so far (observed effects from small samples are unreliable,
#     so treat these as rough).
#   - RT rows: sample size needed for a range of plausible true effects.
#-------------------------------------------------------------------------
source("region_suppression_analysis.R")

paired_diff <- function(data, dv) {
  wide <- data %>% filter(DistractorLocation != "Absent") %>%
    select(sub_num, DistractorLocation, all_of(dv)) %>%
    pivot_wider(names_from = DistractorLocation, values_from = all_of(dv))
  wide$Low - wide$High
}

n_needed <- function(effect, sd_diff, power = 0.80) {
  ceiling(power.t.test(delta = abs(effect), sd = sd_diff, power = power, sig.level = 0.05,
                       type = "paired", alternative = "two.sided")$n)
}

report_power <- function(data, dv, effects = NULL) {
  d <- paired_diff(data, dv)
  n <- sum(!is.na(d)); sd_diff <- sd(d, na.rm = TRUE); observed <- mean(d, na.rm = TRUE)
  detectable <- power.t.test(n = n, sd = sd_diff, power = 0.80, sig.level = 0.05, type = "paired")$delta
  cat(sprintf("\n--- %s (Low minus High) ---\n", dv))
  cat(sprintf("observed difference = %.4g, SD of differences = %.4g, dz = %.2f, N = %d\n",
              observed, sd_diff, observed / sd_diff, n))
  cat(sprintf("smallest true difference detectable with 80%% power at N = %d: %.4g (dz = %.2f)\n",
              n, detectable, detectable / sd_diff))
  cat(sprintf("N for 80%% power if the true effect equals the observed one: %d\n", n_needed(observed, sd_diff)))
  if (!is.null(effects)) {
    print(tibble(true_effect = effects, dz = round(effects / sd_diff, 2),
                 N_for_80_power = map_dbl(effects, n_needed, sd_diff = sd_diff),
                 N_for_90_power = map_dbl(effects, n_needed, sd_diff = sd_diff, power = 0.90)))
  }
}

cat("\n======= POWER: High vs Low =======\n")
report_power(bx_summary, "meanRT", effects = c(20, 30, 40, 50, 75))
if (exists("fixation_summary")) {
  report_power(fixation_summary, "mean_crit_fixated", effects = c(0.01, 0.02, 0.03))
  report_power(fixation_summary, "mean_crit_first_fix", effects = c(0.01, 0.02))
}
