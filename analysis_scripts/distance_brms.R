#-------------------------------------------------------------------------
# Script: distance_brms.R
# Description: Trial-level Bayesian models (brms) asking whether the distance
#              between the target and the critical (colored) distractor
#              matters, and whether that depends on the distractor being at
#              the high- or low-probability location.
#
# - Only distractor-PRESENT trials are used (there is no distance on Absent
#   trials), and only the trials that survive the RT cleaning in
#   region_suppression_analysis.R (correct, not an outlier).
# - Distance = pixels between the center of the target rect and the center
#   of the critical distractor rect, z-scored for the models.
# - Location is coded High = -0.5, Low = +0.5, so the distance effect is the
#   average over locations and the location effect is at the average distance.
#
# Models
#   1. RT (lognormal):            rt ~ location * distance
#   2. Distractor fixated (0/1):  crit_fixated ~ location * distance
#   both with by-subject random intercepts and slopes and a scene intercept.
#
#   3. and 4. repeat 1. and 2. with the target's and the distractor's distance
#      from the screen center added as covariates (see ANALYSIS 2 below).
#
# Fits are cached in analysis_scripts/model_fits/; delete a file there to refit.
#-------------------------------------------------------------------------
source("region_suppression_analysis.R")

library(brms)
library(bayestestR)

dir.create("model_fits", showWarnings = FALSE)

# ======= DISTANCE =====================
present_trials <- all_bx_files %>%
  filter(DistractorLocation != "Absent", !is.na(rt)) %>%
  mutate(target_x = (target_rect_1 + target_rect_3) / 2,
         target_y = (target_rect_2 + target_rect_4) / 2,
         crit_x   = (critical_distractor_rect_1 + critical_distractor_rect_3) / 2,
         crit_y   = (critical_distractor_rect_2 + critical_distractor_rect_4) / 2,
         distance_px = sqrt((target_x - crit_x)^2 + (target_y - crit_y)^2),
         distance_z  = as.numeric(scale(distance_px)),
         location_c  = ifelse(DistractorLocation == "Low", 0.5, -0.5),
         DistractorLocation = droplevels(DistractorLocation),
         scene_idx = as.factor(scene_idx))

distance_mean <- mean(present_trials$distance_px)
distance_sd   <- sd(present_trials$distance_px)

cat("\n======= Distance (pixels) by distractor location =======\n")
present_trials %>%
  group_by(DistractorLocation) %>%
  summarise(n = n(), mean = mean(distance_px), sd = sd(distance_px),
            min = min(distance_px), max = max(distance_px)) %>%
  print()

# descriptive: mean RT by distance third (each subject's own trials)
cat("\n======= Mean RT (ms) by distance third =======\n")
present_trials %>%
  mutate(distance_third = cut(distance_px, quantile(distance_px, c(0, 1/3, 2/3, 1)),
                              labels = c("Near", "Middle", "Far"), include.lowest = TRUE)) %>%
  group_by(sub_num, DistractorLocation, distance_third) %>%
  summarise(meanRT = mean(rt), .groups = "drop") %>%
  group_by(DistractorLocation, distance_third) %>%
  summarise(meanRT = mean(meanRT), .groups = "drop") %>%
  pivot_wider(names_from = distance_third, values_from = meanRT) %>%
  print()

# ---- helper: posterior summary of the fixed effects ----
report_fixed <- function(fit) {
  describe_posterior(fit, centrality = "median", ci = 0.95, ci_method = "eti",
                     test = "p_direction", effects = "fixed") %>%
    as_tibble() %>%
    select(Parameter, Median, CI_low, CI_high, pd, Rhat, ESS) %>%
    print()
}

# ======= MODEL 1: RT =====================
rt_priors <- c(prior(normal(7.3, 0.5), class = "Intercept"),   # exp(7.3) is about 1500 ms
               prior(normal(0, 0.2), class = "b"),
               prior(exponential(5), class = "sd"),
               prior(exponential(2), class = "sigma"),
               prior(lkj(2), class = "cor"))

fit_rt <- brm(rt ~ location_c * distance_z +
                (1 + location_c + distance_z | sub_num) + (1 | scene_idx),
              data = present_trials, family = lognormal(),
              prior = rt_priors,
              chains = 4, cores = 4, iter = 2000, warmup = 1000, seed = 2026,
              backend = "cmdstanr", refresh = 0,
              file = "model_fits/fit_rt_distance")

cat("\n======= MODEL 1: RT ~ location * distance (log scale) =======\n")
report_fixed(fit_rt)

# effect of distance in ms: median RT at -1 SD (near) vs +1 SD (far), per location
rt_draws <- as_draws_df(fit_rt)
predicted_rt <- function(loc, dist) {
  exp(rt_draws$b_Intercept + rt_draws$b_location_c * loc + rt_draws$b_distance_z * dist +
        rt_draws$`b_location_c:distance_z` * loc * dist)
}
summarise_draws_ms <- function(x) {
  tibble(median = median(x), CI_low = quantile(x, 0.025), CI_high = quantile(x, 0.975),
         prob_above_0 = mean(x > 0))
}
cat("\n--- Far minus near (+1 SD vs -1 SD of distance), in ms ---\n")
bind_rows(High = summarise_draws_ms(predicted_rt(-0.5, 1) - predicted_rt(-0.5, -1)),
          Low  = summarise_draws_ms(predicted_rt(0.5, 1) - predicted_rt(0.5, -1)),
          .id = "DistractorLocation") %>% print()
cat("\n--- Low minus High at the average distance, in ms ---\n")
print(summarise_draws_ms(predicted_rt(0.5, 0) - predicted_rt(-0.5, 0)))

# ======= MODEL 2: critical distractor fixated =====================
if (exists("trial_fixation_summary")) {
  present_eye_trials <- present_trials %>%
    inner_join(trial_fixation_summary %>% select(sub_num, run_num, trial_num, crit_fixated, crit_first_fix),
               by = c("sub_num", "run_num", "trial_num"))

  fix_priors <- c(prior(normal(-2.5, 1.5), class = "Intercept"),   # plogis(-2.5) is about 8%
                  prior(normal(0, 1), class = "b"),
                  prior(exponential(2), class = "sd"),
                  prior(lkj(2), class = "cor"))

  fit_fix <- brm(crit_fixated ~ location_c * distance_z +
                   (1 + location_c + distance_z | sub_num) + (1 | scene_idx),
                 data = present_eye_trials, family = bernoulli(),
                 prior = fix_priors,
                 chains = 4, cores = 4, iter = 2000, warmup = 1000, seed = 2026,
                 backend = "cmdstanr", refresh = 0,
                 file = "model_fits/fit_crit_fixated_distance")

  cat("\n======= MODEL 2: distractor fixated ~ location * distance (log-odds) =======\n")
  report_fixed(fit_fix)

  fix_draws <- as_draws_df(fit_fix)
  predicted_p <- function(loc, dist) {
    plogis(fix_draws$b_Intercept + fix_draws$b_location_c * loc + fix_draws$b_distance_z * dist +
             fix_draws$`b_location_c:distance_z` * loc * dist)
  }
  cat("\n--- Probability the distractor is fixated: far minus near (+1 SD vs -1 SD) ---\n")
  bind_rows(High = summarise_draws_ms(predicted_p(-0.5, 1) - predicted_p(-0.5, -1)),
            Low  = summarise_draws_ms(predicted_p(0.5, 1) - predicted_p(0.5, -1)),
            .id = "DistractorLocation") %>% print()
  cat("\n--- Probability the distractor is fixated: Low minus High at the average distance ---\n")
  print(summarise_draws_ms(predicted_p(0.5, 0) - predicted_p(-0.5, 0)))
}


#=========================================================================
# ANALYSIS 2: same models, controlling for eccentricity
#   Every trial starts at the center of the screen, and a target that is far
#   from the distractor also tends to be far from the center. Models 3 and 4
#   add how far the target and the distractor are from the screen center, so
#   the distance effect is no longer mixed up with eccentricity.
#   (Models 1 and 2 above are kept as they were.)
#=========================================================================
screen_center <- c(1920, 1080) / 2   # display resolution used in the experiment

present_trials <- present_trials %>%
  mutate(target_ecc_px = sqrt((target_x - screen_center[1])^2 + (target_y - screen_center[2])^2),
         crit_ecc_px   = sqrt((crit_x - screen_center[1])^2 + (crit_y - screen_center[2])^2),
         target_ecc_z  = as.numeric(scale(target_ecc_px)),
         crit_ecc_z    = as.numeric(scale(crit_ecc_px)))

cat("\n======= Correlations between the distance measures =======\n")
present_trials %>%
  select(distance_px, target_ecc_px, crit_ecc_px) %>%
  cor() %>% round(2) %>% print()

# far minus near (+1 SD vs -1 SD of distance) per location, and Low minus High,
# with both eccentricities held at their average. link_inverse: exp or plogis.
report_distance_effects <- function(fit, link_inverse) {
  d <- as_draws_df(fit)
  predicted <- function(loc, dist) {
    link_inverse(d$b_Intercept + d$b_location_c * loc + d$b_distance_z * dist +
                   d$`b_location_c:distance_z` * loc * dist)
  }
  cat("\n--- Far minus near (+1 SD vs -1 SD of distance) ---\n")
  bind_rows(High = summarise_draws_ms(predicted(-0.5, 1) - predicted(-0.5, -1)),
            Low  = summarise_draws_ms(predicted(0.5, 1) - predicted(0.5, -1)),
            .id = "DistractorLocation") %>% print()
  cat("\n--- Low minus High at the average distance ---\n")
  print(summarise_draws_ms(predicted(0.5, 0) - predicted(-0.5, 0)))
  cat("\n--- +1 SD vs -1 SD of TARGET eccentricity (at average distance) ---\n")
  print(summarise_draws_ms(link_inverse(d$b_Intercept + d$b_target_ecc_z) - link_inverse(d$b_Intercept - d$b_target_ecc_z)))
  cat("\n--- +1 SD vs -1 SD of DISTRACTOR eccentricity (at average distance) ---\n")
  print(summarise_draws_ms(link_inverse(d$b_Intercept + d$b_crit_ecc_z) - link_inverse(d$b_Intercept - d$b_crit_ecc_z)))
}

# ======= MODEL 3: RT, controlling for eccentricity =====================
fit_rt_ecc <- brm(rt ~ location_c * distance_z + target_ecc_z + crit_ecc_z +
                    (1 + location_c + distance_z + target_ecc_z | sub_num) + (1 | scene_idx),
                  data = present_trials, family = lognormal(),
                  prior = rt_priors,
                  chains = 4, cores = 4, iter = 2000, warmup = 1000, seed = 2026,
                  backend = "cmdstanr", refresh = 0,
                  file = "model_fits/fit_rt_distance_eccentricity")

cat("\n======= MODEL 3: RT ~ location * distance + eccentricities (log scale) =======\n")
report_fixed(fit_rt_ecc)
report_distance_effects(fit_rt_ecc, exp)   # differences are in ms

# ======= MODEL 4: distractor fixated, controlling for eccentricity =====================
if (exists("trial_fixation_summary")) {
  present_eye_trials <- present_trials %>%
    inner_join(trial_fixation_summary %>% select(sub_num, run_num, trial_num, crit_fixated, crit_first_fix),
               by = c("sub_num", "run_num", "trial_num"))

  fit_fix_ecc <- brm(crit_fixated ~ location_c * distance_z + target_ecc_z + crit_ecc_z +
                       (1 + location_c + distance_z + crit_ecc_z | sub_num) + (1 | scene_idx),
                     data = present_eye_trials, family = bernoulli(),
                     prior = fix_priors,
                     chains = 4, cores = 4, iter = 2000, warmup = 1000, seed = 2026,
                     backend = "cmdstanr", refresh = 0,
                     file = "model_fits/fit_crit_fixated_distance_eccentricity")

  cat("\n======= MODEL 4: distractor fixated ~ location * distance + eccentricities (log-odds) =======\n")
  report_fixed(fit_fix_ecc)
  report_distance_effects(fit_fix_ecc, plogis)   # differences are in probability
}

cat(sprintf("\nTarget-distractor distance: mean = %.0f px, 1 SD = %.0f px\n", distance_mean, distance_sd))
cat(sprintf("Target eccentricity: mean = %.0f px, 1 SD = %.0f px\n", mean(present_trials$target_ecc_px), sd(present_trials$target_ecc_px)))
cat(sprintf("Distractor eccentricity: mean = %.0f px, 1 SD = %.0f px\n", mean(present_trials$crit_ecc_px), sd(present_trials$crit_ecc_px)))
