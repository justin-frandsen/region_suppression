#-------------------------------------------------------------------------
# Script: graphs.R
# Description: Graphs for region_suppression (same style as curious_ss
#              graphs.R): violin per condition with the mean and
#              within-subject 95% CI on top.
#-------------------------------------------------------------------------
source("region_suppression_analysis.R")

library(gghalves)

palatte_num <- 7

nicelimits <- function(x) {
  range(scales::extended_breaks(only.loose = TRUE)(x))
}

# data: one row per subject x DistractorLocation; dv: column name (string)
condition_violin <- function(data, dv, ylab, percent = FALSE) {
  data <- data %>% filter(!is.na(.data[[dv]])) %>% droplevels()

  # Compute within-subjects summary stats
  summary_within <- Rmisc::summarySEwithin(data = as.data.frame(data),
                                           measurevar = dv,
                                           withinvars = "DistractorLocation",
                                           idvar = "sub_num",
                                           na.rm = TRUE)

  p <- ggplot(data, aes(x = DistractorLocation, y = .data[[dv]])) +
    geom_half_violin(aes(fill = DistractorLocation), side = "r", alpha = 0.6,
                     position = position_nudge(x = 0.07)) +
    geom_line(aes(group = sub_num), color = "grey70", alpha = 0.5) +
    geom_point(data = summary_within, aes(color = DistractorLocation), size = 3) +
    geom_errorbar(data = summary_within,
                  aes(color = DistractorLocation,
                      ymin = .data[[dv]] - ci,
                      ymax = .data[[dv]] + ci),
                  width = 0.1) +
    labs(x = "Critical Distractor Location", y = ylab) +
    scale_fill_brewer(type = "qual", palette = palatte_num) +
    scale_color_brewer(type = "qual", palette = palatte_num) +
    theme_classic() +
    theme(legend.position = "none")

  if (percent) {
    p + scale_y_continuous(labels = scales::percent, limits = nicelimits)
  } else {
    p + scale_y_continuous(limits = nicelimits)
  }
}

response_time_violin <- condition_violin(bx_summary, "meanRT", "Mean Response Time (ms)")
response_time_violin

accuracy_violin <- condition_violin(bx_summary, "meanACC", "Accuracy", percent = TRUE)
accuracy_violin

if (exists("fixation_summary")) {
  target_first_fix_violin <- condition_violin(fixation_summary, "mean_target_first_fix",
                                              "Percentage of first fixations on target", percent = TRUE)
  print(target_first_fix_violin)

  ordinal_fix_violin <- condition_violin(fixation_summary, "mean_Target_fixation_number",
                                         "Fixation number of first target fixation")
  print(ordinal_fix_violin)

  crit_first_fix_violin <- condition_violin(fixation_summary %>% filter(DistractorLocation != "Absent"),
                                            "mean_crit_first_fix",
                                            "Percentage of first fixations on critical distractor", percent = TRUE)
  print(crit_first_fix_violin)
}
