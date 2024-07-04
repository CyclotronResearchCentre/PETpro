function outDataset = pet_AIF(img_ds, blood_ds, destination, varargin)
  % Calculate IF from blood sampling tsv file,
  % Also calculates Pearson correlation map of voxels that
  % have similar signal to (uncorrected) blood IF

  % path and name of current script
  [pathStep, procStep] = fileparts(mfilename('fullpath'));

  % Optional parameters definition
  args = inputParser();
  args.addParameter('subjects', '.*');
  args.addParameter('name', procStep);
  args.addParameter('config', fullfile(pathStep, 'config', 'pet.json'));
  args.addParameter('configsection', 'AIF');
  args.parse(varargin{:});

  % Getting json config file
  if ischar(args.Results.config)
    params = spm_jsonread(args.Results.config);
  else
    params = args.Results.config;
  end

  params_section = params.(args.Results.configsection);

  % Exporting parameters as variables
  procStep = args.Results.name;
  subjects = args.Results.subjects;
  outDataset = fullfile(destination, procStep);

  IMG = bids.layout(img_ds, ...
                     'use_schema', false,...
                     'index_derivatives', false,...
                     'tolerant', true);
  crc_bids_gen_dervative(IMG, destination, procStep,...
                         params_section.image,...
                         subjects);
  crc_bids_gen_dervative(IMG, destination, procStep,...
                         params_section.offset,...
                         subjects);

  if strcmp(blood_ds, img_ds)
    BL = IMG;
  else    
    BL = bids.layout(blood_ds,...
                     'use_schema', false,...
                     'index_derivatives', false,...
                     'tolerant', true);
  end
  crc_bids_gen_dervative(BL, destination, procStep,...
                         params_section.blood,...
                         subjects);

  DERIV = bids.layout(outDataset,...
                      'use_schema', false,...
                      'index_derivatives', false,...
                      'tolerant', true);

  subjects = bids.query(DERIV,'subjects', 'sub', subjects);

  for iSub = 1:numel(subjects)
    sub = subjects{iSub};

    fprintf('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n');
    fprintf('Processing subject %d/%d %s\n', iSub, numel(subjects), sub);
    fprintf('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n');

    try
      pet_data = crc_bids_query_data(DERIV, params_section.image, sub, 'image');
      blood_data = crc_bids_query_data(DERIV, params_section.blood, sub, 'blood');
      caro = crc_bids_query_data(DERIV, params_section.offset, sub, 'offset');
      p = bids.File(pet_data{1});
      source = fullfile(p.bids_path, p.filename);

      % calculating times of images
      query_meta = params_section.image.query;
      query_meta.sub = sub;

      query_meta.target = 'FrameTimesStart';
      start_time = bids.query(DERIV, 'metadata', query_meta);
      query_meta.target = 'FrameDuration';
      frame_duration = bids.query(DERIV, 'metadata', query_meta);
      mid_time = start_time + (frame_duration / 2);

      t = readtable(blood_data{1}, 'TreatAsEmpty', {'n/a'},...
                    'FileType', 'text',...
                    'Delimiter', '\t');

      onset = t.onset;
      blood = t.whole_blood_radioactivty;
      plasma = t.plasma_radioactivty;

      V = crc_read_spm_vol(pet_data);
      D = permute(spm_read_vols(V), [4, 1, 2, 3]);
      C = crc_read_spm_vol(caro);
      caro_mask = spm_read_vols(C(1));

      idif = mean(D(:, find(caro_mask)), 2);

      [~, idx_idif] = max(idif);
      [~, idx_plasma] = max(plasma);

      offset = mid_time(idx_idif) - onset(idx_plasma);
      onset = onset + offset;

      int_blood = pchip(onset, blood, mid_time);
      int_plasma = pchip(onset, plasma, mid_time);

      p.modality = 'pet_IF';
      out_dir = fullfile(outDataset, p.bids_path);
      if ~exist(out_dir, 'dir')
        mkdir(out_dir);
      end

      p.extension = '.tsv';
      p.suffix = 'if';
      p.entities.label = 'blood';
      T = table(mid_time, int_blood, 'VariableNames', {'onset', 'input_function'});
      writetable(T, fullfile(out_dir, p.filename),...
                 'FileType', 'text', 'Encoding', 'UTF-8',...
                 'Delimiter', '\t');

      p.entities.label = 'plasma';
      T = table(mid_time, int_plasma, 'VariableNames', {'onset', 'input_function'});
      writetable(T, fullfile(out_dir, p.filename),...
                 'FileType', 'text', 'Encoding', 'UTF-8',...
                 'Delimiter', '\t');

      R_blood = pet_IDIF.pearson(D, int_blood);
      R_plasma = pet_IDIF.pearson(D, int_plasma);

      p.suffix = 'r2';
      p.extension = '.nii';
      p.entities.label = 'blood';
      p.entities.description = '';

      crc_write_image(V(1), R_blood, fullfile(out_dir, p.filename));

      p.entities.label = 'plasma';
      crc_write_image(V(1), R_plasma, fullfile(out_dir, p.filename));

      pixelspacing = crc_get_vox_size(V(1).mat);
      sigma = fwhm2sigma(params_section.PVC.PSF.FWHM);
      % caro_smooth = gauss3filter(caro_mask, sigma, pixelspacing);
      sigma = sigma' ./ pixelspacing;

      fprintf('--> Applying PVC using Lucy-Richardson deconvolution method\n');
      fprintf('\tSigma: [%.3f, %.3f, %.3f] pixels\n',...
              sigma(1), sigma(2), sigma(3));
      psf = gaus3D_psf(sigma);
      data_pvc = pet_IDIF.pvc_lrd(D, psf, 0);

      R_blood = pet_IDIF.pearson(data_pvc, int_blood);
      R_plasma = pet_IDIF.pearson(data_pvc, int_plasma);

      p.entities.pvc = 'lrd';
      p.entities.label = 'blood';
      crc_write_image(V(1), R_blood, fullfile(out_dir, p.filename));

      p.entities.label = 'plasma';
      crc_write_image(V(1), R_plasma, fullfile(out_dir, p.filename));

      if isfield(params_section, 'metabolite')
        p.entities.pvc = '';
        p.suffix = 'if';
        met_conf = params_section.metabolite;
        if strcmp(met_conf.reference, 'max')
          fprintf('-> Metbolite correction calculated from injection peak\n');
          offset = nan;
        elseif strcmp(met_conf.reference, 'inj')
          fprintf('-> Metbolite correction calculated from injection time\n');
          p_data = bids.File(pet_data{1});
          offset = p_data.metadata.InjectionStart;
        else
          error(['Reference must be either "max" (injection peak) ', ...
                'or "inj" (injection time)']);
        end

        int_blood = pet_IDIF.metabolites_correction(int_blood, mid_time, ...
                                                    met_conf.method, ...
                                                    met_conf.parameters,
                                                    offset);
        int_plasma = pet_IDIF.metabolites_correction(int_plasma, mid_time, ...
                                                     met_conf.method, ...
                                                     met_conf.parameters,
                                                     offset);

        p.entities.metabolite = met_conf.method;
        p = p.metadata_update('MetaboliteModel', met_conf.method,...
                              'MetaboliteParameters', met_conf.parameters);
        p.extension = '.tsv';
        p.entities.label = 'blood';
        T = table(mid_time, int_blood, 'VariableNames', {'onset', 'input_function'});
        writetable(T, fullfile(out_dir, p.filename),...
                   'FileType', 'text', 'Encoding', 'UTF-8',...
                   'Delimiter', '\t');

        p.entities.label = 'plasma';
        T = table(mid_time, int_plasma, 'VariableNames', {'onset', 'input_function'});
        writetable(T, fullfile(out_dir, p.filename),...
                   'FileType', 'text', 'Encoding', 'UTF-8',...
                   'Delimiter', '\t');
      end


    catch ME
      warning('Subject %s failed: %s', sub, ME.getReport('extended'));
      continue;
    end

  end
end


function res = fwhm2sigma(FWHM)
  % passing from width at half maximum to sigma
  res = FWHM / (2 * sqrt(2 * log(2)));
end

function psf = gaus3D_psf(sigma)
  dim = 4 * int8(sigma) + 1;
  idx = dim / 2;
  psf = zeros(dim);
  psf(idx(1), idx(2), idx(3)) = 1;
  psf = imgaussfilt3(psf, sigma);
end
