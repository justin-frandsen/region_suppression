#-------------------------------------------------------------------------
# Script: model_comparison_brms.R
# Description: Two follow-ups to distance_brms.R
#   A. Bayes factors for the paired comparisons from the ANOVAs
#      (is "no difference" actually supported, or just not significant?)
#   B. Model comparison (leave-one-out cross-validation): does adding the
#      eccentricity controls, the location x distance interaction, or all the
#      other two-way interactions make the models predict better?
#   C. Bayes factors for each effect in the main models (models 3 and 4).
#
# Reading Bayes factors (BF10 = evidence for an effect, BF01 = 1/BF10 =
# evidence for no effect):
#   > 10 strong, 3 to 10 moderate, 1 to 3 anecdotal (inconclusive).
# The BFs in section C depend on the priors in distance_brms.R:
#   RT model: normal(0, 0.2) on the log scale; fixation model: normal(0, 1)
#   on the log-odds scale. Wider priors favor the null more.
#-------------------------------------------------------------------------
source("distance_brms.R")

# ======= A. BAYES FACTORS FOR THE PAIRED COMPARISONS =====================
# Default JZS Bayes factor for a paired t-test (Rouder et al., 2009), Cauchy
# prior on effect size with scale 0.707. Same as BayesFactor::ttestBF().
jzs_bf10 <- function(x, y, r = 0.707) {
  d <- x - y
  d <- d[!is.na(d)]
  n <- length(d); v <- n - 1
  t <- mean(d) / (sd(d) / sqrt(n))
  null_lik <- (1 + t^2 / v)^(-(v + 1) / 2)
  alt_lik <- integrate(function(g) {
    (1 + n * g * r^2)^(-1 / 2) * (1 + t^2 / ((1 + n * g * r^2) * v))^(-(v + 1) / 2) *
      (2 * pi)^(-1 / 2) * g^(-3 / 2) * exp(-1 / (2 * g))
  }, lower = 0, upper = Inf)$value
  tibble(mean_diff = mean(d), t = t, df = v, p = 2 * pt(-abs(t), v),
         BF10 = alt_lik / null_lik, BF01 = null_lik / alt_lik)
}

paired_bf <- function(data, dv, level1, level2) {
  wide <- data %>% select(sub_num, DistractorLocation, all_of(dv)) %>%
    pivot_wider(names_from = DistractorLocation, values_from = all_of(dv))
  jzs_bf10(wide[[level1]], wide[[level2]]) %>%
    mutate(measure = dv, comparison = paste(level1, "-", level2), .before = 1)
}

cat("\n======= A. Bayes factors for the paired comparisons =======\n")
bf_table <- bind_rows(
  paired_bf(bx_summary, "meanRT", "High", "Low"),
  paired_bf(bx_summary, "meanRT", "Absent", "High"),
  paired_bf(bx_summary, "meanRT", "Absent", "Low"),
  paired_bf(bx_summary, "meanACC", "High", "Low"),
  paired_bf(bx_summary, "meanACC", "Absent", "High"),
  paired_bf(bx_summary, "meanACC", "Absent", "Low"))
if (exists("fixation_summary")) {
  bf_table <- bind_rows(
    bf_table,
    paired_bf(fixation_summary, "mean_target_first_fix", "High", "Low"),
    paired_bf(fixation_summary, "mean_target_first_fix", "Absent", "High"),
    paired_bf(fixation_summary, "mean_target_first_fix", "Absent", "Low"),
    paired_bf(fixation_summary, "mean_Target_fixation_number", "High", "Low"),
    paired_bf(fixation_summary, "mean_Target_fixation_number", "Absent", "High"),
    paired_bf(fixation_summary, "mean_Target_fixation_number", "Absent", "Low"),
    paired_bf(fixation_summary, "mean_crit_first_fix", "High", "Low"),
    paired_bf(fixation_summary, "mean_crit_fixated", "High", "Low"),
    paired_bf(fixation_summary, "mean_dur_CritDist", "High", "Low"))
}
print(bf_table %>% mutate(across(where(is.numeric), ~ signif(.x, 3))), n = Inf, width = 200)

# ======= B. MODEL COMPARISON (LOO) =====================
fit_settings <- list(chains = 4, cores = 4, iter = 2000, warmup = 1000, seed = 2026,
                     backend = "cmdstanr", refresh = 0)

# ---- RT ----
fit_rt_ecc_noint <- do.call(brm, c(list(
  rt ~ location_c + distance_z + target_ecc_z + crit_ecc_z +
    (1 + location_c + distance_z + target_ecc_z | sub_num) + (1 | scene_idx),
  data = present_trials, family = lognormal(), prior = rt_priors,
  file = "model_fits/fit_rt_ecc_no_interaction"), fit_settings))

fit_rt_ecc_twoway <- do.call(brm, c(list(
  rt ~ (location_c + distance_z + target_ecc_z + crit_ecc_z)^2 +
    (1 + location_c + distance_z + target_ecc_z | sub_num) + (1 | scene_idx),
  data = present_trials, family = lognormal(), prior = rt_priors,
  file = "model_fits/fit_rt_ecc_all_twoway"), fit_settings))

cat("\n======= B1. LOO comparison: RT models =======\n")
cat("(best model on top; elpd_diff = how much worse each model predicts than the best;\n")
cat(" a difference smaller than about 2 x se_diff is not a reliable difference)\n")
loo_rt <- loo_compare(list("1. location x distance (no eccentricity)"     = loo(fit_rt),
                           "3b. + eccentricity, no interaction"           = loo(fit_rt_ecc_noint),
                           "3. + eccentricity (main model)"               = loo(fit_rt_ecc),
                           "3c. + eccentricity, all two-way interactions" = loo(fit_rt_ecc_twoway)))
print(loo_rt, simplify = TRUE)

cat("\n--- Extra interaction terms in the all-two-way RT model ---\n")
report_fixed(fit_rt_ecc_twoway)

# ---- distractor fixated ----
if (exists("present_eye_trials")) {
  fit_fix_ecc_noint <- do.call(brm, c(list(
    crit_fixated ~ location_c + distance_z + target_ecc_z + crit_ecc_z +
      (1 + location_c + distance_z + crit_ecc_z | sub_num) + (1 | scene_idx),
    data = present_eye_trials, family = bernoulli(), prior = fix_priors,
    file = "model_fits/fit_fix_ecc_no_interaction"), fit_settings))

  fit_fix_ecc_twoway <- do.call(brm, c(list(
    crit_fixated ~ (location_c + distance_z + target_ecc_z + crit_ecc_z)^2 +
      (1 + location_c + distance_z + crit_ecc_z | sub_num) + (1 | scene_idx),
    data = present_eye_trials, family = bernoulli(), prior = fix_priors,
    file = "model_fits/fit_fix_ecc_all_twoway"), fit_settings))

  cat("\n======= B2. LOO comparison: distractor-fixated models =======\n")
  loo_fix <- loo_compare(list("2. location x distance (no eccentricity)"     = loo(fit_fix),
                              "4b. + eccentricity, no interaction"           = loo(fit_fix_ecc_noint),
                              "4. + eccentricity (main model)"               = loo(fit_fix_ecc),
                              "4c. + eccentricity, all two-way interactions" = loo(fit_fix_ecc_twoway)))
  print(loo_fix, simplify = TRUE)

  cat("\n--- Extra interaction terms in the all-two-way fixation model ---\n")
  report_fixed(fit_fix_ecc_twoway)
}

# ======= C. BAYES FACTORS FOR EACH EFFECT IN THE MAIN MODELS =====================
# Savage-Dickey Bayes factors need draws from the prior too, so models 3 and 4
# are refitted with sample_prior = "yes" and more iterations (stable BFs).
bf_settings <- modifyList(fit_settings, list(iter = 6000, warmup = 1000, sample_prior = "yes"))

effect_bayes_factors <- function(fit) {
  terms <- c("location_c", "distance_z", "location_c:distance_z", "target_ecc_z", "crit_ecc_z")
  map_dfr(terms, function(term) {
    h <- hypothesis(fit, paste(term, "= 0"))$hypothesis   # Evid.Ratio = BF01 for a point null
    tibble(effect = term, estimate = h$Estimate, CI_low = h$CI.Lower, CI_high = h$CI.Upper,
           BF01 = h$Evid.Ratio, BF10 = 1 / h$Evid.Ratio)
  }) %>% mutate(across(where(is.numeric), ~ signif(.x, 3)))
}

fit_rt_ecc_bf <- do.call(brm, c(list(
  rt ~ location_c * distance_z + target_ecc_z + crit_ecc_z +
    (1 + location_c + distance_z + target_ecc_z | sub_num) + (1 | scene_idx),
  data = present_trials, family = lognormal(), prior = rt_priors,
  file = "model_fits/fit_rt_distance_eccentricity_bf"), bf_settings))

cat("\n======= C1. Bayes factors: RT main model (model 3) =======\n")
print(effect_bayes_factors(fit_rt_ecc_bf), width = 200)

if (exists("present_eye_trials")) {
  fit_fix_ecc_bf <- do.call(brm, c(list(
    crit_fixated ~ location_c * distance_z + target_ecc_z + crit_ecc_z +
      (1 + location_c + distance_z + crit_ecc_z | sub_num) + (1 | scene_idx),
    data = present_eye_trials, family = bernoulli(), prior = fix_priors,
    file = "model_fits/fit_crit_fixated_distance_eccentricity_bf"), bf_settings))

  cat("\n======= C2. Bayes factors: distractor-fixated main model (model 4) =======\n")
  print(effect_bayes_factors(fit_fix_ecc_bf), width = 200)
}
