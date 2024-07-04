function merge_suffix(folder_path, varargin)
  % Renames files with double-bids suffix

  fprintf('Merging suffix from %s\n', folder_path);
  overwrite = false;
  for ii = 1:2:size(varargin, 1)
    if strcmp(varargin{ii}, 'overwrite')
      overwrite = true;
    else
      error(['Unrecognised option ' varargin{ii}]);
    end
  end

  flist = cellstr(bids.internal.file_utils('list', folder_path));

  for iFile = 1:numel(flist)
    pos_und = strfind(flist{iFile}, '_');
    pos_dash = strfind(flist{iFile}, '-');
  
    if isempty(pos_und) || isempty(pos_dash)
      fprintf('\t%s: Not bids\n', flist{iFile});
      continue;
    end
    last_dash = pos_dash(end);
    pos_und = pos_und(pos_und > last_dash);
    if size(pos_und, 2) < 2
      fprintf('\t%s: No duplicated suffixes\n', flist{iFile});
      continue;
    end
    mod_name = flist{iFile};
    mod_name(pos_und(2:end)) = [];
    fprintf('\t%s: renaming to %s\n', flist{iFile}, mod_name);

    old_file = fullfile(folder_path, flist{iFile});
    new_file = fullfile(folder_path, mod_name);

    if ~overwrite && exist(new_file, 'file')
      fprintf('\t%s: file exists\n', mod_name);
      continue;
    end

    [status, msg] = movefile(old_file, new_file);
    if status ~= 1
      fprintf('\t%s: Failed to rename: \n\t\t%s\n', old_file, msg);
    end
  end
end
