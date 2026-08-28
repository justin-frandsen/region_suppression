%-------------------------------------------------------------------------
% Script: randomizor_curious.m
% Author: Justin Frandsen
% Date: 2025/08/05 yyyy/mm/dd
% Description: Prerandomizor for the curious_ss experiment.
%
% For each subject:
% - Assigns scenes to runs (balanced across 6 runs)
% - Randomizes scene orders, distractors, targets, and conditions
% - Generates trial-specific parameters for 6 experimental runs
% - Outputs a struct per subject with trial information
%-------------------------------------------------------------------------

%% CONFIGURATION
SAVE_OUTPUT = true;  % Set to true to save output .mat file

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
number_trials_per_run   = 72;    % Trials per run
total_trials            = total_runs * number_trials_per_run; % Total trials
total_scenes            = 108;   % Number of unique scenes
total_reps_per_scene    = 4;     % Number of times each scene is shown

% Condition configurations
target_inds             = [1 2 3 4];                   % Indices of target shapes
distractor_inds         = [1 2 3];                     % Indices of distractor shapes
condition_inds          = [1 2 0 0 0 0 0 0];           % First-half conditions
condition_inds_second   = [0 1 2 0 1 2];               % Second-half conditions

% Load and filter shapes from stimulus folder
all_shapes = dir('../stimuli/shapes/transparent_black/*');
all_shapes = all_shapes(~ismember({all_shapes.name}, {'.','..','.DS_Store'}));
shape_inds = 1:length(all_shapes);  % Shape indices from filtered directory

% Safety checks
assert(mod(total_scenes * total_reps_per_scene, total_runs) == 0, ...
    'Scene repetitions must divide evenly into runs.');
assert(length(condition_inds) == 8, 'Expected 8 conditions per block.');

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

    % Initialize scene matrix for this subject
    % Columns: [scene_id, rep, run, distractor, target, condition]
    scene_randomizor = zeros(total_scenes * total_reps_per_scene, 6);

    % Populate scene ID and repetition
    row = 1;
    for scene = 1:total_scenes
        for rep = 1:total_reps_per_scene
            scene_randomizor(row, SCENE_ID:REP) = [scene, rep];
            row = row + 1;
        end
    end

    % Assign randomized run numbers (1–6) in balanced blocks
    scene_randomizor = assign_balanced_runs(scene_randomizor, total_runs);

    %% Define stimuli for this subject
    first_half_targets = randsample(shape_inds, length(target_inds));  % 4 targets
    all_distractors = setdiff(shape_inds, first_half_targets);         % Remaining distractors

    first_half_critical_distractors = randsample(all_distractors, 4);  % 4 critical distractors
    noncritical_distractors = setdiff(all_distractors, first_half_critical_distractors);

    target_associations = [1 2 3 randi(3)];  % 4 associations (last repeated)
    target_associations = target_associations(randperm(4));  % Shuffle

    critical_distractor_associations = [1 2 3 randi(3)];  % 4 associations (last repeated)
    critical_distractor_associations = critical_distractor_associations(randperm(4));  % Shuffle

    %% Create distractor pairs for runs 1–4
    pairs = nchoosek(noncritical_distractors, 2);  % Unordered pairs
    flipped = pairs(:, [2 1]);                     % Add reverse order
    all_pairs = [pairs; flipped];                  % Combine both orders

    first_half_distractors = repmat(all_pairs, 2, 1);  % Repeat to get enough
    first_half_distractors = shuffle_matrix(first_half_distractors, [1 2], [2 2]);

    % Assign run numbers to distractor pairs (72 per run × 4 runs)
    row = 1;
    for run = 1:4
        first_half_distractors(row:row+71, 3) = run;
        row = row + 72;
    end

    %% Create distractor triplets for runs 5–6
    triplets = nchoosek(noncritical_distractors, 3);
    all_triplets = [];

    % Generate all permutations for each triplet
    for i = 1:size(triplets, 1)
        all_triplets = [all_triplets; perms(triplets(i, :))];
    end

    second_half_distractors = shuffle_matrix(all_triplets, [1 2 3], [3 3 3]);

    % Assign run numbers to triplets (72 per run × 2 runs)
    row = 1;
    for run = 5:6
        second_half_distractors(row:row+71, 4) = run;
        row = row + 72;
    end

    %% Trial run loop
    current_target = 1;  % Start with target index 1


    for run = 1:total_runs+1
        run_struct = struct();
        run_name = sprintf('run%d', run); % this is because the first run is practice

        % Extract this run’s rows
        if run == 1
            this_run_scene = scene_randomizor(scene_randomizor(:, RUN) == 2, :);
            % Practice run: Randomize scenes, no distractors/conditions
            target_choice =[1 2 3 4 4 3 2 1];
            practice_run_matrix = zeros(8, 6);
            counter = 1;
            for i = 1:8
                practice_run_matrix(i, SCENE_ID) = counter;
                practice_run_matrix(i, REP) = 0; %this doesn't matter for practice
                practice_run_matrix(i, TARGET) = target_choice(i);
                practice_run_matrix(i, CONDITION) = 0; %always valid for practice
                practice_run_matrix(i, RUN) = 1; %practice run
                practice_run_matrix(i, DISTRACTOR) = 0; %no distractors for practice
                counter = counter + 1;
                if counter > 4
                    counter = 1;
                end
            end

            practice_run_matrix = shuffle_matrix(practice_run_matrix, ...
                [SCENE_ID TARGET], [1 1], 10000);

            numRows = size(second_half_distractors, 1);
            randIdx = randperm(numRows, 8);  % random permutation of row indices
            run_distractors = second_half_distractors(randIdx, :);

            all_possible_locations = zeros(8, 4);
            loc1 = [1 2];
            loc2 = [3 4];
            loc3 = [5 6];
            for trial = 1:8
                rand1 = loc1(randperm(2));
                rand2 = loc2(randperm(2));
                rand3 = loc3(randperm(2));
                
                possible_locations = [rand1(1), rand2(1), rand3(1), 0];  % first 3 are random from each group
                
                remaining_distractors = [...
                                        setdiff(loc1, rand1(1)), ...
                                        setdiff(loc2, rand2(1)), ...
                                        setdiff(loc3, rand3(1))...
                                        ];
                
                possible_locations(4) = remaining_distractors(randi(length(remaining_distractors)));  % random from remaining
                all_possible_locations(trial, :) = possible_locations;
            end
        elseif run <= 5 && run > 1
            this_run_scene = scene_randomizor(scene_randomizor(:, RUN) == run-1, :);

            % Assign distractors in groups of 3
            for i = 1:24
                idx = (i-1)*3 + 1;
                this_run_scene(idx:idx+2, DISTRACTOR) = randperm(3);
            end

            % Shuffle trial rows
            this_run_scene = this_run_scene(randperm(size(this_run_scene, 1)), :);

            % Assign targets and conditions in blocks of 8
            for i = 1:9
                idx = (i-1)*8 + 1;
                this_run_scene(idx:idx+7, TARGET) = current_target;
                this_run_scene(idx:idx+7, CONDITION) = condition_inds(randperm(8));
                current_target = mod(current_target, 4) + 1;  % Cycle 1→4
            end

            % Final shuffle of block layout
            this_run_scene = shuffle_matrix(this_run_scene, ...
                [SCENE_ID DISTRACTOR TARGET], [1 3 2], 10000);

            % Use first-half distractors
            run_distractors = first_half_distractors(first_half_distractors(:,3) == run-1, :);
            
            all_possible_locations = zeros(72, 4);
            loc1 = [1 2];
            loc2 = [3 4];
            loc3 = [5 6];
            for trial = 1:number_trials_per_run
                rand1 = loc1(randperm(2));
                rand2 = loc2(randperm(2));
                rand3 = loc3(randperm(2));
            
                possible_locations = [rand1(1), rand2(1), rand3(1), 0];  % first 3 are random from each group
            
                this_trial_distractor = this_run_scene(trial, DISTRACTOR);
                this_trial_distractor_associations = critical_distractor_associations(this_trial_distractor);
            
                if this_trial_distractor_associations == 1
                    possible_locations(4) = setdiff(loc1, rand1(1));
                elseif this_trial_distractor_associations == 2
                    possible_locations(4) = setdiff(loc2, rand2(1));
                elseif this_trial_distractor_associations == 3
                    possible_locations(4) = setdiff(loc3, rand3(1)); % fixed to use loc3
                end
                all_possible_locations(trial, :) = possible_locations;
            end
        elseif run > 5
            this_run_scene = scene_randomizor(scene_randomizor(:, RUN) == run-1, :);

            % Runs 5–6: No distractors, just shuffle
            this_run_scene = this_run_scene(randperm(size(this_run_scene, 1)), :);

            % Assign targets and conditions in blocks of 6
            for i = 1:12
                idx = (i-1)*6 + 1;
                this_run_scene(idx:idx+5, TARGET) = current_target;
                this_run_scene(idx:idx+5, CONDITION) = condition_inds_second(randperm(6));
                current_target = mod(current_target, 4) + 1;
            end

            % Final shuffle
            this_run_scene = shuffle_matrix(this_run_scene, [SCENE_ID TARGET], [1 2], 10000);

            % Use second-half distractors
            run_distractors = second_half_distractors(second_half_distractors(:,4) == run-1, :);

            all_possible_locations = zeros(72, 4);
            loc1 = [1 2];
            loc2 = [3 4];
            loc3 = [5 6];
            for trial = 1:number_trials_per_run
                rand1 = loc1(randperm(2));
                rand2 = loc2(randperm(2));
                rand3 = loc3(randperm(2));
            
                possible_locations = [rand1(1), rand2(1), rand3(1), 0];  % first 3 are random from each group
                
                remaining_distractors = [...
                                        setdiff(loc1, rand1(1)), ...
                                        setdiff(loc2, rand2(1)), ...
                                        setdiff(loc3, rand3(1))...
                                        ];
                
                possible_locations(4) = remaining_distractors(randi(length(remaining_distractors)));  % random from remaining
                all_possible_locations(trial, :) = possible_locations;
            end
        end

        % Generate target direction matrix
        rep_count = length(this_run_scene) / size(t_directions, 1);
        if run == 1
            rep_count = 2;  % Practice run uses each direction once
        end
        full_directions = repmat(t_directions, rep_count, 1);
        full_directions = full_directions(randperm(size(full_directions, 1)), :);

        % Store all run-specific info
        run_struct.first_half_targets                = first_half_targets;
        run_struct.noncritical_distractors           = noncritical_distractors;
        run_struct.first_half_critical_distractors   = first_half_critical_distractors;
        if run == 1
            run_struct.scene_randomizor = practice_run_matrix;
        else
            run_struct.scene_randomizor = this_run_scene;
        end
        run_struct.t_directions                      = full_directions;
        run_struct.target_associations               = target_associations;
        run_struct.critical_distractors_associations = critical_distractor_associations;
        run_struct.this_run_distractors              = run_distractors;
        run_struct.all_possible_locations            = all_possible_locations;

        subject_struct.(run_name) = run_struct;
    end

    % Save full subject struct
    randomizor_matrix.(sub_struct_name) = subject_struct;

    % Print progress every 50 subjects
    if mod(sub_num, 50) == 0
        fprintf('[INFO] Completed subject %d/%d\n', sub_num, total_subs);
    end
end

fprintf('[INFO] Randomization complete.\n');

% Save output if configured
if SAVE_OUTPUT
    save('../trial_structure_files/randomizor.mat', 'randomizor_matrix');
    fprintf('[INFO] Output saved to ../trial_structure_files/randomizor.mat\n');
end

%% Local function for assigning run numbers in a balanced way
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
