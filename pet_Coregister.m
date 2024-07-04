function outDataset = pet_Coregister(ref_ds, img_ds, other_ds,...
                                     destination, varargin)
  % Reorient and resclice images to the reference one

  % path and name of current script
  [pathStep, procStep] = fileparts(mfilename('fullpath'));

  % Optional parameters definition
  args = inputParser();
  args.addParameter('subjects', '.*');
  args.addParameter('name', procStep);
  args.addParameter('config', fullfile(pathStep, 'config', 'pet.json'));
  args.addParameter('configsection', 'registration');
  args.parse(varargin{:});

  % Getting json config file
  if ischar(args.Results.config)
    params = spm_jsonread(args.Results.config);
  else
    params = args.Results.config;
  end
  params = params.(args.Results.configsection);
  space = params.space;
  if isfield(params, 'resolution')
    resolution = params.resolution;
  end

  % Exporting parameters as variables
  procStep = args.Results.name;
  subjects = args.Results.subjects;
  outDataset = fullfile(destination, procStep);

  % This will load bidsified dataset into BIDS structure
  REF = bids.layout(ref_ds,...
                    'use_schema', false,...
                    'index_derivatives', false,...
                    'tolerant', true);
  crc_bids_gen_dervative(REF, destination, procStep,...
                         params.reference,...
                         subjects);

  if strcmp(ref_ds, img_ds)
    IMG = REF;
  else    
    IMG = bids.layout(img_ds,...
                      'use_schema', false,...
                      'index_derivatives', false,...
                      'tolerant', true);
  end
  crc_bids_gen_dervative(IMG, destination, procStep,...
                         params.images,...
                         subjects);

  if ~isempty(other_ds)
    if strcmp(other_ds, ref_ds)
      OTH = REF;
    elseif strcmp(other_ds, img_ds)
      OTH = IMG;
    else
      OTH = bids.layout(other_ds,...
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

    try
      other_img = {};

      % Ref image for coregistration
      ref_img = crc_bids_query_data(DERIV, params.reference, ...
                                    sub, 'reference');
      if isfield(params.reference, 'sum_img')
        % Summing images if needed
        min_img = params.reference.sum_img(1);
        max_img = params.reference.sum_img(2);
        ref_img = {sum_image(ref_img{1}, min_img, max_img)};
      end

      img = crc_bids_query_data(DERIV, params.images, sub, 'images');
      if isfield(params.images, 'sum_img')
        % Summing images if needed
        min_img = params.images.sum_img(1);
        max_img = params.images.sum_img(2);
        sum_img = sum_image(img{1}, min_img, max_img);

        other_img = img;
        img = {sum_img};
      end

      if ~isempty(other_ds)
        other_img = [other_img;...
                     crc_bids_query_data(DERIV, params.other, sub, 'other')];
      end

      out_list = [img; other_img];
      rout_list = cell(size(out_list));
      % Copiyng coregistred images to new name
      for iFile = 1:numel(out_list)
        [pth, fname, ext] = fileparts(out_list{iFile});
        copy_img = fullfile(pth, [fname '_coreg' ext]);
        copyfile(out_list{iFile}, copy_img);
        rout_list{iFile} = copy_img;
      end

      % spm coregister estimate and write with default parameters
      run(fullfile(pathStep, 'MBatches','batch_Coregister.m'));
      prefix = [space, '_'];

      if isfield(params, 'batch_overwrite')
        matlabbatch{1}.spm.spatial.coreg.estwrite =...
          update_batch(matlabbatch{1}.spm.spatial.coreg.estwrite,...
                       params.batch_overwrite);
      end

      matlabbatch{1}.spm.spatial.coreg.estwrite.ref = ref_img;
      matlabbatch{1}.spm.spatial.coreg.estwrite.source = {rout_list{1}};
      matlabbatch{1}.spm.spatial.coreg.estwrite.other = rout_list;
      matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = prefix;

      spm_jobman('run',matlabbatch);

      for iFile = 1:numel(out_list)
        [pth, rfname, ext] = fileparts(rout_list{iFile});
        reoriented = fullfile(pth, [prefix, rfname, ext]);
        if exist(reoriented, 'file')
          p = bids.File(out_list{iFile});
          f_json = fullfile(pth, p.json_filename);
          if exist(f_json, 'file')
            f_json = spm_jsonread(f_json);
          else
            f_json = struct();
          end
          p.entities.space = space;
          if exist('resolution', 'var')
            p.entities.res = resolution;
          end
          outfile = fullfile(pth, p.filename);
          movefile(reoriented, outfile);
          crc_bids_create_json(f_json, outfile,...
                               'Description', ...
                               ['Reoriented to ' space],...
                               'Sources', out_list{iFile},...
                               'SpatialReference', ref_img{1});
        else
          warning('Can''t find resliced file %s', reoriented);
        end
        delete(rout_list{iFile});
      end
    catch ME
      warning('Subject %s failed: %s', sub, ME.getReport('extended'));
      continue;
    end
  end
  
end

function res = sum_image(source, min_frame, max_frame)
  
  p = bids.File(source);
  path = fileparts(source);
  p.entities.space = '';
  p.entities.res = '';
  p.entities.desc = 'sum';
  p.entities.rangeLow = int2str(min_frame);
  p.entities.rangeHigh = int2str(max_frame);
  res = fullfile(path, p.filename);

  V = spm_vol(source);
  flags.dmtx = 1;
  spm_imcalc(V(min_frame: max_frame), res, 'sum(X)', flags);

end

function batch = update_batch(batch, update)
  fields = fieldnames(update);
  for i = 1:numel(fields)
    if ~isfield(batch, fields{i})
      warning('Batch update: Field %s not in the batch structure', fields{i});
      continue;
    end
    if isstruct(update.(fields{i}))
      batch.(fields{i}) = update_batch(batch.(fields{i}), update.(fields{i}));
    else
      batch.(fields{i}) = update.(fields{i});
      fprintf('Batch update: Updated field %s', fields{i});
    end
  end
end
