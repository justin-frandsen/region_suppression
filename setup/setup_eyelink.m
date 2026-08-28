function el = setup_eyelink(windowPtr)
    % setupEyelinkTracker Initialize Eyelink with sensible defaults
    %
    % Inputs:
    %   windowPtr  - Psychtoolbox window pointer
    %   edfFileName - EDF file name string (e.g. 'subj01.edf')
    %
    % Output:
    %   el - Eyelink defaults struct
    
    % Get screen size
    [width, height] = Screen('WindowSize', windowPtr);
    
    % Initialize Eyelink defaults
    el = EyelinkInitDefaults(windowPtr);
    
    % Calibration display colors
    el.backgroundcolour = GrayIndex(el.window);
    el.msgfontcolour  = WhiteIndex(el.window);
    el.imgtitlecolour = WhiteIndex(el.window);  % title color on calibration screen
    el.targetbeep = 0;  % no beep on calibration target
    
    el.calibrationtargetcolour = WhiteIndex(el.window);
    el.calibrationtargetsize = 2;    % calibration target diameter in pixels (adjust as needed)
    el.calibrationtargetwidth = 0.75; % target outline thickness in pixels
    
    % Apply settings
    EyelinkUpdateDefaults(el);
    
    % Initialize connection to Eyelink
    if ~EyelinkInit(0)
        fprintf('Eyelink Init aborted.\n');
        Eyelink('Shutdown');
        Screen('CloseAll');
        error('Eyelink Init failed');
    end
    
    if Eyelink('IsConnected') ~= 1
        Eyelink('Shutdown');
        Screen('CloseAll');
        error('Eyetracker not connected');
    end
    
    % Send important commands to Eyelink
    Eyelink('command', 'add_file_preamble_text ''Recorded by EyelinkToolbox demo-experiment''');
    Eyelink('command', 'screen_pixel_coords = %ld %ld %ld %ld', 0, 0, width - 1, height - 1);
    Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, width - 1, height - 1);
    
    Eyelink('command', 'calibration_type = HV9'); % 9-point calibration
    Eyelink('command', 'generate_default_targets = YES');
    Eyelink('command', 'calibration_area_proportion .85 .85'); % optional: calibration extent
    Eyelink('command', 'validation_area_proportion .85 .85');  % optional: validation extent
    
    Eyelink('command', 'saccade_velocity_threshold = 35');
    Eyelink('command', 'saccade_acceleration_threshold = 9500');
    
    Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
    Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
    
    Eyelink('command', 'file_sample_data = LEFT,RIGHT,GAZE,HREF,AREA,HTARGET,GAZERES,STATUS,INPUT');
    Eyelink('command', 'link_sample_data = LEFT,RIGHT,GAZE,GAZERES,AREA,HTARGET,STATUS,INPUT');
    
    % Display tracker version info
    [v, vs] = Eyelink('GetTrackerVersion');
    fprintf('Running experiment on a ''%s'' tracker.\n', vs);
    
    % Button 5 accepts target fixation (EyeLink Remote)
    Eyelink('command', 'button_function 5 "accept_target_fixation"');
end