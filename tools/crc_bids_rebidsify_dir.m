function outlist = crc_bids_rebidsify_dir(path, prefix_rules, suffix_rules, verbose)

  if ~exist('verbose', 'var')
    verbose = false;
  end

  if verbose
    fprintf('Rebidsifying %s\n', path)
  end
  % Merges multiple bids suffixes into one
  flist = dir(path);
  outlist = cell(0);

  for iFile = 1:numel(flist)
    if flist(iFile).isdir
      continue;
    end

    name = flist(iFile).name;
    folder = flist(iFile).folder;

    [new_name, new_json] = crc_bids_rebidsify(...
        name,...
        prefix_rules,...
        suffix_rules,...
        verbose);
    if strcmp(new_name, name)
      continue;
    end

    old_file = fullfile(folder, name);
    new_file = fullfile(folder, new_name);
    [status, msg] = movefile(old_file, new_file);
    if status ~= 1
      fprintf('\t%s: Failed to rename: \n\t\t%s\n', old_file, msg);
    end
    outlist{end+1} = new_file;
  end
end
