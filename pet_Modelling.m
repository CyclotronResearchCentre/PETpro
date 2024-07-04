function outDataset = pet_Modelling(pet_ds, idif_ds, mask_ds, destination, varargin)
%% Calculates Vt and intersection for pet images in pet_ds

  % path and name of current script
  [pathStep, procStep] = fileparts(mfilename('fullpath'));

  % Optional parameters definition
  args = inputParser();
  args.addParameter('subjects', '.*');
  args.addParameter('name', procStep);
  args.addParameter('config', fullfile(pathStep, 'config', 'pet.json'));
  args.addParameter('configsection', 'modelling');
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
  PET = bids.layout(pet_ds,...
                    'use_schema', false,...
                    'index_derivatives', false,...
                    'tolerant', true);
  crc_bids_gen_dervative(PET, destination, procStep,...
                         params.image,...
                         subjects);

  if strcmp(pet_ds, idif_ds)
    IDIF = PET;
  else
    IDIF = bids.layout(idif_ds,...
                       'use_schema', false,...
                       'index_derivatives', false,...
                       'tolerant', true);
  end
  crc_bids_gen_dervative(IDIF, destination, procStep,...
                         params.idif,...
                         subjects);
              
  if ~isempty(mask_ds)
    if strcmp(pet_ds, mask_ds)
      MASK = PET;
    else
      MASK = bids.layout(mask_ds,...
                         'use_schema', false,...
                         'index_derivatives', false,...
                         'tolerant', true);
    end
    query = params.mask.query;
    if ~isempty(subjects)
      query.sub = subjects;
    end
    crc_bids_gen_dervative(MASK, destination, procStep,...
                           params.mask,...
                           subjects);
  end
  outDataset = fullfile(destination, procStep);

  % loading derivated datast as BIDS layout
  DERIV = bids.layout(outDataset,...
                      'use_schema', false,...
                      'index_derivatives', false,...
                      'tolerant', true);

  % getting list of subjects
  subjects = bids.query(DERIV,'subjects', 'sub', subjects);

  for iSub = 1:numel(subjects)

    sub = subjects{iSub};

    fprintf('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n');
    fprintf('Processing subject %d/%d %s\n', iSub, numel(subjects), sub);
    fprintf('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n');

    base_dir = fullfile(outDataset, ['sub-' sub]);
    Logan_dir = fullfile(base_dir, 'Logan');

    try

      % Retrieving image and times of frames
      pet_img = crc_bids_query_data(DERIV, params.image, sub, 'images');

      query = params.image.query;
      query.sub = sub;
      query.target = 'FrameTimesStart';
      f_start = bids.query(DERIV, 'metadata', query);
      query.target = 'FrameDuration';
      f_duration = bids.query(DERIV, 'metadata', query);
      if ~iscell(f_start)
        f_start = {f_start};
        f_duration = {f_duration};
      end

      % Retrieving IDIF function
      idif_tab = crc_bids_query_data(DERIV, params.idif, sub, 'idif');
      idif_tab = spm_load(idif_tab{1});

      idif = [idif_tab.onset idif_tab.(params.idif.IF)];

      for img = 1:size(pet_img, 1)
        frames = [f_start{img} f_start{img} + f_duration{img}];

        % Retrieving brain mask
        if ~isempty(mask_ds)
          mask_img = crc_bids_query_data(DERIV, params.mask, sub, 'brain mask'); 
          mask_img = mask_img{1};
        else
          mask_img = {};
        end

        if ~exist(Logan_dir, 'dir')
          mkdir(Logan_dir);
        end

        [~, basename, ~] = fileparts(pet_img{img});
        fprintf('%s\n', basename);
        pet_Model.logan_image(pet_img{img}, idif, frames, mask_img, ...
                              params.start_time, ...
                              params.end_time, ...
                              Logan_dir);
      end

    catch ME
      warning('Subject %s failed: %s', sub, ME.getReport('extended'));
      continue;
    end

  end
  
end
