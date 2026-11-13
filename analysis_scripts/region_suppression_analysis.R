#-------------------------------------------------------------------------
# Script: region_suppression_analysis.R
# Description: Behavioral + eye movement analysis for region_suppression.
#              Based on curious_ss/analysis_scripts/E2.R, but the eye data
#              comes from eye_preprocessing.R instead of Data Viewer reports,
#              and the design is a one-way repeated measures ANOVA on
#              critical distractor location: Absent / High / Low.
#
# Usage:
# - Working directory = analysis_scripts/
# - Run eye_preprocessing.R first if you want the eye movement section.
#
# Condition codes in the bx files:
#   0 = critical distractor absent
#   1 = critical distractor on the high-probability surface
#   2, 3 = critical distractor on one of the two low-probability surfaces
# Color codes as actually drawn by region_suppression.m:
#   1 = magenta, 2 = green, 3 = blue
#-------------------------------------------------------------------------
library(tidyverse)
library(lme4)
library(lmerTest)    # for p-values in lmer
library(emmeans)
library(effectsize)

# ======= SETTINGS =====================
data_root     <- Sys.getenv("RS_DATA_ROOT", "../data")
bx_folder     <- file.path(data_root, "bx_data")
fixation_file <- file.path(data_root, "eye_data", "fixations_search_period.csv")

required_main_runs <- 6   # main runs a subject needs to be included (practice, run 1, is not counted:
                          # the practice file was not saved for most subjects)
min_accuracy     <- 0.80   # overall accuracy cutoff (main runs)
min_rt           <- 200    # ms, hard lower bound
sd_cutoff        <- 3      # RTs beyond this many SDs are removed
roi_pad          <- 0      # pixels added around each shape rect when scoring fixations
excluded_subs    <- c()    # e.g. c(120)

# ======= IMPORT BEHAVIORAL DATA =====================
bx_files <- list.files(bx_folder, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
if (length(bx_files) == 0) stop("No CSV files found in folder: ", bx_folder)

# everything is read as text first because the practice files have a
# different set of (empty) critical distractor columns than the main runs
raw_imported_bx_files <- map_dfr(bx_files, ~ read_csv(.x, col_types = cols(.default = col_character()))) %>%
  type_convert(col_types = cols(phase = col_character(), scene_file = col_character(),
                                response_key = col_character(), timestamp = col_character()),
               na = c("", "NA", "NaN"))

all_imported_bx_files <- raw_imported_bx_files %>%
  filter(run_num != 1) %>%   # run 1 is practice
  mutate(DistractorLocation = case_when(condition == 0 ~ "Absent",
                                        condition == 1 ~ "High",
                                        condition %in% c(2, 3) ~ "Low"),
         DistractorLocation = factor(DistractorLocation, levels = c("Absent", "High", "Low")),
         correct = as.integer(accuracy == 1))   # accuracy: 1 correct, 0 incorrect, -1 no response

# ======= RUN SUMMARY & ACCURACY =====================
unique_run_summary <- raw_imported_bx_files %>%
  group_by(sub_num) %>%
  summarise(unique_runs = n_distinct(run_num[run_num != 1]),   # main runs only
            overall_accuracy = mean(accuracy[run_num != 1] == 1, na.rm = TRUE),
            .groups = "drop")
print(unique_run_summary, n = Inf)

# ======= BEHAVIORAL DATA CLEANUP & FILTERING =======
all_bx_files <- all_imported_bx_files %>%
  left_join(unique_run_summary, by = "sub_num") %>%
  # --- Basic inclusion filters ---
  filter(unique_runs >= required_main_runs,
         overall_accuracy > min_accuracy,
         !sub_num %in% excluded_subs) %>%
  # --- Remove RT outliers within participant and condition ---
  group_by(sub_num, DistractorLocation) %>%
  mutate(rt = ifelse(correct == 0, NA, rt),
         rt = ifelse(rt <= min_rt, NA, rt),   # Hard lower bound
         mean_rt = mean(rt, na.rm = TRUE),
         sd_rt   = sd(rt, na.rm = TRUE),
         rt = ifelse(rt > mean_rt + sd_cutoff * sd_rt | rt < mean_rt - sd_cutoff * sd_rt, NA, rt)) %>%
  ungroup() %>%
  select(-mean_rt, -sd_rt) %>%
  mutate(log_rt = log(rt),
         sub_num = as.factor(sub_num),
         run_num = as.factor(run_num))

removed_trials <- all_bx_files %>%
  group_by(sub_num) %>%
  summarise(total_trials = n(),
            kept_trials = sum(!is.na(rt)),
            removed_trials = sum(is.na(rt)))
print(removed_trials, n = Inf)

# ======= SUMMARIES (one row per subject x condition) =======
bx_summary <- all_bx_files %>%
  group_by(sub_num, DistractorLocation) %>%
  summarise(meanRT = mean(rt, na.rm = TRUE),
            meanACC = mean(correct, na.rm = TRUE),
            n_trials = n(),
            .groups = "drop")

print(table(bx_summary$DistractorLocation)) # checks to make sure that we have balanced data

# ---- helper: one-way repeated measures ANOVA + follow-ups ----
# NOTE: aov() does not apply a sphericity correction. With 3 levels that can
# matter for the omnibus F; the paired t-tests below are not affected.
run_rm_anova <- function(data, dv) {
  data <- data %>% filter(!is.na(.data[[dv]])) %>% droplevels()
  # keep only subjects who have every level of the factor
  data <- data %>% group_by(sub_num) %>%
    filter(n_distinct(DistractorLocation) == nlevels(data$DistractorLocation)) %>% ungroup()

  cat("\n==================", dv, "==================\n")
  # bquote puts the real formula and data into the call so emmeans can re-fit the model
  model_formula <- as.formula(paste(dv, "~ DistractorLocation + Error(sub_num/DistractorLocation)"))
  model <- eval(bquote(aov(.(model_formula), data = .(data))))
  print(summary(model))
  print(effectsize::eta_squared(model, partial = TRUE, ci = 0.95))
  print(emmeans(model, pairwise ~ DistractorLocation))

  # paired t-tests for every pair of levels
  wide <- data %>% select(sub_num, DistractorLocation, all_of(dv)) %>%
    pivot_wider(names_from = DistractorLocation, values_from = all_of(dv))
  pairs <- combn(levels(data$DistractorLocation), 2, simplify = FALSE)
  for (p in pairs) {
    cat("\n---", p[1], "vs", p[2], "---\n")
    print(t.test(wide[[p[1]]], wide[[p[2]]], paired = TRUE))
  }
  invisible(model)
}

# ======= RT & ACCURACY ANOVA =======
aov_RT  <- run_rm_anova(bx_summary, "meanRT")
aov_ACC <- run_rm_anova(bx_summary, "meanACC")

# ======= SINGLE-TRIAL LOG RT =======
lmer_data <- all_bx_files %>% filter(!is.na(log_rt))
lmer_RT <- lmer(log_rt ~ DistractorLocation + (1 | sub_num) + (1 | scene_idx), data = lmer_data)
print(summary(lmer_RT))
print(emmeans(lmer_RT, pairwise ~ DistractorLocation))

#======================= EYETRACKING ANALYSIS =========================
if (!file.exists(fixation_file)) {
  message("[INFO] No fixation file found (", fixation_file, "). Run eye_preprocessing.R to get the eye movement analysis.")
} else {
  fixations <- read_csv(fixation_file, show_col_types = FALSE) %>%
    mutate(sub_num = as.factor(sub_num), run_num = as.factor(run_num))

  # ---- attach each trial's shape rects ([left top right bottom]) from the bx file ----
  in_rect <- function(x, y, left, top, right, bottom) {
    !is.na(left) & x >= left - roi_pad & x <= right + roi_pad & y >= top - roi_pad & y <= bottom + roi_pad
  }

  fixations_with_ROIs <- fixations %>%
    inner_join(all_bx_files %>%
                 select(sub_num, run_num, trial_num, DistractorLocation, condition, rt,
                        matches("_rect")),
               by = c("sub_num", "run_num", "trial_num")) %>%
    filter(!is.na(rt)) %>%   # same trials as the RT analysis (correct, not an outlier)
    mutate(in_TargetBox = in_rect(fix_x, fix_y, target_rect_1, target_rect_2, target_rect_3, target_rect_4),
           in_CritDistBox = in_rect(fix_x, fix_y, critical_distractor_rect_1, critical_distractor_rect_2,
                                    critical_distractor_rect_3, critical_distractor_rect_4),
           in_NonCritDistBox =
             in_rect(fix_x, fix_y, noncritical_distractor_rect1_1, noncritical_distractor_rect1_2, noncritical_distractor_rect1_3, noncritical_distractor_rect1_4) |
             in_rect(fix_x, fix_y, noncritical_distractor_rect2_1, noncritical_distractor_rect2_2, noncritical_distractor_rect2_3, noncritical_distractor_rect2_4) |
             in_rect(fix_x, fix_y, noncritical_distractor_rect3_1, noncritical_distractor_rect3_2, noncritical_distractor_rect3_3, noncritical_distractor_rect3_4) |
             in_rect(fix_x, fix_y, noncritical_distractor_rect4_1, noncritical_distractor_rect4_2, noncritical_distractor_rect4_3, noncritical_distractor_rect4_4) |
             in_rect(fix_x, fix_y, noncritical_distractor_rect5_1, noncritical_distractor_rect5_2, noncritical_distractor_rect5_3, noncritical_distractor_rect5_4),
           current_roi = case_when(in_TargetBox ~ "TargetBox",
                                   in_CritDistBox ~ "CritDistBox",
                                   in_NonCritDistBox ~ "NonCritDistBox",
                                   TRUE ~ NA_character_))

  # ---- Summarize fixations per trial ----
  trial_fixation_summary <- fixations_with_ROIs %>%
    group_by(sub_num, run_num, trial_num, DistractorLocation) %>%
    arrange(fix_index, .by_group = TRUE) %>%
    summarise(
      total_fixations        = n(),
      fixations_on_Target    = sum(in_TargetBox),
      fixations_on_CritDist  = sum(in_CritDistBox),
      fixations_on_NonCrit   = sum(in_NonCritDistBox),
      # ---- Total fixation duration per ROI (ms) ----
      dur_Target             = sum(fix_dur_in_period[in_TargetBox]),
      dur_CritDist           = sum(fix_dur_in_period[in_CritDistBox]),
      # ---- First shape fixated (in time order) ----
      first_fixation_ROI     = current_roi[which(!is.na(current_roi))[1]],
      # ---- Fixation number when target was first fixated ----
      Target_fixation_number = fix_index[which(in_TargetBox)[1]],
      .groups = "drop") %>%
    mutate(target_first_fix = as.integer(!is.na(first_fixation_ROI) & first_fixation_ROI == "TargetBox"),
           crit_first_fix   = as.integer(!is.na(first_fixation_ROI) & first_fixation_ROI == "CritDistBox"),
           crit_fixated     = as.integer(fixations_on_CritDist > 0))

  fixation_summary <- trial_fixation_summary %>%
    group_by(sub_num, DistractorLocation) %>%
    summarise(mean_target_first_fix       = mean(target_first_fix, na.rm = TRUE),
              mean_Target_fixation_number = mean(Target_fixation_number, na.rm = TRUE),
              mean_total_fixations        = mean(total_fixations, na.rm = TRUE),
              mean_crit_first_fix         = mean(crit_first_fix, na.rm = TRUE),
              mean_crit_fixated           = mean(crit_fixated, na.rm = TRUE),
              mean_dur_CritDist           = mean(dur_CritDist, na.rm = TRUE),
              .groups = "drop")

  # ---- Target measures: Absent vs High vs Low ----
  aov_First_fix   <- run_rm_anova(fixation_summary, "mean_target_first_fix")
  aov_ordinal_fix <- run_rm_anova(fixation_summary, "mean_Target_fixation_number")

  # ---- Critical distractor measures: only exist when it is present (High vs Low) ----
  crit_summary <- fixation_summary %>%
    filter(DistractorLocation != "Absent") %>%
    select(sub_num, DistractorLocation, mean_crit_first_fix, mean_crit_fixated, mean_dur_CritDist) %>%
    pivot_wider(names_from = DistractorLocation,
                values_from = c(mean_crit_first_fix, mean_crit_fixated, mean_dur_CritDist))

  cat("\n--- First shape fixated was the critical distractor: High vs Low ---\n")
  print(t.test(crit_summary$mean_crit_first_fix_High, crit_summary$mean_crit_first_fix_Low, paired = TRUE))
  cat("\n--- Critical distractor fixated at any point: High vs Low ---\n")
  print(t.test(crit_summary$mean_crit_fixated_High, crit_summary$mean_crit_fixated_Low, paired = TRUE))
  cat("\n--- Dwell time on critical distractor (ms): High vs Low ---\n")
  print(t.test(crit_summary$mean_dur_CritDist_High, crit_summary$mean_dur_CritDist_Low, paired = TRUE))
}
