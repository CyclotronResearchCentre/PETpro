function IDIF = importIDIF(fname)
  % Imports values from IDIF tsv into IDIF structure

  time_column = 'mid_time';

  IDIF = spm_load(fname);
  IDIF.fname = fname;

  if ~isfield(IDIF, time_column)
    error('IDIF structure must contain at least %s', time_column);
  end
end
