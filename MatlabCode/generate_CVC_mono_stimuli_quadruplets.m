function quads = generate_CVC_mono_stimuli_quadruplets(folder_location, seed, ...
                                      initials, finals, vowels, f0_names)
% generate_CVC_mono_stimuli_quadruplets
% Return reproducible random permutation of all stimulus files as
% quadruplets (C1, C2, V, f0, path).
%
% INPUTS
%   folder_location : char
%       Root directory containing *_run sub-folders
%   seed : scalar or char
%       Random seed for reproducible shuffle
%   initials : cellstr
%       Legal onset consonants (e.g., {'D','G','L'})
%   finals : cellstr
%       Legal coda consonants (e.g., {'D','F','TH','JH','G'})
%   vowels : containers.Map
%       Mapping from orthographic vowel to ARPABET
%   f0_names : cellstr
%       Folder names encoding f0 (e.g., {'high_f0','low_f0'})
%
% OUTPUT
%   quads : cell array
%       Each row: {C1, C2, V, f0, path}

% Ensure paths and inputs are consistent
root = fullfile(folder_location);
if ~isfolder(root)
    error('Root folder does not exist: %s', root);
end

% Ensure uppercase for matching
initials = upper(initials);
finals   = upper(finals);
f0_names_lower = lower(f0_names);

% Find all candidate wav files
files = dir(fullfile(root, '**', 'cvc_variant_*_Optimized.wav'));

quads = {};  % will hold rows {C1,C2,V,f0,path}

% Loop over files
for i = 1:length(files)
    wavPath = fullfile(files(i).folder, files(i).name);

    % --- Extract vowel from filename
    token = regexp(files(i).name, 'cvc_variant_[A-Z]+_([A-Z]+)_Optimized\.wav$', 'tokens', 'once');
    if isempty(token)
        continue;
    end
    V = upper(token{1});

    % --- Extract f0 (check folder names)
    pathParts = strsplit(files(i).folder, filesep);
    f0Idx = find(ismember(lower(pathParts), f0_names_lower), 1, 'last');
    if isempty(f0Idx)
        continue;
    end
    f0 = pathParts{f0Idx};

    % --- Word folder (assume one above f0)
    if f0Idx <= 1
        continue;
    end
    wordFolder = pathParts{f0Idx - 1};
    wordLower  = lower(wordFolder);

    % --- Parse C1 (initial)
    C1 = '';
    for c = initials
        cStr = char(c);
        if startsWith(wordLower, lower(cStr))
            C1 = cStr;
            break;
        end
    end

    % --- Parse C2 (final) → longest match
    C2 = '';
    matches = {};
    for c = finals
        cStr = char(c);
        if endsWith(wordLower, lower(cStr))
            matches{end+1} = cStr; %#ok<AGROW>
        end
    end
    if ~isempty(matches)
        [~, idxLongest] = max(cellfun(@length, matches));
        C2 = matches{idxLongest};
    end

    if isempty(C1) || isempty(C2)
        continue;
    end

    % --- Append to results
    quads(end+1,:) = {C1, C2, V, f0, wavPath}; %#ok<AGROW>
end

% Shuffle reproducibly
rng(seed); % seed can be numeric or string hash
order = randperm(size(quads,1));
quads = quads(order,:);

end
