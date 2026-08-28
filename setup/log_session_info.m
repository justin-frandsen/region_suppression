function log_session_info(subjectID, runNum, experimenter_initials, totalTrials, startTime, endTime, logFilePath, eyetracking, edfFileName)
% log_session_info
% Logs basic session metadata to a plain .txt log file
%
% Inputs:
%   subjectID    - numeric or string ID for the participant
%   totalTrials  - number of trials completed
%   startTime    - output of now() when session starts
%   endTime      - output of now() when session ends
%   logFilePath  - full path to log file (e.g., 'data/subj101_log.txt')

    % Convert time to readable format
    startStr = datestr(startTime, 'yyyy-mm-dd HH:MM:SS');
    endStr   = datestr(endTime, 'yyyy-mm-dd HH:MM:SS');

    % System info
    ptbVersion = PsychtoolboxVersion;
    osInfo = system_dependent('getos');
    matlabVersion = version;

    % Monitor info
    screens = Screen('Screens');
    screenNumber = max(screens);
    [width, height] = Screen('WindowSize', screenNumber);
    refreshRate = Screen('NominalFrameRate', screenNumber);

    % Open file
    fid = fopen(logFilePath, 'w');
    if fid == -1
        warning('Failed to write session log to %s', logFilePath);
        return;
    end

    fprintf(fid, '--- Session Log ---\n');
    fprintf(fid, 'Subject ID: %s\n', num2str(subjectID));
    fprintf(fid, 'Run Number: %s\n', num2str(runNum));
    fprintf(fid, 'Date: %s\n', startStr(1:10));
    fprintf(fid, 'Experimenter: %s\n', experimenter_initials);
    fprintf(fid, 'Session Start: %s\n', startStr(12:end));
    fprintf(fid, 'Session End:   %s\n', endStr(12:end));
    fprintf(fid, 'Total Trials:  %d\n', totalTrials);
    fprintf(fid, '\n--- System Info ---\n');
    fprintf(fid, 'OS: %s\n', osInfo);
    fprintf(fid, 'MATLAB Version: %s\n', matlabVersion);
    fprintf(fid, 'Psychtoolbox Version: %s\n', ptbVersion);
    fprintf(fid, '\n--- Display Info ---\n');
    fprintf(fid, 'Screen Resolution: %dx%d\n', width, height);
    fprintf(fid, 'Refresh Rate: %d Hz\n', refreshRate);
    fprintf(fid, 'Screen Number: %d\n', screenNumber);

    if eyetracking
        fprintf(fid, '\n--- EyeLink Info ---\n');
        fprintf(fid, 'EDF File: %s\n', edfFileName);

        [verNum, verStr] = Eyelink('GetTrackerVersion');
        fprintf(fid, 'EyeLink Version: %d\n', verNum);
        fprintf(fid, 'EyeLink Software: %s\n', verStr);

        eye_used = Eyelink('EyeAvailable');
        if eye_used == 0
            eyeName = 'LEFT';
        elseif eye_used == 1
            eyeName = 'RIGHT';
        else
            eyeName = 'BINOCULAR';
        end
        fprintf(fid, 'Eye Tracked: %s\n', eyeName);

        fprintf(fid, 'Sample Rate: %s Hz\n', Eyelink('Command', 'sample_rate?'));
        fprintf(fid, 'Calibration: completed\n');
    end
    fclose(fid);
    fprintf('[INFO] Session log saved to %s\n', logFilePath);
end
