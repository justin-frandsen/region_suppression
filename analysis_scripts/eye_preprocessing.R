#-------------------------------------------------------------------------
# Script: eye_preprocessing.R
# Description: Replaces the Data Viewer fixation report. Converts the EDF
#              files to ASC (with SR Research's edf2asc utility), then pulls
#              every fixation that falls in the SEARCH_PERIOD of each trial
#              and saves one long .csv (one row per fixation).
#
# Usage:
# - Run with the working directory set to analysis_scripts/ (like E1.R/E2.R).
# - edf2asc comes with the free EyeLink Developers Kit (the same kit the
#   Eyelink toolbox in Psychtoolbox needs, so the tracking PCs have it).
#   EDF is a closed binary format, so this one step cannot be done in pure R.
#   If edf2asc is not installed on this computer, convert on a computer that
#   has it and copy the .asc files into data/asc_data/.
#
# Output: data/eye_data/fixations_search_period.csv
#   sub_num, run_num, trial_num : match the behavioral files
#   fix_index            : order of the fixation within the search period
#                          (1 = fixation in progress at search onset, same as
#                          CURRENT_FIX_INDEX in a Data Viewer interest period)
#   fix_x, fix_y         : average gaze position (pixels)
#   fix_start, fix_end   : ms relative to search display onset
#   fix_dur              : full fixation duration (ms)
#   fix_dur_in_period    : duration clipped to the search period (ms)
#   started_before_onset : TRUE if the fixation began before the search display
#-------------------------------------------------------------------------
library(tidyverse)

data_root  <- Sys.getenv("RS_DATA_ROOT", "../data")
edf_folder <- file.path(data_root, "edf_data")
asc_folder <- file.path(data_root, "asc_data")
eye_folder <- file.path(data_root, "eye_data")
out_file   <- file.path(eye_folder, "fixations_search_period.csv")

period_start_msg <- "START_TIME SEARCH_PERIOD"
period_end_msg   <- "END_TIME SEARCH_PERIOD"

dir.create(asc_folder, showWarnings = FALSE, recursive = TRUE)
dir.create(eye_folder, showWarnings = FALSE, recursive = TRUE)

# ======= STEP 1: EDF -> ASC =====================
convert_edf_to_asc <- function(edf_folder, asc_folder) {
  edf_files <- list.files(edf_folder, pattern = "\\.edf$", full.names = TRUE, ignore.case = TRUE)
  asc_names <- paste0(tools::file_path_sans_ext(basename(edf_files)), ".asc")
  todo      <- edf_files[!file.exists(file.path(asc_folder, asc_names))]
  if (length(todo) == 0) {
    message("[INFO] No new EDF files to convert.")
    return(invisible())
  }

  edf2asc <- Sys.which("edf2asc")
  if (edf2asc == "") {
    warning(length(todo), " EDF file(s) have no .asc yet and edf2asc was not found on this computer. ",
            "Install the EyeLink Developers Kit, or convert elsewhere and copy the .asc files into ",
            asc_folder, call. = FALSE)
    return(invisible())
  }

  for (edf in todo) {
    # -e = events only (fixations, saccades, messages; no samples) -> small files
    # -y = overwrite an existing .asc
    system2(edf2asc, c("-e", "-y", shQuote(edf)), stdout = FALSE, stderr = FALSE)
    made <- paste0(tools::file_path_sans_ext(edf), ".asc")  # edf2asc writes next to the EDF
    if (file.exists(made)) {
      file.rename(made, file.path(asc_folder, basename(made)))
      message("[INFO] Converted ", basename(edf))
    } else {
      warning("edf2asc did not produce an .asc for ", basename(edf),
              " (file may be a partial transfer).", call. = FALSE)
    }
  }
}

# ======= STEP 2: ASC -> fixations in the search period =====================
parse_asc_file <- function(asc_file) {
  ids <- str_match(basename(asc_file), "RSS(\\d+)R(\\d+)")
  if (is.na(ids[1, 1])) {
    warning("Skipping ", basename(asc_file), ": name does not look like RSS<sub>R<run>.asc", call. = FALSE)
    return(NULL)
  }
  lines <- readLines(asc_file, warn = FALSE)

  # ---- messages: "MSG <time> <text>" ----
  msg <- str_match(lines[startsWith(lines, "MSG")], "^MSG\\s+(\\d+)\\s+(.*)$")
  msg <- tibble(time = as.numeric(msg[, 2]), text = str_trim(msg[, 3])) %>% filter(!is.na(time))

  trial_starts <- msg %>%
    filter(str_detect(text, "^TRIALID\\s+\\d+")) %>%
    transmute(trial_num = as.integer(str_match(text, "^TRIALID\\s+(\\d+)")[, 2]), trial_time = time)
  if (nrow(trial_starts) == 0) {
    warning("No TRIALID messages in ", basename(asc_file), call. = FALSE)
    return(NULL)
  }

  # first period-start / period-end message after each TRIALID (and before the next one)
  next_trial_time <- c(trial_starts$trial_time[-1], Inf)
  first_msg_between <- function(pattern, from, to) {
    t <- msg$time[msg$text == pattern & msg$time >= from & msg$time < to]
    if (length(t) == 0) NA_real_ else t[1]
  }
  trials <- trial_starts %>%
    mutate(search_onset = map2_dbl(trial_time, next_trial_time, ~ first_msg_between(period_start_msg, .x, .y)),
           search_end   = map2_dbl(trial_time, next_trial_time, ~ first_msg_between(period_end_msg, .x, .y))) %>%
    filter(!is.na(search_onset), !is.na(search_end))   # drops aborted trials

  # ---- fixations: "EFIX <eye> <start> <end> <dur> <x> <y> <pupil>" ----
  fix <- str_split_fixed(str_squish(lines[startsWith(lines, "EFIX")]), " ", 8)
  fix <- tibble(eye = fix[, 2],
                st  = suppressWarnings(as.numeric(fix[, 3])),
                et  = suppressWarnings(as.numeric(fix[, 4])),
                dur = suppressWarnings(as.numeric(fix[, 5])),
                x   = suppressWarnings(as.numeric(fix[, 6])),
                y   = suppressWarnings(as.numeric(fix[, 7]))) %>%
    filter(!is.na(st), !is.na(x), !is.na(y))

  # binocular recording: keep one eye (left, same as the experiment script)
  if (n_distinct(fix$eye) > 1) fix <- fix %>% filter(eye == "L")
  if (nrow(fix) == 0 || nrow(trials) == 0) return(NULL)

  # ---- keep fixations that overlap each trial's search period ----
  trials %>%
    mutate(fixations = map2(search_onset, search_end, ~ fix %>% filter(et > .x, st < .y))) %>%
    unnest(fixations) %>%
    group_by(trial_num) %>%
    arrange(st, .by_group = TRUE) %>%
    mutate(fix_index = row_number()) %>%
    ungroup() %>%
    transmute(sub_num   = as.integer(ids[1, 2]),
              run_num   = as.integer(ids[1, 3]),
              trial_num,
              fix_index,
              eye,
              fix_x     = x,
              fix_y     = y,
              fix_start = st - search_onset,
              fix_end   = et - search_onset,
              fix_dur   = dur,
              fix_dur_in_period    = pmin(et, search_end) - pmax(st, search_onset),
              started_before_onset = st < search_onset,
              search_duration      = search_end - search_onset)
}

# ======= RUN =====================
convert_edf_to_asc(edf_folder, asc_folder)

asc_files <- list.files(asc_folder, pattern = "\\.asc$", full.names = TRUE, ignore.case = TRUE)
if (length(asc_files) == 0) stop("No .asc files found in ", asc_folder)

fixations <- map_dfr(asc_files, parse_asc_file)

write_csv(fixations, out_file)
message("[INFO] Saved ", nrow(fixations), " fixations from ", length(asc_files), " file(s): ", out_file)

# quick check: every subject/run should have its full set of trials
fixations %>%
  group_by(sub_num, run_num) %>%
  summarise(trials_with_fixations = n_distinct(trial_num), fixations = n(), .groups = "drop") %>%
  print(n = Inf)
