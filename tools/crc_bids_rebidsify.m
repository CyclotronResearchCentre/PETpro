function [new_name, new_json] = rebidsify(fname, prefix_rules, suffix_rules, verbose)
  % Recreate bidsified name based on file prefix,
  % multiple suffixes and passed rules
  % If suffix is not set by rules, the combined suffix is used
  if ~exist('verbose', 'var')
    verbose = false;
  end

  new_name = fname;
  new_json = '';

  [base, suff, ext] = extract_suffix(fname);
  if isempty(base)
    if verbose
      fprintf('\t%s -> Not bids\n', fname);
    end
    return;
  end

  suffix = strjoin(suff, '');
  base = [base '_' suffix ext];

  file = bids.File(base);

  if ~isempty(prefix_rules)
    if isfield(prefix_rules, file.prefix)
      file = update_entity(file, prefix_rules.(file.prefix));         
    end
  end

  if ~isempty(suffix_rules)
    for s = 2:numel(suff)
      if isfield(suffix_rules, suff{s})
        file = update_entity(file, suffix_rules.(suff{s}));
      end
    end
  end
  new_name = file.filename;
  new_json = file.json_filename;
  if verbose
    fprintf('\t%s -> %s\n', fname, new_name);
  end
end

function file = update_entity(file, ent_list)
  entities = fieldnames(ent_list);

  for i = 1:numel(entities)
    switch entities{i}
      case 'prefix'
        file.prefix = ent_list.prefix;
      case 'suffix'
        file.suffix = ent_list.suffix;
      case 'extension'
        file.extension = ent_list.extension;
      otherwise
        file.entities.(entities{i}) = ent_list.(entities{i}); 
    end
  end

end

function [base, suff, ext] = extract_suffix(fname)
  % Extract multiple suffixes from filename
  % Returns name before suffix, array of suffixes
  % and extention

  base = '';
  ext = '';
  suff = {};

  % '^([a-zA-Z0-9_-]*)(sub-[a-zA-Z0-9]+)  -- prefix and sub
  % (_[a-zA-Z0-9]+-[a-zA-Z0-9]+)*         -- entities
  % (_[a-zA-Z0-9]+)+(\.[a-zA-Z0-9]+)$'    -- suffix and ext
  % [res, t] = regexp(['abc!_' name], exp2, 'match', 'tokens')
  pre_tok = '([a-zA-Z0-9_-]*)';
  sub_tok = '(sub-[a-zA-Z0-9]+)';
  ent_tok = '(_?[a-zA-Z0-9]+-[a-zA-Z0-9]+)*';
  suf_tok = '(_[a-zA-Z0-9]+)+';
  ext_tok = '(\.[a-zA-Z0-9.]+)';

  pattern = [ent_tok suf_tok ext_tok '$'];
  [unmatch, res, tok] = regexp(fname, pattern, 'split', 'match', 'tokens');

  if isempty(res) || isempty(tok{1}{1})
    % No match
    return;
  end

  base = [unmatch{1} tok{1}{1}];
  ext = tok{1}{end};

  suff = regexp(tok{1}{end - 1}, '_', 'split');
end
