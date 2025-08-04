function pairs = generate_CVC_dichotic_pairs(root, seed, ...
                    initials, finals, vowels, f0_names, ...
                    monoCount, possibleDichoticVowels)
% Generate stimulus PAIRS for dichotic listening.
%
%   pairs = generate_CVC_dichotic_pairs(root, seed, initials, finals, ...
%              vowels, f0_names, monoCount, possibleDichoticVowels)
%
%   *root*                    : folder that contains the *_run sub-folders
%   *seed*                    : fixes shuffle order
%   *initials*,*finals*       : legal onset / coda sets (cellstr, upper-case)
%   *vowels*                  : containers.Map single-letter → ARPABET
%   *f0_names*                : e.g. {'high_f0','low_f0'}
%   *monoCount*               : # monaural pairs (identical L/R)
%   *possibleDichoticVowels*  : e.g. {'AE','IH'}
%
%   RETURNS   Nx2 cell array; each entry is {C1,C2,V,f0,path}

if nargin < 8 || isempty(possibleDichoticVowels)
    possibleDichoticVowels = {'AE','IH'};
end

% ---------- 1. list ALL individual tokens (reuse your mono helper) ------
allQuads = generate_CVC_mono_stimuli_quadruplets( ...
                 root, seed, initials, finals, vowels, f0_names);

% quick index for lookup:  map 'C1|C2|V|f0' -> path
key = @(c1,c2,v,f0) sprintf('%s|%s|%s|%s',c1,c2,v,f0);
quadMap = containers.Map;
for i = 1:size(allQuads,1)
    quadMap(key(allQuads{i,1:4})) = allQuads{i,5};
end

rng(seed,'twister');

pairs = {};

% ---------- 2. MONAURAL --------------------------------------------------
monoOrder = randperm(size(allQuads,1), min(monoCount,size(allQuads,1)));
for k = monoOrder
    q = allQuads(k,:);
    pairs(end+1,1:2) = {q, q}; %#ok<AGROW>
end

% ---------- 3. DICHOTIC  -------------------------------------------------
f0list = f0_names(:)';                   % row cell
vlist  = upper(possibleDichoticVowels(:)');

for i = 1:size(allQuads,1)
    C1 = allQuads{i,1};  C2 = allQuads{i,2};
    V  = allQuads{i,3};  f0 = allQuads{i,4};
    p1 = allQuads{i,5};

    % skip vowels not in dichotic set
    if ~ismember(V,vlist), continue; end

    % ---- D1: same V, diff f0 ------------------------------------------
    for f0b = f0list
        if strcmp(f0b,f0), continue; end
        k2 = key(C1,C2,V,f0b{1});
        if quadMap.isKey(k2)
            q2 = {C1,C2,V,f0b{1}, quadMap(k2)};
            pairs(end+1,:) = {allQuads(i,:), q2}; %#ok<AGROW>
        end
    end

    % ---- D3: same f0, diff V ------------------------------------------
    for Vb = vlist
        if strcmp(Vb,V), continue; end
        k2 = key(C1,C2,Vb{1},f0);
        if quadMap.isKey(k2)
            q2 = {C1,C2,Vb{1},f0, quadMap(k2)};
            pairs(end+1,:) = {allQuads(i,:), q2}; %#ok<AGROW>
        end
    end

    % ---- D2: diff V AND diff f0 ---------------------------------------
    for Vb = vlist
        if strcmp(Vb,V), continue; end
        for f0b = f0list
            if strcmp(f0b,f0), continue; end
            k2 = key(C1,C2,Vb{1},f0b{1});
            if quadMap.isKey(k2)
                q2 = {C1,C2,Vb{1},f0b{1}, quadMap(k2)};
                pairs(end+1,:) = {allQuads(i,:), q2}; %#ok<AGROW>
            end
        end
    end
end

% reproducible shuffle of final list
order = randperm(size(pairs,1));
pairs = pairs(order,:);
end
