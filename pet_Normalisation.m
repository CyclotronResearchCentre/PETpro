function outDataset = pet_Normalisation(flow_ds, img_ds, destination, varargin)
%% Performs normalisation to MNI space of given images in img_ds, according to
%% templates in template_ds

  % path and name of current script
  [pathStep, procStep] = fileparts(mfilename('fullpath'));

  % Optional parameters definition
  args = inputParser();
  args.addParameter('subjects', '.*');
  args.addParameter('name', procStep);
  args.addParameter('config', fullfile(pathStep, 'config', 'pet.json'));
  args.addParameter('configsection', 'normalisation');
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

  FLW = bids.layout(flow_ds, ...
                    'use_schema', false,...
                    'index_derivatives', false,...
                    'tolerant', true);
  crc_bids_gen_dervative(FLW, destination, procStep,...
                         params.flowfield,...
                         subjects);
  IMG = bids.layout(img_ds, ...
                    'use_schema', false,...
                    'index_derivatives', false,...
                    'tolerant', true);
  DERIV = crc_bids_gen_dervative(IMG, destination, procStep,...
                                 params.images,...
                                 subjects);

  subjects = bids.query(DERIV,'subjects', 'sub', subjects);

  for iSub = 1:numel(subjects)
    sub = subjects{iSub};

    fprintf('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n');
    fprintf('Processing subject %d/%d %s\n', iSub, numel(subjects), sub);
    fprintf('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n');

    try

      flowfield = crc_bids_query_data(DERIV, params.flowfield, ...
                                      sub, 'flowfield');
      
      images = crc_bids_query_data(DERIV, params.images, ...
                                   sub, 'images');
      results_path = fileparts(images{1});
      fprintf('%d images will be normalized to mni space\n', size(images, 1));

      clear matlabbatch;
      run(fullfile(pathStep, 'MBatches','Std_norm.m'));
      matlabbatch{1}.spm.spatial.normalise.write.subj.def = flowfield;
      matlabbatch{1}.spm.spatial.normalise.write.subj.resample = images;

      spm_jobman('run',matlabbatch);

      prefix_rules(1).w.prefix = '';
      prefix_rules(1).w.space = 'MNI152';
      prefix_rules(1).w.res = '2mm';
      crc_bids_rebidsify_dir(results_path,...
                             prefix_rules,...
                             []);
    catch ME
      warning('Subject %s failed: %s', sub, ME.getReport('extended'));
      continue;
    end

  end

end
