function stereo = pad_and_scale(yL,yR,audflag,scale,pad)
    if audflag, % <insert HL-correction if you still need it>
    end
    stereo = [zeros(pad,2); [yL yR]; zeros(pad,2)] * scale;
end

function flash(h,idx,msg)
    buttonv6(idx).name=msg; bcontrol(h,1,buttonv6,idx,'w',20); pause(.6);
end

function cat = pickCategory(f01,f02)
    if  f01==1 && f02==1,        cat='lowlow';
    elseif f01==2 && f02==2,     cat='highhigh';
    else,                        cat='alt'; end
end

function out = pick(def,val,arr)
    if val==-1, out=def; else, out=arr{val}; end
end

function out = pickStr(def,val,bv)
    if val==-1, out='NA'; else, out=bv(val).name; end
end



function percentScore = CVC(subjID, howmany, audflag, catchflag)
% CVC  Dichotic / diotic concurrent-vowel identification (up to 3 answers).
%
%   percentScore = CVC(subjID, howmany, audflag, catchflag)
%
%   • Two independent audio streams (left / right)
%   • Participant may pick 1-to-3 buttons (+ two replays max)
%   • Results saved to   <subjID>_CVC_0.txt                (numeric)
%                         <subjID>_CVC_human_readable_0.txt
%   • Console prints every trial + end-of-run summaries
% -------------------------------------------------------------------------
%                 *****  USER-EDITABLE CONSTANTS  *****
fsPlayback     = 44100;
bits           = 32;
padSamples     = 2000;
playScale      = 10^(-31/20);        % Babyface Pro
maxReplays     = 2;                  % per trial
buttonToVowel  = [1 2 3 1 2 3 1 2 3];% mapping GUI idx → vowel idx
vowLabels      = {'IH','EH','AE'};   % order on GUI bottom row
vowelCodeMap   = containers.Map({'IH','EH','AE'},{1,2,3});
singleLetter   = containers.Map({'IH','EH','AE'},{'i','e','a'});
f0Label        = containers.Map({'106.9','109.0'},1); % low_f0 ID = 1
f0Label('151.2') = 2; f0Label('155.0') = 2; f0Label('201.8') = 2; % high_f0 ID = 2
% -----------------------------------------------------
if nargin<4, catchflag=0; end
if nargin<3, audflag  =0; end
if nargin<2, howmany  =84+(24*catchflag); end

%% =====  RESULTS FILES  ==================================================
dataDir = fullfile('/Experiments/Data',subjID); if ~exist(dataDir,'dir'), mkdir(dataDir); end
cd(dataDir);
intFile   = fileExistCheck(dir,[subjID '_CVC_0.txt']);
humanFile = fileExistCheck(dir,[subjID '_CVC_human_readable_0.txt']);
fidInt  = fopen(intFile ,'wt');
fidHum  = fopen(humanFile,'wt');

% headers -----------------------------------------------------------------
fprintf(fidInt ,'Con1 Con2 V1 V2 F01 F02 Ans1V Ans2V Ans3V Ans1C Ans2C Ans3C OneType BothOK RT\n');
fprintf(fidHum ,'C1 C2 Vowel1 Vowel2 F0_1 F0_2 Ans1V Ans2V Ans3V Ans1C Ans2C Ans3C Ans1 Ans2 Ans3 OneType BothOK RT\n');

%% =====  GUI / HW  SET-UP  ==============================================
global shp; close all;
status = status_bar; load C:/Development/Matlab/ark1.mat
h = ark1v6;
defaultTop  = {'big','beg','bag'};
for k=1:3, buttonv6(k).name=defaultTop{k}; buttonv6(k+3).name=vowLabels{k}; end
buttonv6(9).name='Press any button to start.';
bcontrol(h,1,buttonv6,9,'w',20); bcontrol(h,6,buttonv6,0,'w',30);
shp=0; waitButton;
bcontrol(h,6,buttonv6,0,'blue',40); pause(1);
bcontrol(h,6,buttonv6,0,'red' ,30); pause(1);

%% =====  MAIN LOOP  ======================================================
totOK1=0; totOKboth=0; rtTot=0;          % overall
statsCat = struct('lowlow',[],'highhigh',[],'alt',[]); % per-F0 condition
tally    = struct;                       % per (C1,C2)

for trial = 1:howmany
    %% ---- pick / load stimulus pair (legacy lists kept) -----------------
    [wavL,wavR,C1,C2,V1,V2,f01,f02] = legacy_pick_stims(trial,catchflag); %#ok<*ASGLU>
    f01id = f0Label(f01); f02id = f0Label(f02);

    %% ---- build GUI buttons --------------------------------------------
    for i=1:3
        key=[lower(C1) singleLetter(vowLabels{i}) lower(C2)];
        buttonv6(i).name = key;                    % no fancy map here
        buttonv6(i+3).name = vowLabels{i};
    end
    bcontrol(h,6,buttonv6,0,'red',28);

    %% ---- play  (with optional HL correction) --------------------------
    stereo = pad_and_scale(wavL,wavR, audflag, playScale, padSamples);
    buttonv6(9).name=sprintf('Playing trial %d of %d...',trial,howmany);
    bcontrol(h,1,buttonv6,9,'w',20); pause(.7);
    a=audioplayer(stereo,fsPlayback,bits); playblocking(a); pause(.3);

    %% ---- collect up-to-3 answers  -------------------------------------
    buttonv6(9).name='Pick 1–3 buttons (▶ to replay)'; bcontrol(h,1,buttonv6,9,'w',20);
    vowelChosen=false(1,3); replayCnt=0; answers=[]; shp=0; t0=tic;
    while true
        waitButton; idx=shp;
        if idx==7      % ▶ replay
            if replayCnt<maxReplays, playblocking(a); replayCnt=replayCnt+1;
            else, flash(h,9,'Replay limit reached'); end
        elseif idx<=6  % a vowel button
            if ~vowelChosen(idx), vowelChosen(idx)=true; answers(end+1)=idx; bcontrol(h,1,buttonv6,idx,'blue',30); %#ok<AGROW>
            else, vowelChosen(idx)=false; answers(answers==idx)=[]; bcontrol(h,1,buttonv6,idx,'red',30);
            end
        elseif idx==8  % ✔ confirm
            if ~isempty(answers) && numel(answers)<=3, break; else, flash(h,9,'Pick 1-3'); end
        end
    end
    RT=toc(t0); rtTot=rtTot+RT;

    %% ---- bookkeeping ---------------------------------------------------
    nAns = numel(answers);
    answers(end+1:3) = -1;                 %#ok<AGROW>
    ansVowel = arrayfun(@(x) buttonToVowel(x),answers); % 1-3 or -1
    ansCons  = answers<=3 & answers~=-1;   % top-row → heard consonant
    ansCons(end+1:3)=0;
    oneType  = all(ansVowel(ansVowel~=-1)==ansVowel(find(ansVowel~=-1,1)));
    stimSet  = unique([vowelCodeMap(V1) vowelCodeMap(V2)]);
    selSet   = unique(ansVowel(ansVowel~=-1));
    bothOK   = isequal(sort(stimSet),sort(selSet));

    % overall tallies
    if any(ismember(selSet,stimSet)), totOK1=totOK1+1; end
    if bothOK, totOKboth=totOKboth+1; end

    % category by F0 condition
    cat = pickCategory(f01id,f02id);
    statsCat.(cat).n = getfield(statsCat,cat,'n',0)+1;                %#ok<GFLD>
    statsCat.(cat).ok1  = getfield(statsCat,cat,'ok1',0)+both(any(ismember(selSet,stimSet)));
    statsCat.(cat).ok2  = getfield(statsCat,cat,'ok2',0)+bothOK;

    % per consonant pair tally
    keyCC = sprintf('%s_%s',C1,C2);
    if ~isfield(tally,keyCC)
        tally.(keyCC)=struct('both',0,'one',0,'N',0,'IH',0,'EH',0,'AE',0);
    end
    tall = tally.(keyCC);
    tall.N  = tall.N + 1;
    tall.both = tall.both + bothOK;
    tall.one  = tall.one  + oneType;
    for v=selSet, if v==1, tall.IH=tall.IH+1; elseif v==2, tall.EH=tall.EH+1; else, tall.AE=tall.AE+1; end, end
    tally.(keyCC)=tall;

    %% ---- write files ---------------------------------------------------
    fmtInt  = '%d %d %d %d %d %d %d %d %d %d %d %d %d %d %.4f\n';
    fmtHum  = '%s %s %s %s %s %s %s %s %s %d %d %d %s %s %s %d %d %.4f\n';
    v1id=vowelCodeMap(V1); v2id=vowelCodeMap(V2);
    fprintf(fidInt,fmtInt,...
        consonantID(strcmpi(C1,consonantList)), ...
        consonantID(strcmpi(C2,consonantList)), ...
        v1id, v2id, f01id, f02id, ...
        ansVowel, ansCons, oneType, bothOK, RT);

    fprintf(fidHum,fmtHum,...
        C1,C2,V1,V2,f01,f02,...
        vowLabels{max(ansVowel(1),1)}, pick(-1,ansVowel(2),vowLabels), pick(-1,ansVowel(3),vowLabels), ...
        ansCons, ...
        pickStr(-1,answers(1),buttonv6), pickStr(-1,answers(2),buttonv6), pickStr(-1,answers(3),buttonv6), ...
        oneType,bothOK,RT);

    % ---- echo to console ------------------------------------------------
    fprintf('%s %s %s %s %s %s %s %s %s %d %d %d %s %s %s %d %d %.4f\n', ...
            C1,C2,V1,V2,f01,f02, ...
            vowLabels{max(ansVowel(1),1)},pick(-1,ansVowel(2),vowLabels),pick(-1,ansVowel(3),vowLabels), ...
            ansCons, pickStr(-1,answers(1),buttonv6),pickStr(-1,answers(2),buttonv6),pickStr(-1,answers(3),buttonv6), ...
            oneType,bothOK,RT);
end

%% =====  SUMMARY  =======================================================
fprintf('\n=== OVERALL SUMMARY =========================================\n');
fprintf('Avg ≥1 correct:  %5.2f %%\n', 100*totOK1/howmany);
fprintf('Both correct:    %5.2f %%\n', 100*totOKboth/howmany);
fprintf('Mean RT:         %7.4f  s\n', rtTot/howmany);
fprintf('Total RT:        %7.4f  s\n', rtTot);

cats={'lowlow','highhigh','alt'};
for c=cats
    S=statsCat.(c{1}); if isempty(S), N=0; ok1=0; ok2=0; else, N=S.n; ok1=S.ok1; ok2=S.ok2; end
    fprintf('%8s  N=%3d  ≥1corr=%5.2f %%  both=%5.2f %%\n',...
            c{1},N,100*ok1/max(N,1),100*ok2/max(N,1));
end

fprintf('\nC1  C2   both%%  one%%  IH%%  EH%%  AE%%\n');
keys=fieldnames(tally);
for k=1:numel(keys)
    T=tally.(keys{k}); parts=split(keys{k},'_');
    fprintf('%-2s  %-2s  %5.2f  %5.2f  %5.2f  %5.2f  %5.2f\n',...
            upper(parts{1}),upper(parts{2}),...
            100*T.both/max(T.N,1), 100*T.one/max(T.N,1), ...
            100*T.IH/max(T.N,1), 100*T.EH/max(T.N,1), 100*T.AE/max(T.N,1));
end

fclose('all'); close all; clear;  percentScore=100*totOKboth/howmany;
end
