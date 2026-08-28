function location_overlap_checker(scene_type_main0_practice1, unchecked0_checked1)
%-----------------------------------------------------------------------
% Script: location_overlap_checker.m
% Author: Justin Frandsen
% Date: 22/07/2025 %dd/mm/yyyy
% Description:
% - This script takes the output of shape_position_finder.m and checks what
%   locations are overlapping.
% Usage:
% - For main scenes use scene_type_main0_practice1 = 0 and for practice scenes
%   use scene_type_main0_practice1 = 1. 
% - To use output from shape_position_checker.m instead use
%   unchecked0_checked1 = 1
%-----------------------------------------------------------------------

if scene_type_main0_practice1 == 0 && unchecked0_checked1 == 0
    shape_location_types = load('trialDataFiles/shape_location_types_main.mat');
    shape_positions = load('trialDataFiles/shape_positions_main.mat');
elseif scene_type_main0_practice1 == 1 && unchecked0_checked1 == 0
    shape_location_types = load('trialDataFiles/shape_location_types_practice.mat');
    shape_positions = load('trialDataFiles/shape_positions_practice.mat');
elseif scene_type_main0_practice1 == 0 && unchecked0_checked1 == 1
    shape_location_types = load('trialDataFiles/shape_location_types_main_checked.mat');
    shape_positions = load('trialDataFiles/shape_positions_main_checked.mat');
elseif scene_type_main0_practice1 == 1 && unchecked0_checked1 == 1
    shape_location_types = load('trialDataFiles/shape_location_types_practice_checked.mat');
    shape_positions = load('trialDataFiles/shape_positions_practice_checked.mat');
end

saved_positions = shape_positions.savedPositions;
num_scenes = length(saved_positions);
num_rects = 4;

total_different_matched_scenes = 0;
floor_with_wall = 0;
floor_with_counter = 0;
counter_with_wall = 0;

overlap_matrix = cell(num_scenes, num_rects);

for this_scene_num = 1:num_scenes
    this_scene_overlap_matrix = zeros(num_scenes, num_rects);
    for k = 1:num_rects
        
        this_position = saved_positions(this_scene_num, k);
        total_matches_counter = 0;
        different_type_matches_counter = 0;
        for scene_num = 1:num_scenes
            for i = 1:num_rects
                rect2 = saved_positions(scene_num, i); % Exclude the type column
                
                % Check for overlap
                if rect_overlap(this_position{1}, rect2{1})
                    % Store the type in the overlap_matrix
                    primary_scene_type = shape_location_types.locationTypes(this_scene_num, k);
                    secondary_scene_type = shape_location_types.locationTypes(scene_num, i);
                    this_scene_overlap_matrix(scene_num, i) = secondary_scene_type;
                    
                    total_matches_counter = total_matches_counter + 1;
                    if primary_scene_type ~= secondary_scene_type
                        fprintf("Primary Scene(%d, %d), Type: %d -- SecondaryScene(%d, %d) Type: %d\n", this_scene_num, k, primary_scene_type, scene_num, i, secondary_scene_type)
                        different_type_matches_counter = different_type_matches_counter + 1;
                        
                        if (primary_scene_type == 1 && secondary_scene_type == 3) || (primary_scene_type == 3 && secondary_scene_type == 1)
                            counter_with_wall = counter_with_wall + 1;
                        elseif (primary_scene_type == 1 && secondary_scene_type == 2) || (primary_scene_type == 2 && secondary_scene_type == 1)
                            floor_with_wall = floor_with_wall + 1;
                        elseif (primary_scene_type == 2 && secondary_scene_type == 3) || (primary_scene_type == 3 && secondary_scene_type == 2)
                            floor_with_counter = floor_with_counter + 1;
                        end
                    end
                end
            end
        end
        fprintf("Scene(%d, %d) total matches = %d, different matches = %d\n", this_scene_num, k, total_matches_counter, different_type_matches_counter);
        if different_type_matches_counter > 0
            total_different_matched_scenes = total_different_matched_scenes + 1;
        end
        overlap_matrix{this_scene_num, k} = this_scene_overlap_matrix;
        
    end
    
end

fprintf("Scenes Positions w/ different matches = %d/%d\n", total_different_matched_scenes, num_scenes * 4)
fprintf("Floor with Wall Match Count = %d\n", floor_with_wall / 2) %divide by 2 because it checks each position twice
fprintf("Floor with Counter Match Count = %d\n", floor_with_counter / 2) 
fprintf("Counter with Wall Match Count = %d\n", counter_with_wall / 2)

for scene_num = 1:num_scenes
    if sum(find(shape_location_types.locationTypes(2, :) == 1)) >= 1 && ...
       sum(find(shape_location_types.locationTypes(2, :) == 2)) >= 1 && ...
       sum(find(shape_location_types.locationTypes(2, :) == 3)) >= 1
        fprintf("SceneNum: %d, is good\n", scene_num);
    else
        fprintf("SceneNum: %d, is bad\n", scene_num);
    end
end
end

function overlap = rect_overlap(rect1, rect2)
    x1 = rect1(1);
    y1 = rect1(2);
    w1 = rect1(3) - x1;
    h1 = rect1(4) - y1;
    
    x2 = rect2(1);
    y2 = rect2(2);
    w2 = rect2(3) - x2;
    h2 = rect2(4) - y2;
    
    % Calculate the right and bottom edges of the rectangles
    right1 = x1 + w1;
    bottom1 = y1 + h1;
    
    right2 = x2 + w2;
    bottom2 = y2 + h2;
    
    % Check for overlap
    overlap = (x1 < right2) && (x2 < right1) && (y1 < bottom2) && (y2 < bottom1);   
end