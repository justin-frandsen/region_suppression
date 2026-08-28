function [] = centralFixation(expWin, scrH, scrW, fixScreen, fix, t, el, eye)
% CENTRALFIXATION Checks for central fixation before starting a trial.
%   expWin   = PTB window pointer
%   scrH/W   = screen height/width
%   fixScreen= texture with fixation cross
%   fix      = struct with fields reqDur (ms), timeout (ms), radius (pixels)
%   t        = trial index
%   el       = Eyelink defaults
%   eye      = index of tracked eye

ctrX = scrW/2;
ctrY = scrH/2;
len  = 16;  % half-length of cross arms in pixels
col  = 15;  % white (0=black, 15=white, 7=gray)
fix.finished = 0;
Eyelink('command', 'draw_line %d %d %d %d %d', ctrX-len, ctrY, ctrX+len, ctrY, col); % horizontal
Eyelink('command', 'draw_line %d %d %d %d %d', ctrX, ctrY-len, ctrX, ctrY+len, col); % vertical

while ~fix.finished
    Eyelink('Message','FIXATION_ONSET_1');

    % Draw fixation screen
    Screen('DrawTexture', expWin, fixScreen);
    Screen('Flip', expWin);

    fixSuccess = false;
    trialStart = GetSecs;

    while (GetSecs - trialStart)*1000 < fix.timeout && Eyelink('IsConnected')
        samp = Eyelink('NewestFloatSample');
        
        % skip if no valid sample
        if isempty(samp), WaitSecs(0.005); continue; end
        if samp.gx(eye) == el.MISSING_DATA || samp.gy(eye) == el.MISSING_DATA
            WaitSecs(0.005); continue;
        end

        % check if gaze is within fixation radius
        inFix = sqrt((samp.gx(eye)-ctrX)^2 + (samp.gy(eye)-ctrY)^2) < fix.radius;

        if inFix
            fixStart = GetSecs;
            % hold fixation loop
            while Eyelink('IsConnected')
                samp = Eyelink('NewestFloatSample');
                if isempty(samp), break; end
                x = samp.gx(eye); y = samp.gy(eye);
                inFix = sqrt((x-ctrX)^2 + (y-ctrY)^2) < fix.radius;

                % check keys
                [keyIsDown,~,keyCode] = KbCheck(-1);
                if keyIsDown
                    if keyCode(KbName('m'))
                        sca; Eyelink('Shutdown'); error('Experiment aborted');
                    elseif keyCode(KbName('c'))  % manual drift correction
                        Eyelink('StopRecording');
                        WaitSecs(0.5);
                        EyelinkDoDriftCorrection(el);
                        Eyelink('StartRecording');
                        Screen('DrawTexture', expWin, fixScreen);
                        Screen('Flip', expWin);
                        WaitSecs(0.01);
                        break; % restart fixation check
                    end
                end

                % fixation held long enough
                if inFix && (GetSecs - fixStart)*1000 >= fix.reqDur
                    fixSuccess = true;
                    break;
                end

                % small pause to reduce CPU load
                WaitSecs(0.005);

                if ~inFix
                    break; % lost fixation before meeting reqDur
                end
            end
        end

        if fixSuccess
            break;
        end

        WaitSecs(0.005); % small pause in outer loop
    end

    if fixSuccess
        fix.finished = 1;
    else
        % timeout: recalibrate
        Eyelink('StopRecording');
        WaitSecs(0.5);
        EyelinkDoDriftCorrection(el);
        Eyelink('StartRecording');
        Screen('DrawTexture', expWin, fixScreen);
        Screen('Flip', expWin);
        WaitSecs(0.01);
    end
end

end
