%-----------------------------------------------------------------------
% Script: region_suppression.m
% Author: Justin Frandsen
% Date: 15/09/2026 %dd/mm/yyyy
% Description: This script runs a visual search experiment where participants
%              search for a target shape among 6 distractor shapes. One of the distractor shapes 
%              is sometimes a color distractor and that color is associated with a given region 
%              of the scene more often.
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

%% -----------------------------------------------------------------------
% SETTINGS
% ------------------------------------------------------------------------

% Experiment identifiers
expName      = 'region_suppression';

% Monitor
refresh_rate = 60;  % Hz

% Eyetracker
eyetracking             = false; % true = real eyetracking, false = no eyetracking
fixationTimeThreshold   = 50;    % ms, minimum fixation duration to log
fix.radius              = 90;
fix.timeout             = 5000;
fix.reqDur              = 500;
eye_used                = 2; % 1 = left eye, 2 = right eye, 3 = both eyes want to change this to get it from the tracker later

% Feedback
border_line_width = 30;
penalty           = 2000;  % ms
timeout           = 5000;  % ms
post_search_duration = 5;  % sec

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

stimuli_folder = 'stimuli';
black_shapes   = fullfile(stimuli_folder, 'shapes', 'transparent_black');
red_shapes     = fullfile(stimuli_folder, 'shapes', 'transparent_red');
green_shapes   = fullfile(stimuli_folder, 'shapes', 'transparent_green');
blue_shapes    = fullfile(stimuli_folder, 'shapes', 'transparent_blue');

% Output formats
bx_file_format   = 'bx_Subj%.3dRun%.2d.csv';
eye_file_format  = 'fixation_data_subj_%.3d_run_%.3d.csv';
edf_file_format  = 'RSS%.2dR%.1d.edf';
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

[practice_scene_file_paths, practice_scene_textures] = image_stimuli_import(fullfile('stimuli','scenes', 'practice'), '', w);

[scene_file_paths, scene_textures] = image_stimuli_import(fullfile('stimuli', 'scenes', 'main'), '', w);

% Load in shape stimuli
instruction_shapes = fullfile('stimuli', 'shapes', 'instructions');
black_shapes       = fullfile('stimuli', 'shapes', 'transparent_black');
left_shapes        = fullfile('stimuli', 'shapes', 'Black_Left_T');
right_shapes       = fullfile('stimuli', 'shapes', 'Black_Right_T');
green_left_shapes  = fullfile('stimuli', 'shapes', 'Green_Left_T');
green_right_shapes = fullfile('stimuli', 'shapes', 'Green_Right_T');
blue_left_shapes   = fullfile('stimuli', 'shapes', 'Blue_Left_T');
blue_right_shapes  = fullfile('stimuli', 'shapes', 'Blue_Right_T');
mag_left_shapes    = fullfile('stimuli', 'shapes', 'Mag_Left_T');
mag_right_shapes   = fullfile('stimuli', 'shapes', 'Mag_Right_T');

[sorted_instruction_shapes_file_paths, sorted_instruction_shapes_textures] = image_stimuli_import(instruction_shapes, '*.png', w, true);
[sorted_left_shapes_file_paths, sorted_left_shapes_textures] = image_stimuli_import(left_shapes, '*.png', w, true);
[sorted_right_shapes_file_paths, sorted_right_shapes_textures] = image_stimuli_import(right_shapes, '*.png', w, true);

[sorted_black_shapes_file_paths, sorted_black_shapes_textures] = image_stimuli_import(black_shapes, '*.png', w, true); %cue shapes

%magenta shapes
[sorted_left_mag_shapes_file_paths, sorted_left_mag_shapes_textures]     = image_stimuli_import(mag_left_shapes, '*.png', w, true);
[sorted_right_mag_shapes_file_paths, sorted_right_mag_shapes_textures]     = image_stimuli_import(mag_right_shapes, '*.png', w, true);
%green shapes
[sorted_left_green_shapes_file_paths, sorted_left_green_shapes_textures] = image_stimuli_import(green_left_shapes, '*.png', w, true);
[sorted_right_green_shapes_file_paths, sorted_right_green_shapes_textures] = image_stimuli_import(green_right_shapes, '*.png', w, true);
%blue shapes
[sorted_left_blue_shapes_file_paths, sorted_left_blue_shapes_textures] = image_stimuli_import(blue_left_shapes, '*.png', w, true);
[sorted_right_blue_shapes_file_paths, sorted_right_blue_shapes_textures] = image_stimuli_import(blue_right_shapes, '*.png', w, true);

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
randomizor = load('trial_structure_files/randomizor_matrix.mat'); % load the pre-randomized data
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
    if run_looper == 1
        total_trials = 8;
    else
        total_trials = 72;
    end

    clear bx_trial_info   % prevent "dissimilar structures" across runs

    % Preallocate structure for all trials
    if run_looper == 1
        phase = 'practice';
    elseif run_looper > 1
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
        'target_position', [], ...                   % target position (grid index)
        'target_rect', [], ...                       % target coordinates [x1 y1 x2 y2]
        'critical_distractor_idx', [], ...           % critical distractor texture index
        'critical_distractor_association', [], ...   % critical distractor association
        'critical_distractor_rect', [], ...          % critical distractor coords
        'noncritical_distractor_idx1', [], ...       % non-critical distractors (indices)
        'noncritical_distractor_rect1', [], ...      % non-critical distractors (coords)
        'noncritical_distractor_idx2', [], ...       % non-critical distractors (indices)
        'noncritical_distractor_rect2', [], ...      % non-critical distractors (coords)
        'noncritical_distractor_idx3', [], ...       % non-critical distractors (indices)
        'noncritical_distractor_rect3', [], ...      % non-critical distractors (coords)
        'noncritical_distractor_idx4', [], ...       % non-critical distractors (indices)
        'noncritical_distractor_rect4', [], ...      % non-critical distractors (coords)
        'noncritical_distractor_idx5', [], ...       % non-critical distractors (indices)
        'noncritical_distractor_rect5', [], ...      % non-critical distractors (coords)
        'noncritical_distractor_idx6', [], ...       % non-critical distractors (indices)
        'noncritical_distractor_rect6', [], ...      % non-critical distractors (coords)
        'condition', [], ...                         % condition code
        't_direction', [], ...                       % target T-direction (0=left,1=right)
        ...
        ... % ---- RESPONSE VARIABLES ----
        'rt', [], ...                                % reaction time (ms)
        'accuracy', [], ...                          % 1=correct, 0=incorrect, -1=no response
        'response_made', [], ...                     % logical: did subject respond
        'response_key', '', ...                      % key pressed
        ...
        ... % ---- SYSTEM VARIABLES ----
        'trial_onset', [], ...                       % stim onset (absolute)
        'trial_offset', [], ...                      % stim offset (absolute)
        'response_clock_time', [], ...               % time of response key
        'timestamp', '' ...                          % optional formatted datetime
    );

    fixationCounter = 0;
    currentFixationRect = 0;
    previousFixationRect = 0;

    %% LOAD DATA FOR THIS SUBJECT AND RUN
    this_subj_this_run    = randomizor.(sprintf('subj%d', sub_num)); %method of getting into the struct

    %load practice trials (they are the same for all subjects and runs and lightweight so load everytime)
    practice_matrix       = randomizor.practice_matrix; % Get the practice trials for this subject and run
    practice_shapes       = randomizor.practice_shapes;
    practice_t_directions = randomizor.practice_t_directions;

    % main run vars
    this_block = this_subj_this_run.blocks{run_looper}; % Get the block for this run which contains: Columns: [scene_id, target_pos, epoch, condition, block]
    shapes = this_subj_this_run.shape_blocks{run_looper}; % Get the shapes for this run
    t_directions = this_subj_this_run.t_direction_blocks{run_looper}; % Get the target directions for this run
    colors = this_subj_this_run.color_blocks{run_looper}; % Get the colors for this run

    if run_looper == 1
        this_block = practice_matrix; % Use practice trials for the first run
        shapes = practice_shapes; % Use practice shapes for the first run
        t_directions = practice_t_directions; % Use practice target directions for the first run
    end

    high_probability_distractor_location = this_subj_this_run.high_probability_distractor_location; % Get the high probability distractor location for this subject and run
    
    if eyetracking
        % Ensure tracker is connected
        if ~Eyelink('IsConnected')
            error('Eyelink not connected!');
        end
        
        % Create unique EDF filename for this run
        edf_file_name = sprintf(edf_file_format, sub_num, run_looper);

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

        %% DRAW SCENE   
        search = Screen('OpenOffscreenWindow', scrID, col.bg, rect, 32);

        % Draw the scene texture
        scene_inds = this_block(trial_looper, 1); % Get the scene index for this trial
        if run_looper == 1
            Screen('DrawTexture', search, practice_scene_textures(scene_inds), [], rect);
        else
            Screen('DrawTexture', search, scene_textures(scene_inds), [], rect);
        end

        % Enable blending for transparency inside this offscreen window
        Screen('BlendFunction', search, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        
        % ---- map TYPE → POSITION and draw TARGET
        all_positions       = 1:6; % 6 possible positions
        target_position     = this_block(trial_looper, 2); % Get the target position for this trial
        target_rect         = saved_positions{scene_inds, target_position};  % use POSITION!
        remaining_positions = setdiff(all_positions, target_position, 'stable');  % remaining positions for distractors dont sort

        target_inds = shapes(trial_looper, target_position); % Get the target shape index for this trial
        trial_t_directions = t_directions(trial_looper, :); % Get the target directions for this trial

        if eyetracking
            % Define AOIs
            Eyelink('command', 'draw_box %d %d %d %d %d', ceil(target_rect(1)), ceil(target_rect(2)), ceil(target_rect(3)), ceil(target_rect(4)), 15); % Target in white
            Eyelink('Message', '!V IAREA RECTANGLE 1 %d %d %d %d TargetBox', ceil(target_rect(1)), ceil(target_rect(2)), ceil(target_rect(3)), ceil(target_rect(4)));
        end

        
        if trial_t_directions(1) == 0
            % left target
            Screen('DrawTexture', search, sorted_left_shapes_textures(target_inds), [], target_rect);
        elseif trial_t_directions(1) == 1
            % right target  
            Screen('DrawTexture', search, sorted_right_shapes_textures(target_inds), [], target_rect);
        end
        
        if run_looper == 1
            trial_condition = 0;
        else
            trial_condition = this_block(trial_looper, 4); % Get the condition for this trial
        end

        % ---- draw CRITICAL DISTRACTOR 
        if trial_condition ~= 0
            % Map each surface (1=wall, 2=counter, 3=floor) to its two positions
            surface_positions = {[1 2], [3 4], [5 6]};

            if trial_condition == 1
                % High-probability surface
                target_surface = high_probability_distractor_location;
            else
                % Low-probability surfaces (the two that are NOT high-prob)
                low_surfaces   = setdiff([1 2 3], high_probability_distractor_location);
                target_surface = low_surfaces(trial_condition - 1);  % cond 2->1st, cond 3->2nd
            end
        
            possible_crit_positions = surface_positions{target_surface};
        
            % Keep only positions still available (target already removed)
            possible_crit_positions = intersect(possible_crit_positions, remaining_positions, 'stable');
        
            % Randomly select one (handles 1 or 2 candidates)
            crit_position = possible_crit_positions(randi(numel(possible_crit_positions)));
        
            % Remove chosen position from remaining
            remaining_positions = setdiff(remaining_positions, crit_position, 'stable');
        else
            crit_position = [];   % absent condition
        end

        if run_looper > 1 && trial_condition ~= 0
            crit_rect = saved_positions{scene_inds, crit_position};
            crit_inds = shapes(trial_looper, crit_position); % Get the critical distractor shape index for this trial
            if trial_t_directions(6) == 0
                % left critical distractor
                if colors(trial_looper) == 1
                    % green critical distractor
                    Screen('DrawTexture', search, sorted_left_mag_shapes_textures(crit_inds), [], crit_rect);
                elseif colors(trial_looper) == 2
                    % blue critical distractor
                    Screen('DrawTexture', search, sorted_left_green_shapes_textures(crit_inds), [], crit_rect);
                elseif colors(trial_looper) == 3
                    % magenta critical distractor
                    Screen('DrawTexture', search, sorted_left_blue_shapes_textures(crit_inds), [], crit_rect);
                end
            elseif trial_t_directions(6) == 1
                % right critical distractor
                if colors(trial_looper) == 1
                    % green critical distractor
                    Screen('DrawTexture', search, sorted_right_mag_shapes_textures(crit_inds), [], crit_rect);
                elseif colors(trial_looper) == 2
                    % blue critical distractor
                    Screen('DrawTexture', search, sorted_right_green_shapes_textures(crit_inds), [], crit_rect);
                elseif colors(trial_looper) == 3
                    % magenta critical distractor
                    Screen('DrawTexture', search, sorted_right_blue_shapes_textures(crit_inds), [], crit_rect);
                end
            end
            if eyetracking
                % Define AOIs
                Eyelink('command', 'draw_box %d %d %d %d %d', ceil(crit_rect(1)), ceil(crit_rect(2)), ceil(crit_rect(3)), ceil(crit_rect(4)), 7);  % Critical distractor in gray
                Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d CritDistBox', 2, ceil(crit_rect(1)), ceil(crit_rect(2)), ceil(crit_rect(3)), ceil(crit_rect(4)));
            end
        end

        if trial_condition == 0
            rect_id = 2; % Start rect_id at 2 for non-critical distractors
        elseif trial_condition ~= 0
            rect_id = 3; % Start rect_id at 3 for non-critical distractors
        end
        
        %set these as nan because on some trials there will be less than 6 non-critical distractors
        noncrit_rect6 = nan;
        noncrit_ind6 = nan;

        for k = 1:numel(remaining_positions)
            this_pos  = remaining_positions(k);       % map TYPE → POSITION
            this_rect = saved_positions{scene_inds, this_pos};
            distractor_texture_index = shapes(trial_looper, this_pos); % Get the distractor shape index for this trial
            if trial_t_directions(1+k) == 0
                % left non-critical distractor
                Screen('DrawTexture', search, sorted_left_shapes_textures(distractor_texture_index), [], this_rect);
            elseif trial_t_directions(1+k) == 1
                % right non-critical distractor
                Screen('DrawTexture', search, sorted_right_shapes_textures(distractor_texture_index), [], this_rect);
            end

            if k == 1
                noncrit_rect1 = this_rect;
                noncrit_ind1 = distractor_texture_index;
            elseif k == 2
                noncrit_rect2 = this_rect;
                noncrit_ind2 = distractor_texture_index;
            elseif k == 3
                noncrit_rect3 = this_rect;
                noncrit_ind3 = distractor_texture_index;
            elseif k == 4
                noncrit_rect4 = this_rect;
                noncrit_ind4 = distractor_texture_index;
            elseif k == 5
                noncrit_rect5 = this_rect;
                noncrit_ind5 = distractor_texture_index;
            elseif k == 6
                noncrit_rect6 = this_rect;
                noncrit_ind6 = distractor_texture_index;
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
        Screen('DrawTexture', cue_display, sorted_black_shapes_textures(target_inds));

        if eyetracking   
            centralFixation(w, height, width, fixation, fix, trial_looper, el, eye_used)
        else
            % Fixation cross just drawn for when testing.
            Screen('DrawTexture', w, fixation);
            Screen('Flip', w);
            WaitSecs(.5)
        end
        
        % CUE DISPLAY
        Screen('DrawTexture', w, cue_display);
        Screen('Flip', w);

        if eyetracking
            Eyelink('Message','CUE_ONSET %d', target_inds);
        end

        % Draw fixation cross
        Screen('DrawTexture', w, fixation);
        WaitSecs(1); % 1 second cue
        
        Screen('Flip', w); %Flip to show fixation cross again

        if eyetracking
            Eyelink('Message','FIXATION_ONSET_2');
        end

        Screen('DrawTexture', w, search); %draw the search display
        WaitSecs(1); % 1 second central fixation

        %% SEARCH DISPLAY
        stimOnsetTime = Screen('Flip', w); %this Flip displays the scene with all four shapes

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
        secs = NaN; % Initialize secs as NaN

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

        if trial_t_directions(1) == 0 && strcmp(response, key.left)
            trial_accuracy = 1;
        elseif trial_t_directions(1) == 1 && strcmp(response, key.right)
            trial_accuracy = 1;
        elseif trial_t_directions(1) == 1 && strcmp(response, key.left)
            trial_accuracy = 0;
        elseif trial_t_directions(1) == 0 && strcmp(response, key.right)
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
            bx_trial_info(trial_looper).scene_file           = practice_scene_file_paths{scene_inds};
        else
            bx_trial_info(trial_looper).scene_file           = scene_file_paths{scene_inds};
        end

        % Target info
        bx_trial_info(trial_looper).target_shape_idx         = target_inds;
        bx_trial_info(trial_looper).target_position          = target_position;
        bx_trial_info(trial_looper).target_rect              = target_rect;
        
        % Distractors
        if run_looper > 1 && trial_condition ~= 0
            bx_trial_info(trial_looper).critical_distractor_idx         = crit_inds;
            bx_trial_info(trial_looper).critical_distractor_association = high_probability_distractor_location;
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
        bx_trial_info(trial_looper).noncritical_distractor_idx4   = noncrit_ind4;
        bx_trial_info(trial_looper).noncritical_distractor_rect4  = noncrit_rect4;
        bx_trial_info(trial_looper).noncritical_distractor_idx5   = noncrit_ind5;
        bx_trial_info(trial_looper).noncritical_distractor_rect5  = noncrit_rect5;
        bx_trial_info(trial_looper).noncritical_distractor_idx6   = noncrit_ind6;
        bx_trial_info(trial_looper).noncritical_distractor_rect6  = noncrit_rect6;

        % Condition / stimulus info
        bx_trial_info(trial_looper).condition   = trial_condition;
        bx_trial_info(trial_looper).t_direction = trial_t_directions(1);

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

        feedback_duration = 0.5; % seconds
        if eyetracking
            Eyelink('Message', 'END_TIME SEARCH_PERIOD');
        end

        if trial_accuracy == 1
            DrawFormattedText(w, 'Correct!', 'center', 'center', col.fg);
        else
            DrawFormattedText(w, 'Incorrect!', 'center', 'center', col.fg);
        end
        Screen('Flip', w);

        if eyetracking
            Eyelink('Message', 'START_TIME FEEDBACK_PERIOD');        
        end
        
        WaitSecs(feedback_duration); % give feedback for .5 seconds before closing

        %draw blank ITI
        Screen('Flip', w);

        if eyetracking
            Eyelink('Message', 'END_TIME FEEDBACK_PERIOD');
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

%        ...     % ---- EYE-TRACKING VARIABLES ----
%        ...     % First saccade (primary capture measure)
%        'first_saccade_latency', [], ...        % ms from search onset to 1st saccade
%        'first_saccade_endpoint_x', [], ...     % x coord where 1st saccade landed
%        'first_saccade_endpoint_y', [], ...     % y coord
%        'first_saccade_aoi', '', ...            % which AOI: 'target','crit_dist','noncrit','none'
%        'first_saccade_direction', [], ...      % angle (deg), optional
%        ...
%        ... % Capture / suppression flags (derived, but handy to store)
%        'captured_by_crit_dist', [], ...        % 1 if 1st saccade -> critical distractor
%        'saccade_to_target_first', [], ...      % 1 if 1st saccade -> target
%        'crit_dist_at_high_prob', [], ...       % 1 if CD was in high-prob location this trial
%        ...
%        ... % Time to target (efficiency measure)
%        'time_to_target_fixation', [], ...      % ms from onset to first target fixation
%        'n_fixations_before_target', [], ...    % # fixations before landing on target
%        'target_fixated', [], ...               % 1 if target ever fixated
%        ...
%        ... % Distractor dwell (suppression can show as reduced dwell)
%        'crit_dist_fixated', [], ...            % 1 if CD ever fixated
%        'crit_dist_dwell_time', [], ...         % total ms fixating CD
%        'crit_dist_n_fixations', [], ...        % # fixations on CD
%        ...
%        ... % Full trace (for offline flexibility)
%        'fixation_sequence', [], ...            % ordered list of AOIs fixated
%        'fixation_onsets', [], ...              % onset times of each fixation
%        'fixation_durations', [], ...           % duration of each fixation
%        'saccade_count', [], ...                % total saccades this trial