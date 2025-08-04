function percentScore = CVCmono(subjID, ear, howmany, feedback, audflag)
% CVCmono  Run a monaural / binaural concurrent-vowel identification task.
%
%   percentScore = CVCmono(subjID, ear, howmany, feedback, audflag)
%
%   INPUTS
%   --------------------------------------------------------------------
%   subjID   : subject folder name (string)
%   ear      : 'L' | 'R' | 'B'  → test left, right, or both ears
%   howmany  : number of trials (default = 72, the full set)
%   feedback : 'y' | 'n'        → provide visual feedback or not (default = 'y')
%   audflag  : 0 = normal-hearing (default)
%              1 = use /Experiments/Data/<subjID>/Audiogram.txt for HL correction
%
%   OUTPUT
%   --------------------------------------------------------------------
%   percentScore : proportion correct × 100 for this run
%
%   The stimulus set comprises 6 vowels × 3 F0s × 4 repetitions = 72 tokens.
%   Audio files live in /SoundFiles/ConcurrVowels/New8vowels/.
% -------------------------------------------------------------------------

%% ------------------------ CONSTANTS & PARAMETERS ------------------------
maxTrials           = 72;          % full factorial design (6×3×4)
if nargin < 3, howmany  = maxTrials; end
if nargin < 4, feedback = 'y';     end
if nargin < 5, audflag  = 0;       end

% Fixed playback sampling rate (all stimuli are stored at 44.1 kHz)
fsPlayback          = 44100;

% Audio padding (ms → samples) to avoid onset clicks
padSamples          = 2000;

% Playback attenuation for Babyface Pro interface
playScaleLeft       = 10^(-31/20);     % left or right only
playScaleBinaural   = 10^(-32.5/20);   % both ears

%% ----------- LOOKUP-TABLES: label <-> integer mapping -------------------
consonantList = {'d','g','l','f','th','jh'};
consonantID   = 1:numel(consonantList);
consonantMap  = containers.Map(consonantList, consonantID);

vowelList     = {'IH','EH','AE'};
vowelID       = 1:numel(vowelList);
vowelIDMap    = containers.Map(vowelList, vowelID);

f0List        = {'high_f0','low_f0'};
f0ID          = 1:numel(f0List);
f0IDMap       = containers.Map(f0List, f0ID);

%% --------------------- STIMULUS-LIST GENERATION ------------------------
initials   = {'D','G','L'};
finals     = {'D','F','TH','JH','G'};
vowelMap   = containers.Map({'a','e','i'},{'AE','EH','IH'});
vowLabels  = {'IH','EH','AE'};
f0Names    = {'high_f0','low_f0'};
seed       = subjID;

if ischar(seed) || isstring(seed)
    numericSeed = sum(double(char(seed)));
else
    numericSeed = seed;
end
rng(numericSeed);

stimRoot   = '/SoundFiles/CVC2025/Dichotic_Lexical_Fusion_Experiment/actual_stimuli';

quadList   = generate_CVC_mono_stimuli_quadruplets( ...
                 stimRoot, seed, initials, finals, vowelMap, f0Names);
nStim      = size(quadList,1);

if nStim == 0
    error('No usable stimulus files found under %s', stimRoot);
end

rng('shuffle','twister');
shuffleIdx = randperm(nStim);

%% --------------------------- INITIAL SETUP -----------------------------
earIdx = strmatch(upper(ear), ['L'; 'R'; 'B']);
if isempty(earIdx)
    error('Ear must be ''L'', ''R'', or ''B''.');
end

dataPath = fullfile('/Experiments/Data', subjID);  % <-- FIXED: define dataPath
if ~exist(dataPath, 'dir')
    if ~mkdir('/Experiments/Data/', subjID)
        error('Unable to create subject directory.');
    end
end
cd(dataPath);

if audflag
    fidAudiogram = fopen(sprintf('Audiogram.txt'), 'r');
    if fidAudiogram == -1
        error('Audiogram.txt not found for subject %s.', subjID);
    end
    freqRead   = fscanf(fidAudiogram, '%i', [8 1])';
    audiogram  = fscanf(fidAudiogram, '%f', [8 2])';   % rows: L, R
    fclose(fidAudiogram);
end

%% -------------- Prepare both results files: int + human ----------------
intFile   = fileExistCheck(dir, [subjID '_CVCmono_0.txt']);
humanFile = fileExistCheck(dir, [subjID '_CVCmono_human_readable_0.txt']);

fidInt = fopen(intFile  ,'wt');
fidHum = fopen(humanFile,'wt');

% Key header for the integer file
fprintf(fidInt,'# Keys:\n# Consonant_ID  : ');
for k=1:numel(consonantList)
    fprintf(fidInt,'%s=%d ', consonantList{k}, consonantID(k));
end
fprintf(fidInt,'\n');
fprintf(fidInt,'# Vowel_ID      : ');
for k=1:numel(vowelList)
    fprintf(fidInt,'%s=%d ', vowelList{k}, vowelID(k));
end
fprintf(fidInt,'\n');
fprintf(fidInt,'# F0_ID         : ');
for k=1:numel(f0List)
    fprintf(fidInt,'%s=%d ', f0List{k}, f0ID(k));
end
fprintf(fidInt,'\n');
fprintf(fidInt,['# Columns       : Consonant_1_ID Consonant_2_ID Vowel_ID ' ...
                'F0_ID Heard_Consonant Answer_vowel Correct Time_elapsed\n']);

% Header for human-readable file
fprintf(fidHum,'Vowel F0 Answer Answer_vowel Heard_Consonant Heard_correct_vowel Time_elapsed\n');

fprintf('Results saved to\n  %s  (integers + key)\n  %s  (readable)\n',...
            fullfile(dataPath,intFile), fullfile(dataPath,humanFile));

%% ------------------------ GUI / HARDWARE SETUP -------------------------
originalDir   = pwd;
global shp;               % button pressed by subject
close all;

statusBar     = status_bar();     % run-status text field
load C:/Development/Matlab/ark1.mat
guiHandle     = ark1v6practice;

buttonv6(9).name = 'Press any button to start.';
bcontrol(guiHandle, 1, buttonv6, 9, 'w', 20);

shp           = 0;
waitButton;   % block until participant presses a button

bcontrol(guiHandle, 6, buttonv6, 0, 'blue', 40); pause(1);
bcontrol(guiHandle, 6, buttonv6, 0, 'red',  30); pause(1);

%% ---------------------------- MAIN LOOP --------------------------------
rng('shuffle','twister');
totalCorrect    = 0;
totalRespTime   = 0;

for trialIdx = 1:howmany
    set(statusBar,'String',num2str(trialIdx));

    idxInList   = mod(trialIdx-1, nStim) + 1;
    thisQuad    = quadList(shuffleIdx(idxInList), :);   % {C1,C2,V,f0,path}

    C1 = lower(thisQuad{1});
    C2 = lower(thisQuad{2});
    V  = thisQuad{3};      % 'IH','EH','AE'
    f0Label = thisQuad{4};
    wavFile = thisQuad{5};

    [wavData, fsFile] = audioread(wavFile);
    if fsFile ~= fsPlayback
        error('File %s has sampling rate %d, expected %d.', wavFile, fsFile, fsPlayback);
    end
    paddedMono = [zeros(padSamples,1); wavData; zeros(padSamples,1)];

    switch earIdx
        case 1     % Left-only
            stereoBuffer = [paddedMono, zeros(size(paddedMono))]*playScaleLeft;
        case 2     % Right-only
            stereoBuffer = [zeros(size(paddedMono)), paddedMono]*playScaleLeft;
        otherwise  % Both ears
            stereoBuffer = [paddedMono, paddedMono]*playScaleBinaural;
    end

    for iV = 1:length(vowLabels)
        buttonv6(iV).name   = sprintf('%s%s%s', C1, lower(vowLabels{iV}), C2);
        buttonv6(iV+3).name = sprintf('-%s-', vowLabels{iV});
    end
    bcontrol(guiHandle, 6, buttonv6, 0, 'red', 28);

    buttonv6(9).name = sprintf('Playing trial %d of %d...', trialIdx, howmany);
    bcontrol(guiHandle, 1, buttonv6, 9, 'w', 20);
    pause(0.7);

    sound(stereoBuffer, fsPlayback);
    pause(0.3);

    buttonv6(9).name = 'Which word/individual vowel did you hear?';
    bcontrol(guiHandle, 1, buttonv6, 9, 'w', 20);

    shp      = 0;
    tStart   = tic;
    waitButton;
    respTime = toc(tStart);
    answer   = shp;  % 1–6 button pressed

    buttonToVowel = [1 2 3 1 2 3]; % IH,EH,AE,IH,EH,AE mapping
    correctVowelIndex = find(strcmp(vowLabels, V));

    pressedVowelIndex = buttonToVowel(answer);
    correct = (pressedVowelIndex == correctVowelIndex);

    % -------------------- Save both human + int files ------------------
    c1ID   = consonantMap(C1);     % convert to int
    c2ID   = consonantMap(C2);
    vowID  = vowelIDMap(V);
    f0IDn  = f0IDMap(f0Label);

    heardConsonant = answer <= 3;     % 1–3 are CVC (consonant) choices
    answerVowelID  = buttonToVowel(answer);  % 1–3 mapping

    % Integer file:      C1_ID C2_ID V_ID F0_ID Heard_Consonant Answer_vowel Correct Time_elapsed
    fprintf(fidInt,'%d %d %d %d %d %d %d %.4f\n', ...
        c1ID, c2ID, vowID, f0IDn, heardConsonant, answerVowelID, correct, respTime);

    % Human-readable:    Vowel F0 Answer Answer_vowel Heard_Consonant Heard_correct_vowel Time_elapsed
    fprintf(fidHum,'%s %s %s %s %d %d %.4f\n', ...
        V, f0Label, buttonv6(answer).name, vowelList{answerVowelID}, heardConsonant, correct, respTime);

    % ------------- Feedback (optional, highlight correct button) -------------
    if feedback == 'y'
        correctButtonIdx = correctVowelIndex;
        bcontrol(guiHandle,1,buttonv6,correctButtonIdx,'blue',40); pause(1);
        bcontrol(guiHandle,1,buttonv6,correctButtonIdx,'red', 30); pause(1);
    else
        pause(0.5);
    end
end

%% ------------------------- FINAL SUMMARY -------------------------------
buttonv6(9).name = 'Run finished.';
bcontrol(guiHandle, 1, buttonv6, 9, 'w', 20);

percentScore  = totalCorrect/howmany * 100;
meanRT        = totalRespTime/howmany;

fprintf('Score: %5.2f %%  |  Mean RT: %5.2f s\n', percentScore, meanRT);

fclose(fidInt);
fclose(fidHum);
cd(originalDir);

for k = 1:3
    bcontrol(guiHandle,6,buttonv6,0,'blue',30); pause(0.8);
    bcontrol(guiHandle,6,buttonv6,0,'red', 20); pause(0.8);
end
close all;

closereq;
closereq;

clear;

end  % ------------------------------ CVCmono ------------------------------
