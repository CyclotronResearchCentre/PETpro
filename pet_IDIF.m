function outDataset = pet_IDIF(source, destination, varargin)
  % Extract IF from dynamic PET image based on carotide mask(s)
  % Based on M.Schain [Schain, J. Cereb Blood Flow Metab, 2013]
  % alghorythm.

  % path and name of current script
  [pathStep, procStep] = fileparts(mfilename('fullpath'));

  % Optional parameters definition
  args = inputParser();
  args.addParameter('subjects', '.*');
  args.addParameter('name', procStep);
  args.addParameter('config', fullfile(pathStep, 'config', 'pet.json'));
  args.addParameter('configsection', 'IDIF');
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

  % This will load bidsified dataset into BIDS structure
  BIDS = bids.layout(source,...
                     'use_schema', false,...
                     'index_derivatives', false,...
                     'tolerant', true);
  DERIV = crc_bids_gen_dervative(BIDS, destination, procStep,...
                                 params_section, subjects);

  subjects = bids.query(DERIV,'subjects', 'sub', subjects);

  for iSub = 1:numel(subjects)
    sub = subjects{iSub};

    fprintf('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n');
    fprintf('Processing subject %d/%d %s\n', iSub, numel(subjects), sub);
    fprintf('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n');

    try
      pet_data = crc_bids_query_data(DERIV, params_section.images, sub, 'images');
      caro = crc_bids_query_data(DERIV, params_section.carotide,...
                                 sub, 'carotide');
      p = bids.File(caro{1});
      source = fullfile(p.bids_path, p.filename);

      % calculating times of images
      query_meta = params_section.images.query;
      query_meta.sub = sub;

      query_meta.target = 'FrameTimesStart';
      start_time = bids.query(DERIV, 'metadata', query_meta);
      query_meta.target = 'FrameDuration';
      frame_duration = bids.query(DERIV, 'metadata', query_meta);
      mid_time = start_time + (frame_duration / 2);
      
      fprintf('-> Applying PVC\n');
      V = crc_read_spm_vol(pet_data);
      D = permute(spm_read_vols(V), [4, 1, 2, 3]);
      C = crc_read_spm_vol(caro);
      caro_mask = spm_read_vols(C(1));

      % Replacing negative values by 0
      D(D < 0) = 0;

      frames = find(mid_time(:) > params_section.PVC.time_correction, 1) - 1;
      pixelspacing = crc_get_vox_size(V(1).mat);
      sigma = fwhm2sigma(params_section.PVC.PSF.FWHM);
      % caro_smooth = gauss3filter(caro_mask, sigma, pixelspacing);
      sigma = sigma' ./ pixelspacing;

      if strcmp(params_section.PVC.method, 'gmt')
        fprintf('--> Applying PVC using GMT with 1 compartement\n')
        fprintf('\tSigma: [%.3f, %.3f, %.3f] pixels\n',...
                sigma(1), sigma(2), sigma(3));
        fprintf('\tFrames used: %d (%d sec)\n', frames,...
                params_section.PVC.time_correction);
        caro_smooth = imgaussfilt3(caro_mask, sigma);
        data_pvc = pet_IDIF.pvc_gmt1(D, caro_smooth, frames);
      elseif strcmp(params_section.PVC.method, 'lrd')
        fprintf('--> Applying PVC using Lucy-Richardson deconvolution method\n');
        fprintf('\tSigma: [%.3f, %.3f, %.3f] pixels\n',...
                sigma(1), sigma(2), sigma(3));
        fprintf('\tFrames used: %d (%d sec)\n', frames,...
                params_section.PVC.time_correction);
        psf = gaus3D_psf(sigma);
        data_pvc = pet_IDIF.pvc_lrd(D, psf, frames);
      elseif strcmp(params_section.PVC.method, 'none')
        data_pvc = D;
      else
        error('Unknown method for PVC: %s', params_section.PVC.method);
      end

      D(D == 0) = nan;

      idx_caro = find(caro_mask);

      IF_PVC = zeros(numel(mid_time), 1);
      IF = zeros(numel(mid_time), 1);
      for i = 1:numel(mid_time)
          IF(i) = mean(D(i, idx_caro), 'omitnan');
          if i <= size(data_pvc, 1)
            tmp = data_pvc(i, idx_caro);
            IF_PVC(i) = mean(tmp(:), 'omitnan');
          else
              IF_PVC(i) = IF(i);
          end
      end

      if isfield(params_section, 'metabolite')
        met_conf = params_section.metabolite;
        if strcmp(met_conf.offset, 'peak')
          fprintf('-> Metbolite correction calculated from injection peak\n');
          offset = nan;
        elseif strcmp(met_conf.offset, 'injection')
          fprintf('-> Metbolite correction calculated from injection time\n');
          p_data = bids.File(pet_data{1});
          offset = p_data.metadata.InjectionStart;
        else
          error(['Reference must be either "peak" (injection peak) ', ...
                'or "injection" (injection time)']);
        end

        IF_MET = pet_IDIF.metabolites_correction(IF_PVC, mid_time, ...
                                                 met_conf.model, ...
                                                 met_conf.params, ...
                                                 offset);
        p.entities.metabolite = met_conf.model;
        p = p.metadata_update('MetaboliteModel', met_conf.model,...
                              'MetaboliteParameters', met_conf.params);
      end

      fig = figure('Name', 'Image Derived Input Function',...
                   'visible', 'off');
      loglog(mid_time, IF, '-b*', 'linewidth', 1, ...
             'DisplayName', 'IDIF');
      hold on;
      loglog(mid_time, IF_PVC, '-r*', 'linewidth', 1, ...
             'DisplayName', 'IDIF+PVC');
      loglog(mid_time, IF_MET, '--r*', 'linewidth', 1, ...
             'DisplayName', 'IDIF+PVC+metabolite');

      legend;
      xlabel('Time [s]');
      xlim([1, 1e+4]);
      ylim([1e1, 1e+5]);
      ylabel('Count [Bq]');
      title(['sub-', sub, ' input function']);
      hold off;

      p.modality = 'pet_IF';
      p.extension = '.png';
      p.suffix = 'if';
      p.entities.pvc = params_section.PVC.method;

      out_dir = fullfile(outDataset, p.bids_path);
      if ~exist(out_dir)
        mkdir(out_dir);
      end
      saveas(fig, fullfile(out_dir, p.filename));

      p.extension = '.tsv';
      out_pth = fullfile(outDataset, p.bids_path);
      p.path = fullfile(out_pth, p.filename());
      p.metadata_write('Description', 'IF from crotides mask with PVC and metabolite correction',...
                       'Sources', {source},...
                       'PVC', params_section.PVC);

      T = table(mid_time, IF_MET, 'VariableNames', {'onset', 'input_function'});
      writetable(T, fullfile(out_dir, p.filename),...
                 'FileType', 'text', 'Encoding', 'UTF-8',...
                 'Delimiter', '\t');
      

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
