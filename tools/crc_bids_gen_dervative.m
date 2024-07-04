function DERIV = crc_bids_gen_dervative(BIDS, outDir, name, selection, subjects)
%% Utility function that creates derivatives dataset from base BIDS
%% dataset, and copy data from selection in it
%% If path to derivative dataset is the same as BIDS, nothing is done
%% and original dataset is returned
%%
%% BIDS: source dataset structure (bids-matlab)
%% outDir: path to output directory, must exist
%% name: name of derivative dataset
%% selection: structure containing individual selection structures

  if ~exist('subjects', 'var')
    subjects = '.*';
  end

  outDataset = fullfile(outDir, name);

  if strcmp(BIDS.pth, outDataset)
    DERIV = BIDS;
    return;
  end

  if iscell(selection)
    for i = 1:numel(selection)
      fprintf('Generating %s for %d selection\n', name, i);
      crc_bids_gen_dervative(BIDS, outDir, name, selection{i}, subjects);
    end
    if nargout > 1
      DERIV = bids.layout(outDataset,...
                          'use_schema', false,...
                          'index_derivatives', false,...
                          'tolerant', true);
    end
    return;
  end

  for i = 1:numel(selection)
    fprintf('Generating %s for %d selection\n', name, i);
  
    if isfield(selection,'query')
      query = selection(i).query;
      query.sub = subjects;
      % creating derived dataset
      bids.copy_to_derivative(BIDS,...
                              'filter', query,...
                              'out_path', outDir,...
                              'pipeline_name', name,...
                              'unzip', true, ...
                              'skip_dep', true, ...
                              'use_schema', false, ...
                              'verbose', true);
    else

      fields = fieldnames(selection);

      for i = 1:size(fields, 1)
        if ~isfield(selection.(fields{i}),'query')
          continue;
        end

        query = selection.(fields{i}).query;
        query.sub = subjects;
        % creating derived dataset
        bids.copy_to_derivative(BIDS,...
                                'filter', query,... 
                                'out_path', outDir,...
                                'pipeline_name', name,...
                                'unzip', true, ...
                                'skip_dep', true, ...
                                'use_schema', false, ...
                                'verbose', true);
      end
    end
  end

  if nargout > 0
    DERIV = bids.layout(outDataset,...
                        'use_schema', false,...
                        'index_derivatives', false,...
                        'tolerant', true);
  end
end
