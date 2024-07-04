function codeDir = crc_bids_make_code_dir(ds_path, procStep, conf_files)
  %% Function creating code directory in bidsified dataset:
  %%    <ds_path>/code/<procStep>
  %% files in conf_files into it
  %%
  %% Parameters:
  %% -----------
  %%  ds_path: char
  %%    path to bidsified dataset
  %%  procStep: char
  %%    name of current processing step
  %%  conf_files: cellarray of char
  %%    list of files to copy into code directory
  %%    may be empty or ommitted
  %%
  %%  Returns:
  %%  --------
  %%  codeDir: char
  %%    path to newly created code directory

  if ~exist(ds_path, 'dir')
    error('Bidsified dataset %s don''t exist', ds_path);
  end

  codeDir = fullfile(ds_path, 'code', procStep);
  if ~exist(codeDir, 'dir')
    mkdir(codeDir);
  end

  if exist('conf_files', 'var')
    if ischar(conf_files)
      conf_files = cellstr(conf_files);
    end
    for i = 1:numel(conf_files)
      if ~exist(conf_files{i}, 'file')
        warning('Can''t find file %s', conf_files{i});
        continue;
      end
      copyfile(conf_files{i}, codeDir);
    end
  end
end
