function data = crc_bids_query_data(BIDS, images, sub, id)
%% Utility function that retrives data from BIDS dataset
%% and compares it with expected number
%%
%%  images must be a struct with query sub-structure, following
%%    starndard definition of bids-matlab
%%    if 'number' field is present in images, then output of query
%%    is compared with it and an error will be raised in case of mismatch
%%  sub must contain a cellarray of requested sub id 
%%    or be empty for all subjects
%%  id is identification name to print if data retrieval fails

  try
    if ~isempty(sub)
      images.query.sub = sub;
    else
      sub = bids.query(BIDS, 'subjects', images.query);
    end

    if iscell(sub)
      nsub = numel(sub);
    else
      nsub = 1;
    end

    data = bids.query(BIDS, 'data', images.query);

    if isfield(images, 'number')
      if images.number > 0
        requested = images.number * nsub;
        assert(size(data, 1) == requested, ...
               'expected %d files, recieved %d', ...
               requested, size(data, 1));
      end
    else
      assert(size(data, 1) > 0, '0 images selected');
    end

    fprintf('%s: Selected %d images\n', id, size(data, 1));
  catch ME
    err.identifier = ME.identifier;
    query_str = print_query(images.query);
    err.message = sprintf('%s: Data retrieval failed: %s',...
                          id, ME.message);
    fprintf(strcat('Failed query:\n', query_str));
    err.stack = ME.stack;
    rethrow(err);
  end

end


function res = print_query(query)
  res = '';
  fields = fieldnames(query);

  for i = 1:numel(fields)
    res = strcat(res, '\t', fields{i}, ': ');
    constrain = query.(fields{i});
    res = print_constrain(res, constrain);
    res = strcat(res, '\n');
  end
end


function res = print_constrain(res, constrain)
  % Cell
  if iscell(constrain)
    res = strcat(res, '{');
    for i = 1:numel(constrain)
      res = print_constrain(res, constrain{i});
      res = strcat(res, ', ');
    end
    res = strcat(res, '}');
  % Char
  elseif ischar(constrain)
    res = strcat(res, '''', constrain, '''');
  % array of number
  elseif numel(constrain) > 1
    res = strcat(res, '{');
    for i = 1:numel(constrain)
      res = print_constrain(res, constrain{i});
      res = strcat(res, ', ');
    end
    res = strcat(res, '}');
  % isolated number
  else
    res = strcat(num2str(constrain))
  end
end
