function outDataset = pet_copyFiles(source_ds, ...
                                    destination, varargin)
  % Copy selected files from source dataset to destination
  % Usefull for collecting data before processing

  % path and name of current script
  [pathStep, procStep] = fileparts(mfilename('fullpath'));

  % Optional parameters definition
  args = inputParser();
  args.addParameter('subjects', '.*');
  args.addParameter('name', procStep);
  args.addParameter('config', fullfile(pathStep, 'config', 'pet.json'));
  args.addParameter('configsection', 'copyFiles');
  args.parse(varargin{:});

  % Getting json config file
  if ischar(args.Results.config)
    params = spm_jsonread(args.Results.config);
  else
    params = args.Results.config;
  end
  params = params.(args.Results.configsection);

  % Exporting parameters as variables
  procStep = args.Results.name;
  subjects = args.Results.subjects;
  outDataset = fullfile(destination, procStep);

  % This will load bidsified dataset into BIDS structure
  SOURCE = bids.layout(source_ds,...
                       'use_schema', false,...
                       'index_derivatives', false,...
                       'tolerant', true);
  crc_bids_gen_dervative(SOURCE, destination, procStep,...
                         params,...
                         subjects);

end
