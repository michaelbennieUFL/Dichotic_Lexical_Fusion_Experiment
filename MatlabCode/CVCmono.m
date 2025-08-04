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

%% --------------------- STIMULUS-LIST GENERATION ------------------------
% top-level options used by the quad-generator
initials   = {'D','G','L'};
finals     = {'D','F','TH','JH','G'};
vowelMap   = containers.Map({'a','e','i'},{'AE','EH','IH'});
f0Names    = {'high_f0','low_f0'};
seed       = subjID;                        % anything reproducible

% Root that contains all *_run folders:
stimRoot   = '/SoundFiles/ConcurrVowels';   % one level **above** sub-folders

% Get {C1,C2,V,f0,path} and shuffle once
quadList   = generate_CVC_mono_stimuli_quadruplets( ...
                 stimRoot, seed, initials, finals, vowelMap, f0Names);
nStim      = size(quadList,1);

if nStim == 0
    error('No usable stimulus files found under %s', stimRoot);
end

% Random order we will keep re-using with modulo indexing
rng('shuffle','twister');
shuffleIdx = randperm(nStim);


%% --------------------------- INITIAL SETUP -----------------------------
% Validate ear selection
earIdx = strmatch(upper(ear), ['L'; 'R'; 'B']);
if isempty(earIdx)
    error('Ear must be ''L'', ''R'', or ''B''.');
end

% Prepare subject data directory
if ~exist(dataPath, 'dir')
    if ~mkdir('/Experiments/Data/', subjID)
        error('Unable to create subject directory.');
    end
end
cd(dataPath);

% Read audiogram if needed
if audflag
    fidAudiogram = fopen(sprintf('Audiogram.txt'), 'r');
    if fidAudiogram == -1
        error('Audiogram.txt not found for subject %s.', subjID);
    end
    freqRead   = fscanf(fidAudiogram, '%i', [8 1])';
    audiogram  = fscanf(fidAudiogram, '%f', [8 2])';   % rows: L, R
    fclose(fidAudiogram);
end

% Prepare results file (auto-increment if file exists)
resultsFile = fileExistCheck(dir, [subjID '_CV6mono_0.txt']);
fidResults  = fopen(resultsFile, 'wt');
fprintf(fidResults,'Ear: %s\n', ear);
if audflag
    fprintf(fidResults,'Audiogram left  : [%s]\n', sprintf('%d ', audiogram(1,:)));
    fprintf(fidResults,'Audiogram right : [%s]\n', sprintf('%d ', audiogram(2,:)));
else
    fprintf(fidResults,'Audiogram left  : NA\n');
    fprintf(fidResults,'Audiogram right : NA\n');
end
fprintf(fidResults,'vowID F0ID answer correct timeElapsed\n');
fprintf('Results saved to %s\n', fullfile(dataPath, resultsFile));

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

% Flash GUI to get participant’s attention
bcontrol(guiHandle, 6, buttonv6, 0, 'blue', 40); pause(1);
bcontrol(guiHandle, 6, buttonv6, 0, 'red',  30); pause(1);

%% ---------------------------- MAIN LOOP --------------------------------
rng('shuffle','twister');                           % randomize trial order
totalCorrect       = 0;
totalRespTime      = 0;

for trialIdx = 1:howmany
    set(statusBar,'String',num2str(trialIdx));

    % --- Wrap-around indexing (used in cases where trialIdx> number of stimuli)
    idxInList   = mod(trialIdx-1, nStim) + 1;
    thisQuad    = quadList(shuffleIdx(idxInList), :);   % {C1,C2,V,f0,path}

    vowStr      = thisQuad{3};          % e.g. 'AE'
    f0Label     = thisQuad{4};          % e.g. 'high_f0'
    wavFile     = thisQuad{5};

    % Numeric vowID (needed for GUI buttons)
    vowID = find(strcmp(vowLabels, vowStr));
    if isempty(vowID)
        error('Unexpected vowel label %s in file %s', vowStr, wavFile);
    end

    [wavData, fsFile] = audioread(wavFile);




    if fsFile ~= fsPlayback
        error('File %s has sampling rate %d, expected %d.', ...
              filename, fsFile, fsPlayback);
    end
    paddedMono      = [zeros(padSamples,1); wavData; zeros(padSamples,1)];

    %% --------- Ear-specific processing & attenuation -------------------
    switch earIdx
        case 1     % Left-only
            if audflag
                [attenuatedData, ~, ~] = ampstim(paddedMono, fsPlayback, audiogram(1,:));
                attenuatedData = attenuatedData / 10^(28/20);
            else
                attenuatedData = paddedMono;
            end
            stereoBuffer = [attenuatedData, zeros(size(attenuatedData))];
            playScale    = playScaleLeft;

        case 2     % Right-only
            if audflag
                [attenuatedData, ~, ~] = ampstim(paddedMono, fsPlayback, audiogram(2,:));
                attenuatedData = attenuatedData / 10^(28/20);
            else
                attenuatedData = paddedMono;
            end
            stereoBuffer = [zeros(size(attenuatedData)), attenuatedData];
            playScale    = playScaleLeft;

        otherwise  % Both ears
            if audflag
                [leftData,  ~, ~] = ampstim(paddedMono, fsPlayback, audiogram(1,:));
                [rightData, ~, ~] = ampstim(paddedMono, fsPlayback, audiogram(2,:));
                leftData  = leftData  / 10^(28/20);
                rightData = rightData / 10^(28/20);
            else
                leftData  = paddedMono;
                rightData = paddedMono;
            end
            stereoBuffer = [leftData, rightData];
            playScale    = playScaleBinaural;
    end

    stereoBuffer = stereoBuffer * playScale;

    %% --------- Play stimulus & collect response ------------------------
    buttonv6(9).name = sprintf('Playing trial %d of %d...', trialIdx, howmany);
    bcontrol(guiHandle, 1, buttonv6, 9, 'w', 20);
    pause(0.7);

    sound(stereoBuffer, fsPlayback);
    pause(0.3);

    buttonv6(9).name = 'Which vowel did you hear?';
    bcontrol(guiHandle, 1, buttonv6, 9, 'w', 20);

    shp        = 0;
    tStart     = tic;
    waitButton;                    % blocks until subject answers
    respTime   = toc(tStart);
    answer     = shp;

    %% --------- Feedback (optional) -------------------------------------
    if feedback == 'y'
        bcontrol(guiHandle,1,buttonv6,vowID,'blue',40); pause(1);
        bcontrol(guiHandle,1,buttonv6,vowID,'red', 30); pause(1);
    else
        pause(0.5);
    end

    %% --------- Update score & write trial line -------------------------
    correct          = (answer == vowID);
    totalCorrect     = totalCorrect + correct;
    totalRespTime    = totalRespTime + respTime;

    fprintf(fidResults,'%d %s %d %d %.4f\n', vowID, f0Label, ...
        answer, correct, respTime);

end

%% ------------------------- FINAL SUMMARY -------------------------------
buttonv6(9).name = 'Run finished.';
bcontrol(guiHandle, 1, buttonv6, 9, 'w', 20);

percentScore  = totalCorrect/howmany * 100;
meanRT        = totalRespTime/howmany;

fprintf('Score: %5.2f %%  |  Mean RT: %5.2f s\n', percentScore, meanRT);

fclose('all');
cd(originalDir);

% End-of-session GUI flash
for k = 1:3
    bcontrol(guiHandle,6,buttonv6,0,'blue',30); pause(0.8);
    bcontrol(guiHandle,6,buttonv6,0,'red', 20); pause(0.8);
end
close all;

closereq;
closereq;

clear;

end  % ------------------------------ CVCmono ------------------------------
