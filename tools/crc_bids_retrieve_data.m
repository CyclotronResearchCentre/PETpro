function data = crc_bids_retrieve_data(BIDS, selection, subjects)
%% Utility function  that retrieves all data in BIDS dataset
%% and cited in selection structure
%%
%% BIDS: source dataset structure (bids-matlab)
%% selection: structure containing individual selection structures
%% subjects: list of requested subjects

  fields = fieldnames(selection);
  data = [];

  for i = 1:size(fields, 1)
    if ~isfield(selection.(fields{i}),'query')
      continue;
    end
    data.(fields{i}) = crc_bids_query_data(BIDS, selection.(fields{i}), ...
                                           subjects, fields{i});
  end
end

