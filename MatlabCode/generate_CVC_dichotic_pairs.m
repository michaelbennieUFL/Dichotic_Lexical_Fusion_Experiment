function pairs = generate_CVC_dichotic_pairs(root, seed, ...
                        initials, finals, vowels, f0_names, ...
                        monoCount, dichoticCount, possibleDichoticVowels)
% Generate stimulus PAIRS for dichotic listening.
%
%   pairs = generate_CVC_dichotic_pairs(root, seed, initials, finals, ...
%              vowels, f0_names, monoCount, dichoticCount, ...
%              possibleDichoticVowels)
%
%   *monoCount*      : Number of monaural (identical L/R) pairs.
%   *dichoticCount*  : Number of dichotic (L≠R) pairs.
%                      (omit or [] to return all available dichotic pairs)
%   *possibleDichoticVowels* : Cell array of vowels (e.g., {'AE','IH'})
%
%   RETURNS Nx2 cell array; each entry is {C1,C2,V,f0,path}

if nargin < 8 || isempty(dichoticCount)
    dichoticCount = inf;  % Default: all dichotic pairs
end
if nargin < 9 || isempty(possibleDichoticVowels)
    possibleDichoticVowels = {'AE','IH'};
end

% Generate full list of stimuli
allQuads = generate_CVC_mono_stimuli_quadruplets( ...
                 root, seed, initials, finals, vowels, f0_names);

% Create quick lookup map: key -> file path
key = @(c1,c2,v,f0) sprintf('%s|%s|%s|%s',c1,c2,v,f0);
quadMap = containers.Map;
for i = 1:size(allQuads,1)
    quadMap(key(allQuads{i,1:4})) = allQuads{i,5};
end

% Seed RNG for reproducibility
if ischar(seed) || isstring(seed)
    seed = sum(double(char(seed)));   % deterministic hash
end
rng(seed,'twister');

% Separate lists for mono and dichotic pairs
monoPairs     = {};
dichoticPairs = {};

% ---------- Select exactly 'monoCount' monaural pairs ----------
if monoCount > size(allQuads,1)
    error('Requested %d mono pairs, only %d tokens available.', monoCount, size(allQuads,1));
end
monoOrder = randperm(size(allQuads,1), monoCount);
for k = monoOrder
    q = allQuads(k,:);
    monoPairs(end+1,1:2) = {q, q}; %#ok<AGROW>
end

% ---------- Generate candidate dichotic pairs ----------
f0list = f0_names(:)';
vlist  = upper(possibleDichoticVowels(:)');

for i = 1:size(allQuads,1)
    C1 = allQuads{i,1};  C2 = allQuads{i,2};
    V  = allQuads{i,3};  f0 = allQuads{i,4};

    % Skip vowels not allowed for dichotic stimuli
    if ~ismember(V, vlist), continue; end

    % -- Dichotic Type 1: same vowel, different f0 --
    for f0b = f0list
        if strcmp(f0b{1}, f0), continue; end
        k2 = key(C1,C2,V,f0b{1});
        if quadMap.isKey(k2)
            q2 = {C1,C2,V,f0b{1}, quadMap(k2)};
            dichoticPairs(end+1,:) = {allQuads(i,:), q2}; %#ok<AGROW>
        end
    end

    % -- Dichotic Type 2: different vowel, same f0 --
    for Vb = vlist
        if strcmp(Vb{1}, V), continue; end
        k2 = key(C1,C2,Vb{1},f0);
        if quadMap.isKey(k2)
            q2 = {C1,C2,Vb{1},f0, quadMap(k2)};
            dichoticPairs(end+1,:) = {allQuads(i,:), q2}; %#ok<AGROW>
        end
    end

    % -- Dichotic Type 3: different vowel, different f0 --
    for Vb = vlist
        if strcmp(Vb{1},V), continue; end
        for f0b = f0list
            if strcmp(f0b{1},f0), continue; end
            k2 = key(C1,C2,Vb{1},f0b{1});
            if quadMap.isKey(k2)
                q2 = {C1,C2,Vb{1},f0b{1}, quadMap(k2)};
                dichoticPairs(end+1,:) = {allQuads(i,:), q2}; %#ok<AGROW>
            end
        end
    end
end

% ---------- Randomly sample dichotic pairs if dichoticCount specified ----------
if isfinite(dichoticCount)
    if dichoticCount > size(dichoticPairs,1)
        error('Requested %d dichotic pairs, only %d available.', dichoticCount, size(dichoticPairs,1));
    end
    pick = randperm(size(dichoticPairs,1), dichoticCount);
    dichoticPairs = dichoticPairs(pick,:);
end

% ---------- Combine & shuffle mono + dichotic pairs ----------
pairs = [monoPairs ; dichoticPairs];
order = randperm(size(pairs,1));
pairs = pairs(order,:);
end
