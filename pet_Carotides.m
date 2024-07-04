function outDataset = pet_IDIF(source, destination, varargin)
  % Extracts carotides masks from PET dinamic scan, masks among
  % other images are stored in Carotides modality.
  % Output contain:
  %   seed mask: label-CR_desc-seed_mask.nii
  %     seeds used for carotid detection
  %   core mask: label-CR_desc-core_mask.nii
  %     core region with high quality signal
  %   expanded mask: label-CR_desc-expanded_mask.nii
  %     expanded carotides, with less reliable signal
  %   mean injection: label-mean_desc-injection_pet.nii 
  %     mean PET image from injection window
  %   mean signal: label-mean_desc-signal_pet.nii 
  %     mean PET image from signal window
  %   ratio between injection and signal: label-ratio_pet.nii
  %     ratio of PET mean images between injection and signal windows 

  % path and name of current script
  [pathStep, procStep] = fileparts(mfilename('fullpath'));

  % Optional parameters definition
  args = inputParser();
  args.addParameter('subjects', '.*');
  args.addParameter('name', procStep);
  args.addParameter('config', fullfile(pathStep, 'config', 'pet.json'));
  args.addParameter('configsection', 'Carotides');
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
      fprintf('-> Searching for carotides...\n');
      pet_data = crc_bids_query_data(DERIV, params_section.images, sub, 'images');
      
      V = crc_read_spm_vol(pet_data);
      p = bids.File(V(1).fname);
      p.modality = 'Carotides';

      out_pth = fullfile(outDataset, p.bids_path);
      p.path = fullfile(out_pth, p.filename());
      if ~exist(out_pth, 'dir')
        mkdir(out_pth);
      end

      sources = {};
      p = p.metadata_update('RawSources', pet_data);

      % Reading data and calculating mean signal and injection
      vv = spm_read_vols(V);
      [frames, fig] = pet_IDIF.frame_estimate(vv, params_section.frames);
      p_fig = p;
      p_fig.extension = '.png';
      p_fig.suffix = 'AC';
      p_fig.entities.label = 'central';
      title(p.entities.sub);
      saveas(fig, fullfile(out_pth, p_fig.filename()));

      [mean_inj, mean_sig, noise_mask] = pet_IDIF.mean_pet(vv, frames);
      p.entities.description = 'noise';
      p.suffix = 'mask';
      crc_write_image(V(1), noise_mask, fullfile(out_pth, p.filename()));
      p.metadata_write('Description', 'Average signal in injection time window',...
                       'Frames', frames.injection);
      sources{end + 1} = fullfile(p.bids_path, p.filename());

      p.suffix = 'pet';
      p.entities.label = 'mean';
      p.entities.description = 'injection';
      crc_write_image(V(1), mean_inj, fullfile(out_pth, p.filename()));
      p.metadata_write('Description', 'Average signal in injection time window',...
                       'Frames', frames.injection);
      sources{end + 1} = fullfile(p.bids_path, p.filename());
      p.entities.description = 'signal';
      crc_write_image(V(1), mean_sig, fullfile(out_pth, p.filename()));
      p.metadata_write('Description', 'Average signal in signal time window',...
                       'Frames', frames.signal);
      sources{end + 1} = fullfile(p.bids_path, p.filename());
      
      % Creating masks
      geom_mask = pet_IDIF.cilindrical_mask(mean_sig, params_section.masks);

      % Creating ratio injection to noise
      v_ratio = mean_inj ./ mean_sig;
      v_ratio(isnan(v_ratio) | isinf(v_ratio) ) = 0;
      v_ratio(~geom_mask) = 0;
      v_ratio(v_ratio < 0) = 0;
      v_ratio(mean_inj < 0) = 0;
      
      p.entities.label = 'ratio';
      p.entities.description = '';
      crc_write_image(V(1), v_ratio, fullfile(out_pth, p.filename()));
      p.metadata_write('Description', 'Ratio between mean injection and mean signal',...
                       'Sources', sources);

      ratio_mask = v_ratio > params_section.masks.signal;

      seed_candidates = v_ratio .* (noise_mask & ratio_mask);
      caro_candidates = mean_inj .* ratio_mask;

      [seeds_mask, core_mask, exp_mask] = pet_IDIF.caro_search(...
          seed_candidates, caro_candidates,...
          params_section.seed,...
          params_section.expansion);
      p.suffix = 'mask';                                                    
      p.entities.label = 'CR';
      p.entities.description = 'seed';
      crc_write_image(V(1), seeds_mask, fullfile(out_pth, p.filename()));
      p.metadata_write('Description', 'Mask of seeds used for carotides search',...
                       'Sources', sources);

      p.entities.description = 'core';
      crc_write_image(V(1), core_mask, fullfile(out_pth, p.filename()));
      p.metadata_write('Description', 'Mask of core carotid region',...
                       'Sources', sources);

      p.entities.description = 'expanded';
      crc_write_image(V(1), exp_mask, fullfile(out_pth, p.filename()));
      p.metadata_write('Description', 'Mask of expanded carotides region',...
                       'Sources', sources);

      corr_mask = pet_IDIF.caro_correlate(vv, core_mask, exp_mask,...
                                          params_section.correlation);
      p.entities.description = 'correlated';
      crc_write_image(V(1), corr_mask, fullfile(out_pth, p.filename()));
      p.metadata_write('Description', 'Mask of correlated carotides region',...
                       'Sources', sources);

    catch ME
      warning('Subject %s failed: %s', sub, ME.getReport('extended'));
      continue;
    end

  end

end
