%######################################################################## 
% Works for both GripForce device and the Trainer. S/N of the DYN devices needs to
% be recorded bc we have multiple devices.
% Originally developed by JCX, Oct 25, 2021
% Modified and Tested by JCX, April 2022, on Win10+ Matlab R2019b+ PTB
% 3.0.16 + Updated VPIxx
% This version includes a part of eyetracking using TRACKpixx3. 
% If necessary, calibration should be done seperately before running the code. 
%########################################################################
commandwindow
clear all;
close all;
clc;
AssertOpenGL;
%Screen('Preference', 'SkipSyncTests', 1);
%%%%%%%%%%%%


%========= set up the dialog box===============%

OrigScreenLevel = Screen('Preference','Verbosity'   ,1);  % Don't log the GL stuff

JoystickId=0;    % ID#  for the grip force connected to the USB port
prompt = {'Enter subject number:', 'Enter session number:','Enter run number:', 'Enter Frequency:', 'Calibrate?','EyeTracker?','MVC','taskType(A1,V2)','useVPIxx','MR compatible DYN?','DYN S/N'}; 
defaults = {'', '','', '1000','0','1','','','1','1',''}; %you can put in default responses 
answer = inputdlg(prompt, 'Exp Config',1.2,defaults); %opens dialog defined the height of each edit field only (1.2) matlab
SUBJECT = answer{1}; %Gets Subject ID#
Session = answer{2}; %Gets Session#  







Run = str2num(answer{3}); %Gets Run#
Frequency = answer{4}; %Gets Frequency
Calibrate = str2num(answer{5}); %If Calibration needs to be done or not?
eyetrack = str2num(answer{6}); %If eye tracking data will be recorded or not?
EyeTrack_StartTime=-999.0; % this is the default Eyetrack start time , -999 (in the log file)  means no eye tracking
EyeTrack_FinishTime=-999.0;
mvc=str2num(answer{7}); % Individual's maximum volume contraction (MVC) for that particular session
taskType = str2num(answer{8}); % 1 = Auditory (default task), 2 = Visual
useDatapixx = str2num(answer{9}); % Are we using VPIxx/datapixx? 0 or 1 (default)
MrCompatible_Dyn=answer{10};
dyn_sn=answer{11}; % S/N of the DYN . 

if ((str2num(MrCompatible_Dyn)==0) && (str2num(dyn_sn)~=4115263)) || ((str2num(MrCompatible_Dyn)==1) && ((str2num(dyn_sn)~=4115258) && (str2num(dyn_sn)~=4113735)))
    warning('S/N and MR compatiblity of DYN do NOT match! Pls check your input!');
    Screen('CloseAll');
    return;
end;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%!!! The following parameters are setup based on extensive tests  for the success of the experiment!!! 
%%!!! If the Grip baseline is out of the ranges, DO NOT change the
%%parameters. Check the Hardware Instead!!! THX
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if (str2num(MrCompatible_Dyn)==0) 
    gripBaseLThr=40000;
    gripBaseUThr=66000;
else
    gripBaseLThr=40000;  % FORP
    gripBaseUThr=60000;
end; 

if taskType == 1
    baseNameString = '_Aoddball_'; 
elseif taskType == 2
    baseNameString = '_Voddball_'; 
end
% if ~useDatapixx; Screen ('Preference', 'SkipSyncTests', 1); end % Skips sync tests unless we're doing real data collection
Screen('Preference', 'SkipSyncTests', 1)
currentrun= Run;

%========= setup file for saving ===============%

c = clock; %Current date and time.
baseName=['subject' SUBJECT baseNameString 'session' Session '_run' num2str(currentrun) '_' num2str(c(2)) '_' num2str(c(3)) '_' num2str(c(4)) '_' num2str(c(5))]; %makes unique filename Aoddball; audio oddball
therand=GetSecs; % PTB-3
rng(therand,'twister');

fname1= sprintf('%s_logP.txt',baseName);
gripforce_fname= sprintf('%s_gripforce.csv',baseName);
eyetrack_fname = sprintf('%s_eyetrack.mat',baseName);

fid1 = fopen(fname1,'a'); %Open log file 

try
%========= set up the windows display===========%
% We are assuming that the DATAPixx is connected to the highest number screen.
% If it isn't, then assign screenNumber explicitly here.
screens=Screen('Screens');
screenNumber=max(screens);
gray= [127 127 127] ; 
orange=[255 128 0]; % orange color 
[window, windowRect]=Screen('OpenWindow',screenNumber,gray); 
% Get the size of the on screen window
[screenXpixels, screenYpixels] = Screen('WindowSize', window);
FlipInt=Screen('GetFlipInterval',window); %Gets Flip Interval 
% HideCursor(); % commented off for debugging
KbName('UnifyKeyNames'); %used for cross-platform compatibility of keynaming
Screen('TextSize',window, 50);
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);

%Define Dynamometer display
FillColor_OR=[128 0 0]; 
FillColor=[50 205 50];
FillColor_BT=[225 225 0];
FrameColor=[0 0 0];  % black
rectColor=[127 127 127]; % gray color
recordvpxx=1;% record vpixx time
showbkg1=0; 
showbkg2=0; 
FrameColor_Rlx=[0 204 255];     
FrameColor_Sqz=[255 160 122]; % salmon color
% done for the windows display set up

[center(1), center(2)] = RectCenter(windowRect);
numreps=1; % # of reps
TR=1.75; % TR value=1.75s
mon_width= 21;   
v_dist=31.5;   
fix_r=.2; 
ppd = pi * windowRect(3) / atan(mon_width/v_dist/2) / 360;    
fix_cord = [center-fix_r*ppd center+fix_r*ppd];
noIfi=5; 

% preparing the Gauge display parameters 
scrXctr=screenXpixels/2; % screen X center
scrYctr=screenYpixels/2; % screen Y center
baseRect=[0 0 scrXctr/8 scrYctr/2]; 
centeredRect=CenterRectOnPointd(baseRect, scrXctr, scrYctr); 
frame_thickness=10; 

% grip force params
lo_gf_per=0.05;
hi_gf_per=0.40;
grip_duration=3; % grip duration=3s
blank_duration=0.25; % a blank screen for 250ms
fix_duration=0.50; % 500ms for the fixation
RelaxTR=0; 
GripRelaxTime=RelaxTR*TR+0.25; % 250ms

% Response params: RESP1: Oddball?  RESP2: Confidence Rate
Resp1_Duration=3;  
Resp2_Duration=3; 
gridX=1:screenXpixels/20:screenXpixels; 
gridY=1:screenYpixels/20:screenYpixels; 
[scrXgrid scrYgrid]=meshgrid(gridX,gridY); 

darkcolor=[0 0 0]; % dark color for the confidence rate
CRColor(1,:)=[255 0 0];   % red
CRColor(2,:)=[50 205 50]; % green
CRColor(3,:)=[1 128 181]; % blue
CRColor(4,:)=[225 226 0]; % yellow

CRHead = 'Confidence'; 
CRLabel1 = '1';
CRLabel2 = '2';
CRLabel3 = '3';
CRLabel4 = '4';
CRFoot1='Low';
CRFoot2='High';

hdg_bsln_y=scrYgrid(2,1)+10;  
btnCtr1=[scrXgrid(3,8),scrYgrid(3,8)]; 
btnCtr2=[scrXgrid(3,10),scrYgrid(3,10)];
btnCtr3=[scrXgrid(3,12),scrYgrid(3,12)];
btnCtr4=[scrXgrid(3,14),scrYgrid(3,14)];
btnR=30; 
btnLoc1=[btnCtr1-btnR   btnCtr1+btnR];  
btnLoc2=[btnCtr2-btnR   btnCtr2+btnR];
btnLoc3=[btnCtr3-btnR   btnCtr3+btnR];
btnLoc4=[btnCtr4-btnR   btnCtr4+btnR];

ynImgLoc='.\images\yes-no-oddball-transparentBG.png';
crImgLoc='.\images\confidence-transparentBG.png';
[ynImg ynMap ynTransparency]=imread(ynImgLoc);
[crImg crMap crTransparency]=imread(crImgLoc);
ynImgTex=Screen('MakeTexture',window,ynImg);
crImgTex=Screen('MakeTexture',window,crImg);

[s1_yn,s2_yn,s3_yn]=size(ynImg);
[s1_cr,s2_cr,s3_cr]=size(crImg);
aspectRatio_yn=round(s2_yn / s1_yn);
aspectRatio_cr=round(s2_cr / s1_cr);

imgHts_yn=190;
imgHts_cr=190;
imgWdt_yn=imgHts_yn * aspectRatio_yn;
imgWdt_cr=imgHts_cr * aspectRatio_cr;

imgRect_yn=[0 0 imgWdt_yn imgHts_yn];
imgRect_cr=[0 0 imgWdt_cr imgHts_cr];

dstRect_yn=CenterRectOnPointd(imgRect_yn,scrXgrid(3,18),scrYgrid(3,18));
dstRect_cr=CenterRectOnPointd(imgRect_cr,scrXgrid(3,18),scrYgrid(3,18));

%========= PARAMS FOR VIS AND AUDITORY TASKS =============%

%for both visual and audio
ISI = [.5];
numsegs=[2]; %# of audio segments, always a standard seg 1st and then another seg of standard or oddball
numTrialReps=3; % # of repetition of each type of trials
% no feedback
feedback=0;  %if then feedback;

%======= AUDIO PARAMS=========%

fs = 44100; %audio sampling rate
D = [.1]; %base durations
rDur=.01; 
F = str2num(Frequency); 
A = .18*5; %base amplitudes

%calculates ramps
rampU= 0:1/(fs*rDur):1; %ramp up
rampD= 1:-1/(fs*rDur):0; %ramp down

TheSnd{1}=[];%sets sound matrix
d=D(1); %sets duration
f=F; %set frequency
t = 0:(1/fs):d(1); %time vector
SS=ones(1,length(t)-length([rampU rampD]));
y = sin(2*pi*f(1)*t); %sound vector
y=A*y.*[rampU SS rampD]; %modulates sound based upon ramp.
TheSnd{1}=A*[y; y] ; % stereo style

%======= ALL VISUAL PARAMS=========%
gabor_diam=4; 
gaborDimPix = round(gabor_diam * ppd); 
sigma = gaborDimPix / 7; 
contrast = [0.06, 0.12, 0.24, 0.48]; %equivalent to stimLev1 05/27/2022 AYS changed from [0.04, 0.08, 0.16, 0.32]
standardContrast = 0.2;  
orientation = 0;
aspectRatio = 1.0;
phase = 0;
numCycles = 6; 
freq = numCycles / gaborDimPix;
backgroundOffset = [.5 .5 .5 0];
disableNorm = 1; %normalization of the total amplitude of the gabor. set to default
preContrastMultiplier = 1;
gabortex = CreateProceduralGabor(window, gaborDimPix, gaborDimPix, [],...
    backgroundOffset, disableNorm, preContrastMultiplier);
gaborDur = .1;

%============SETUP TRIAL MATRICES===============%

% the generation of trial parameters
% sound design matrix
if taskType == 1
    StimLev1 = [8 16 32 64]; %if audiotry stimuli session 05/27/2022 AYS changed from [4 8 32 128]
elseif taskType == 2
    StimLev1 = contrast; %stimLev for the visual stimuli
end

StimLev=[zeros(1,numTrialReps*2) repmat(StimLev1,1,numTrialReps*2)];
TRmat=fullfact([length(StimLev) numreps]);

TRlist=repmat([ 1 1 2 2 3]', ceil(length(TRmat)/5),1); %generates list
TRmat(:,2)=TRlist(randperm(length(TRmat))); %scrambles and assigns to the 2 column.

foo=find(TRmat(:,1)<=(numTrialReps*2)); 
TRmat(foo,3)= 2;  % 3rd column: 2 non oddball; 1 oddball
TRmat(find(~TRmat(:,3)),3)= 1;

%set up the indices of hi(=1) or lo (=0) strengths for column 4
TRmat(:,4)=[zeros(1,numTrialReps) zeros(1,numTrialReps)+1 repmat([zeros(1,length(StimLev1)) zeros(1,length(StimLev1))+1],1,numTrialReps)];

therand=GetSecs; % PTB-3
rng(therand,'twister');
mixtr=TRmat(randperm(length(TRmat)),:);


foo=mixtr(1,2);
foo2=find(mixtr(:,2)==1);
mixtr(1,2)=1;
mixtr(foo2(6),2)=foo;


isoddball=zeros(1,length(mixtr));
TrialBaseline=zeros(1,length(mixtr));
isStrengthHi=zeros(1, length(mixtr));
ButtonResponse=zeros(1,length(mixtr))-1;
ButtonRT=zeros(1,length(mixtr))-1; % RT for RESP1
%Confidence Rate
ConfidenceRate=zeros(1,length(mixtr))-1;
% RESP2 RT
ButtonRT2=zeros(1,length(mixtr))-1;

%=====PRE-GENERATE SOUND AND VISUAL STIMULI=====%

% start to make Sound File and GF(GripForce)_HiLo for each trial
for trial=1:length(mixtr) %runs through trials
    
    NumStim=numsegs(randi(1));
     
    if mixtr(trial,3)==1  
        theT=2;
        TheOffset=StimLev(mixtr(trial,1)); 
        isoddball(trial)=1; % added for visual
    else
        theT=6; % non oddball
        TheOffset=0;
        isoddball(trial)=0; %added for visual
    end


    switch taskType
        case 1 % auditory
            TheSnd{2}=[];
                       
            %calculates target sounds
            if TheOffset
                f=F+TheOffset;
            else
                f=F;
            end
            y = sin(2*pi*f(1)*t); %sound vector
            y=A*y.*[rampU SS rampD]; %modulates sound based upon ramp.
            TheSnd{2}=A*[y; y] ;


            %makes sounds...in single sequence
            TrialSND=[]; % Trial Sound init
            for stim = 1:NumStim
                if (stim==theT)  % oddball 
                    istarg=1;

                else
                    istarg=0;
                end
                TrialSND=[TrialSND TheSnd{istarg+1}];
                if (stim<NumStim) 
                    TrialSND=[TrialSND zeros(2,ISI*fs)];
                end
            end

            TrialSND1{trial}=TrialSND;
            trial_offset(trial)=TheOffset;
        case 2
            trial_offset(trial) = TheOffset;
    end % switch
    
    theThist(trial)=theT; 
    trial_theT(trial)=theT;
    % end of making sound for each trial, the T =2 oddball, 6 non oddball
    % making the Grip force HiLo  hi(=1) or lo (=0)
    if mixtr(trial,4)==1  % Hi Grip Force
        gf_trPer(trial)=hi_gf_per; % grip force trial percentage Hi
        isStrengthHi(trial)=1;
    else
        gf_trPer(trial)=lo_gf_per; % grip force trial percentage Lo
        isStrengthHi(trial)=0;
    end
  
end % trial
 % end of making sound  and GF(GripForce)_HiLo for each trial 

%===PREPARE DATAPIXX OR AUDIOPORT TO PRESENT===%
%================== SOUND =====================%

% set up playing sounds or using datapixx for timestamps
if useDatapixx
    Datapixx('Open');
    audioGrpDelay=Datapixx('GetAudioGroupDelay',fs); 
    audioDelay=FlipInt-audioGrpDelay; 
    Datapixx('StopAllSchedules');
    Datapixx('InitAudio');
    Datapixx('SetAudioVolume', [1,1]);
    Datapixx('SetDinLog');
    Datapixx('StartDinLog');
    Datapixx('EnableDinDebounce');
    Datapixx('RegWrRd');
else
    % Use internal speakers n stuff
    InitializePsychSound(1); %initializes sound driver (must call before PsychPortAudio)
    pahandle = PsychPortAudio('Open', [], 1, 2, fs, 2); %, 0);% opens sound buffer. fs= frequency, 2 channel
end

if useDatapixx && eyetrack  %do tracking with TRACKPixx3
        if Calibrate
            %CalibrateTracker; %obsolete
            TPxTrackpixx3CalibrationTesting;
            Calibrate=0;
        end
        %% TO START EYE TRACKING DATA:
        dpx_isReady = Datapixx('IsReady');
        if useDatapixx && (~dpx_isReady) 
             Datapixx('Open');
             audioGrpDelay=Datapixx('GetAudioGroupDelay',fs); 
             audioDelay=FlipInt-audioGrpDelay; 
             Datapixx('StopAllSchedules');
             Datapixx('InitAudio');
             Datapixx('SetAudioVolume', [1,1]);
             Datapixx('SetDinLog');
             Datapixx('StartDinLog');
             Datapixx('EnableDinDebounce');
             Datapixx('RegWrRd');
             Screen('Preference', 'SkipSyncTests', 1); 
        end;
         
        Datapixx('SetupTPxSchedule');
        Datapixx('RegWrRd');
        Datapixx('StartTPxSchedule');
        Datapixx('RegWrRdVideoSync'); % put VideoSync here, so that the eye tracking sync with the flipping
        EyeTrack_StartTime=Datapixx('GetTime');
end % if useDatapixx && eyetrackys

TheTargs=[3 1]; % RESP1 targs Green(=3) Red(=1)
TheTargs_CR=[1 3 4 2]; % red=CR 1; green=CR 2; Blue=CR 3; Yellow=CR 4  confidence rate.
TheTrigger=11;

% DYN Init
AllMeasure_Dummy=[];
[JoyX JoyY]=WinJoystickMex(JoystickId);
for i=1: 200
    [JoyX JoyY]=WinJoystickMex(JoystickId);
    AllMeasure_Dummy(i) = JoyY;
    WaitSecs(0.02);
end
grip_baseline=median(AllMeasure_Dummy(101:end));
if (grip_baseline < gripBaseLThr) || (grip_baseline > gripBaseUThr)  
    warning('Grip baseline was NOT correctly detected!');
    Screen('CloseAll');
    return;
end;
%===============BEGIN THE RUN==================%
%==============================================% 

DrawFormattedText(window,sprintf('Run %d is starting, please hold the dynamometer & get ready',currentrun),'center','center',0);
Screen('Flip',window); %draws response screen

if useDatapixx
    [Bpress timestamp1]=WaitForEvent_Jerry(500, TheTrigger); % waits for trigger
    Datapixx('SetMarker');
    Datapixx('RegWrVideoSync'); % time sync
    ExpStartTimeP=Screen('Flip',window); %PTB-3 
    Datapixx('RegWrRd');
    ExpStartTimeD=Datapixx('GetMarker');
else
    KbWait;
    ExpStartTimeP=Screen('Flip',window);
end


TRcount=0;
% fid1 is the log file 
fprintf(fid1,'%%SUBJECT: %d. \tRUN: %d.\t TemporalOriginP:%12.6f\t EyeTrackTemporalOrigin:%12.6f\t TemporalOriginD:%12.6f\n\n%%TASKTYPE: %s \tMVC: %8.3f\t AU\t MRICompatible_DYN: %d\t DYN_S/N: %s\t GripBaseln: %8.3f\n\n',str2num(SUBJECT),currentrun,ExpStartTimeP,EyeTrack_StartTime,ExpStartTimeD,baseNameString,mvc,str2num(MrCompatible_Dyn),dyn_sn,grip_baseline); 

switch taskType
         case 1 % auditory
           fprintf(fid1,'%s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\n','Trial#','Oddball?','Hi Grip?','TrialST','blankST','fixST','A/V_ST','A/V_CT','relaxST','Resp1ST','Resp2ST','EoT','BPressed?','BResp(r1g3)','isCorrect?','Freq_Offset','Trial_RT','BPressed2(CR)?','CR','CR_RT','TrialinTRsD/P','TrialSTD/P','fixOFSTP','Resp1ET','Resp2ET'); % removed 5 variables /columns
         case 2 % visual
           fprintf(fid1,'%s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\t %s\n','Trial#','Oddball?','Hi Grip?','TrialST','blankST','fixST','A/V_ST','A/V_CT','relaxST','Resp1ST','Resp2ST','EoT','BPressed?','BResp(r1g3)','isCorrect?','Freq_Offset','Trial_RT','BPressed2(CR)?','CR','CR_RT','TrialinTRsD/P','TrialSTD/P','fixOFSTP','Resp1ET','Resp2ET','G1_OFST','G2_ONST','G2_OFST'); %removed 6 variables
end; % switch


for trial=1:length(mixtr) %runs through trials
    TrialStart = getTime(useDatapixx);
    TRpass=floor((TrialStart-ExpStartTimeD)/TR); 
    TRcount=TRcount+mixtr(trial,2)-1;
    while TRpass<TRcount
        if useDatapixx
            WaitForEvent_Jerry(3, TheTrigger); % TR=1.75 
        else
            WaitSecs(TR);
        end
        CurrentTime = getTime(useDatapixx);
        TRpass=round((CurrentTime-ExpStartTimeD)/TR);
    end
    
    stimulusStartTime(trial)=getTime(useDatapixx);%  this is the actual trial start time after the Jittering
    
    %         % screen flip the display the HiLo here for ~3s then switch to blank
    %         % screen (white) for ~250ms , then flip to fixation for 500ms ,
    %         % plus (play sound) for 700ms, if done then switch to "relax" screen for GripRelaxTime , then RESP 1, after that RESP2 (CR)
       
    % For Grip Strength
    % Overt Handgrip
    AllMeasure1=[];
    TimeStmp1=[];
    TimeStmpVpx1=[];
    % TrialBaseline1=0;
    % Blank 
    AllMeasure2=[];
    TimeStmp2=[];
    TimeStmpVpx2=[];
    TrialBaseline2=0;
    % Fixation
    AllMeasure3=[];
    TimeStmp3=[];
    TimeStmpVpx3=[];
    TrialBaseline3=0;
    % Stim  
    AllMeasure4=[];
    TimeStmp4=[];
    TimeStmpVpx4=[];
    TrialBaseline4=0;
    % Relax. 
    AllMeasure5=[];
    TimeStmp5=[];
    TimeStmpVpx5=[];
    TrialBaseline5=0;
    
    %G1
    AllMeasure6=[];
    TimeStmp6=[];
    TimeStmpVpx6=[];
    TrialBaseline6=0;
    
    %G2
    AllMeasure7=[];
    TimeStmp7=[];
    TimeStmpVpx7=[];
    TrialBaseline7=0;
    
    if useDatapixx 
        [AllMeasure1 TimeStmp1 TimeStmpVpx1 TrialBaseline(trial) stimulusStartTimeP(trial) stimulusStartTimeD(trial)] = HandgripDisplayCurrentDesign_windows9(window,gf_trPer(trial),mvc,grip_duration-noIfi*FlipInt,rectColor,FrameColor,FillColor,black,centeredRect,scrXctr,scrYctr,1,JoystickId,recordvpxx,showbkg1,grip_baseline,FlipInt,FillColor_BT,FillColor_OR,windowRect,FrameColor_Sqz);
    else
        [AllMeasure1 TimeStmp1 TimeStmpVpx1 TrialBaseline(trial) stimulusStartTimeP(trial) stimulusStartTimeD(trial)] = fakeHandgrip_v2(grip_duration-noIfi*FlipInt);
    end
    
    switch taskType
        case 1 % auditory
            if useDatapixx
                % write the audio buffer, preparing the audio stim play
                Datapixx('WriteAudioBuffer',TrialSND1{trial},0);
                Datapixx('SetAudioSchedule',0,fs,length(TrialSND1{trial}),3,0,length(TrialSND1{trial}) ); 
                Datapixx('RegWrRd'); %push these onto the hardware
            else    
                PsychPortAudio('FillBuffer', pahandle,TrialSND1{trial}); % loads data into buffer
            end
        case 2 % visual
           
    end
    
    Screen('FrameRect',window, FrameColor_Sqz, windowRect,frame_thickness);
    blankStartTimeP(trial)=Screen('Flip',window,stimulusStartTimeP(trial)+ grip_duration -0.5*FlipInt); 
    if useDatapixx
        [AllMeasure2 TimeStmp2 TimeStmpVpx2 TrialBaseline2 blankStartTimeP1(trial) blankStartTimeD1(trial)] = HandgripDisplayCurrentDesign_windows9(window,gf_trPer(trial),mvc,blank_duration-noIfi*FlipInt,rectColor,FrameColor,FillColor,black,centeredRect,scrXctr,scrYctr,0,JoystickId,recordvpxx,showbkg2,TrialBaseline(trial),FlipInt,FillColor_BT,FillColor_OR,windowRect,FrameColor_Sqz);
    else
        [AllMeasure2 TimeStmp2 TimeStmpVpx2 TrialBaseline2 blankStartTimeP1(trial) blankStartTimeD1(trial)] = fakeHandgrip_v2(blank_duration-noIfi*FlipInt);
    end
    
    Screen('FillOval', window, FrameColor_Sqz, fix_cord); % draw fixation dot
    fixStartTimeP(trial)=Screen('Flip',window,blankStartTimeP(trial)+ blank_duration -0.5*FlipInt,1);
    
    if useDatapixx
        [AllMeasure3 TimeStmp3 TimeStmpVpx3 TrialBaseline3 fixStartTimeP1(trial) fixStartTimeD1(trial)] = HandgripDisplayCurrentDesign_windows9(window,gf_trPer(trial),mvc,fix_duration-noIfi*FlipInt,rectColor,FrameColor,FillColor,black,centeredRect,scrXctr,scrYctr,0,JoystickId,recordvpxx,showbkg2,TrialBaseline(trial),FlipInt,FillColor_BT,FillColor_OR,windowRect,FrameColor_Sqz);
    else
        [AllMeasure3 TimeStmp3 TimeStmpVpx3 TrialBaseline3 fixStartTimeP1(trial) fixStartTimeD1(trial)] = fakeHandgrip_v2(fix_duration-noIfi*FlipInt);
    end
       
  
    fixOffsetP(trial)=Screen('Flip',window,fixStartTimeP(trial)+fix_duration-0.5*FlipInt); 
    switch taskType
        case 1 % auditory
            if useDatapixx 
                Datapixx('SetMarker'); 
                Datapixx('StartAudioSchedule');
                Datapixx('RegWrVideoSync'); 
                Screen('FillOval', window, FrameColor_Sqz, fix_cord); 
                Screen('FrameRect',window, FrameColor_Sqz, windowRect,frame_thickness);
                SoundStartTimeP(trial)=Screen('Flip', window,0,1); 
                Datapixx('RegWrRd'); 
                SoundStartTimeD(trial) = Datapixx('GetMarker');
            else
                PsychPortAudio('Start', pahandle,1,0,1); %starts sound
            end

             if useDatapixx
                [AllMeasure4 TimeStmp4 TimeStmpVpx4 TrialBaseline4 SoundStartTimeP1(trial) SoundStartTimeD1(trial)] = HandgripDisplayCurrentDesign_windows9(window,gf_trPer(trial),mvc,0.7-noIfi*FlipInt,rectColor,FrameColor,FillColor,black,centeredRect,scrXctr,scrYctr,0,JoystickId,recordvpxx,showbkg2,TrialBaseline(trial),FlipInt,FillColor_BT,FillColor_OR,windowRect,FrameColor_Sqz);
             else
                [AllMeasure4 TimeStmp4 TimeStmpVpx4 TrialBaseline4 SoundStartTimeP1(trial) SoundStartTimeD1(trial)] = fakeHandgrip_v2(0.7-noIfi*FlipInt);
             end;
            
             if useDatapixx
                 while 1
                     Datapixx('RegWrRd');   % Update registers for GetAudioStatus
                     status = Datapixx('GetAudioStatus');
                     if ~status.scheduleRunning
                         break;
                     end
                 end
                 audiocompleteTimeD(trial)=getTime(useDatapixx);
                 audiocompleteTimeP(trial)=Screen('Flip',window);
             else
                 audiocompleteTimeD(trial)=getTime(useDatapixx);
                 audiocompleteTimeP(trial)=Screen('Flip',window,SoundStartTimeP+0.7-0.5*FlipInt);
                 PsychPortAudio('Stop', pahandle);% Stop sound playback if you haven't already
             end
             
                         
        case 2 % visual
            Screen('FrameRect',window, FrameColor_Sqz, windowRect,frame_thickness);
            Screen('DrawTexture', window, gabortex, [], [], orientation, [], [],...
                  [], [], 0, [phase+180, freq, sigma,...
                  standardContrast, aspectRatio, 0, 0, 0]); 
            SoundStartTimeP(trial)=Screen('Flip',window,0,1); 
            SoundStartTimeD(trial) = getTime(useDatapixx);
            if useDatapixx
                [AllMeasure6 TimeStmp6 TimeStmpVpx6 TrialBaseline6 SoundStartTimeP1(trial) SoundStartTimeD1(trial)] = HandgripDisplayCurrentDesign_windows9(window,gf_trPer(trial),mvc,gaborDur-noIfi*FlipInt,rectColor,FrameColor,FillColor,black,centeredRect,scrXctr,scrYctr,0,JoystickId,recordvpxx,showbkg2,TrialBaseline(trial),FlipInt,FillColor_BT,FillColor_OR,windowRect,FrameColor_Sqz);
            else
                [AllMeasure6 TimeStmp6 TimeStmpVpx6 TrialBaseline6 SoundStartTimeP1(trial) SoundStartTimeD1(trial)] = fakeHandgrip_v2(gaborDur-noIfi*FlipInt); 
            end;
            
            Screen('FrameRect',window, FrameColor_Sqz, windowRect,frame_thickness);
            g1_OffsetTimeP(trial)=Screen('Flip',window,SoundStartTimeP(trial)+gaborDur-0.5*FlipInt,0); 

            if useDatapixx
                [AllMeasure4 TimeStmp4 TimeStmpVpx4 TrialBaseline4 g1_OffsetTimeP1(trial) g1_OffsetTimeD1(trial)] = HandgripDisplayCurrentDesign_windows9(window,gf_trPer(trial),mvc,ISI-noIfi*FlipInt,rectColor,FrameColor,FillColor,black,centeredRect,scrXctr,scrYctr,0,JoystickId,recordvpxx,showbkg2,TrialBaseline(trial),FlipInt,FillColor_BT,FillColor_OR,windowRect,FrameColor_Sqz);
             else
                [AllMeasure4 TimeStmp4 TimeStmpVpx4 TrialBaseline4 g1_OffsetTimeP1(trial) g1_OffsetTimeD1(trial)] = fakeHandgrip_v2(ISI-noIfi*FlipInt); % reduced the ISI so that the entire V Stim pair is ~700ms  ?
             end;
            
            Screen('FrameRect',window, FrameColor_Sqz, windowRect,frame_thickness);
            Screen('DrawTexture', window, gabortex, [], [], orientation, [], [],...
                  [], [], 0, [phase+180, freq, sigma,...
                  trial_offset(trial)+standardContrast, aspectRatio, 0, 0, 0]); 
            g2_OnsetTimeP(trial)=Screen('Flip',window,SoundStartTimeP(trial)+gaborDur+ISI-0.5*FlipInt,1);

            if useDatapixx
                [AllMeasure7 TimeStmp7 TimeStmpVpx7 TrialBaseline7 g2_OnsetTimeP1(trial) g2_OnsetTimeD1(trial)] = HandgripDisplayCurrentDesign_windows9(window,gf_trPer(trial),mvc,gaborDur-noIfi*FlipInt,rectColor,FrameColor,FillColor,black,centeredRect,scrXctr,scrYctr,0,JoystickId,recordvpxx,showbkg2,TrialBaseline(trial),FlipInt,FillColor_BT,FillColor_OR,windowRect,FrameColor_Sqz);
            else
                [AllMeasure7 TimeStmp7 TimeStmpVpx7 TrialBaseline7 g2_OnsetTimeP1(trial) g2_OnsetTimeD1(trial)] = fakeHandgrip_v2(gaborDur-noIfi*FlipInt); % reduced the ISI so that the entire V Stim pair is ~700ms  ?
            end;
            
            Screen('FrameRect',window, FrameColor_Sqz, windowRect,frame_thickness); 
            g2_OffsetTimeP(trial)=Screen('Flip',window,SoundStartTimeP(trial)+2*gaborDur+ISI-0.5*FlipInt,0); % offset the 2nd gabor
            audiocompleteTimeD(trial)=getTime(useDatapixx); 
            audiocompleteTimeP(trial)=g2_OffsetTimeP(trial);
    end; % switch
    
   % relax for GripRelaxTime
    Screen('FrameRect',window, FrameColor_Rlx, windowRect,frame_thickness);
    relaxStartTimeP(trial)=Screen('Flip',window); 

    if useDatapixx
        [AllMeasure5 TimeStmp5 TimeStmpVpx5 TrialBaseline5 relaxStartTimeP1(trial) relaxStartTimeD1(trial)] = HandgripDisplayCurrentDesign_windows9(window,gf_trPer(trial),mvc,GripRelaxTime-noIfi*FlipInt,rectColor,FrameColor,FillColor,black,centeredRect,scrXctr,scrYctr,0,JoystickId,recordvpxx,showbkg2,TrialBaseline(trial),FlipInt,FillColor_BT,FillColor_OR,windowRect,FrameColor_Rlx);
    else
        [AllMeasure5 TimeStmp5 TimeStmpVpx5 TrialBaseline5 relaxStartTimeP1(trial) relaxStartTimeD1(trial)] = fakeHandgrip_v2(GripRelaxTime-noIfi*FlipInt);
    end
    
    %record all grip force data to the cvs file
    switch taskType
         case 1 % auditory
            if (trial==1)
                dlmwrite(gripforce_fname,[[AllMeasure1;AllMeasure2;AllMeasure3;AllMeasure4;AllMeasure5]  [TimeStmp1;TimeStmp2;TimeStmp3;TimeStmp4;TimeStmp5]  [TimeStmpVpx1;TimeStmpVpx2;TimeStmpVpx3;TimeStmpVpx4;TimeStmpVpx5] zeros(length([AllMeasure1;AllMeasure2;AllMeasure3;AllMeasure4;AllMeasure5]),1)+trial],'precision', '%.6f');
            else
                dlmwrite(gripforce_fname,[[AllMeasure1;AllMeasure2;AllMeasure3;AllMeasure4;AllMeasure5]  [TimeStmp1;TimeStmp2;TimeStmp3;TimeStmp4;TimeStmp5]  [TimeStmpVpx1;TimeStmpVpx2;TimeStmpVpx3;TimeStmpVpx4;TimeStmpVpx5] zeros(length([AllMeasure1;AllMeasure2;AllMeasure3;AllMeasure4;AllMeasure5]),1)+trial],'-append','precision', '%.6f');
            end;
         case 2 % visual
            if (trial==1)
                dlmwrite(gripforce_fname,[[AllMeasure1;AllMeasure2;AllMeasure3;AllMeasure6;AllMeasure4;AllMeasure7;AllMeasure5]  [TimeStmp1;TimeStmp2;TimeStmp3;TimeStmp6;TimeStmp4;TimeStmp7;TimeStmp5]  [TimeStmpVpx1;TimeStmpVpx2;TimeStmpVpx3;TimeStmpVpx6;TimeStmpVpx4;TimeStmpVpx7;TimeStmpVpx5] zeros(length([AllMeasure1;AllMeasure2;AllMeasure3;AllMeasure6;AllMeasure4;AllMeasure7;AllMeasure5]),1)+trial],'precision', '%.6f');
            else
                dlmwrite(gripforce_fname,[[AllMeasure1;AllMeasure2;AllMeasure3;AllMeasure6;AllMeasure4;AllMeasure7;AllMeasure5]  [TimeStmp1;TimeStmp2;TimeStmp3;TimeStmp6;TimeStmp4;TimeStmp7;TimeStmp5]  [TimeStmpVpx1;TimeStmpVpx2;TimeStmpVpx3;TimeStmpVpx6;TimeStmpVpx4;TimeStmpVpx7;TimeStmpVpx5] zeros(length([AllMeasure1;AllMeasure2;AllMeasure3;AllMeasure6;AllMeasure4;AllMeasure7;AllMeasure5]),1)+trial],'-append','precision', '%.6f');
            end;
    end; % switch
             
    relaxEndTimeP(trial)=Screen('Flip',window,relaxStartTimeP(trial)+GripRelaxTime-0.5*FlipInt);
    % Get to RESP1    
    % preparing for the register of RESPONSEPixx
    if useDatapixx
        Datapixx('SetDinLog');
        Datapixx('StartDinLog');
        Datapixx('RegWrRd'); 
    end
    
    Screen('TextSize',window, 50);
    DrawFormattedText(window,'Different?','center',hdg_bsln_y,0); 
    Screen('FillOval', window, CRColor(1,:), btnLoc2); 
    Screen('FillOval', window, CRColor(2,:), btnLoc3); 
    Screen('TextSize',window, 36);
    DrawFormattedText(window,'Y',scrXgrid(3,10)-20,scrYgrid(3,10)+20,0);
    DrawFormattedText(window,'N',scrXgrid(3,12)-20,scrYgrid(3,12)+20,0);
    Screen('DrawTexture',window,ynImgTex,[], dstRect_yn);
    Screen('FrameRect',window, FrameColor_Rlx, windowRect,frame_thickness); % this is the frame
    Screen('FillOval', window, FrameColor_Rlx, fix_cord); % this is the fixation pnt
    Resp1StartTimeP(trial)=Screen('Flip',window,0,1); 
    Resp1StartTimeD(trial)=getTime(useDatapixx); 
    
    %start to record the response
    
    if useDatapixx
        [Bpressed trial_RT TheButtonIndex bin_buttonpress{trial} inter_buttonpress{trial}] = WaitForEvent_Jerry(Resp1_Duration-2*FlipInt, TheTargs, Resp1StartTimeD(trial));
    else
%        [trial_RT,keyCode] = waitforkey(2,0,[]);
       strt = GetSecs();
       WaitSecs(2);
       trial_RT = GetSecs() - strt;
       if trial_RT<=2; Bpressed = 1; else Bpressed = 0; end
       TheButtonIndex = 1; %update to actually listen to buttons later
    end
    
    if Bpressed && (length(TheButtonIndex)==1)
       
        ButtonRT(trial)= trial_RT;
        ButtonResponse(trial)= TheTargs(TheButtonIndex);
        
        if  TheButtonIndex==2
            RESP1_Color=CRColor(1,:); %RED
        elseif TheButtonIndex==1   
            RESP1_Color=CRColor(2,:); %GREEN
        end;   
        
        if ( ( ( TheButtonIndex==2) && (theThist(trial)==2) ) || ( ( TheButtonIndex==1) && (theThist(trial)==6) ) )
            iscorr(trial)=1; %mark as correct
            FeedbackMessage=('Correct'); %and you give the feedback 'correct'
            
        else
            iscorr(trial)=0;%mark as incorrect
            FeedbackMessage=('Wrong');
            
        end
        
    else
        iscorr(trial)=NaN; %if response = -1 (no response during time window) then recorded as NaN
        FeedbackMessage=('Missed Response'); %and message displayed as a missed response
        RESP1_Color=FrameColor_Rlx; % no change
    end

    Screen('FillOval', window, RESP1_Color, fix_cord);
    Resp1EndTimeP_SBP(trial)=Screen('Flip',window); 
    Resp1EndTimeP(trial)=Screen('Flip',window,Resp1StartTimeP(trial)+Resp1_Duration-0.5*FlipInt);
    Resp1EndTimeD(trial) = getTime(useDatapixx); 
    % Confidence rate Stage
    % preparing for the register of RESPONDPixx
    if useDatapixx
        Datapixx('SetDinLog');
        Datapixx('StartDinLog');
        Datapixx('RegWrRd');
    end
    % CR screen preparing
    Screen('TextSize',window, 50);
    DrawFormattedText(window,CRHead,'center',hdg_bsln_y,black);
    Screen('FillOval', window, CRColor(1,:), btnLoc1); 
    Screen('FillOval', window, CRColor(2,:), btnLoc2); 
    Screen('FillOval', window, CRColor(3,:), btnLoc3); 
    Screen('FillOval', window, CRColor(4,:), btnLoc4);
    Screen('TextSize',window, 36);
    DrawFormattedText(window,CRLabel1,scrXgrid(3,8)-15,scrYgrid(3,8)+20,black);
    DrawFormattedText(window,CRLabel2,scrXgrid(3,10)-15,scrYgrid(3,10)+20,black);
    DrawFormattedText(window,CRLabel3,scrXgrid(3,12)-15,scrYgrid(3,12)+20,black);
    DrawFormattedText(window,CRLabel4,scrXgrid(3,14)-15,scrYgrid(3,14)+20,black);
    DrawFormattedText(window,CRFoot1,scrXgrid(5,8),scrYgrid(5,8),black);
    DrawFormattedText(window,CRFoot2,scrXgrid(5,13),scrYgrid(5,13),black);
    Screen('DrawTexture',window,crImgTex,[], dstRect_cr);
    Screen('FrameRect',window, FrameColor_Rlx, windowRect,frame_thickness); 
    Screen('FillOval', window, black, fix_cord); 
    Resp2StartTimeP(trial)=Screen('Flip',window,0,1); 
    Resp2StartTimeD(trial)=getTime(useDatapixx);
        
    %start to record the response2
     
    if useDatapixx
        [Bpressed2 trial_RT2 TheButtonIndex2 bin_buttonpress2{trial} inter_buttonpress2{trial}] = WaitForEvent_Jerry(Resp2_Duration-2*FlipInt, TheTargs_CR, Resp2StartTimeD(trial)); % has to be at least 2 ifi ahead so that 1) the button press results can be shown; 2)  
    else
     % [trial_RT,keyCode] = waitforkey(2,0,[]);
       strt = GetSecs();
       WaitSecs(2);
       trial_RT = GetSecs() - strt;
       if trial_RT<=2; Bpressed2 = 1; else Bpressed2 = 0; end
       TheButtonIndex2 = 1; %update to actually listen to buttons later
    end
    
    if Bpressed2 && (length(TheButtonIndex2)==1)
        ButtonRT2(trial)= trial_RT2;
        ConfidenceRate(trial)= TheButtonIndex2;
        RESP2_Color= CRColor(TheButtonIndex2,:);
    else
        ConfidenceRate(trial)=NaN; %if response = -1 (no Confidence rate during time window) then recorded as NaN
        RESP2_Color= black;
    end

    Screen('FillOval', window, RESP2_Color, fix_cord);
    Resp2EndTimeP_SBP(trial)=Screen('Flip',window); 
    Resp2EndTimeP(trial)=Screen('Flip',window,Resp2StartTimeP(trial)+Resp2_Duration-0.5*FlipInt,0);
    Resp2EndTimeD(trial) = getTime(useDatapixx); 
    EndofTrial_timeP(trial)=Resp2EndTimeP(trial);
    EndofTrial_timeD(trial)=getTime(useDatapixx); 
    TrialinTRsP(trial)=ceil((EndofTrial_timeP(trial)- stimulusStartTimeP(trial))/TR); 
    TrialinTRsD(trial)=ceil((EndofTrial_timeD(trial)- stimulusStartTimeD(trial))/TR); 

    switch taskType
         case 1 % auditory
           fprintf(fid1,'%d\t %d\t %d\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %d\t %d\t %d\t %8.3f\t %8.3f\t %d\t %d\t %8.3f\t %d\t %8.3f\t %8.3f\t %8.3f\t %8.3f\n',trial,isoddball(trial),isStrengthHi(trial),stimulusStartTimeP(trial)-ExpStartTimeP,blankStartTimeP(trial)-ExpStartTimeP,fixStartTimeP(trial)-ExpStartTimeP,SoundStartTimeP(trial)-ExpStartTimeP,audiocompleteTimeP(trial)-ExpStartTimeP,relaxStartTimeP(trial)-ExpStartTimeP,Resp1StartTimeP(trial)-ExpStartTimeP,Resp2StartTimeP(trial)-ExpStartTimeP,EndofTrial_timeP(trial)-ExpStartTimeP,Bpressed,ButtonResponse(trial),iscorr(trial),trial_offset(trial),ButtonRT(trial),Bpressed2,ConfidenceRate(trial),ButtonRT2(trial),TrialinTRsP(trial),stimulusStartTimeP(trial)-ExpStartTimeP,fixOffsetP(trial)-ExpStartTimeP,Resp1EndTimeP(trial)-ExpStartTimeP,Resp2EndTimeP(trial)-ExpStartTimeP);
         case 2 % visual
           fprintf(fid1,'%d\t %d\t %d\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %d\t %d\t %d\t %8.3f\t %8.3f\t %d\t %d\t %8.3f\t %d\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\n',trial,isoddball(trial),isStrengthHi(trial),stimulusStartTimeP(trial)-ExpStartTimeP,blankStartTimeP(trial)-ExpStartTimeP,fixStartTimeP(trial)-ExpStartTimeP,SoundStartTimeP(trial)-ExpStartTimeP,audiocompleteTimeP(trial)-ExpStartTimeP,relaxStartTimeP(trial)-ExpStartTimeP,Resp1StartTimeP(trial)-ExpStartTimeP,Resp2StartTimeP(trial)-ExpStartTimeP,EndofTrial_timeP(trial)-ExpStartTimeP,Bpressed,ButtonResponse(trial),iscorr(trial),trial_offset(trial),ButtonRT(trial),Bpressed2,ConfidenceRate(trial),ButtonRT2(trial),TrialinTRsP(trial),stimulusStartTimeP(trial)-ExpStartTimeP,fixOffsetP(trial)-ExpStartTimeP,Resp1EndTimeP(trial)-ExpStartTimeP,Resp2EndTimeP(trial)-ExpStartTimeP,g1_OffsetTimeP(trial)-ExpStartTimeP,g2_OnsetTimeP(trial)-ExpStartTimeP,g2_OffsetTimeP(trial)-ExpStartTimeP);
     end; % switch
    TRcount=TRcount+TrialinTRsP(trial);
    
end % for trial
%DrawFormattedText(window,'You have now finished this part.\n\n Please wait for further instructions ','center','center',0);
DrawFormattedText(window,'Keep Still~','center','center',0);
t1_endofrunP=Screen('Flip',window); %draws response screen
t1_endofrunD=getTime(useDatapixx);
fprintf(fid1,'%%Total Duration of the run: %8.3f\t seconds \n',t1_endofrunP-ExpStartTimeP);

if useDatapixx && eyetrack
        Datapixx('StopTPxSchedule');
        Datapixx('RegWrRdVideoSync'); 
        EyeTrack_FinishTime = Datapixx('GetTime'); % 
        DrawFormattedText(window,'Run finished, saving eye tracking file....... ','center','center',0);
        Screen('Flip',window); %draws response screen 
        status = Datapixx('GetTPxStatus');
        toRead = status.newBufferFrames;
        [bufferData, underflow, overflow] = Datapixx('ReadTPxData', toRead);
        %dlmwrite(eyetrack_fname,bufferData,'precision','%.6f');
        save(eyetrack_fname,'bufferData'); % save as binary
end

DrawFormattedText(window,'You have now finished this part.\n\n Please wait for further instructions ','center','center',0); 
t1_endofsavingfileP=Screen('Flip',window); %draws response screen
t1_endofsavingfileD=getTime(useDatapixx);
fprintf(fid1,'%%Total Duration plus EyeTracking File Saving: %8.3f\t seconds \n',t1_endofsavingfileP-ExpStartTimeP);

fclose(fid1);
save(baseName); % saves everything in the workspace
KbWait; 

% [x,performance] = psychometricfxn_visualauditory  (iscorr, StimLev, mixtr, ConfidenceRate);

%=========CLOSE DATAPIXX OR PORTAUDIO==========%
ListenChar(0); %makes it so characters typed do show up in the command window
ShowCursor(); %shows the cursor
Screen('CloseAll');
Screen('Preference','Verbosity',OrigScreenLevel);
if useDatapixx
%   Datapixx('StopTPxSchedule');
    Datapixx('StopDinLog');
    Datapixx('RegWrRd');
    finish_time = Datapixx('GetTime');
    Datapixx('Close');
else
    PsychPortAudio('Close', pahandle);% Close the audio device:
end;

%%catch 
catch ME
    ListenChar(0); %makes it so characters typed do show up in the command window
    ShowCursor(); %shows the cursor
    Screen('CloseAll');
    Screen('Preference','Verbosity',OrigScreenLevel);
    fclose(fid1);
    save(baseName);      
    if useDatapixx && eyetrack && Datapixx('IsReady')
        Datapixx('StopTPxSchedule');
        status = Datapixx('GetTPxStatus');
        toRead = status.newBufferFrames;
        [bufferData, underflow, overflow] = Datapixx('ReadTPxData', toRead);
        save(eyetrack_fname,'bufferData'); 
    end;
    if Datapixx('IsReady')
        Datapixx('StopDinLog');
        Datapixx('Close');
    end;  
    disp(ME);
end

performance_standard_adt = [0.855882353 0.17745098 0.389215686 0.711764706 0.899019608];
performance_standard_vdt = [0.911889597 0.156050955 0.408704883 0.824840764 0.963906582];

figure;
subplot(2, 2, 1);
if taskType==1
    plot_perf_avdt_run(ButtonResponse, iscorr, performance_standard_adt, mixtr, StimLev, 0, ConfidenceRate);
elseif taskType==2
    plot_perf_avdt_run(ButtonResponse, iscorr, performance_standard_vdt, mixtr, StimLev, 0, ConfidenceRate);
end
subplot(2, 2, 2);
plot_gripforce_run(gripforce_fname, mvc, stimulusStartTimeD,SoundStartTimeD,Resp1StartTimeD,Resp1EndTimeD,EndofTrial_timeD,0)
subplot(2, 2, 3);
plot_confhist_run(ButtonResponse,ConfidenceRate,0);
if eyetrack
    subplot(2, 2, 4);
    plot_invalidpupilhist_run(bufferData,stimulusStartTimeD,SoundStartTimeD,Resp1StartTimeD,Resp1EndTimeD,EndofTrial_timeD,0)
end
set(gcf,'Position',[200 200 1000 500])
saveas(gcf, append(baseName, '.png'));
