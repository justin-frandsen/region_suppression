function pfp_ptb_cleanup

disp('Doing cleanup...');
Screen('CloseAll');
IOPort('CloseAll');
ShowCursor;
fclose('all');
Priority(0);
ListenChar(0);

sca;