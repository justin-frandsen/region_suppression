function [sub_num, run_num, experimenter_initials] = experiment_setup()
%% Ask for subject info
prompt = {'Subject number:', 'Run number:', 'Experimenter initials:'};
dlg_title = 'Experiment Setup';
num_lines = 1;
defaultans = {'', '', ''}; % empty defaults
answer = inputdlg(prompt, dlg_title, num_lines, defaultans);

% Handle cancel
if isempty(answer)
    error('User cancelled at subject info dialog.');
end

% Parse values
sub_num = str2double(answer{1});
run_num = str2double(answer{2});
experimenter_initials = strtrim(answer{3});

if isnan(sub_num) || isnan(run_num) || isempty(experimenter_initials)
    error('Invalid input: please enter numeric subject/run and non-empty initials.');
end

%% Confirmation dialog
confirm_msg = sprintf('Subject: %d\nRun: %d\nExperimenter: %s\n\nDo you want to continue?', ...
                      sub_num, run_num, experimenter_initials);
button = questdlg(confirm_msg, 'Confirm Setup', 'Continue', 'Cancel', 'Continue');

if isempty(button) || strcmp(button,'Cancel')
    error('Experimenter cancelled at confirmation dialog.');
end
end
