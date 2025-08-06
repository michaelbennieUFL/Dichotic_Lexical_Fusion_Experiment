function percentScore = CVC(subjID, BinauralPairCount, audflag, monoPairCount)
    % CVC  Dichotic / diotic concurrent-vowel identification (up to 3 answers).
    % Scores & console summaries are computed for dichotic (different-vowel) trials only.

    % ===== USER CONSTANTS =====
    fsPlayback     = 44100;
    bits           = 24;
    padSamples     = 2000;
    playScaleLeft  = 10^(-40/20);   % attenuations for Babyface Pro
    playScaleRight = 10^(-42/20);
    maxReplays     = 2;

    buttonToVowel  = [1 2 3 1 2 3 1 2 3];
    vowLabels      = {'IH','EH','AE'};
    vowelCodeMap   = containers.Map({'IH','EH','AE'},{1,2,3});
    singleLetter   = containers.Map({'IH','EH','AE'},{'i','e','a'});
    f0Label        = containers.Map({'low_f0','high_f0'}, {1,2});

    consonantList = {'d','g','l','f','th','jh','p','sh','t'};
    consonantID   = 1:numel(consonantList);

    if nargin<4, monoPairCount=33; end
    if nargin<3, audflag=0; end
    if nargin<2, BinauralPairCount=66+monoPairCount; end

    % ===== LABEL OVERRIDES =====
    cvcLabelMap = containers.Map( ...
        {'did','ded','dad','dijh','dejh','dajh','dif','def','daf','dish','desh','dash', ...
         'gig','geg','gag','gith','geth','gath','git','get','gat', ...
         'lijh','lejh','lajh','lith','leth','lath','lid','led','lad','lip','lep','lap'}, ...
        {'did','dead','dad','didge','dedge','dadge','diff','deaf','daff','dish','desh','dash', ...
         'gig','geg','gag','gith','geth','gath','git','get','gat', ...
         'lidge','ledge','ladge','lith','leth','lath','lid','led','lad','lip','lep','lap'} );

    % ===== BUILD PLAYLIST =====
    stimRoot = '/SoundFiles/CVC2025/Dichotic_Lexical_Fusion_Experiment/actual_stimuli';
    initials = {'D','G','L'};
    finals   = {'D','F','TH','JH','G','P','SH','T'};
    vMap     = containers.Map({'a','e','i'},{'AE','EH','IH'});
    f0Names  = {'high_f0','low_f0'};

    pairList = generate_CVC_dichotic_pairs( ...
                    stimRoot, subjID, initials, finals, vMap, f0Names, ...
                    monoPairCount, BinauralPairCount, {'AE','IH'});

    totalTrials = BinauralPairCount + monoPairCount;
    if totalTrials > size(pairList,1)
        error('Requested %d trials but only %d pairs exist.', totalTrials, size(pairList,1));
    end
    pairList = pairList(1:totalTrials ,:);

    % ===== RESULTS FILES =====
    dataDir = fullfile('/Experiments/Data',subjID);
    if ~exist(dataDir,'dir'), mkdir(dataDir); end
    cd(dataDir);
    intFile   = fileExistCheck(dir,[subjID '_CVC_0.txt']);
    humanFile = fileExistCheck(dir,[subjID '_CVC_human_readable_0.tsv']);
    fidInt  = fopen(intFile ,'wt');
    fidHum  = fopen(humanFile,'wt');

    ear = 'B';
    audiogram = [];
    if audflag
        fidAudiogram = fopen('Audiogram.txt','r');
        if fidAudiogram == -1, error('Audiogram.txt not found.'); end
        unused_var = fscanf(fidAudiogram, '%i', [8 1])';
        audiogram  = fscanf(fidAudiogram, '%f', [8 2])';
        fclose(fidAudiogram);
        audLeftStr  = strjoin(string(audiogram(1 ,:)), ',');
        audRightStr = strjoin(string(audiogram(2 ,:)), ',');
    else
        audLeftStr  = 'NA'; audRightStr = 'NA';
    end

    fprintf(fidInt ,'Ear: %s\n', ear);
    fprintf(fidHum ,'Ear: %s\n', ear);
    fprintf(fidInt ,'Audiogram left  : %s\nAudiogram right : %s\n', audLeftStr, audRightStr);
    fprintf(fidHum ,'Audiogram left  : %s\nAudiogram right : %s\n', audLeftStr, audRightStr);

    fprintf(fidInt,'# Keys:\n# Consonant_ID  : ');
    for k=1:numel(consonantList)
        fprintf(fidInt,'%s=%d ',consonantList{k},consonantID(k));
    end
    fprintf(fidInt,'\n# Vowel_ID      : IH=1 EH=2 AE=3 \n');
    fprintf(fidInt,'# F0_ID         : high_f0=1 low_f0=2 \n');

    fprintf(fidInt,'# Columns       : Trial Con1 Con2 V1 V2 F01 F02 Ans1V Ans2V Ans3V Ans1C Ans2C Ans3C OneType BothOK RT\n');
    fprintf(fidHum,'Trial\tC1\tC2\tVowel1\tVowel2\tF0_1\tF0_2\tAns1V\tAns2V\tAns3V\tAns1C\tAns2C\tAns3C\tAns1\tAns2\tAns3\tOneType\tBothOK\tRT\tEar\tAudiogram_Left\tAudiogram_Right\n');

    % ===== GUI SETUP =====
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

    % ===== DICHOTIC COUNTERS =====
    totOK1_dich = 0;
    totOKboth_dich = 0;
    totalDichoticTrials = 0;
    statsCat_dich = struct('lowlow',[],'highhigh',[],'alt',[]);
    tally_dich = struct;
    rtTot = 0;

    % ===== MAIN LOOP =====
    for trial = 1:totalTrials
        L = pairList{trial,1}; R = pairList{trial,2};
        C1 = L{1}; C2 = L{2};
        V1 = L{3}; V2 = R{3};
        f01= L{4}; f02= R{4};
        f01id = f0Label(f01); f02id = f0Label(f02);
        wavL = audioread(L{5}); wavR = audioread(R{5});

        % GUI button labels
        for i = 1:3
            keyPhon = lower([C1 singleLetter(vowLabels{i}) C2]);
            if isKey(cvcLabelMap,keyPhon)
                buttonv6(i).name = cvcLabelMap(keyPhon);
            else
                buttonv6(i).name = keyPhon;
            end
            buttonv6(i+3).name = vowLabels{i};
        end
        bcontrol(h,6,buttonv6,0,'red',28);

        % Play audio
        stereo = pad_and_scale(wavL,wavR,audflag,audiogram,playScaleLeft,playScaleRight,padSamples);
        buttonv6(9).name=sprintf('Playing trial %d of %d...',trial,totalTrials);
        bcontrol(h,1,buttonv6,9,'w',20);
        a=audioplayer(stereo,fsPlayback,bits); playblocking(a);

        % Collect answers
        buttonv6(9).name="Choose 1-3 sounds you heard ('Repeat' to replay)";
        bcontrol(h,1,buttonv6,9,'w',20);
        vowelChosen = false(1,6); replayCnt=0; answers=[]; shp=0; t0=tic;
        while true
            waitButton; idx=shp;
            if idx==7 && replayCnt < maxReplays
                playblocking(a); replayCnt = replayCnt + 1;
            elseif idx <= 6
                if ~vowelChosen(idx)
                    if nnz(vowelChosen) < 3
                        vowelChosen(idx) = true;
                        answers(end+1)  = idx;
                        bcontrol(h,1,buttonv6,idx,'blue',30);
                    end
                else
                    vowelChosen(idx) = false;
                    answers(answers == idx) = [];
                    bcontrol(h,1,buttonv6,idx,'red',30);
                end
            elseif idx==8
                if ~isempty(answers) && numel(answers) <= 3, break; end
            end
        end
        RT=toc(t0); rtTot=rtTot+RT;

        % Bookkeeping
        answers(end+1:3) = -1;
        ansVowel = -1 * ones(1,3);
        for k = 1:3
            if answers(k) ~= -1
                ansVowel(k) = buttonToVowel(answers(k));
            end
        end
        ansCons  = answers<=3 & answers~=-1; ansCons(end+1:3)=0;
        oneType  = all(ansVowel(ansVowel~=-1)==ansVowel(find(ansVowel~=-1,1)));
        stimSet  = unique([vowelCodeMap(V1) vowelCodeMap(V2)]);
        selSet   = unique(ansVowel(ansVowel~=-1));
        bothOK   = isequal(sort(stimSet),sort(selSet));

        % Only score dichotic trials
        if ~strcmp(V1, V2)
            totalDichoticTrials = totalDichoticTrials + 1;
            if any(ismember(selSet, stimSet)), totOK1_dich = totOK1_dich + 1; end
            if bothOK, totOKboth_dich = totOKboth_dich + 1; end

            cat = pickCategory(f01id,f02id);
            if isempty(statsCat_dich.(cat))
                statsCat_dich.(cat) = struct('n',0,'ok1',0,'ok2',0);
            end
            Sd = statsCat_dich.(cat);
            Sd.n = Sd.n + 1;
            Sd.ok1 = Sd.ok1 + ~isempty(intersect(selSet,stimSet));
            Sd.ok2 = Sd.ok2 + bothOK;
            statsCat_dich.(cat) = Sd;

            % Consonant pair tally
            keyCC = sprintf('%s_%s',C1,C2);
            if ~isfield(tally_dich,keyCC)
                tally_dich.(keyCC)=struct('both',0,'one',0,'N',0,'IH',0,'EH',0,'AE',0);
            end
            tall = tally_dich.(keyCC);
            tall.N  = tall.N + 1;
            tall.both = tall.both + bothOK;
            tall.one  = tall.one  + oneType;
            for v=selSet
                if v==1, tall.IH=tall.IH+1;
                elseif v==2, tall.EH=tall.EH+1;
                else, tall.AE=tall.AE+1;
                end
            end
            tally_dich.(keyCC)=tall;
        end

        % Write files
        v1id=vowelCodeMap(V1); v2id=vowelCodeMap(V2);
        fprintf(fidInt,'%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %.4f\n',...
                trial, consonantID(strcmpi(C1,consonantList)), ...
                consonantID(strcmpi(C2,consonantList)), v1id, v2id, ...
                f01id, f02id, ansVowel, ansCons, oneType, bothOK, RT);

        fprintf(fidHum,'%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%s\t%s\t%s\t%d\t%d\t%.4f\t%s\t%s\t%s\n',...
                trial, C1,C2,V1,V2,f01,f02, ...
                pick('NaN', ansVowel(1), vowLabels), pick('NaN', ansVowel(2), vowLabels), pick('NaN', ansVowel(3), vowLabels), ...
                ansCons(1),ansCons(2),ansCons(3), ...
                pickStr('NaN', answers(1), buttonv6), pickStr('NaN', answers(2), buttonv6), pickStr('NaN', answers(3), buttonv6), ...
                oneType,bothOK,RT,ear,audLeftStr,audRightStr);
    end

    % ===== SUMMARY: DICHOTIC ONLY =====
    fprintf('\n=== DICHOTIC‑ONLY SUMMARY (different vowels only) ===\n');
    if totalDichoticTrials > 0
        fprintf('Avg ≥1 correct:  %5.2f %%\n', 100 * totOK1_dich / totalDichoticTrials);
        fprintf('Both correct:    %5.2f %%\n', 100 * totOKboth_dich / totalDichoticTrials);
    else
        fprintf('No dichotic trials were included.\n');
    end

    cats = {'lowlow','highhigh','alt'};
    for ci = 1:numel(cats)
        c = cats{ci};
        Sd = statsCat_dich.(c);
        if isempty(Sd), N = 0; ok1 = 0; ok2 = 0;
        else, N = Sd.n; ok1 = Sd.ok1; ok2 = Sd.ok2; end
        fprintf('%8s  N=%3d  ≥1corr=%5.2f %%  both=%5.2f %%\n', ...
                c, N, 100 * ok1 / max(N,1), 100 * ok2 / max(N,1));
    end

    fprintf('\nC1  C2   both%%  one%%  IH%%  EH%%  AE%%\n');
    keys=fieldnames(tally_dich);
    for k=1:numel(keys)
        T=tally_dich.(keys{k}); parts=split(keys{k},'_');
        fprintf('%-2s  %-2s  %5.2f  %5.2f  %5.2f  %5.2f  %5.2f\n',...
                upper(parts{1}),upper(parts{2}),...
                100*T.both/max(T.N,1), 100*T.one/max(T.N,1), ...
                100*T.IH/max(T.N,1), 100*T.EH/max(T.N,1), 100*T.AE/max(T.N,1));
    end

    % Percent score
    if totalDichoticTrials > 0
        percentScore = 100 * totOKboth_dich / totalDichoticTrials;
    else
        percentScore = NaN;
    end

    fclose('all'); close all;
    clearvars -except percentScore
end


function stereo = pad_and_scale(yL,yR,audflag,audiogram,scale_l,scale_r,pad)
    % 1 · force column vectors
    yL = yL(:); yR = yR(:);

    % 2 · match durations
    N  = max(numel(yL),numel(yR));
    if numel(yL)<N, yL(end+1:N)=0; end
    if numel(yR)<N, yR(end+1:N)=0; end

    % 3 · HL compensation (only if audiogram provided)
    if audflag && ~isempty(audiogram)
        [yL,~,~] = ampstim(yL,44100,audiogram(1,:));   % left ear
        [yR,~,~] = ampstim(yR,44100,audiogram(2,:));   % right ear
        % CV divides by 10^(28/20) afterwards — keep it for consistency
        yL = yL  / 10^(28/20);
        yR = yR  / 10^(28/20) ;
    end

    % 4 · leading / trailing zeros and global scale
    stereo = [zeros(pad,2); [yL *scale_l, yR *scale_r]; zeros(pad,2)];
end



function flash(h,idx,msg)
    global buttonv6

    buttonv6(idx).name = msg; % update label
    bcontrol(h,1,buttonv6,idx,'w',20);  % works for every button (1–9)
    pause(0.6);
end



function cat = pickCategory(f01,f02)
    if  f01==1 && f02==1,        cat='lowlow';
    elseif f01==2 && f02==2,     cat='highhigh';
    else,                        cat='alt'; end
end

function out = pick(def,val,arr)
    if nargin < 1 || isempty(def), def = 'NaN'; end
    if val==-1, out=def; else, out=arr{val}; end
end

function out = pickStr(def,val,bv)
    if nargin < 1 || isempty(def), def = 'NaN'; end
    if val==-1, out=def; else, out=bv(val).name; end
end
