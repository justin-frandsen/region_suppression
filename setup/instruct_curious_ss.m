function [] = instruct_curious_ss(sub_num, run_num, expWin, scrID, rect, col)

[scrW, scrH] = RectSize(rect);
ctrX = scrW/2;
ctrY = scrH/2;
           
          
bufimg =  Screen('OpenOffscreenWindow', scrID, col.bg, rect);
          Screen('TextFont', bufimg, 'Arial');
          Screen('TextSize', bufimg, 56);
          
bufimg2 = Screen('OpenOffscreenWindow', scrID, col.bg, rect);
          Screen('TextFont', bufimg2, 'Arial');
          Screen('TextSize', bufimg2, 56);
          
iWin =    Screen('OpenOffscreenWindow',scrID, col.bg,rect);
          Screen('TextFont',iWin, 'Arial');
          Screen('TextSize',iWin, 56);


%% FIXATION

imagename = sprintf('stimuli/instruction_images/Instructions_Practice_Fixation');

simg = imread(imagename, 'png');
Screen('PutImage', bufimg, simg, rect);
Screen('DrawTexture', expWin, bufimg);
Screen('Flip', expWin);

WaitSecs(2);
while 1
    [keyIsDown, ~, keyCode] = KbCheck(-1);
    if keyIsDown && keyCode(KbName('N')) 
        break;
    end
end

% Task Instructions
imagename = sprintf('stimuli/instruction_images/instruct_red_singleton');

simg = imread(imagename, 'png');
Screen('PutImage', bufimg, simg, rect);
Screen('DrawTexture', expWin, bufimg);
Screen('Flip', expWin);

WaitSecs(1);
while 1
    [keyIsDown, ~, keyCode] = KbCheck(-1);
    if keyIsDown && keyCode(KbName('N')) 
        break;
    end
end

% Singleton Types
imagename = sprintf('stimuli/instruction_images/instruct_singleton_types');

simg = imread(imagename, 'png');
Screen('PutImage', bufimg, simg, [0 0 scrW scrH]);
Screen('DrawTexture', expWin, bufimg);
Screen('Flip', expWin);

WaitSecs(1);
while 1
    [keyIsDown, ~, keyCode] = KbCheck(-1);
    if keyIsDown && keyCode(KbName('N')) 
        break;
    end
end

 %% SPEED AND ACCURACY %%
Screen('FillRect', bufimg, col.bg, rect)
DrawFormattedText(bufimg, 'SPEED AND ACCURACY', 'center', 150, [200 200 200]);
txt = ['Try to respond as quickly and accurately as possible.'...
    ' If you make an error, a low beep will sound.'...
    ' If you are making too many errors, slow down'...
    ' to improve your performance.\n\n'];
txt = WrapString(txt,70);
DrawFormattedText(bufimg, txt, 'center', 250, col.fg);

txt =  [' There will several breaks in this experiment.  During these breaks,'...
    ' the computer will give you feedback about your performance. Try to have fun'...
    ' and improve your performance as the experiment progresses.'];

txt = WrapString(txt,70);
DrawFormattedText(bufimg, txt, 'center', 450, col.fg);

Screen('DrawTexture', expWin, bufimg);
Screen('Flip', expWin);

WaitSecs(1);
while 1
    [keyIsDown, ~, keyCode] = KbCheck(-1);
    if keyIsDown && keyCode(KbName('N')) 
        break;
    end
end

%% close offscreen windows
Screen('close', bufimg);
end