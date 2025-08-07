function quads = generate_CVC_mono_stimuli_quadruplets(folder_location, seed, ...
                                      initials, finals, vowels, f0_names)
%fprintf('\n[DEBUG] Starting stimulus scan in: %s\n', folder_location);

% Ensure paths and inputs are consistent
root = fullfile(folder_location);
if ~isfolder(root)
    error('[ERROR] Root folder does not exist: %s', root);
end
%fprintf('[DEBUG] Root folder verified: %s\n', root);

% Ensure uppercase for matching (stay as cell array)
initials = cellfun(@upper, initials, 'UniformOutput', false);
finals   = cellfun(@upper, finals, 'UniformOutput', false);
f0_names_lower = lower(f0_names);

%fprintf('[DEBUG] Looking for F0 folders matching: %s\n', strjoin(f0_names_lower, ', '));

% Find all candidate wav files
files = dir(fullfile(root, '**', 'cvc_variant_*_Optimized.wav'));
%fprintf('[DEBUG] Found %d candidate wav files.\n', length(files));

quads = {};  % will hold rows {C1,C2,V,f0,path}

% Loop over files
for i = 1:length(files)
    wavPath = fullfile(files(i).folder, files(i).name);
%    fprintf('[DEBUG] Checking file: %s\n', wavPath);

    % --- Extract vowel from filename
    token = regexp(files(i).name, ...
        'cvc_variant_[A-Z]+_(?:discordant_)?([A-Z]+)_Optimized\.wav$', ...
        'tokens', 'once');
    if isempty(token)
%        fprintf('[DEBUG]   -> Skipped (no vowel token match)\n');
        continue;
    end
    V = upper(token{1});
%    fprintf('[DEBUG]   -> Vowel extracted: %s\n', V);

    % --- Extract f0 (check folder names)
    pathParts = strsplit(files(i).folder, filesep);
    f0Idx = find(ismember(lower(pathParts), f0_names_lower), 1, 'last');
    if isempty(f0Idx)
%        fprintf('[DEBUG]   -> Skipped (no F0 folder match)\n');
        continue;
    end
    f0 = pathParts{f0Idx};
%    fprintf('[DEBUG]   -> F0 extracted: %s\n', f0);

    % -------- Word folder (look *below* the f0 folder) ------------------
    wordFolder = '';   % will hold the folder that yields valid C1 & C2
    C1 = '';  C2 = '';

    for wIdx = f0Idx+1 : length(pathParts)          % walk downward
        cand = lower(pathParts{wIdx});              % candidate folder
        % ---- C1 (initial) ----
        C1tmp = '';
        for c = initials
            if startsWith(cand, lower(c{:}))
                C1tmp = c{:};
                break;
            end
        end
        % ---- C2 (final)  ----
        C2tmp = '';
        hit   = {};
        for c = finals
            if endsWith(cand, lower(c{:}))
                hit{end+1} = c{:}; %#ok<AGROW>
            end
        end
        if ~isempty(hit)
            [~,idx] = max(cellfun(@length, hit));
            C2tmp   = hit{idx};
        end

        if ~isempty(C1tmp) && ~isempty(C2tmp)
            % success: keep this folder
            wordFolder = cand;
            C1 = C1tmp;  C2 = C2tmp;
            break;
        end
    end

    if isempty(wordFolder)
%        fprintf('[DEBUG]   -> Skipped (no folder satisfied C1 & C2)\n');
        continue;
    end
%    fprintf('[DEBUG]   -> Word folder: %s  |  C1=%s  C2=%s\n', ...
%            wordFolder, C1, C2);

    % --- Append to results
%    fprintf('[DEBUG]   -> Added Quad: {%s, %s, %s, %s}\n', C1, C2, V, f0);
    quads(end+1,:) = {C1, C2, V, f0, wavPath}; %#ok<AGROW>
end

fprintf('[DEBUG] Total usable quads: %d\n', size(quads,1));
if isempty(quads)
    warning('[DEBUG] No usable quads found. Check consonant lists or folder structure.');
end

% Shuffle reproducibly
if ischar(seed) || isstring(seed)
    numericSeed = sum(double(char(seed)));  % simple hash
else
    numericSeed = seed;
end
rng(numericSeed, 'twister');  % ensure reproducible sequence
order = randperm(size(quads,1));
quads = quads(order,:);

%fprintf('[DEBUG] Quads shuffled.\n');
end
