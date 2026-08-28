% practice
% Runs a practice block of the experiment.
% This is a fixed practice. Participants will complete 8 trials. 100% validity in this task
while inaccurate
    for practice_trial = 1:8
        % present practice trial
        % record accuracy
        % if accurate, break loop
        % if inaccurate, repeat practice block

                %% DRAW SCENE   
        search = Screen('OpenOffscreenWindow', scrID, col.bg, rect, 32);
        post_search = Screen('OpenOffscreenWindow', scrID, col.bg, rect, 32);
        % Draw the scene texture
        Screen('DrawTexture', search, scene_textures(scene_inds), [], rect);
        Screen('DrawTexture', post_search, scene_textures(scene_inds), [], rect);

        % Enable blending for transparency inside this offscreen window
        Screen('BlendFunction', search, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        % Enable blending for transparency inside this offscreen window
        Screen('BlendFunction', post_search, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        types     = [1 2 3];      % semantic categories: wall/counter/floor
        positions = [1 2 3 4];    % physical rect indices

        % ---- choose the target TYPE for this trial
        if run_looper <= 4
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
        else
            % Testing: trial_condition chooses whether target uses its associated
            % location or one of the other two we make this so that it is completely
            % random instead this time though but i use the same var to ranodmize it
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
        end

        % ---- map TYPE → POSITION and draw TARGET
        target_position    = possible_positions(target_type);               % e.g., 1..4
        target_rect        = saved_positions{scene_inds, target_position};  % use POSITION!
        remaining_positions = setdiff(possible_positions, target_position, 'stable');  % remaining positions for distractors dont sort

        if eyetracking
            % Define AOIs
            Eyelink('Message', '!V IAREA TARGET %d %d %d %d TargetBox', target_rect(1), target_rect(2), target_rect(3), target_rect(4));
        end

        if t_directions(1) == 0
            % left target
            Screen('DrawTexture', search, sorted_left_shapes_textures(target_texture_index), [], target_rect);
        elseif t_directions(1) == 1
            % right target  
            Screen('DrawTexture', search, sorted_right_shapes_textures(target_texture_index), [], target_rect);
        end

        crit_dist_position = []; 
        
        % ---- draw CRITICAL DISTRACTOR only in training
        if run_looper <= 4
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
                Eyelink('Message', '!V IAREA DISTRACTOR %d %d %d %d CritDistBox', crit_rect(1), crit_rect(2), crit_rect(3), crit_rect(4));
            end
        end

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

            if eyetracking
                % Define AOIs
                Eyelink('Message', '!V IAREA DISTRACTOR %d %d %d %d NonCritDistBox%d', this_rect(1), this_rect(2), this_rect(3), this_rect(4), k);
            end
        end
    end
end