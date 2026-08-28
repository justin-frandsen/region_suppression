function [w, wRect, screenNumber]=pfp_ptb_init

%this is a workaround for an error I get sometimes. I believe that this
%error can cause mistakes in timing, so it is important to fix before full
%experiment setup.
Screen('Preference', 'SkipSyncTests', 1);

%Do various initializations, pop up a window. Returns window pointer and rectangle
% For now, default to medium gray as background colour.
grayval = 127;

% check for OpenGL compatibility, abort otherwise:
AssertOpenGL;

% Make sure keyboard mapping is the same on all supported operating systems
% Apple MacOS/X, MS-Windows and GNU/Linux:
KbName('UnifyKeyNames');

% Get screenNumber of stimulation display. We choose the display with
% the maximum index, which is usually the right one, e.g., the external
% display on a Laptop:
screens=Screen('Screens');
screenNumber=max(screens);

% Inform user of current resolution and give them the opportunity to bail out
cur_res=Screen('Resolution',screenNumber);
button=questdlg(['Current resolution is ' int2str(cur_res.width) ' x ' int2str(cur_res.height) '. Press OK to continue, Quit to bail out and change resolution.'],'','OK','Quit','OK');
if isempty(button) || strcmp(button,'Quit')
    error('User quit');
end

%Hide the mouse cursor:
HideCursor;

% Returns as default the mean gray value of screen:
grayval=GrayIndex(screenNumber,grayval/255); 

% Open a double buffered fullscreen window on the stimulation screen
% 'screenNumber' and choose/draw a gray background. 'w' is the handle
% used to direct all drawing commands to that window - the "Name" of
% the window. 'wRect' is a rectangle defining the size of the window.
% See "help PsychRects" for help on such rectangles and useful helper
% functions:
[w, wRect]=Screen('OpenWindow', screenNumber, grayval);

% Set text size (Most Screen functions must be called after
% opening an onscreen window, as they only take window handles 'w' as
% input:
Screen('TextSize', w, 32);

%don't echo keypresses to Matlab window
ListenChar(2);

% Do dummy calls to GetSecs, WaitSecs, KbCheck to make sure
% they are loaded and ready when we need them - without delays
% in the wrong moment:
KbCheck;
WaitSecs(0.1);
GetSecs;

% Set priority for script execution to realtime priority:
priorityLevel=MaxPriority(w);
Priority(priorityLevel);
