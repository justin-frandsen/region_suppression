%-------------------------------------------------------------------------
% Script: randomizor_rs.m
% Author: Justin Frandsen
% Date: 2026/09/09 yyyy/mm/dd
% Description: Prerandomizor for the curious_ss experiment.
%
% For each subject:
% - Assigns scenes to runs (balanced across 6 runs)
% - Randomizes scene orders, distractors, targets, and conditions
% - Generates trial-specific parameters for 6 experimental runs
% - Outputs a struct per subject with trial information
%-------------------------------------------------------------------------

%% CONFIGURATION
SAVE_OUTPUT = false;  % Set to true to save output .mat file

% Column constants for scene matrix
SCENE_ID   = 1;
REP        = 2;
RUN        = 3;
DISTRACTOR = 4;
TARGET     = 5;
CONDITION  = 6;

% Experiment parameters
total_subs              = 500;   % Total subjects to generate
total_runs              = 6;     % Number of experimental runs per subject
number_trials_per_run   = 54;    % Trials per run
total_trials            = total_runs * number_trials_per_run; % Total trials
total_scenes            = 108;   % Number of unique scenes
total_reps_per_scene    = 4;     % Number of times each scene is shown

% Condition configurations
crit_dist_presence_percentage         = 2/3; % crit distractor is present 2 thrids of trials, absent 1/3 of trials
high_probability_location_percentage   = 0.75; % on target present trials, crit distractor is in high probability location 75% of the time
condition_inds         = [0 0 0 0 1 1 1 1 1 1 2 3]; % crit distractor location , 0=absent 1=high probability, 2=low probability location 1, 3 = low probability location 2      

% Load and filter shapes from stimulus folder
all_shapes = dir('../stimuli/shapes/transparent_black/*');
all_shapes = all_shapes(~ismember({all_shapes.name}, {'.','..','.DS_Store'}));
shape_inds = 1:length(all_shapes);  % Shape indices from filtered directory

% Safety checks
assert(mod(total_scenes * total_reps_per_scene, total_runs) == 0, ...
    'Scene repetitions must divide evenly into runs.');
assert(length(condition_inds) == 12, 'Expected 8 conditions per block.');

% Generate all permutations of [0 0 1 1] (used for target directions)
t_directions = unique(perms([0 0 1 1]), 'rows');

%% Initialize output
randomizor_matrix = struct();
rng('shuffle');  % Seed RNG for per-subject randomness

fprintf('[INFO] Beginning randomization for %d subjects...\n', total_subs);

%% Subject loop
for sub_num = 1:total_subs
    sub_struct_name = sprintf('subj%d', sub_num);  % e.g., 'subj1'
    subject_struct = struct();


    n_scenes = 108;
    n_positions = 3   % positions 1-3

    scene_ids = (1:n_scenes)';

    % Cycle 1,2,3... down the scenes
    base_cycle = mod((0:n_scenes-1), n_positions) + 1;

    % Shift starting point based on subject number
    offset = mod(sub_num - 1, n_positions);
    positions = mod(base_cycle - 1 + offset, n_positions) + 1;

    scene_matrix = [scene_ids, positions'];
    % Initialize scene matrix for this subject
    % Columns: [scene_id, rep, run, distractor, target, condition]
    Epoch1_order = [1:108]
    Epoch2_order = randperm(total_runs);
    Epoch3_order = randperm(total_runs);
    Epoch4_order = randperm(total_runs);

    Block1_order = [Epoch1_order(1:number_trials_per_run)];
    Block2_order = [Epoch1_order(number_trials_per_run+1:end)];
    Block3_order = [Epoch2_order(1:number_trials_per_run)];
    Block4_order = [Epoch2_order(number_trials_per_run+1:end)];
    Block5_order = [Epoch3_order(1:number_trials_per_run)];
    Block6_order = [Epoch3_order(number_trials_per_run+1:end)];
    Block7_order = [Epoch4_order(1:number_trials_per_run)];
    Block8_order = [Epoch4_order(number_trials_per_run+1:end)];

    % Assign randomized run numbers (1–6) in balanced blocks
    scene_randomizor = assign_balanced_runs(scene_randomizor, total_runs);

    high_probability_location_type = mod(sub_num - 1, 3) + 1;

end

function scene_randomizor = assign_balanced_runs(scene_randomizor, total_runs)
    RUN = 3;
    num_rows = size(scene_randomizor, 1);

    % Check that the number of rows is divisible by the number of runs
    assert(mod(num_rows, total_runs) == 0, ...
        'Total number of rows (%d) must be divisible by total_runs (%d).', ...
        num_rows, total_runs);

    % Assign a random permutation of run numbers to each group of total_runs rows
    for i = 1:(num_rows / total_runs)
        idx = (i - 1) * total_runs + 1;
        scene_randomizor(idx : idx + total_runs - 1, RUN) = randperm(total_runs);
    end
end