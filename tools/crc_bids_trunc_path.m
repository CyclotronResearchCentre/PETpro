function trunc_path = crc_bids_trunc_path(paths)
  % Make given absolute path relative to bids dataset root
  % Essentually search for sub- level, and goes up
  % for one step.
  % If input is cellarray, truncation is performed to all
  % files in array

  if iscell(paths)
    trunc_path = cell(size(paths));
    for i = 1:numel(paths)
      trunc_path = crc_bids_trunc_path(paths{i});
    end
    return;
  end

  trunc_path = '';
  % removing duplicated filesep
  path = java.io.File(paths).getCanonicalPath().toCharArray';
  path = regexp(path, [filesep '+'], 'split');

  % Short paths, assuming relative to root already
  if numel(path) <= 2
    trunc_path = strjoin(path, filesep);
    return;
  end

  for i = numel(path):-1:1
    if regexp(path{i}, '^sub-[0-9a-zA-Z]+$')
      trunc_path = strjoin(path(i:end), filesep);
      break;
    end
  end

  % If no sub-xyz string, assuming subject-level file
  if isempty(trunc_path)
    trunc_path = strjoin(path(end-1:end), filesep);
  end

end
