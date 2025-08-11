function pairs = generate_CVC_dichotic_pairs(root, seed, ...
                        initials, finals, vowels, f0_names, ...
                        monoCount, dichoticCount, possibleDichoticVowels)
% generate_CVC_dichotic_pairs: Generates pairs of stimuli for dichotic experiments.
%
% pairs = generate_CVC_dichotic_pairs(root, seed, initials, finals, ...
%         vowels, f0_names, monoCount, dichoticCount, possibleDichoticVowels)
%
% monoCount:      Number of monaural pairs (identical or same vowel/different f0)
% dichoticCount:  Number of dichotic pairs (different vowels only)
%
% RETURNS Nx2 cell array; each entry: {C1,C2,V,f0,path}
% Michael Bennie 8/9 Fixed sampling



if nargin < 8 || isempty(dichoticCount)
    dichoticCount = inf;
end
if nargin < 9 || isempty(possibleDichoticVowels)
    possibleDichoticVowels = {'AE','IH'};
end

%% Generate all available stimuli
allQuads = generate_CVC_mono_stimuli_quadruplets( ...
                 root, seed, initials, finals, vowels, f0_names);

quadMap = containers.Map();
key = @(c1,c2,v,f0) sprintf('%s|%s|%s|%s',c1,c2,v,f0);
for i = 1:size(allQuads,1)
    quadMap(key(allQuads{i,1:4})) = allQuads{i,5};
end

%% Seed RNG for reproducibility
if ischar(seed) || isstring(seed)
    seed = sum(double(char(seed)));
end
rng(seed,'twister');

f0list = f0_names(:)';
vlist  = upper(possibleDichoticVowels(:)');

desired_f0_1 = 'low_f0';
other_f0s = setdiff(f0list, {desired_f0_1});  % e.g., {'high_f0'} if you have 2 F0s


%% --------- Generate Mono Pairs (Identical or Same Vowel/Diff F0) ---------
diffF0Pairs = {};
identicalPairs = {};

for i = 1:size(allQuads,1)
    C1 = allQuads{i,1};
    C2 = allQuads{i,2};
    V  = allQuads{i,3};
    f0 = allQuads{i,4};

    % Same vowel, different f0
    for f0b = other_f0s
        if strcmp(f0b{1},f0), continue; end
        k2 = key(C1,C2,V,f0b{1});
        if quadMap.isKey(k2)
            q2 = {C1,C2,V,f0b{1},quadMap(k2)};
            diffF0Pairs(end+1,:) = {allQuads(i,:), q2};
        end
    end

    % Identical stimuli (same file)
    identicalPairs(end+1,:) = {allQuads(i,:), allQuads(i,:)};
end

fprintf('[DEBGU] different F0/ same vowel pairs: %d\n',size(diffF0Pairs,1));
fprintf('[DEBGU] same F0/ same vowel pairs: %d\n',size(identicalPairs,1));

% Select mono pairs
requiredDiffF0 = min(33, monoCount);
if size(diffF0Pairs,1) < requiredDiffF0
    error('Not enough "same vowel, different f0" mono pairs to satisfy first %d slots.', requiredDiffF0);
end

% Randomly select requiredDiffF0 from diffF0Pairs
pickDiffF0 = randperm(size(diffF0Pairs,1), requiredDiffF0);
monoPairs = diffF0Pairs(pickDiffF0,:);

% If more needed, fill in with identicalPairs
remainingMono = monoCount - requiredDiffF0;
if remainingMono > 0
    if size(identicalPairs,1) < remainingMono
        error('Not enough identical mono pairs to fill the remaining %d slots.', remainingMono);
    end
    pickIdentical = randperm(size(identicalPairs,1), remainingMono);
    monoPairs = [monoPairs; identicalPairs(pickIdentical,:)];
end

%% --------- Generate Dichotic Pairs (Different vowels only) ---------
dichoticCandidates = {};

for i = 1:size(allQuads,1)
    C1 = allQuads{i,1};
    C2 = allQuads{i,2};
    V  = allQuads{i,3};
    f0 = allQuads{i,4};

    % Skip vowels not in allowed list
    if ~ismember(V,vlist), continue; end

    % Different vowel, same f0
    for Vb = vlist
        if strcmp(Vb{1},V), continue; end
        k2 = key(C1,C2,Vb{1},f0);
        if quadMap.isKey(k2)
            q2 = {C1,C2,Vb{1},f0,quadMap(k2)};
            dichoticCandidates(end+1,:) = {allQuads(i,:), q2};
        end
    end
    
    % Different vowel, different f0
    for Vb = vlist
        if strcmp(Vb{1},V), continue; end
        for f0b = other_f0s
            if strcmp(f0b{1},f0), continue; end
            k2 = key(C1,C2,Vb{1},f0b{1});
            if quadMap.isKey(k2)
                q2 = {C1,C2,Vb{1},f0b{1},quadMap(k2)};
                dichoticCandidates(end+1,:) = {allQuads(i,:), q2};
            end
        end
    end
    
end
fprintf('[DEBGU] dichotic vowel pairs: %d\n',size(dichoticCandidates,1));

% Check if enough dichotic candidates are available
if isfinite(dichoticCount)
    if dichoticCount > size(dichoticCandidates,1)
        error('Requested %d dichotic pairs, only %d available.', ...
            dichoticCount, size(dichoticCandidates,1));
    end
    pickDichotic = randperm(size(dichoticCandidates,1), dichoticCount);
    dichoticPairs = dichoticCandidates(pickDichotic,:);
else
    dichoticPairs = dichoticCandidates;
end

%% --------- Combine and Randomize All Pairs ---------
pairs = [monoPairs; dichoticPairs];
pairs = pairs(randperm(size(pairs,1)),:);

end