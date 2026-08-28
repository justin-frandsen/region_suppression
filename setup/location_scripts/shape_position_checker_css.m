%-----------------------------------------------------------------------
% Script: shape_position_checker_css.m
% Author: Justin Frandsen
% Date: 22/07/2025 %dd/mm/yyyy
% Description:
% - Takes output from shape_position_finder_css.m and lets you Fix any
%   mislabeling or mistakes in positioning
% Usage:
% - make sure the output from shape_position_finder_css.m is in the
%   trial_structure_files/shape_positions.mat file.
% - run this script to check the positions of the shapes in the scenes.
% - Use the mouse to move the image across the screen. Use - & + to increase
%   or decrease the size of the shapes, and use space to save that position
%   and size. 
%-----------------------------------------------------------------------
%% CLEAR VARIABLES
clc;
close all;
clear all;
sca;

%% ADD PATHS
addpath(genpath('../'));

main = true; % set to false to only run practice scenes

%% SETTINGS
if main
    scene_folder = '../../stimuli/scenes/main';
    shape_positions_file = '../../trial_structure_files/shape_positions.mat';
else
    scene_folder = '../../stimuli/scenes/practice';
    shape_positions_file = '../../trial_structure_files/practice_shape_positions.mat';
end

shapes_folder = '../../stimuli/shapes/transparent_black';

scr_w = 1920;
scr_h = 1080;
scr_hz = 60;

% colors
col.white = [255 255 255]; 
col.black = [0 0 0];
col.gray = [117 117 117];

col.bg = col.gray; % background color
col.fg = col.white; % foreground color
col.fix = col.black; % fixation color

screens = Screen('Screens'); % Get the list of screens
scrID = max(screens); % Get the maximum screen ID (this should usually be the external monitor if using multiple screens)

%% INITIALIZE PTB WINDOW
[w, rect] = ../ptb_scripts/pfp_ptb_init;
[width, height] = Screen('WindowSize', 0);

Screen('BlendFunction', w, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA'); %allows the .png files to be transparent

%% Load in images
DrawFormattedText(w, 'Loading Images...', 'center', 'center');
Screen('Flip', w);

[~, scenes_texture_matrix] = imageStimuliImport(scene_folder, '', w);
[~, stimuli_texture_matrix] = imageStimuliImport(shapesFolder, '*.png', w);

%load in shape positions
saved_positions = load(shape_positions_file);
saved_positions = saved_positions.saved_positions;

%get size of shape position matrix
num_scenes = size(saved_positions, 1);
num_positions = size(saved_positions, 2);

% Set initial position of the texture
textureSize = [0, 0, 106, 106]; % In this version I am maintaining the same size as the previos experiment at 106 pixels tall and wide

KbName('UnifyKeyNames');

% load offscreen window for each text type
wall_text = Screen('OpenOffscreenWindow', scrID, col.bg, rect);
DrawFormattedText(wall_text, 'Position Type: Wall', 'center', 'center')

counter_text = Screen('OpenOffscreenWindow', scrID, col.bg, rect);
DrawFormattedText(counter_text, 'Position Type: Counter', 'center', 'center')

floor_text = Screen('OpenOffscreenWindow', scrID, col.bg, rect);
DrawFormattedText(floor_text, 'Position Type: Floor', 'center', 'center')

for scene_num = 1:num_scenes
    %% DRAW SCENE   
    scene = Screen('OpenOffscreenWindow', scrID, col.bg, rect);
    % Draw the scene texture
    Screen('DrawTexture', scene, scenes_texture_matrix(scene_num), [], rect);

    for position_num = 1:num_positions
        this_shape = stimuli_texture_matrix(randsample(1:22, 1));
        
        thisScenePosition = savedPositions(scene_num, positionNum);
        
        Screen('DrawTexture', w, scene);
        Screen('DrawTexture', w, this_shape, [], thisScenePosition{1});

        if position_num == 1 || position_num == 2
            Screen('DrawTexture', w, scene);
        elseif position_num == 3 || position_num == 4
            Screen('DrawTexture', w, scene);
        elseif position_num == 5 || position_num == 6
            Screen('DrawTexture', w, scene);
        end
        
        Screen('Flip', w);
        
        % Wait for a response
        [~, keyCode, ~] = KbWait([], 2);
        keyChar = KbName(keyCode);
        
        % Wait for a key press
        while true
            [~, ~, keyCode] = KbCheck;
            
            % Check if 'y' or 'n' key is pressed
            if any(strcmpi(KbName(find(keyCode)), {'y', 'n'}))
                break;
            end
        end
        
        if any(strcmp(keyChar, {'n', 'N'}))
            WaitSecs(0.5);
            running = true;
            this_shape = stimuli_texture_matrix(randsample(1:22, 1));
            while running == true
                
                % Check for keyboard events
                [keyIsDown, ~, keyCode] = KbCheck;
                
                if keyIsDown && keyCode(KbName('ESCAPE'))
                    pfp_ptb_cleanup
                end
                
                % Update mouse position
                [x, y, buttons] = GetMouse(w);
                textureMover = [x y x y];
                
                % check if left mouse button is pressed. If it is exit loop
                if buttons(1)
                    running = false;
                end
                
                % Draw texture at new position
                position = textureSize + textureMover;
                Screen('DrawTexture', w, scene);
                Screen('DrawTexture', w, this_shape, [], position);
                Screen('Flip', w);
                
                WaitSecs(0.01);
            end
            
            savedPositions{scene_num, positionNum} = position;
        end
    end
end

DrawFormattedText(w, 'Saving Data', 'center', 'center')
Screen('Flip', w);

% save the updated positions
save ../../trial_structure_files/shape_positions_checked.mat saved_positions

pfp_ptb_cleanup
% end of script
%-----------------------------------------------------------------------