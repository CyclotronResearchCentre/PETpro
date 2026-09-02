function outDataset = pet_Normalisation(img_ds, template_ds, destination, varargin)
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

  template = params.template;
  if ~exist(template, 'file')
    template = fullfile(template_ds, 'DartellTemplates', params.template);
    if ~exist(template, 'file')
      error('filed to find template %s%s', template);
    end
  end
  fprintf('Using template from %s\n', template);

  TEMPLATE = bids.layout(template_ds, ...
                         'use_schema', false,...
                         'index_derivatives', false,...
                         'tolerant', true);
  crc_bids_gen_dervative(TEMPLATE, destination, procStep,...
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
      fprintf('%d images will be normalized to mni space\n', size(images, 1));

      clear matlabbatch;
      run(fullfile(pathStep, 'MBatches','Dartel_norm.m'));
      matlabbatch{1}.spm.tools.dartel.mni_norm.data.subj.flowfield = flowfield;
      matlabbatch{1}.spm.tools.dartel.mni_norm.data.subj.images = images;
      matlabbatch{1}.spm.tools.dartel.mni_norm.template = {template};

      spm_jobman('run',matlabbatch);

      % changing names of files
      for i = 1:size(images, 1)
        path = fileparts(images{i});
        p = bids.internal.parse_filename(images{i});
        p.use_schema = false;

        p.ext = '.json';
        orig_json = fullfile(path, crc_create_filename(p));

        p.ext = '.nii';
        p.prefix = 'w';
        in_mni_file = fullfile(path, crc_create_filename(p));
        if ~exist(in_mni_file, 'file')
          p.prefix = 'sw';
          in_mni_file = fullfile(path, crc_create_filename(p));
        end
        p.ext = '.json';
        in_mni_json = fullfile(path, crc_create_filename(p));

        p.prefix = '';
        p.ext = '.nii';
        p.entities.space = 'MNI';
        p.entities.res = '';
        out_mni_file = fullfile(path, crc_create_filename(p));

        p.ext = '.json';
        out_mni_json = fullfile(path, crc_create_filename(p));

        if ~exist(in_mni_file, 'file')
          warning('Subject %s: Normalised file %s not found', ...
                  sub, in_mni_file);
          continue;
        end
        movefile(in_mni_file, out_mni_file);

        if exist(in_mni_json, 'file')
          delete(in_mni_json);
        end

        if exist(orig_json, 'file')
          js = spm_jsonread(orig_json);
        else
          js = struct();
        end

        crc_bids_create_json(js, out_mni_json,...
                             'Description', ...
                             'Normalised to MNI space',...
                             'Sources', images{i},...
                             'SpatialReference', template);
      end
    catch ME
      warning('Subject %s failed: %s', sub, ME.getReport('extended'));
      continue;
    end

  end

end
