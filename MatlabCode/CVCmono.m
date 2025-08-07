function percentScore = CVCmono(subjID, ear, howmany, feedback, audflag)
% CVCmono  Run a monaural / binaural concurrent-vowel identification task.
%
%   percentScore = CVCmono(subjID, ear, howmany, feedback, audflag)
%
%   --------------------------------------------------------------------
%   subjID   : subject folder name (string)
%   ear      : 'L' | 'R' | 'B'  – test left, right, or both ears
%   howmany  : number of trials (default = 72, the full set)
%   feedback : 'y' | 'n'        – provide visual feedback or not (default = 'y')
%   audflag  : 0 = normal-hearing (default)
%              1 = use /Experiments/Data/<subjID>/Audiogram.txt for HL correction
%
%   percentScore : proportion correct × 100 for this run
%   --------------------------------------------------------------------

%% ------------------------ CONSTANTS & PARAMETERS ------------------------
maxTrials           = 72;
if nargin < 3, howmany  = maxTrials; end
if nargin < 4, feedback = 'y';       end
if nargin < 5, audflag  = 0;         end

fsPlayback          = 44100;         % fixed playback sr
padSamples          = 20;          % onset/offset padding
playScaleLeft       = 10^(-40/20);   % attenuations for Babyface Pro
playScaleRight       = 10^(-42/20);   % attenuations for Babyface Pro
playScaleBinaural   = 10^(-40/20);

%% ----------- LOOKUP-TABLES: label ↔ integer mapping --------------------
consonantList = {'d','g','l','f','th','jh','p','sh','t'};
consonantID   = 1:numel(consonantList);
consonantMap  = containers.Map(consonantList, consonantID);

vowelList     = {'IH','EH','AE'};
vowelID       = 1:numel(vowelList);
vowelIDMap    = containers.Map(vowelList, vowelID);

f0List        = {'high_f0','low_f0'};
f0ID          = 1:numel(f0List);
f0IDMap       = containers.Map(f0List, f0ID);

% ------------------------------------------------------------------------
%  GUI label overrides for specific CVC triplets
%  key  = lower-case phonetic spelling that comes out of the stimulus code
%  val  = what you want to show on the GUI button
% ------------------------------------------------------------------------
cvcLabelMap = containers.Map( ...
    { ...
        'did','ded','dad', ...             % d- initial
        'dijh','dejh','dajh', ...
        'dif','def','daf', ...
        'dish','desh','dash', ...
        'gig','geg','gag', ...           % g- initial
        'gith','geth','gath', ...
        'git','get','gat', ...
        'lijh','lejh','lajh', ...        % l- initial
        'lith','leth','lath', ...
        'lid','led','lad', ...
        'lip','lep','lap' ...
    },{ ...
        'did','dead','dad', ...        % -d        % d- initial
        'didge','dedge','dadge', ...   % -jh  →  -dge
        'diff','deaf','daff', ...      % -f   : “deaf” matches /dɛf/
        'dish','desh','dash', ...      % -sh
        'gig','geg','gag', ...         % -g         % g- initial
        'gith','geth','gath', ...      % -th
        'git','get','gat', ...         % -t
        'lidge','ledge','ladge', ...   % -jh  →  -dge         % l- initial
        'lith','leth','lath', ...      % -th
        'lid','led','lad', ...         % -d
        'lip','lep','lap' ...          % -p
    });
vowelCodeMap = containers.Map({'IH','EH','AE'}, {'i','e','a'});

%% --------------------- STIMULUS-LIST GENERATION ------------------------
initials   = {'D','G','L'};
finals   = {'D','F','TH','JH','G','P','SH','T'};
vowelMap   = containers.Map({'a','e','i'},{'AE','EH','IH'});
vowLabels  = {'IH','EH','AE'};
f0Names    = {'high_f0','low_f0'};
seed       = subjID;

if ischar(seed) || isstring(seed)
    numericSeed = sum(double(char(seed)));   % simple hash for reproducibility
else
    numericSeed = seed;
end
rng(numericSeed);

stimRoot   = '/SoundFiles/CVC2025/Dichotic_Lexical_Fusion_Experiment/actual_stimuli';
quadList   = generate_CVC_mono_stimuli_quadruplets( ...
                 stimRoot, seed, initials, finals, vowelMap, f0Names);
nStim      = size(quadList,1);
if nStim == 0, error('No usable stimulus files found under %s', stimRoot); end

rng('shuffle','twister');                    % random order for this run
shuffleIdx = randperm(nStim);

%% --------------------------- INITIAL SETUP -----------------------------
earIdx = strmatch(upper(ear), ['L'; 'R'; 'B']);
if isempty(earIdx), error('Ear must be ''L'', ''R'', or ''B''.'); end

dataPath = fullfile('/Experiments/Data', subjID);
if ~exist(dataPath, 'dir')
    if ~mkdir('/Experiments/Data/', subjID)
        error('Unable to create subject directory.');
    end
end
cd(dataPath);

if audflag
    fidAudiogram = fopen('Audiogram.txt','r');
    if fidAudiogram == -1, error('Audiogram.txt not found for %s.', subjID); end
    unused_var = fscanf(fidAudiogram, '%i', [8 1])';           % frequencies (unused)
    audiogram  = fscanf(fidAudiogram, '%f', [8 2])';  % rows: L  R
    fclose(fidAudiogram);
end

%% -------------- Prepare both results files: int + human ----------------
intFile   = fileExistCheck(dir,[subjID '_CVCmono_0.txt']);
humanFile = fileExistCheck(dir,[subjID '_CVCmono_human_readable_0.tsv']);

fidInt = fopen(intFile,'wt');
fidHum = fopen(humanFile,'wt');

% ----- Common header lines: Ear & Audiogram ----------------------------
fprintf(fidInt ,'Ear: %s\n', ear);
if audflag
    fprintf(fidInt ,'Audiogram left  : [%s]\n', sprintf('%.0f ', audiogram(1,:)));
    fprintf(fidInt ,'Audiogram right : [%s]\n', sprintf('%.0f ', audiogram(2,:)));
    audLeftStr  = strjoin(string(audiogram(1 ,:)), ',');   % e.g. 10,15,20,…
    audRightStr = strjoin(string(audiogram(2 ,:)), ',');
else
    fprintf(fidInt ,'Audiogram left  : NA\nAudiogram right : NA\n');
    audLeftStr  = 'NA';
    audRightStr = 'NA';
end

% ----- Key header for integer file -------------------------------------
fprintf(fidInt,'# Keys:\n# Consonant_ID  : ');
for k=1:numel(consonantList), fprintf(fidInt,'%s=%d ',consonantList{k},consonantID(k)); end
fprintf(fidInt,'\n# Vowel_ID      : ');
for k=1:numel(vowelList),     fprintf(fidInt,'%s=%d ',vowelList{k},vowelID(k));         end
fprintf(fidInt,'\n# F0_ID         : ');
for k=1:numel(f0List),        fprintf(fidInt,'%s=%d ',f0List{k},f0ID(k));               end
fprintf(fidInt,'# Columns       : Trial Consonant_1_ID Consonant_2_ID Vowel_ID F0_ID Heard_Consonant Answer_vowel Correct Time_elapsed\n');

% ----- Header for human-readable file -----------------------------------
fprintf(fidHum,'Trial\tC1\tC2\tVowel\tF0\tAnswer\tAnswer_vowel\tHeard_Consonant\tHeard_correct_vowel\tTime_elapsed\tEar\tAudiogram_Left\tAudiogram_Right\n');

fprintf('Results saved to\n  %s\n  %s\n', fullfile(dataPath,intFile), fullfile(dataPath,humanFile));

%% ------------------------ GUI / HARDWARE SETUP -------------------------
originalDir   = pwd;
global shp;
close all;

statusBar     = status_bar();
load C:/Development/Matlab/ark1.mat
guiHandle     = ark1v6practice;

defaultTopRow    = {'big','beg','bag'};
defaultBottomRow = {'IH','EH','AE'};
for iV = 1:3
    buttonv6(iV).name   = defaultTopRow{iV};
    buttonv6(iV+3).name = defaultBottomRow{iV};
end
buttonv6(9).name = 'Press any button to start.';
bcontrol(guiHandle,1,buttonv6,9,'w',20);
bcontrol(guiHandle,6,buttonv6,0,'w', 30);
shp = 0; waitButton;

bcontrol(guiHandle,6,buttonv6,0,'blue',40); pause(1);
bcontrol(guiHandle,6,buttonv6,0,'red', 30); pause(1);

%% ---------------------------- MAIN LOOP --------------------------------
totalCorrect     = 0;           % across all trials
totalRespTime    = 0;
trialsPerC1      = zeros(1,numel(consonantList));
correctPerC1     = zeros(1,numel(consonantList));

for trialIdx = 1:howmany
    set(statusBar,'String',num2str(trialIdx));

    idxInList   = mod(trialIdx-1,nStim)+1;
    thisQuad    = quadList(shuffleIdx(idxInList),:);  % {C1,C2,V,f0,path}
    C1   = lower(thisQuad{1});
    C2   = lower(thisQuad{2});
    V    = thisQuad{3};        % 'IH','EH','AE'
    f0Lbl= thisQuad{4};
    wavFile = thisQuad{5};

    [wavData, fsFile] = audioread(wavFile);
    if fsFile~=fsPlayback, error('File %s has sr %d, expected %d.',wavFile,fsFile,fsPlayback); end
        paddedMono = [zeros(padSamples,1); wavData; zeros(padSamples,1)];
        stereoBuffer=[paddedMono*playScaleLeft,paddedMono*playScaleRight];


    % --- Update GUI buttons for this trial ---------------------------------
    for iV = 1:numel(vowLabels)
        oneLetter = vowelCodeMap(vowLabels{iV});   % 'IH' → 'i', etc.
        labelKey  = [C1 oneLetter C2];             % e.g. 'lajh'

        if isKey(cvcLabelMap,labelKey)
            buttonv6(iV).name = cvcLabelMap(labelKey);
        else
            buttonv6(iV).name = labelKey;          % fallback
        end

        buttonv6(iV+3).name = vowLabels{iV};       % bottom row stays IH/EH/AE
    end


    bcontrol(guiHandle,6,buttonv6,0,'red',28);

    buttonv6(9).name = sprintf('Playing trial %d of %d...',trialIdx,howmany);
    bcontrol(guiHandle,6,buttonv6,0,'w', 30);
    bcontrol(guiHandle,1,buttonv6,9,'w',20);
    sound(stereoBuffer,fsPlayback); pause(1.7);
    bcontrol(guiHandle,6,buttonv6,0,'red', 30);

    buttonv6(9).name = 'Which word/individual vowel did you hear?';
    bcontrol(guiHandle,1,buttonv6,9,'w',20);

    shp = 0; tStart=tic; waitButton; respTime=toc(tStart); answer=shp;

    buttonToVowel = [1 2 3 1 2 3];                    % IH EH AE map
    correctVowelIndex = find(strcmp(vowLabels,V));
    pressedVowelIndex = buttonToVowel(answer);
    correct           = (pressedVowelIndex==correctVowelIndex);

    % --- Update tallies -------------------------------------------------
    totalCorrect   = totalCorrect + correct;
    totalRespTime  = totalRespTime + respTime;
    c1Idx          = consonantMap(C1);
    trialsPerC1(c1Idx)  = trialsPerC1(c1Idx)  + 1;
    correctPerC1(c1Idx) = correctPerC1(c1Idx) + correct;

    % --- Prepare values for files --------------------------------------
    c1ID = c1Idx;
    c2ID = consonantMap(C2);
    vowID= vowelIDMap(V);
    f0IDn= f0IDMap(f0Lbl);

    heardConsonant = answer<=3;
    answerVowelID  = buttonToVowel(answer);     % 1–3

    % ----- Integer file line -------------------------------------------
    fprintf(fidInt,'%d %d %d %d %d %d %d %d %.4f\n',...
            trialIdx, c1ID,c2ID,vowID,f0IDn,heardConsonant,answerVowelID,correct,respTime);


    % ----- Human-readable file line ------------------------------------
    fprintf(fidHum,'%d\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%.4f\t%s\t%s\t%s\n',...
            trialIdx,C1,C2,V,f0Lbl,buttonv6(answer).name,vowelList{answerVowelID},...
            heardConsonant,correct,respTime,ear,audLeftStr,audRightStr);


    % ----- Feedback -----------------------------------------------------
    if feedback=='y'
        bcontrol(guiHandle,1,buttonv6,correctVowelIndex,'blue',40); pause(1);
        bcontrol(guiHandle,1,buttonv6,correctVowelIndex,'red', 30); pause(1);
    else
        pause(0.1);
    end
end

%% ------------------------- FINAL SUMMARY -------------------------------
percentScore = totalCorrect/howmany*100;
meanRT       = totalRespTime/howmany;

fprintf('Score: %5.2f %% | Mean RT: %7.4f s | Total RT: %7.4f s\n',...
        percentScore, meanRT, totalRespTime);

for k = 1:numel(consonantList)
    if trialsPerC1(k)
        fprintf('%s: %5.2f %%\n', upper(consonantList{k}),...
                correctPerC1(k)/trialsPerC1(k)*100);
    else
        fprintf('%s: N/A\n', upper(consonantList{k}));
    end
end

fclose(fidInt); fclose(fidHum); cd(originalDir);

for k=1:3
    bcontrol(guiHandle,6,buttonv6,0,'blue',30); pause(0.8);
    bcontrol(guiHandle,6,buttonv6,0,'red', 20); pause(0.8);
end
close all; closereq; closereq; clear;
end  % ----------------------------- CVCmono ------------------------------
