function pairs = generate_CVC_dichotic_pairs(root, seed, ...
                        initials, finals, vowels, f0_names, ...
                        monoCount, dichoticCount, possibleDichoticVowels)
% Generate stimulus PAIRS for dichotic listening.
%
% pairs = generate_CVC_dichotic_pairs(root, seed, initials, finals, ...
%         vowels, f0_names, monoCount, dichoticCount, ...
%         possibleDichoticVowels)
%
% monoCount: Number of monaural pairs (identical or same vowel/different f0)
% dichoticCount: Number of dichotic pairs (different vowels only)
%
% RETURNS Nx2 cell array; each entry is {C1,C2,V,f0,path}

if nargin < 8 || isempty(dichoticCount)
    dichoticCount = inf;
end
if nargin < 9 || isempty(possibleDichoticVowels)
    possibleDichoticVowels = {'AE','IH'};
end

% Generate all available stimuli
allQuads = generate_CVC_mono_stimuli_quadruplets( ...
                 root, seed, initials, finals, vowels, f0_names);

% Quick lookup
key = @(c1,c2,v,f0) sprintf('%s|%s|%s|%s',c1,c2,v,f0);
quadMap = containers.Map;
for i = 1:size(allQuads,1)
    quadMap(key(allQuads{i,1:4})) = allQuads{i,5};
end

% Seed RNG for reproducibility
if ischar(seed) || isstring(seed)
    seed = sum(double(char(seed)));
end
rng(seed,'twister');

% Initialize pairs
monoPairs = {};
dichoticPairs = {};

f0list = f0_names(:)';
vlist  = upper(possibleDichoticVowels(:)');

%% --------- MONO PAIRS (Identical OR Same Vowel/Diff F0) ---------
monoCandidates = {};

% Find mono pairs candidates
for i = 1:size(allQuads,1)
    C1 = allQuads{i,1};
    C2 = allQuads{i,2};
    V  = allQuads{i,3};
    f0 = allQuads{i,4};

    % Case A: identical stimuli (same file)
    monoCandidates{end+1,1} = {C1,C2,V,f0,quadMap(key(C1,C2,V,f0))}; %#ok<*AGROW>
    monoCandidates{end,2}   = monoCandidates{end,1};

    % Case B: same vowel, different f0
    for f0b = f0list
        if strcmp(f0b{1},f0), continue; end
        k2 = key(C1,C2,V,f0b{1});
        if quadMap.isKey(k2)
            q2 = {C1,C2,V,f0b{1},quadMap(k2)};
            monoCandidates(end+1,:) = {allQuads(i,:), q2};
        end
    end
end

% Ensure requested monoCount doesn't exceed available candidates
if monoCount > size(monoCandidates,1)
    error('Requested %d mono pairs, but only %d available.', monoCount, size(monoCandidates,1));
end
pickMono = randperm(size(monoCandidates,1), monoCount);
monoPairs = monoCandidates(pickMono,:);

%% --------- DICHOTIC PAIRS (Different vowels only) ---------
for i = 1:size(allQuads,1)
    C1 = allQuads{i,1};
    C2 = allQuads{i,2};
    V  = allQuads{i,3};
    f0 = allQuads{i,4};

    if ~ismember(V, vlist), continue; end

    % Different vowel, same f0
    for Vb = vlist
        if strcmp(Vb{1},V), continue; end
        k2 = key(C1,C2,Vb{1},f0);
        if quadMap.isKey(k2)
            q2 = {C1,C2,Vb{1},f0, quadMap(k2)};
            dichoticPairs(end+1,:) = {allQuads(i,:), q2};
        end
    end

    % Different vowel, different f0
    for Vb = vlist
        if strcmp(Vb{1},V), continue; end
        for f0b = f0list
            if strcmp(f0b{1},f0), continue; end
            k2 = key(C1,C2,Vb{1},f0b{1});
            if quadMap.isKey(k2)
                q2 = {C1,C2,Vb{1},f0b{1}, quadMap(k2)};
                dichoticPairs(end+1,:) = {allQuads(i,:), q2};
            end
        end
    end
end

% Ensure dichoticCount doesn't exceed available dichotic pairs
if isfinite(dichoticCount)
    if dichoticCount > size(dichoticPairs,1)
        error('Requested %d dichotic pairs, only %d available.', dichoticCount, size(dichoticPairs,1));
    end
    pickDichotic = randperm(size(dichoticPairs,1), dichoticCount);
    dichoticPairs = dichoticPairs(pickDichotic,:);
end

%% --------- Combine and Shuffle All Pairs ---------
pairs = [monoPairs ; dichoticPairs];
order = randperm(size(pairs,1));
pairs = pairs(order,:);

end
