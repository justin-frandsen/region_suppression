function showInstructions(w, sortedInstructionShapesTextures, leftKey, rightKey)
% showInstructions
% Displays experiment instructions with customizable response keys.
%
% Usage:
%   showInstructions(w, sortedInstructionShapesTextures, 'z', '/')
%
% Inputs:
%   w       : Psychtoolbox window pointer
%   sortedInstructionShapesTextures : cell/array of textures for examples
%   leftKey : key for "orientation 1" response (e.g., 'z')
%   rightKey: key for "orientation 2" response (e.g., '/')

    % Define pages of instructions
    instructionPages = {
        sprintf(['Welcome to the experiment.\n\n' ...
            'On each trial, you will be shown a TARGET shape. Afterward,\nyou will' ...
            ' search for this shape within a scene that contains several\nshapes.'...
            ' Every shape will contain a sideways "T". Your task is to\nreport the ' ...
            'orientation of the T inside the TARGET shape only.\n\n' ...
            'Press SPACEBAR to continue.']);

        sprintf(['If the T inside the target shape appears like this:\n\n' ...
            'Press the "%s" key.\n\n' ...
            'Press SPACEBAR to continue.'], rightKey);

        sprintf(['If the T inside the target shape appears like this:\n\n' ...
            'Press the "%s" key.\n\n' ...
            'Press SPACEBAR to begin the experiment.'], leftKey)
    };

    % Left margin for text
    leftMargin = [50, 300, 300];

    % Loop through instruction pages
    for iPage = 1:numel(instructionPages)

        % Draw instruction text
        DrawFormattedText(w, instructionPages{iPage}, leftMargin(iPage), 'center');

        % Show example shapes on the correct pages
        if iPage == 2
            % Example T orientation for rightKey
            Screen('DrawTexture', w, sortedInstructionShapesTextures(1), [], [910, 490, 1010, 590]);
        elseif iPage == 3
            % Example T orientation for leftKey
            Screen('DrawTexture', w, sortedInstructionShapesTextures(2), [], [910, 490, 1010, 590]);
        end

        % Flip to screen
        Screen('Flip', w);

        % Wait for SPACEBAR before continuing
        KbWait([], 2);
    end
end
