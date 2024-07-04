function crc_compare_batch(ref_batch, test_batch)
  %% Compares two matlab batches structures and prints discrepency
  %% If one of the entry is path to file, will compare the basename
  %% and original (before bidsification) names, if sidecar json
  %% contains field `OriginalFile`
  %%
  %% Parameters:
  %% -----------
  %%  ref_batch: struct
  %%    reference batch, loaded as structure
  %%  test_batch: struct
  %%    batch to test, loaded as structure

  compare_structure(inputname(1), ref_batch, test_batch)
end

function compare_structure(path, ref_s, test_s)
  fprintf('Checking %s\n', path);
  if numel(ref_s) ~= numel(test_s)
    warning('%s: Structure array has unmatched sizes', inputname(1));
  end

  ref_fields = sort(fieldnames(ref_s));
  test_fields = sort(fieldnames(test_s));

  %check sizes
  if any(size(ref_fields) ~= size(test_fields))
    warning('%s: Mismatched number of fields', inputname(1));
  end

  for i = 1:numel(ref_fields)
    fname = ref_fields{i};
    loc_path = sprintf('%s.%s', path, fname);
    if ~isfield(test_s, fname)
      warning('%s: Missing field %s', path, fname);
      continue;
    end

    if isstruct(ref_s.(fname))
      compare_structure(loc_path, ref_s.(fname), test_s.(fname));
    elseif iscell(ref_s.(fname))
      compare_cell(loc_path, ref_s.(fname), test_s.(fname));
    elseif isnumeric(ref_s.(fname))
      compare_num(loc_path, ref_s.(fname), test_s.(fname));
    elseif ischar(ref_s.(fname))
      compare_char(loc_path, ref_s.(fname), test_s.(fname));
    else
      fprintf('%s: %s\n', loc_path, class(ref_s.(fname)));
    end
  end
end

function compare_cell(path, ref_c, test_c)
  fprintf('Checking %s\n', path);
  if numel(ref_c) ~= numel(test_c)
    warning('%s: Structure array has unmatched sizes', path);
  end
  n_elem = min(numel(ref_c), numel(test_c));

  for i = 1:n_elem
    loc_path = sprintf('%s{%d}', path, i);
    if isstruct(ref_c{i})
      compare_structure(loc_path, ref_c{i}, test_c{i});
    elseif iscell(ref_c{i})
      compare_cell(loc_path, ref_c{i}, test_c{i});
    elseif isnumeric(ref_c{i})
      compare_num(loc_path, ref_c{i}, test_c{i});
    elseif ischar(ref_c{i})
      compare_char(loc_path, ref_c{i}, test_c{i});
    else
      fprintf('%s: %s\n', loc_path, class(ref_c{i}));
    end
  end

end

function compare_num(path, ref_n, test_n)
  if any(size(ref_n) ~= size(test_n))
    warning('Dimentions mismatch');
  end
  for i = 1:min(numel(ref_n), numel(test_n))
    loc_path = sprintf('%s(%d)', path, i);
    if ref_n(i) ~= test_n(i)
      warning('%s: Value mismatch', loc_path);
      warning('%f vs %f', ref_n(i), test_n(i));
    end
  end
end


function compare_char(path, ref_c, test_c)
  if size(ref_c, 1) ~= size(test_c, 1)
    warning('Dimentions mismatch');
  end
  for i = 1:min(size(ref_c, 1), size(test_c, 1))
    loc_path = sprintf('%s(%d, :)', path, i);
    ref = deblank(ref_c(i, :));
    test = deblank(test_c(i, :));
    if strcmp(ref, test)
      continue;
    end

    [ref_path, ref_name, ref_ext, ref_index] = split_filename(ref);
    [test_path, test_name, test_ext, test_index] = split_filename(test);
    % checking the path
    if strcmp(ref_name, test_name) && strcmp(ref_ext, test_ext) && ref_index == test_index
      fprintf('%s vs %s\n', ref_name, test_name);
      continue;
    end

    % trying bids
    bids_sub = regexp(ref_name, 'sub-');
    if ~isempty(bids_sub)
      js = spm_jsonread(fullfile(ref_path, [ref_name, '.json']));
      if isfield(js, 'OriginalName')
        [ref_path, ref_name, ref_ext, ref_index] = split_filename(js.OriginalName);
      end
    end
    
    bids_sub = regexp(test_name, 'sub-');
    if ~isempty(bids_sub)
      js = spm_jsonread(fullfile(test_path, [test_name, '.json']));
      if isfield(js, 'OriginalName')
        [test_path, test_name, test_ext, test_index] = split_filename(js.OriginalName);
      end
    end

    if strcmp(ref_name, test_name) && strcmp(ref_ext, test_ext) && ref_index == test_index
      continue;
    end

    warning('%s: Value mismatch', loc_path);
    warning('%s vs %s', [ref_name, ref_ext], [test_name, test_ext]);
  end
end

function [index, ext] = split_index(ext)
  index = 1;
  pos = find(ext == ',');
  if isempty(pos)
    return
  end

  if size(pos, 2) > 1
    pos = pos(end)
  end

  index = str2num(ext(pos+1:end));
  ext = ext(1:pos-1);

end

function [path, base, ext, index] = split_filename(fname)
  [path, base, ext] = fileparts(fname);
  if endsWith(base, '.gz')
    base = base(1:end - 3);
    ext = ['.gz', ext];
  end

  [index, ext] = split_index(ext);

end
