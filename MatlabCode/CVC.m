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
    bits           = 24;
    padSamples     = 2000;
    playScale      = 10^(-31/20);        % Babyface Pro
    maxReplays     = 2;                  % per trial
    buttonToVowel  = [1 2 3 1 2 3 1 2 3];% mapping GUI idx → vowel idx
    vowLabels      = {'IH','EH','AE'};   % order on GUI bottom row
    vowelCodeMap   = containers.Map({'IH','EH','AE'},{1,2,3});
    singleLetter   = containers.Map({'IH','EH','AE'},{'i','e','a'});
    f0Label = containers.Map({'low_f0','high_f0'}, {1,2});
    consonantList = {'d','g','l','f','th','jh'};
    consonantID   = 1:numel(consonantList);

    % ------------------------------------------------------------------------
    %  GUI label overrides for specific CVC triplets
    % ------------------------------------------------------------------------
    cvcLabelMap = containers.Map( ...
        { ...
            'did','ded','dad','dijh','dejh','dajh','dif','def','daf','dish','desh','dash', ...
            'gig','geg','gag','gith','geth','gath','git','get','gat', ...
            'lijh','lejh','lajh','lith','leth','lath','lid','led','lad','lip','lep','lap' ...
        },{ ...
            'did','dead','dad','didge','dedge','dadge','diff','deaf','daff','dish','desh','dash', ...
            'gig','geg','gag','gith','geth','gath','git','get','gat', ...
            'lidge','ledge','ladge','lith','leth','lath','lid','led','lad','lip','lep','lap' ...
        });

    %% =====  BUILD PLAYLIST  (mono + dichotic)  =============================
    stimRoot = '/SoundFiles/CVC2025/Dichotic_Lexical_Fusion_Experiment/actual_stimuli';

    initials = {'D','G','L'};
    finals   = {'D','F','TH','JH','G'};
    vMap     = containers.Map({'a','e','i'},{'AE','EH','IH'});
    f0Names  = {'high_f0','low_f0'};

    monoPairs = round(howmany*0.1);          % e.g. 10 % identical L/R
    pairList  = generate_CVC_dichotic_pairs( ...
                    stimRoot, subjID, initials, finals, vMap, f0Names, ...
                    monoPairs, {'AE','IH'});       % returns Nx2 cell array

    if howmany > size(pairList,1)
        error('Requested %d trials but only %d pairs exist. Reduce *howmany*.',...
              howmany, size(pairList,1));
    end
    pairList = pairList(1:howmany,:);        % crop / random-order preserved




    % -----------------------------------------------------
    if nargin<4, catchflag=0; end
    if nargin<3, audflag  =0; end
    if nargin<2, howmany  =84+(24*catchflag); end

    %% =====  RESULTS FILES  ==================================================
    dataDir = fullfile('/Experiments/Data',subjID); if ~exist(dataDir,'dir'), mkdir(dataDir); end
    cd(dataDir);
    intFile   = fileExistCheck(dir,[subjID '_CVC_0.txt']);
    humanFile = fileExistCheck(dir,[subjID '_CVC_human_readable_0.tsv']);
    fidInt  = fopen(intFile ,'wt');
    fidHum  = fopen(humanFile,'wt');


    ear = 'B';
    audiogram = [];                    % default → empty (= NH)
    if audflag
        fidAudiogram = fopen('Audiogram.txt','r');
        if fidAudiogram == -1, error('Audiogram.txt not found for %s.', subjID); end
        unused_var = fscanf(fidAudiogram, '%i', [8 1])';           % frequencies (unused)
        audiogram  = fscanf(fidAudiogram, '%f', [8 2])';  % rows: L  R
        fclose(fidAudiogram);
        audLeftStr  = strjoin(string(audiogram(1 ,:)), ',');   % e.g. 10,15,20,25,…
        audRightStr = strjoin(string(audiogram(2 ,:)), ',');
    else
        aLeft  = 'NA'; aRight = 'NA';
        audLeftStr  = 'NA';
        audRightStr = 'NA';
    end

    % ----- shared header lines --------------------------------------------
    fprintf(fidInt ,'Ear: %s\n', ear);
    fprintf(fidHum ,'Ear: %s\n', ear);
    if audflag
        fprintf(fidInt ,'Audiogram left  : [%s]\n',sprintf('%.0f ',audiogram(1,:)));
        fprintf(fidInt ,'Audiogram right : [%s]\n',sprintf('%.0f ',audiogram(2,:)));
        fprintf(fidHum ,'Audiogram left  : [%s]\n',sprintf('%.0f ',audiogram(1,:)));
        fprintf(fidHum ,'Audiogram right : [%s]\n',sprintf('%.0f ',audiogram(2,:)));
    else
        fprintf(fidInt ,'Audiogram left  : NA\nAudiogram right : NA\n');
        fprintf(fidHum ,'Audiogram left  : NA\nAudiogram right : NA\n');
    end


    fprintf(fidInt,'# Keys:\n# Consonant_ID  : ');
    for k=1:numel(consonantList)
        fprintf(fidInt,'%s=%d ',consonantList{k},consonantID(k));
    end
    fprintf(fidInt,'\n# Vowel_ID      : IH=1 EH=2 AE=3 \n');
    fprintf(fidInt,'# F0_ID         : high_f0=1 low_f0=2 \n');



    % headers -----------------------------------------------------------------
    fprintf(fidInt,'# Columns       : Trial Con1 Con2 V1 V2 F01 F02 Ans1V Ans2V Ans3V Ans1C Ans2C Ans3C OneType BothOK RT\n');
    fprintf(fidHum,'Trial\tC1\tC2\tVowel1\tVowel2\tF0_1\tF0_2\tAns1V\tAns2V\tAns3V\tAns1C\tAns2C\tAns3C\tAns1\tAns2\tAns3\tOneType\tBothOK\tRT\tEar\tAudiogram_Left\tAudiogram_Right\n');

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
        L = pairList{trial,1};    % {C1,C2,V,f0,path}
        R = pairList{trial,2};

        C1 = L{1};  C2 = L{2};
        V1 = L{3};  V2 = R{3};
        f01= L{4};  f02= R{4};
        f01id = f0Label(f01);
        f02id = f0Label(f02);
        wavL = audioread(L{5});
        wavR = audioread(R{5});

        %% ---- build GUI buttons --------------------------------------------
        for i = 1:3
            keyPhon = lower([C1 singleLetter(vowLabels{i}) C2]);   % e.g. lajh
            if  isKey(cvcLabelMap,keyPhon)
                buttonv6(i).name = cvcLabelMap(keyPhon);           % pretty label
            else
                buttonv6(i).name = keyPhon;                        % fallback
            end
            buttonv6(i+3).name = vowLabels{i};                     % IH / EH / AE
        end

        bcontrol(h,6,buttonv6,0,'red',28);

        %% ---- play  (with optional HL correction) --------------------------
        stereo = pad_and_scale(wavL,wavR,audflag,audiogram,playScale,padSamples);
        buttonv6(9).name=sprintf('Playing trial %d of %d...',trial,howmany);
        bcontrol(h,1,buttonv6,9,'w',20); pause(.7);
        a=audioplayer(stereo,fsPlayback,bits); playblocking(a); pause(.3);

        %% ---- collect up-to-3 answers  -------------------------------------
        buttonv6(9).name="Choose 1-3 sounds you heard ('Repeat' to replay)"; bcontrol(h,1,buttonv6,9,'w',20);
        vowelChosen = false(1,6); replayCnt=0; answers=[]; shp=0; t0=tic;
        while true
            waitButton; idx=shp;
            if idx==7      % ▶ replay
                if replayCnt < maxReplays
                    playblocking(a); replayCnt = replayCnt + 1;
                else                            % -------- inline flash -------------
                    buttonv6(9).name = 'Replay limit reached';
                    bcontrol(h,1,buttonv6,9,'w',20); pause(.6);
                end
            elseif idx <= 6               % a vowel (top or bottom row)
                if ~vowelChosen(idx)
                    if nnz(vowelChosen) < 3            % still room for another choice
                        vowelChosen(idx) = true;
                        answers(end+1)  = idx;
                        bcontrol(h,1,buttonv6,idx,'blue',30);
                    else                               % -------- inline flash --------
                        buttonv6(9).name = 'Max 3 choices';
                        bcontrol(h,1,buttonv6,9,'w',20); pause(.6);
                    end
                else                                    % toggle off
                    vowelChosen(idx) = false;
                    answers(answers == idx) = [];
                    bcontrol(h,1,buttonv6,idx,'red',30);
                end
            elseif idx==8  % ✔ confirm
                    if ~isempty(answers) && numel(answers) <= 3
                        break;
                    else                            % -------- inline flash -------------
                        buttonv6(9).name = 'Pick 1-3';
                        bcontrol(h,1,buttonv6,9,'w',20); pause(.6);
                    end
            end
        end
        RT=toc(t0); rtTot=rtTot+RT;

        %% ---- bookkeeping ---------------------------------------------------
        nAns = numel(answers);
        answers(end+1:3) = -1;                 % pad with –1 placeholders
        ansVowel = -1 * ones(1,3);             % pre-allocate output

        for k = 1:3
            if answers(k) ~= -1                % real button pressed
                ansVowel(k) = buttonToVowel( answers(k) );
                % buttonToVowel is the lookup [1 2 3 1 2 3 1 2 3]
                %                    idx 1-9  →  vowel code 1-3
            end                                % else it stays –1
        end

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
        % ---------- update per-F0-category counters -----------------------------
        if isempty(statsCat.(cat))
            statsCat.(cat) = struct('n',0,'ok1',0,'ok2',0);
        end

        statsCat.(cat).n   = statsCat.(cat).n   + 1;
        hitOne             = ~isempty(intersect(selSet,stimSet));   % ≥1 correct
        statsCat.(cat).ok1 = statsCat.(cat).ok1 + hitOne;
        statsCat.(cat).ok2 = statsCat.(cat).ok2 + bothOK;


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
        fmtInt = '%d %d %d %d %d %d %d %d %d %d %d %d %d %d %.4f\n';
        fmtHum = ['%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t' ...
                    '%s\t%s\t%s\t%d\t%d\t%.4f\t%s\t%s\t%s\n'];
        v1id=vowelCodeMap(V1); v2id=vowelCodeMap(V2);
        fprintf(fidInt,fmtInt,...
                trial, ...
                consonantID(strcmpi(C1,consonantList)), ...
                consonantID(strcmpi(C2,consonantList)), ...
                v1id, v2id, f01id, f02id, ...
                ansVowel, ansCons, oneType, bothOK, RT);


        fprintf(fidHum,fmtHum, ...
                trial, C1,C2,V1,V2,f01,f02, ...
                vowLabels{max(ansVowel(1),1)}, ...
                pick(-1,ansVowel(2),vowLabels), ...
                pick(-1,ansVowel(3),vowLabels), ...
                ansCons(1),ansCons(2),ansCons(3), ...
                pickStr(-1,answers(1),buttonv6), ...
                pickStr(-1,answers(2),buttonv6), ...
                pickStr(-1,answers(3),buttonv6), ...
                oneType,bothOK,RT, ...
                ear,audLeftStr,audRightStr);

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

    percentScore = 100*totOKboth / howmany;   % compute BEFORE clearing

    fclose('all');
    close all;

    clearvars -except percentScore            % keep only the output
end   % =======================  CVC  =======================

function stereo = pad_and_scale(yL,yR,audflag,audiogram,scale,pad)
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
        yL = yL / 10^(28/20);
        yR = yR / 10^(28/20);
    end

    % 4 · leading / trailing zeros and global scale
    stereo = [zeros(pad,2); [yL yR]; zeros(pad,2)] * scale;
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
    if val==-1, out=def; else, out=arr{val}; end
end

function out = pickStr(def,val,bv)
    if val==-1, out='NA'; else, out=bv(val).name; end
end