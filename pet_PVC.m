function outDataset = pet_PVC(pet_ds, seg_ds, ...
                              destination, varargin)
  % corrects PET data for PVE using the Iterative Yang method.
  % The function receives the following inputs : 
  %   - dynamic PET data, 
  %   - tissues probability maps. 
  % It generates the 4D mask of the tissues probabilities maps and 
  % run the PVC correction in the PET space and using the PET resolution.

  % path and name of current script
  [pathStep, procStep] = fileparts(mfilename('fullpath'));

  % Optional parameters definition
  args = inputParser();
  args.addParameter('subjects', '.*');
  args.addParameter('name', procStep);
  args.addParameter('config', fullfile(pathStep, 'config', 'pet.json'));
  args.addParameter('configsection', 'PVC');
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
                         params.images,...
                         subjects);

  SEG = bids.layout(seg_ds,...
                    'use_schema', false,...
                    'index_derivatives', false,...
                    'tolerant', true);
  DERIV = crc_bids_gen_dervative(SEG, destination, procStep,...
                                 params.tissues,...
                                 subjects);

  % getting list of subjects
  subjects = bids.query(DERIV,'subjects', 'sub', subjects);

  for iSub = 1:numel(subjects)

    sub = subjects{iSub};

    fprintf('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n');
    fprintf('Processing subject %d/%d %s\n', iSub, numel(subjects), sub);
    fprintf('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n');

    base_dir = fullfile(outDataset, ['sub-' sub]);
    PVC_dir = fullfile(base_dir, 'PVC');
    pet_dir = fullfile(base_dir, 'pet');

    try
      % Generating 4D tissue map
      tissue_masks = crc_bids_query_data(DERIV, params.tissues, ...
                                         sub, 'tissues');
      tissue_4D = crc_bids_query_data(DERIV, params.tissues, sub, 'tissues');
      tissue_4D = tissue_4D{1};

      if ~exist(PVC_dir, 'dir')
        mkdir(PVC_dir);
      end

      pet_img = crc_bids_query_data(DERIV, params.images, sub, 'images');

      p = bids.internal.parse_filename(pet_img{1});
      p.ext = '.json';
      pet_json = spm_jsonread(fullfile(pet_dir, crc_create_filename(p)));
      p.ext = '.nii';

      p.use_schema = false;

      % pet_pvc works only with 3D images, splitting 4D volume
      Vo = spm_file_split(pet_img{1});
      MG_img = cell(size(numel(Vo)));

      method = params.method;

      p.entities.label = regexprep(method, '[^a-zA-Z0-9]+', '');
      p.entities.desc = 'PVC';

      for i = 1:numel(Vo)
        p.ext = sprintf('.%03d%s', i, '.nii');
        MG_img{i} = fullfile(PVC_dir, crc_create_filename(p));
        if(i < params.frame_skip)
          copyfile(Vo(i).fname, MG_img{i});
        else
          cmd = ['petpvc -i ' Vo(i).fname ' -m ' tissue_4D ...
                 ' -o ' MG_img{i}  ' --pvc ' method ...
                 sprintf(' -x %.2f -y %.2f -z %.2f', params.FWHM(:)) ...
                 ];
          if ~isempty(params.option)
            cmd = [cmd ' ' params.option]; %#ok<AGROW>
          end
          fprintf('\t%s\n', cmd);
          status = system(cmd);
          if status ~= 0
            error('pvc calculation failed')
          end
        end
        % cleaning up processed 3D images
        delete(Vo(i).fname);
      end

      p.ext = '.nii';

      pet_pvc_4D = fullfile(pet_dir, crc_create_filename(p));
      spm_file_merge(MG_img, pet_pvc_4D);
      delete(MG_img{:});

      crc_bids_create_json(pet_json, pet_pvc_4D, ...
                           'Description', ...
                           ['Partial volume corrected using ' method], ...
                           'Sources-add', pet_img{1});

    catch ME
      warning('Subject %s failed: %s', sub, ME.getReport('extended'));
      continue;
    end
  end
  
end

