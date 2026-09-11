%-------------------------------------------------------------------------
% Script: randomizor_rs.m
% Author: Justin Frandsen
% Date: 2026/09/09 yyyy/mm/dd
% Description: Prerandomizor for the curious_ss experiment.
%
% For each subject:
% - Assigns scenes to blocks (balanced across 6 blocks)
% - Randomizes scene orders, distractors, targets, and conditions
% - Ensures target never repeats location within a scene (across epochs)
% - Generates trial-specific parameters for 6 experimental blocks
% - Outputs a struct per subject with trial information
%-------------------------------------------------------------------------

%% CONFIGURATION
SAVE_OUTPUT = true;   % Set to true to save output .mat file

total_subs           = 500;    % <-- set number of subjects
total_scenes         = 108;
total_reps_per_scene = 4;
total_runs           = 6;

% Condition configurations
crit_dist_presence_percentage        = 2/3;   % crit distractor present 2/3, absent 1/3
high_probability_location_percentage = 0.75;  % on present trials, high-prob 75%
condition_inds = [0 0 0 0 1 1 1 1 1 1 2 3];
% crit distractor location: 0=absent, 1=high probability,
% 2=low probability location 1, 3=low probability location 2

% Load and filter shapes from stimulus folder
all_shapes = dir('../stimuli/shapes/transparent_black/*');
all_shapes = all_shapes(~ismember({all_shapes.name}, {'.','..','.DS_Store'}));
shape_inds = 1:length(all_shapes);   % Shape indices from filtered directory

% Safety checks
assert(mod(total_scenes * total_reps_per_scene, total_runs) == 0, ...
    'Scene repetitions must divide evenly into runs.');
assert(length(condition_inds) == 12, 'Expected 12 conditions per unit.');

% Generate all permutations of [0 0 1 1] (used for target directions)
t_directions = unique(perms([0 0 1 1]), 'rows');

%% Dimensions
n_scenes           = 108;
n_epochs           = 4;
n_blocks           = 6;
trials_per_block   = 72;
scene_ids          = (1:n_scenes)';
total_trials       = n_blocks * trials_per_block;   % 432
n_shapes_per_trial = 6;
n_shape_options    = 22;

% Interleaved position order (surface-alternating): wall,counter,floor,...
% positions 1,2=wall  3,4=counter  5,6=floor
interleaved = [1 3 5 2 4 6];

%% Initialize output
randomizor_matrix = struct();
rng('shuffle');   % Seed RNG for per-subject randomness

fprintf('[INFO] Beginning randomization for %d subjects...\n', total_subs);

%% Subject loop
for sub_num = 1:total_subs
    sub_struct_name = sprintf('subj%d', sub_num);   % e.g., 'subj1'
    subject_struct  = struct();

    % ---------------------------------------------------------------
    % Build target_locations (108 scenes x 4 epochs)
    %   - no position repeats within a scene
    %   - (2,1,1) surface pattern (one surface doubled)
    %   - balanced positions per epoch (18 each)
    %   - subject-dependent offset for counterbalancing
    % ---------------------------------------------------------------
    epoch_start = [1 2 3 4];   % starting index into interleaved per epoch
    target_locations = zeros(n_scenes, n_epochs);
    for e = 1:n_epochs
        for s = 1:n_scenes
            idx = mod( (epoch_start(e) - 1) + (s - 1) + (sub_num - 1), ...
                       length(interleaved) ) + 1;
            target_locations(s, e) = interleaved(idx);
        end
    end

    % ---------------------------------------------------------------
    % Distractor shapes: 6 distinct shapes per trial (random)
    % ---------------------------------------------------------------
    shape_matrix = zeros(total_trials, n_shapes_per_trial);
    for t = 1:total_trials
        shape_matrix(t, :) = randperm(n_shape_options, n_shapes_per_trial);
    end

    % ---------------------------------------------------------------
    % Step 1: shuffle each epoch (scene + target + condition together)
    % ---------------------------------------------------------------
    epoch_blocks = cell(1, n_epochs);
    for e = 1:n_epochs
        % Balanced condition vector for this epoch (108 trials = 9 units)
        conditions = repmat(condition_inds, 1, n_scenes / numel(condition_inds));
        conditions = conditions(randperm(n_scenes))';   % 108x1 shuffled

        shuffle_idx = randperm(n_scenes);
        epoch_data  = [scene_ids, target_locations(:, e), ...
                       repmat(e, n_scenes, 1), conditions];
        %  col1=scene  col2=target_pos  col3=epoch  col4=condition
        epoch_blocks{e} = epoch_data(shuffle_idx, :);
    end

    % ---------------------------------------------------------------
    % Step 2: randomly order the 4 epochs
    % ---------------------------------------------------------------
    epoch_order = randperm(n_epochs);   % e.g. [4 2 3 1]

    % ---------------------------------------------------------------
    % Step 3: concatenate epochs in that order
    % ---------------------------------------------------------------
    all_trials = [];
    for e = epoch_order
        all_trials = [all_trials; epoch_blocks{e}];
    end
    % all_trials: 432 x 4 -> [scene_id, target_pos, epoch, condition]

    % ---------------------------------------------------------------
    % Step 4: assign block numbers (72 per block) -> column 5
    % ---------------------------------------------------------------
    block_labels = repelem((1:n_blocks)', trials_per_block);   % 432x1
    all_trials(:, 5) = block_labels;
    % Columns: [scene_id, target_pos, epoch, condition, block]

    % ---------------------------------------------------------------
    % Step 5: split into 6 blocks
    % ---------------------------------------------------------------
    blocks = cell(1, n_blocks);
    for b = 1:n_blocks
        blocks{b} = all_trials(all_trials(:,5) == b, :);
    end

    % ---------------------------------------------------------------
    % Split distractor shapes into 6 blocks (parallel to trial blocks)
    % ---------------------------------------------------------------
    shape_blocks = cell(1, n_blocks);
    for b = 1:n_blocks
        row_start = (b-1)*trials_per_block + 1;
        row_end   = b*trials_per_block;
        shape_blocks{b} = shape_matrix(row_start:row_end, :);
    end

    % ---------------------------------------------------------------
    % Subject-specific high-probability distractor location
    % ---------------------------------------------------------------
    high_probability_distractor_location = mod(sub_num - 1, 3) + 1;

    % ---------------------------------------------------------------
    % Store into subject struct
    % ---------------------------------------------------------------
    subject_struct.high_probability_distractor_location = high_probability_distractor_location;
    subject_struct.epoch_order   = epoch_order;
    subject_struct.blocks        = blocks;         % 1x6 cell, each 72x5
    subject_struct.shape_blocks  = shape_blocks;   % 1x6 cell, each 72x6
    subject_struct.all_trials    = all_trials;     % full 432x5 (optional)

    randomizor_matrix.(sub_struct_name) = subject_struct;

    fprintf('[INFO] Subject %d done. Epoch order: %s | High-prob loc: %d\n', ...
        sub_num, mat2str(epoch_order), high_probability_distractor_location);

    % Check one subject
    subj = randomizor_matrix.subj1;
end

%% ---------------------------------------------------------------------
%  PRACTICE MATRIX: 8 trials, 4 scenes x 2 reps
%  ---------------------------------------------------------------------
n_practice_scenes = 4;
n_practice_reps   = 2;
practice_scene_ids = (1:n_practice_scenes)';

% Two distinct target positions per practice scene
practice_targets = zeros(n_practice_scenes, n_practice_reps);
for s = 1:n_practice_scenes
    for e = 1:n_practice_reps
        idx = mod( (s - 1) + (e - 1), length(interleaved) ) + 1;
        practice_targets(s, e) = interleaved(idx);
    end
end

% Build practice trial list: [scene_id, target_pos, rep]
practice_matrix = [];
for e = 1:n_practice_reps
    rep_block = [practice_scene_ids, practice_targets(:, e), ...
                 repmat(e, n_practice_scenes, 1)];
    practice_matrix = [practice_matrix; rep_block];
end
practice_matrix = practice_matrix(randperm(size(practice_matrix,1)), :);

% Practice distractor shapes (6 distinct per trial)
practice_shapes = zeros(size(practice_matrix,1), n_shapes_per_trial);
for t = 1:size(practice_matrix,1)
    practice_shapes(t, :) = randperm(n_shape_options, n_shapes_per_trial);
end

randomizor_matrix.practice_matrix = practice_matrix;
randomizor_matrix.practice_shapes = practice_shapes;

%% ---------------------------------------------------------------------
%  SAVE OUTPUT
%  ---------------------------------------------------------------------
if SAVE_OUTPUT
    save('randomizor_matrix.mat', 'randomizor_matrix');
    fprintf('[INFO] Saved randomizor_matrix.mat\n');
end

fprintf('[INFO] Randomization complete.\n');