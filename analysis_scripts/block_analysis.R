#-------------------------------------------------------------------------
# Script: block_analysis.R
# Description: Does suppression of the high-probability location develop
#              over the experiment? Same measures as
#              region_suppression_analysis.R, split by block
#              (block 1-6 = runs 2-7).
#
#   A. Condition x block means and repeated measures ANOVAs
#   B. High vs Low difference in each block (paired t-tests)
#   C. Trial-level mixed models with block as a linear predictor
#      (lmer for log RT, glmer for distractor fixated)
#
# NOTE: there are only about 12 Low trials per subject per block (72 in the
# whole experiment), so single-block Low means are noisy. The trial-level
# models in C use every trial and are the better test of a change over time.
#-------------------------------------------------------------------------
source("region_suppression_analysis.R")

all_bx_files <- all_bx_files %>%
  mutate(block = as.integer(as.character(run_num)) - 1,   # run 2 = block 1
         block_f = factor(block),
         block_c = block - 3.5)                           # centered, for the mixed models

# ======= A. CONDITION x BLOCK =====================
block_summary <- all_bx_files %>%
  group_by(sub_num, DistractorLocation, block_f) %>%
  summarise(meanRT = mean(rt, na.rm = TRUE), meanACC = mean(correct), n_trials = n(), .groups = "drop")

cat("\n======= A. Trials per subject per cell (min / mean) =======\n")
block_summary %>% group_by(DistractorLocation) %>%
  summarise(min_trials = min(n_trials), mean_trials = mean(n_trials)) %>% print()

cat("\n======= A. Mean RT (ms) by condition and block =======\n")
block_summary %>% group_by(DistractorLocation, block_f) %>%
  summarise(meanRT = mean(meanRT, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = block_f, values_from = meanRT, names_prefix = "block") %>% print()

cat("\n======= A. RT: condition x block ANOVA =======\n")
aov_RT_block <- aov(meanRT ~ DistractorLocation * block_f + Error(sub_num / (DistractorLocation * block_f)),
                    data = block_summary)
print(summary(aov_RT_block))
print(effectsize::eta_squared(aov_RT_block, partial = TRUE, ci = 0.95))

cat("\n======= A. RT: High vs Low only x block ANOVA =======\n")
aov_RT_block_HL <- aov(meanRT ~ DistractorLocation * block_f + Error(sub_num / (DistractorLocation * block_f)),
                       data = block_summary %>% filter(DistractorLocation != "Absent") %>% droplevels())
print(summary(aov_RT_block_HL))

# ======= B. HIGH vs LOW IN EACH BLOCK =====================
# data: one row per subject x DistractorLocation x block_f
high_low_by_block <- function(data, dv) {
  data %>%
    filter(DistractorLocation != "Absent") %>%
    select(sub_num, block_f, DistractorLocation, all_of(dv)) %>%
    pivot_wider(names_from = DistractorLocation, values_from = all_of(dv)) %>%
    group_by(block_f) %>%
    summarise(mean_High = mean(High, na.rm = TRUE), mean_Low = mean(Low, na.rm = TRUE),
              Low_minus_High = mean(Low - High, na.rm = TRUE),
              t = t.test(Low, High, paired = TRUE)$statistic,
              df = t.test(Low, High, paired = TRUE)$parameter,
              p = t.test(Low, High, paired = TRUE)$p.value, .groups = "drop") %>%
    mutate(across(where(is.numeric), ~ signif(.x, 3)))
}

cat("\n======= B. RT: Low minus High in each block (positive = suppression) =======\n")
print(high_low_by_block(block_summary, "meanRT"))

# ======= C. TRIAL-LEVEL: does the effect change across blocks? =====================
# Contrasts: present vs absent, and Low vs High (the suppression effect)
lmer_block_data <- all_bx_files %>%
  filter(!is.na(log_rt)) %>%
  mutate(present_vs_absent = ifelse(DistractorLocation == "Absent", -2/3, 1/3),
         low_vs_high = case_when(DistractorLocation == "Low" ~ 0.5,
                                 DistractorLocation == "High" ~ -0.5,
                                 TRUE ~ 0))

cat("\n======= C. log RT ~ (present vs absent + Low vs High) * block =======\n")
lmer_RT_block <- lmer(log_rt ~ (present_vs_absent + low_vs_high) * block_c +
                        (1 + block_c | sub_num) + (1 | scene_idx),
                      data = lmer_block_data)
print(summary(lmer_RT_block)$coefficients)
cat("\nlow_vs_high         = suppression effect (Low slower than High) at the middle of the experiment\n")
cat("low_vs_high:block_c = change in that effect per block (positive = suppression grows)\n")

#======================= EYE MOVEMENTS BY BLOCK =========================
if (exists("trial_fixation_summary")) {
  trial_fixation_summary <- trial_fixation_summary %>%
    mutate(block = as.integer(as.character(run_num)) - 1, block_f = factor(block), block_c = block - 3.5)

  fixation_block_summary <- trial_fixation_summary %>%
    group_by(sub_num, DistractorLocation, block_f) %>%
    summarise(mean_crit_fixated = mean(crit_fixated), mean_crit_first_fix = mean(crit_first_fix),
              mean_target_first_fix = mean(target_first_fix),
              mean_Target_fixation_number = mean(Target_fixation_number, na.rm = TRUE), .groups = "drop")

  cat("\n======= B. Distractor fixated at any point: Low minus High in each block =======\n")
  print(high_low_by_block(fixation_block_summary, "mean_crit_fixated"))
  cat("\n======= B. Distractor was first shape fixated: Low minus High in each block =======\n")
  print(high_low_by_block(fixation_block_summary, "mean_crit_first_fix"))
  cat("\n======= B. Fixation number of first target fixation: Low minus High in each block =======\n")
  print(high_low_by_block(fixation_block_summary, "mean_Target_fixation_number"))

  cat("\n======= C. Distractor fixated ~ Low vs High * block (logistic mixed model) =======\n")
  glmer_data <- trial_fixation_summary %>%
    filter(DistractorLocation != "Absent") %>%
    mutate(low_vs_high = ifelse(DistractorLocation == "Low", 0.5, -0.5))
  glmer_fix_block <- glmer(crit_fixated ~ low_vs_high * block_c + (1 + block_c | sub_num),
                           data = glmer_data, family = binomial,
                           control = glmerControl(optimizer = "bobyqa"))
  print(summary(glmer_fix_block)$coefficients)

  cat("\n======= C. Distractor was first shape fixated ~ Low vs High * block =======\n")
  glmer_first_block <- glmer(crit_first_fix ~ low_vs_high * block_c + (1 + block_c | sub_num),
                             data = glmer_data, family = binomial,
                             control = glmerControl(optimizer = "bobyqa"))
  print(summary(glmer_first_block)$coefficients)
}

#======================= BLOCK EFFECTS WITH DISTANCE COVARIATES =========================
# Same question (does the Low vs High effect change over blocks?), on
# distractor-present trials, controlling for target-distractor distance and
# for how far the target and the distractor are from the screen center.
# Location also gets a by-subject random slope here.
screen_center <- c(1920, 1080) / 2

present_block_trials <- all_bx_files %>%
  filter(DistractorLocation != "Absent", !is.na(log_rt)) %>%
  mutate(target_x = (target_rect_1 + target_rect_3) / 2,
         target_y = (target_rect_2 + target_rect_4) / 2,
         crit_x   = (critical_distractor_rect_1 + critical_distractor_rect_3) / 2,
         crit_y   = (critical_distractor_rect_2 + critical_distractor_rect_4) / 2,
         distance_z   = as.numeric(scale(sqrt((target_x - crit_x)^2 + (target_y - crit_y)^2))),
         target_ecc_z = as.numeric(scale(sqrt((target_x - screen_center[1])^2 + (target_y - screen_center[2])^2))),
         crit_ecc_z   = as.numeric(scale(sqrt((crit_x - screen_center[1])^2 + (crit_y - screen_center[2])^2))),
         low_vs_high  = ifelse(DistractorLocation == "Low", 0.5, -0.5))

cat("\n======= D. log RT ~ Low vs High * block + distance covariates =======\n")
lmer_RT_block_cov <- lmer(log_rt ~ low_vs_high * block_c + distance_z + target_ecc_z + crit_ecc_z +
                            (1 + low_vs_high + block_c | sub_num) + (1 | scene_idx),
                          data = present_block_trials)
print(summary(lmer_RT_block_cov)$coefficients)

if (exists("trial_fixation_summary")) {
  present_block_eye_trials <- present_block_trials %>%
    inner_join(trial_fixation_summary %>% select(sub_num, run_num, trial_num, crit_fixated, crit_first_fix),
               by = c("sub_num", "run_num", "trial_num"))

  cat("\n======= D. Distractor fixated ~ Low vs High * block + distance covariates =======\n")
  glmer_fix_block_cov <- glmer(crit_fixated ~ low_vs_high * block_c + distance_z + target_ecc_z + crit_ecc_z +
                                 (1 + low_vs_high + block_c | sub_num) + (1 | scene_idx),
                               data = present_block_eye_trials, family = binomial,
                               control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5)))
  print(summary(glmer_fix_block_cov)$coefficients)

  cat("\n======= D. Distractor was first shape fixated ~ Low vs High * block + distance covariates =======\n")
  glmer_first_block_cov <- glmer(crit_first_fix ~ low_vs_high * block_c + distance_z + target_ecc_z + crit_ecc_z +
                                   (1 + low_vs_high + block_c | sub_num) + (1 | scene_idx),
                                 data = present_block_eye_trials, family = binomial,
                                 control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5)))
  print(summary(glmer_first_block_cov)$coefficients)
}
