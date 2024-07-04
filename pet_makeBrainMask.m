function outDataset = pet_makeBrainMask(seg_ds, other_ds,...
                                        destination, varargin)
  % Generates brain mask and 4D prob-map image out of
  % MRI segmented files
  % Resulting masks and probmaps will be generated
  % with bidsified names

  % path and name of current script
  [pathStep, procStep] = fileparts(mfilename('fullpath'));

  % Optional parameters definition
  args = inputParser();
  args.addParameter('subjects', '.*');
  args.addParameter('name', procStep);
  args.addParameter('config', fullfile(pathStep, 'config', 'pet.json'));
  args.addParameter('configsection', 'brainmask');
  args.addParameter('stopOnError', false);
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
  SEG = bids.layout(seg_ds,...
                    'use_schema', false,...
                    'index_derivatives', false,...
                    'tolerant', true);
  crc_bids_gen_dervative(SEG, destination, procStep,...
                         params.tissues,...
                         subjects);

  if isempty(other_ds)
    OTH = [];
  else
    if strcmp(seg_ds, other_ds)
      OTH = SEG;
    else    
      OTH = bids.layout(img_ds,...
                        'use_schema', false,...
                        'index_derivatives', false,...
                        'tolerant', true);
    end
    crc_bids_gen_dervative(OTH, destination, procStep,...
                           params.other,...
                           subjects);
  end

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

    try
      % Generating 4D tissue map
      tissue_masks = crc_bids_query_data(DERIV, params.tissues, ...
                                         sub, 'tissues');
      [Masks_dir, ~, ~] = fileparts(tissue_masks{1});
      tissue_masks = sort_segmented(tissue_masks);

      p = bids.File(tissue_masks{1});
      p.prefix = '';
      if ~strcmp(p.suffix, 'probseg')
        p.entities.desc = p.suffix;
        p.suffix = 'probseg';
      end

      % Reading segmentation maps
      V = spm_vol(tissue_masks{1});
      vv = zeros([V(1).dim size(tissue_masks, 1)]);
      vv(:, :, :, 1) = spm_read_vols(V(1));
      for i = 2:numel(tissue_masks)
        V = [V; spm_vol(tissue_masks{i})]; %#ok<AGROW>
        vv(:, :, :, i) = spm_read_vols(V(i));
      end

      V_out = V(1);
      % Saving brain mask
      p.entities.label = 'Brain';
      p.suffix = 'mask';
      fprintf('Calculating brain mask %s\n', p.filename());
      sum_vv = sum(vv, 4);
      clear vv;
      sum_vv(sum_vv > 1.) = 1.;
      mask = sum_vv > params.treshold;
      V_out.fname = fullfile(Masks_dir, p.filename());
      spm_write_vol(V_out, mask);

      % Saving non-brain segmentation (complementary segmentation)
      p.entities.label = 'NB';
      p.suffix = 'probseg';
      fprintf('Calculating non-brain mask %s\n', p.filename());
      V_out.fname = fullfile(Masks_dir, p.filename());
      V_NB = spm_write_vol(V_out, 1. - sum_vv);

      % Saving 4D mask
      p.entities.label = '';
      fprintf('Saving 4D tissues segmentation %s\n', p.filename());
      tissue_4D = fullfile(Masks_dir, p.filename());
      spm_file_merge([V; V_NB], tissue_4D);

      if isempty(OTH)
        continue;
      end
      other = crc_bids_query_data(DERIV, params.other, ...
                                  sub, 'other'); 
      for i = 1:numel(other)
        [path, basename, ext] = fileparts(other{i});
        fprintf('Applying brain mask to %s\n', basename);
        V = spm_vol(other{i});
        vv = spm_read_vols(V);
        if params.use_zero
          vv(~mask) = 0; 
        else
          vv(~mask) = nan;
        end
        p = bids.File(other{i});
        p.entities.mask = 'Brain';
        V.fname = fullfile(path, p.filename());
        spm_write_vol(V, vv);
      end

    catch ME
      warning('Subject %s failed: %s', sub, ME.getReport('extended'));
      if args.Results.stopOnError
        rethrow(ME);
      else
        continue;
      end
    end

  end

end

function sorted = sort_segmented(probseg)
  prefixes.c1 = 1;
  prefixes.c2 = 2;
  prefixes.c3 = 3;
  labels.GM = 1;
  labels.WM = 2;
  labels.CSF = 3;

  tissues_order = {'Gray Matter', 'White Matter', 'CSF'};

  sorted = cell(1, 3);
  for i = 1:numel(probseg)
    index = 0;
    p = bids.File(probseg{i});

    if isfield(p.entities, 'label')
      if isfield(labels, p.entities.label)
        index = labels.(p.entities.label);
      end
    end
    
    if index == 0 && ~isempty(p.prefix)
      if isfield(prefixes, p.prefix)
        index = prefixes.(p.prefix);
      end
    end
      
    if index == 0
      warning('Failed to identify tissue type for %f\n', p.filename);
    else
      if isempty(sorted{index})
        sorted{index} = probseg{i};
        fprintf('%s: %s\n', tissues_order{index}, p.filename);
      else
        warning('%s: Tissue already in use, will ignore %s\n',...
                tissues_order{index}, p.filename);
      end
    end
  end
end
