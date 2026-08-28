%-----------------------------------------------------------------------
% Script: shapeSearch.m
% Author: Justin Frandsen
% Date: 22/07/2025 %dd/mm/yyyy
% Description: This script runs a visual search experiment where participants
%              search for a target shape among distractor shapes. Participants
%              are given a viewing window after the search duration to see if
%              exploration leads to distractor learning.
%
% Additional Comments:
% - This script is designed to be run after the setup scripts have been executed.
% - It requires the Psychtoolbox to be initialized and the necessary image files to be imported.
%
% Usage:
% - Ensure that the Psychtoolbox is initialized and the image files are imported using
%   the `imageStimuliImport` function.
% - The script will prompt for subject and run numbers, and check if the output files already
%   exist to prevent overwriting.
% - The experiment will run through a series of trials where participants search for target shapes.
% - At the end of the experiment, it will save the behavioral data, eye movement data,
%   and EDF files if eye tracking is enabled.
% - Script will output a .csv file containing behavioral data, a .csv file
%   containing fixation data, a .mat file containing all variables in the
%   matlab enviroment, and a .edf file for usage with eyelink data viewer.
%   containing all matlab script variables, and a .edf file containing
%   eyetracking data.
%-----------------------------------------------------------------------

%% CLEAR VARIABLES
clc;
close all;
clear all;
sca;
rng('shuffle'); % Resets the random # generator
%% ADD PATHS
addpath(genpath('setup'));

%% COLUMN NAMES FOR SCENE MATRIX
SCENE_INDS = 1;
REP        = 2; % just used to create the randomizor matrix not used in the experiment
RUN        = 3; % col contains the run number
DISTRACTOR = 4;
TARGET     = 5;
CONDITION  = 6;

%% -----------------------------------------------------------------------
% SETTINGS
% ------------------------------------------------------------------------

% Experiment identifiers
expName      = 'curious_ss';

% Monitor
refresh_rate = 60;  % Hz

% Eyetracker
eyetracking             = false; % true = real eyetracking, false = no eyetracking
fixationTimeThreshold   = 50;    % ms, minimum fixation duration to log
fix.radius              = 90;
fix.timeout             = 5000;
fix.reqDur              = 500;
eye_used             = 2; % 1 = left eye, 2 = right eye, 3 = both eyes want to change this to get it from the tracker later

% Feedback
border_line_width = 30;
penalty           = 2000;  % ms
timeout           = 5000;  % ms
post_search_duration = 5;  % sec
feedback_duration   = 0.2; % sec

% Trial control
main_runs      = 6;
practice_runs  = 1;
total_runs     = main_runs + practice_runs;
total_trials   = 72;
search_display_duration = 15; % sec

% Fonts
my_font      = 'Arial';
my_font_size = 60;

% Beeper
beeper.tone     = 200;  % Hz
beeper.loudness = 0.5;  % 0-1
beeper.duration = 0.3;  % sec

% Response Keys
KbName('UnifyKeyNames');
key.left  = 'z';
key.right = '/?';
key.yes   = '1!';
key.no    = '2@';
key.esc   = '0)';
validKeys = {key.left, key.right};

% Colors
col.white = [255 255 255]; 
col.black = [0 0 0];
col.gray  = [117 117 117];
col.red   = [255 0 0];
col.green = [0 255 0];
col.bg    = col.gray;
col.fg    = col.white;
col.fix   = col.black;

% Directories
data_folder             = 'data';
bx_output_folder_name   = fullfile(data_folder, 'bx_data');
eye_output_folder_name  = fullfile(data_folder, 'eye_data');
edf_output_folder_name  = fullfile(data_folder, 'edf_data');
mat_output_folder_name  = fullfile(data_folder, 'MAT_data');

stimuli_folder         = 'stimuli';
scene_folder            = 'stimuli/scenes/main';
practice_scenes_folder  = 'stimuli/scenes/practice';
nonsided_shapes         = 'stimuli/shapes/transparent_black';
shapes_left             = 'stimuli/shapes/black_left_T';
shapes_right            = 'stimuli/shapes/black_right_T';
instruction_shapes       = 'stimuli/shapes/instructions';

% Output formats
bx_file_format   = 'bx_Subj%.3dRun%.2d.csv';
eye_file_format  = 'fixation_data_subj_%.3d_run_%.3d.csv';
edf_file_format  = 'S%.3dR%.1d.edf';
MAT_file_format  = 'subj%.3d_run%.2d.mat';

%% GET SUBJECT INFO
[sub_num, run_num, experimenter_initials] = experiment_setup();

%% MAKE SURE data directory and its subdirectories exist
subdirs = {'bx_data', 'edf_data', 'eye_data', 'log_files', 'MAT_data'};

if ~exist(data_folder, 'dir')
    [status, msg] = mkdir(data_folder);
    if ~status
        error('Failed to create directory: %s', msg);
    end
end

for i = 1:length(subdirs)
    subdir_path = fullfile(data_folder, subdirs{i});
    if ~exist(subdir_path, 'dir')
        [status, msg] = mkdir(subdir_path);
        if ~status
            error('Failed to create directory: %s', msg);
        end
    end
end

%% TEST IF OUTPUT FILES EXIST
% Test if bx output file already exists
bx_file_name = sprintf(bx_file_format, sub_num, run_num);
if exist(fullfile(bx_output_folder_name, bx_file_name), 'file')
    error('Subject bx file already exists. Delete the file to rerun with the same subject number.');
end

% Test if preprocessed eyemovement data file already exists
eye_file_name = sprintf(eye_file_format, sub_num, run_num);
if exist(fullfile(eye_output_folder_name, eye_file_name), 'file')
    error('Subject eye file already exists. Delete the file to rerun with the same subject number.');
end

% Test if .edf file already exists
edf_file_name = sprintf(edf_file_format, sub_num, run_num);
if exist(fullfile(edf_output_folder_name, edf_file_name), 'file')
    error('Subject edf file already exists. Delete the file to rerun with the same subject number.');
end

% Initilize PTB window
[w, rect, scrID] = pfp_ptb_init; %call this function which contains all the screen initilization.
[width, height] = Screen('WindowSize', scrID); %get the width and height of the screen
% Enable alpha blending for transparency
Screen('BlendFunction', w, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA'); %allows the .png files to be transparent

%% LOAD STIMULI!!!
DrawFormattedText(w, 'Loading Images...', 'center', 'center');
Screen('Flip', w);

[practice_scene_file_paths, practice_scene_textures] = image_stimuli_import(practice_scenes_folder, '', w);

[scene_file_paths, scene_textures] = image_stimuli_import(scene_folder, '', w);
total_scenes = length(scene_file_paths);

% Load in shape stimuli
[sorted_nonsided_shapes_file_paths, sorted_nonsided_shapes_textures] = image_stimuli_import(nonsided_shapes, '*.png', w, true);
[sorted_left_shapes_file_paths, sorted_left_shapes_textures]         = image_stimuli_import(shapes_left, '*.png', w, true);
[sorted_right_shapes_file_paths, sorted_right_shapes_textures]       = image_stimuli_import(shapes_right, '*.png', w, true);

%load in shapes for instructions
[sorted_instruction_shapes_file_paths, sorted_instruction_shapes_textures] = image_stimuli_import(instruction_shapes, '*.png', w, true);

%% Background Screens
% Screens
Screen('TextSize', w, my_font_size);
Screen('TextFont', w, my_font);

% fixation cross
fixsize = 16;
fixthick = 4;
[fixationX, fixationY] = RectCenter(rect);
fixation =  Screen('OpenOffscreenWindow', scrID, col.bg, rect);

% Draw horizontal line
Screen('FillRect', fixation, col.fix, ...
    CenterRectOnPoint([-fixsize -fixthick fixsize fixthick], fixationX, fixationY));

% Draw vertical line
Screen('FillRect', fixation, col.fix, ...
    CenterRectOnPoint([-fixthick -fixsize fixthick fixsize], fixationX, fixationY));

% draw targets textures
% load randomizor for target shapes
randomizor = load('trial_structure_files/randomizor.mat'); % load the pre-randomized data
randomizor = randomizor.randomizor_matrix; % get the matrix from the struct

%% INITIALIZE EYETRACKER
if eyetracking
    % Initialize Eyelink
    if ~exist(edf_output_folder_name, 'dir')
        mkdir(edf_output_folder_name);
    end
    
    el = setup_eyelink(w);
end
%% Start Experiment
t = 0;
ACCcount = 0;
trialcounter = 0;

%% EXPERIMENT START
for run_looper = run_num:total_runs
    % LOG FILE SETTINGS
    logFile = sprintf('data/log_files/subj%d_run%dlog.txt', sub_num, run_looper);
    sessionStart = now;

    if run_looper == 1
        % Load in the shape positions
        shape_positions = load('trial_structure_files/practice_shape_positions.mat'); % Load the shape positions
        saved_positions = shape_positions.saved_positions; % Assign saved_positions for later use
    else
        % Load in the shape positions
        shape_positions = load('trial_structure_files/shape_positions.mat'); % Load the shape positions
        saved_positions = shape_positions.saved_positions; % Assign saved_positions for later use
    end

    %% INITIALIZE BX STRUCT
    % Preallocate structure for all trials
    if run_looper == 1
        phase = 'practice';
    elseif run_looper > 1 && run_looper <= 5
        phase = 'training';
    elseif run_looper > 5
        phase = 'testing';
    end

    bx_trial_info(1:total_trials) = struct( ...
        'sub_num', sub_num, ...                      % subject ID
        'run_num', run_looper, ...                   % run number
        'phase', phase, ...                          % training/testing/etc
        'trial_num', [], ...                         % trial index within run
        'scene_idx', [], ...                         % scene index (numerical)
        'scene_file', '', ...                        % scene filename (traceability)
        'target_shape_idx', [], ...                  % target texture index
        'target_shape_association', [], ...          % associated location/condition
        'target_position', [], ...                   % target position (grid index)
        'target_rect', [], ...                       % target coordinates [x1 y1 x2 y2]
        'critical_distractor_idx', [], ...           % critical distractor texture index
        'critical_distractor_association', [], ...   % critical distractor association
        'critical_distractor_rect', [], ...          % critical distractor coords
        'noncritical_distractor_idx1', [], ...        % non-critical distractors (indices)
        'noncritical_distractor_rect1', [], ...      % non-critical distractors (coords)
        'noncritical_distractor_idx2', [], ...        % non-critical distractors (indices)
        'noncritical_distractor_rect2', [], ...      % non-critical distractors (coords)
        'noncritical_distractor_idx3', [], ...        % non-critical distractors (indices)
        'noncritical_distractor_rect3', [], ...      % non-critical distractors (coords)
        'condition', [], ...                         % condition code
        't_direction', [], ...                       % orientation of T
        'response_key', '', ...                      % key pressed
        'response_made', [], ...                     % flag: 1=response, 0=miss
        'rt', [], ...                                % response time (sec)
        'accuracy', [], ...                          % 1=correct, 0=incorrect
        'trial_onset', [], ...                       % stim onset (absolute)
        'trial_offset', [], ...                      % stim offset (absolute)
        'response_clock_time', [], ...               % time of response key
        'timestamp', '' ...                          % optional formatted datetime
    );


    fixationCounter = 0;
    currentFixationRect = 0;
    previousFixationRect = 0;

    %% LOAD DATA FOR THIS SUBJECT AND RUN
    this_subj_this_run = randomizor.(sprintf('subj%d', sub_num)).(sprintf('run%d', run_looper)); %method of getting into the struct

    scene_randomizor = this_subj_this_run.scene_randomizor; % Get the scene randomizor for this subject and run
    target_inds = this_subj_this_run.first_half_targets;
    target_associations = this_subj_this_run.target_associations;
    critical_distractor_inds = this_subj_this_run.first_half_critical_distractors;
    critical_distractor_associations = this_subj_this_run.critical_distractors_associations;
    noncritical_distractors = this_subj_this_run.noncritical_distractors;

    
    if eyetracking
        % Ensure tracker is connected
        if ~Eyelink('IsConnected')
            error('Eyelink not connected!');
        end
        
        % Create unique EDF filename for this run
        edf_file_name = sprintf('CSS%.3dR%.1d.edf', sub_num, run_looper);

        % Open EDF file on Eyelink computer
        i = Eyelink('OpenFile', edf_file_name);
        if i ~= 0
            fprintf('Cannot create EDF file ''%s''.\n', edf_file_name);
            Eyelink('Shutdown');
            pfp_ptb_cleanup
            error('EDF file creation failed');
        end
    
        % Tracker setup/calibration
        EyelinkDoTrackerSetup(el);
    
        % Send run start message
        Eyelink('Message', 'Experiment start Subject %d Run %d', sub_num, run_looper);
    end
    
    % show instructions
    showInstructions(w, sorted_instruction_shapes_textures, key.left, key.right);

    %% Loop through trials
    if run_looper == 1
        total_trials = 8;
    elseif run_looper > 1
        total_trials = 72;
    end

    for trial_looper = 1:total_trials
        if eyetracking
            Eyelink('command', 'clear_screen 0'); % optional: clear tracker display
            Eyelink('Message', 'TRIALID %d', trial_looper); % support said to put this before the recording starts
            Eyelink('StartRecording');
            WaitSecs(0.1); % Wait for 100 ms to allow the tracker to
            HideCursor(scrID);         % Hide mouse cursor before the next trial
            SetMouse(10, 10, scrID);   % Move the mouse to the corner -- in case some jerk has unhidden it 
        end

        response = -1; % set response to -1 (missing) at start of each trial
        %% GET TRIAL VARIABLES
        scene_inds                     = scene_randomizor(trial_looper, SCENE_INDS); % Get the scene index for this trial
        possible_positions             = this_subj_this_run.all_possible_locations(trial_looper, :); % Get the possible positions for this trial
        t_directions                   = this_subj_this_run.t_directions(trial_looper, :); % Get the target directions for this trial
        target_index1                  = scene_randomizor(trial_looper, TARGET);

        if run_looper <= 5
            target_texture_index       = target_inds(target_index1);
            target_association         = target_associations(target_index1); %1 = wall 2 = counter, 3 = floor.
        elseif run_looper > 5
            target_texture_index       = critical_distractor_inds(target_index1); %in testing we use the critical distractor shapes as targets
            target_association         = critical_distractor_associations(target_index1); %1 = wall 2 = counter, 3 = floor.
        end
        
        trial_condition                = scene_randomizor(trial_looper, CONDITION);
        this_run_distractors           = this_subj_this_run.this_run_distractors(trial_looper, :);
        length_this_run_distractors    = length(this_run_distractors);
        this_trial_distractors         = noncritical_distractors(1:length_this_run_distractors-1); % remove the last one which is just the run number

        % get critical distractor info if in training phase
        if run_looper <= 5 && run_looper > 1
            critical_distractor_index1 = scene_randomizor(trial_looper, DISTRACTOR);
            cd_texture_index = critical_distractor_inds(critical_distractor_index1);
            critical_distractor_association = critical_distractor_associations(critical_distractor_index1);
        else
            cd_texture_index = NaN; % no critical distractor in testing phase
            critical_distractor_association = NaN;
        end

        %% DRAW SCENE   
        search = Screen('OpenOffscreenWindow', scrID, col.bg, rect, 32);
        post_search = Screen('OpenOffscreenWindow', scrID, col.bg, rect, 32);
        % Draw the scene texture
        if run_looper == 1
            Screen('DrawTexture', search, practice_scene_textures(scene_inds), [], rect);
            Screen('DrawTexture', post_search, practice_scene_textures(scene_inds), [], rect);
        else
            Screen('DrawTexture', search, scene_textures(scene_inds), [], rect);
            Screen('DrawTexture', post_search, scene_textures(scene_inds), [], rect);
        end

        % Enable blending for transparency inside this offscreen window
        Screen('BlendFunction', search, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        % Enable blending for transparency inside this offscreen window
        Screen('BlendFunction', post_search, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        types     = [1 2 3];      % semantic categories: wall/counter/floor
        positions = [1 2 3 4];    % physical rect indices

        % ---- choose the target TYPE for this trial
        % training: trial_condition chooses whether target uses its associated
        % location or one of the other two
        switch trial_condition
            case 0
                target_type = target_association;  % use its associated type
            case 1
                tmp = setdiff(types, target_association);
                target_type = tmp(1);
            case 2
                tmp = setdiff(types, target_association);
                target_type = tmp(2);
            otherwise
                error('Unexpected trial_condition value.');
        end
        

        % ---- map TYPE → POSITION and draw TARGET
        target_position    = possible_positions(target_type);               % e.g., 1..4
        target_rect        = saved_positions{scene_inds, target_position};  % use POSITION!
        remaining_positions = setdiff(possible_positions, target_position, 'stable');  % remaining positions for distractors dont sort

        if eyetracking
            % Define AOIs
            Eyelink('command', 'draw_box %d %d %d %d %d', ceil(target_rect(1)), ceil(target_rect(2)), ceil(target_rect(3)), ceil(target_rect(4)), 15); % Target in white
            Eyelink('Message', '!V IAREA RECTANGLE 1 %d %d %d %d TargetBox', ceil(target_rect(1)), ceil(target_rect(2)), ceil(target_rect(3)), ceil(target_rect(4)));
        end

        if t_directions(1) == 0
            % left target
            Screen('DrawTexture', search, sorted_left_shapes_textures(target_texture_index), [], target_rect);
        elseif t_directions(1) == 1
            % right target  
            Screen('DrawTexture', search, sorted_right_shapes_textures(target_texture_index), [], target_rect);
        end
        
        crit_dist_position = []; 
        rect_id = 2; % ID for critical distractor AOI
        
        % ---- draw CRITICAL DISTRACTOR only in training
        if run_looper <= 5 && run_looper > 1
            crit_pos  = possible_positions(4); % 4th entry encodes CD position
            remaining_positions = setdiff(remaining_positions, crit_pos, 'stable'); % remove CD position from remaining positions
            crit_rect = saved_positions{scene_inds, crit_pos};
            if t_directions(4) == 0
                % left critical distractor
                Screen('DrawTexture', search, sorted_left_shapes_textures(cd_texture_index), [], crit_rect);
                Screen('DrawTexture', post_search, sorted_left_shapes_textures(cd_texture_index), [], crit_rect);
            elseif t_directions(4) == 1
                % right critical distractor
                Screen('DrawTexture', search, sorted_right_shapes_textures(cd_texture_index), [], crit_rect);
                Screen('DrawTexture', post_search, sorted_right_shapes_textures(cd_texture_index), [], crit_rect);
            end

            if eyetracking
                % Define AOIs
                Eyelink('command', 'draw_box %d %d %d %d %d', ceil(crit_rect(1)), ceil(crit_rect(2)), ceil(crit_rect(3)), ceil(crit_rect(4)), 7);  % Critical distractor in gray
                Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d CritDistBox', rect_id, ceil(crit_rect(1)), ceil(crit_rect(2)), ceil(crit_rect(3)), ceil(crit_rect(4)));
                rect_id = rect_id + 1; % Increment rect_id for next AOI
            end
        end


        noncrit_rect3 = nan;
        noncrit_ind3 = nan;

        for k = 1:numel(remaining_positions)
            this_pos  = remaining_positions(k);       % map TYPE → POSITION
            this_rect = saved_positions{scene_inds, this_pos};
            distractor_texture_index = this_trial_distractors(k);
            this_distarctor = noncritical_distractors(distractor_texture_index);
            if t_directions(1+k) == 0
                % left non-critical distractor
                Screen('DrawTexture', search, sorted_left_shapes_textures(this_distarctor), [], this_rect);
                Screen('DrawTexture', post_search, sorted_left_shapes_textures(this_distarctor), [], this_rect);
            elseif t_directions(1+k) == 1
                % right non-critical distractor
                Screen('DrawTexture', search, sorted_right_shapes_textures(this_distarctor), [], this_rect);
                Screen('DrawTexture', post_search, sorted_right_shapes_textures(this_distarctor), [], this_rect);
            end

            if k == 1
                noncrit_rect1 = this_rect;
                noncrit_ind1 = this_distarctor;
            elseif k == 2
                noncrit_rect2 = this_rect;
                noncrit_ind2 = this_distarctor;
            elseif k == 3
                noncrit_rect3 = this_rect;
                noncrit_ind3 = this_distarctor;
            end

            if eyetracking
                % Define AOIs
                Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d NonCritDistBox%d', rect_id, ceil(this_rect(1)), ceil(this_rect(2)), ceil(this_rect(3)), ceil(this_rect(4)), k);
                Eyelink('command', 'draw_box %d %d %d %d %d', ceil(this_rect(1)), ceil(this_rect(2)), ceil(this_rect(3)), ceil(this_rect(4)), 3);  % Non-critical distractor in darker gray
                rect_id = rect_id + 1; % Increment rect_id for next AOI
            end
        end

        %% DRAW CUE DISPLAY
        % Open an offscreen window with alpha channel (32-bit RGBA)
        cue_display = Screen('OpenOffscreenWindow', scrID, col.bg, rect, 32);

        % Enable blending for transparency inside this offscreen window
        Screen('BlendFunction', cue_display, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        % Draw your texture into the offscreen window
        Screen('DrawTexture', cue_display, sorted_nonsided_shapes_textures(target_texture_index));

        if eyetracking   
            centralFixation(w, height, width, fixation, fix, trial_looper, el, eye_used)
        else
            % Fixation cross just drawn for when testing.
            Screen('DrawTexture', w, fixation);
            Screen('flip', w);
            WaitSecs(.5)
        end
        
        % CUE DISPLAY
        Screen('DrawTexture', w, cue_display);
        Screen('flip', w);

        if eyetracking
            Eyelink('Message','CUE_ONSET %d', target_texture_index);
        end

        % Draw fixation cross
        Screen('DrawTexture', w, fixation);
        WaitSecs(1); % 1 second cue
        
        Screen('flip', w); %flip to show fixation cross again

        if eyetracking
            Eyelink('Message','FIXATION_ONSET_2');
        end

        Screen('DrawTexture', w, search); %draw the search display
        WaitSecs(1); % 1 second central fixation

        %% SEARCH DISPLAY
        stimOnsetTime = Screen('Flip', w); %this flip displays the scene with all four shapes

        if eyetracking
            Eyelink('Message', 'START_TIME SEARCH_PERIOD');
            Eyelink('Message', 'SYNCTIME');
            Eyelink('Message', '!V TRIAL_VAR condition %d', trial_condition);
            Eyelink('Message', '!V TRIAL_VAR trial_num %d', trial_looper);
            Eyelink('Message', '!V TRIAL_VAR sub_num %d', sub_num);
            Eyelink('Message', '!V TRIAL_VAR block %d', run_looper);
            Eyelink('Message', '!V TRIAL_VAR scene %d', scene_inds);
        end
        % --- Wait for response or until deadline ---
        responseMade = false;
        trialActive  = true;
        RT = -999; % Initialize RT as -999
        trial_accuracy = -1; % Initialize accuracy as -1 (no response)

        while trialActive && (GetSecs - stimOnsetTime) < search_display_duration
            [key_is_down, secs, key_code] = KbCheck;
            if key_is_down && ~responseMade
                responseKey = KbName(key_code);
                if iscell(responseKey)
                    responseKey = responseKey{1};
                end
                if ismember(responseKey, validKeys)
                    response = responseKey;
                    RT = round((secs - stimOnsetTime) * 1000);
                    responseMade = true;
                
                    if eyetracking
                        Eyelink('Message', 'RESPONSE Key %s RT %d', response, RT);
                    end
                
                    % End trial after logging last fixation
                    trialActive = false;
                end
            end
        end

        if t_directions(1) == 0 && strcmp(response, key.left)
            trial_accuracy = 1;
        elseif t_directions(1) == 1 && strcmp(response, key.right)
            trial_accuracy = 1;
        elseif t_directions(1) == 1 && strcmp(response, key.left)
            trial_accuracy = 0;
        elseif t_directions(1) == 0 && strcmp(response, key.right)
            trial_accuracy = 0;
        end

        %% LOG OUTPUT VARIABLES
        bx_trial_info(trial_looper).trial_num                = trial_looper;
        bx_trial_info(trial_looper).trial_onset              = stimOnsetTime;
        bx_trial_info(trial_looper).trial_offset             = GetSecs();
        bx_trial_info(trial_looper).response_clock_time      = secs;

        % Subject & run info (already set in initialization, but safe to overwrite)
        bx_trial_info(trial_looper).sub_num                  = sub_num;
        bx_trial_info(trial_looper).run_num                  = run_looper;
        bx_trial_info(trial_looper).phase                    = phase;

        % Scene info
        bx_trial_info(trial_looper).scene_idx                = scene_inds;
        if run_looper == 1
            bx_trial_info(trial_looper).scene_file               = practice_scene_file_paths{scene_inds};
        else
            bx_trial_info(trial_looper).scene_file               = scene_file_paths{scene_inds};
        end

        % Target info
        bx_trial_info(trial_looper).target_shape_idx         = target_texture_index;
        bx_trial_info(trial_looper).target_shape_association = target_association;
        bx_trial_info(trial_looper).target_position          = target_position;
        bx_trial_info(trial_looper).target_rect              = target_rect;
        
        % Distractors
        if run_looper <= 5 && run_looper > 1
            bx_trial_info(trial_looper).critical_distractor_idx         = cd_texture_index;
            bx_trial_info(trial_looper).critical_distractor_association = critical_distractor_association;
            bx_trial_info(trial_looper).critical_distractor_rect        = crit_rect;
        else
            bx_trial_info(trial_looper).critical_distractor_idx         = NaN;
            bx_trial_info(trial_looper).critical_distractor_association = NaN;
            bx_trial_info(trial_looper).critical_distractor_rect        = [];
        end

        bx_trial_info(trial_looper).noncritical_distractor_idx1   = noncrit_ind1;
        bx_trial_info(trial_looper).noncritical_distractor_rect1  = noncrit_rect1;
        bx_trial_info(trial_looper).noncritical_distractor_idx2   = noncrit_ind2;
        bx_trial_info(trial_looper).noncritical_distractor_rect2  = noncrit_rect2;
        bx_trial_info(trial_looper).noncritical_distractor_idx3   = noncrit_ind3;
        bx_trial_info(trial_looper).noncritical_distractor_rect3  = noncrit_rect3;

        % Condition / stimulus info
        bx_trial_info(trial_looper).condition   = trial_condition;
        bx_trial_info(trial_looper).t_direction = t_directions(1);

        % Response
        bx_trial_info(trial_looper).rt            = RT;
        bx_trial_info(trial_looper).accuracy      = trial_accuracy;
        bx_trial_info(trial_looper).response_made = responseMade;
        if responseMade
            bx_trial_info(trial_looper).response_key = response;
        else
            bx_trial_info(trial_looper).response_key = '';
        end

        % Timestamp (human-readable string, e.g., for debugging logs)
        bx_trial_info(trial_looper).timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');


        post_search_duration = 4; % 4 seconds
        feedback_duration = 0.2; % seconds
        post_viewing = true;

        % if incorrect give feedback (red border) for 200 ms then show post search screen for remaining time
        % if correct show post search screen for full duration
        if run_looper <= 5 && run_looper > 1
            if trial_accuracy == 0
                resp_color = col.red;
                Screen('DrawTexture', w, post_search);
                Screen('FrameRect', w, resp_color, rect, border_line_width);
                Screen('flip', w);
                % Eyelink message for feedback onset
                if eyetracking
                    Eyelink('Message', 'END_TIME SEARCH_PERIOD');
                    Eyelink('Message', 'START_TIME POST_SEARCH_PERIOD');
                    Eyelink('Message', 'Feedback: Incorrect onset / Post-search onset');
                end

                WaitSecs(feedback_duration); % 200 ms
                Screen('DrawTexture', w, post_search);
                Screen('flip', w);

                % Eyelink message for feedback offset / post-search onset
                if eyetracking
                    Eyelink('Message', 'Feedback: Incorrect offset / Post-search continued');
                end

                WaitSecs(post_search_duration-feedback_duration)
            elseif trial_accuracy == 1
                resp_color = col.green;
                Screen('DrawTexture', w, post_search);
                Screen('flip', w);

                % Eyelink message for correct feedback/post-search
                if eyetracking
                    Eyelink('Message', 'END_TIME SEARCH_PERIOD');
                    Eyelink('Message', 'START_TIME POST_SEARCH_PERIOD');
                end

                WaitSecs(post_search_duration)
            end
        elseif run_looper == 1 || run_looper > 4
            if trial_accuracy == false
                DrawFormattedText(w, 'Incorrect!', 'center', 'center', col.fg);
                Screen('Flip', w);
                WaitSecs(.5); % Wait for 2 seconds before closing
            end
        end
        %draw blank ITI
        Screen('flip', w);

        if eyetracking
            if run_looper <= 5 && run_looper > 1
                Eyelink('Message', 'END_TIME POST_SEARCH_PERIOD');
            elseif run_looper == 1 || run_looper > 5
                Eyelink('Message', 'END_TIME SEARCH_PERIOD');
            end
            Eyelink('Message', '!V IAREA END');
            Eyelink('Message', '!V TRIAL_VAR RT %d', RT);
            Eyelink('Message', '!V TRIAL_VAR acc %d', trial_accuracy);
            Eyelink('Message', 'TRIAL_RESULT 0');

            Eyelink('StopRecording');
        end
        WaitSecs(.5); % 500 ms ITI
    end

    %% END OF RUN
    %% SAVE EYETRACKING DATA
    if eyetracking
        Eyelink('Message', 'Experiment end Subject %d Run %d', sub_num, run_looper);
        % Go idle and close file
        Eyelink('Command', 'set_idle_mode');
        WaitSecs(0.5);
        status = Eyelink('CloseFile'); %close the EDF file
        if status ~= 0
            fprintf('CloseFile failed with status %d\n', status);
        end
        
        % Wait a bit longer for safety
        WaitSecs(2);

        % Full local path to save EDF file
        localPath = fullfile(edf_output_folder_name, edf_file_name);

        maxTries = 3;
        for attempt = 1:maxTries
            try
                status = Eyelink('ReceiveFile', edf_file_name, localPath, 1);
                if status > 0 && exist(localPath, 'file')
                    fprintf('EDF transfer succeeded on attempt %d\n', attempt);
                    break;
                else
                    warning('EDF transfer attempt %d failed, retrying...\n', attempt);
                end
            catch
                warning('Error during ReceiveFile attempt %d\n', attempt);
            end
        end
    end

    %% SAVE BX DATA
    % log session info
    sessionEnd = now;
    log_session_info(sub_num, run_looper, experimenter_initials, total_trials, sessionStart, sessionEnd, logFile, eyetracking, edf_file_name);
    
    % save trial data to CSV
    trialTable = struct2table(bx_trial_info);
    % Define filenames with formatting
    csv_filename = sprintf('Subj%dRun%02d.csv', sub_num, run_looper);
    MAT_filename = sprintf('Subj%dRun%02d.mat', sub_num, run_looper);
    
    % Combine with folder
    csv_filename = fullfile(bx_output_folder_name, csv_filename);
    MAT_filename = fullfile(mat_output_folder_name, MAT_filename);
    
    %write files
    writetable(trialTable, csv_filename);
    fprintf('[INFO] Saved behavioral data: %s\n', csv_filename);
    
    save(MAT_filename); % Save as .mat file
    fprintf('[INFO] Full workspace saved: %s\n', MAT_filename);

    %% END OF RUN MESSAGE
    text = sprintf('Run %d of %d complete!\n\nPress SPACEBAR to continue.', ...
                run_looper, total_runs);
    DrawFormattedText(w, text, 'center', 'center', col.fg);
    Screen('Flip', w);
    KbWait([], 2);   % waits for spacebar (or any key if you don’t filter)
end

%% END EXPERIMENT
% Show end of experiment message
if eyetracking
    Eyelink('Message', 'EXPERIMENT COMPLETE Subject %d', sub_num);
    Eyelink('Shutdown');
end

DrawFormattedText(w, 'Experiment Complete! Thank you for participating.', 'center', 'center', col.fg);
Screen('Flip', w);
KbWait([], 2);   % wait for spacebar (or any key if you don’t filter)

pfp_ptb_cleanup; % cleanup PTB
%close all; % close all windows
%clear all; % clear all variables
sca; % close PTB