function [] = screenshot(window, file_name, sub_num, trial_num, run_num)
%SCREENSHOT - input which array you want to screenshot and what you want to
%name it. Then, takes and saves a screenshot of the array as a png file

[scrW, scrH] = Screen('WindowSize', window); % Get the size of the window

% window = which window do you want to screenshot?
% file_name = name of the saved screenshot
% sub_num = subject number
% run_num = run number
% trial_num = trial number

% capture the screen "window" and save it as an image
imageArray = Screen('GetImage', window, [0 0 scrW scrH]);
% name the screenshot ("name" _ "iteration"
namePNG = sprintf('%s_S%i_R%i_T%i.png', file_name, sub_num, run_num, trial_num);
ssname = sprintf('figures/%s', namePNG);
imwrite(imageArray, ssname);

end