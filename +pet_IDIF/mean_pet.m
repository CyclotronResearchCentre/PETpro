function [mean_inj, mean_sig, noise_mask] = mean_pet(vv, frames)
  % Calculates average image from signal and injection frames
  % Also caclulates noise mask
  %
  % Parameters:
  %   vv: 4D matrix representing PET image
  %   frames: structure containing parameters for calculating means
  %   frames.injection: range of frames for injection region
  %   frames.signal: range of frames for signal region
  %   frames.noise_cut: cummulative value of voxels to be considered as noisy

  % default values
  def_frames.injection = [2, 6]; % Frames defining injection region
  def_frames.signal = [8];       % Frames defining signal region
  def_frames.noise_cut = 1.2;    % If sum of negative values of voxel is below this,
                                 % voxel is noisy
  
  fprintf('--> Calculating mean injection and signal for frames:\n');
  frames = crc_update_config(frames, def_frames);

  if numel(frames.injection) < 2
    frames.injection = [1, frames.injection(1)];
  end

  if numel(frames.signal) < 2
    frames.signal = [frames.signal(1), size(vv, 4)];
  end

  v_inj = vv(:, :, :, frames.injection(1):frames.injection(2));
  v_sig = vv(:, :, :, frames.signal(1):frames.signal(2));

  mean_sig_noise = mean(v_sig, 4, 'omitnan');

  % Removing negative values from frames
  v_inj(v_inj < 500) = nan;
  v_sig(v_sig < 0) = nan;

  mean_inj = mean(v_inj, 4, 'omitnan');
  mean_sig = mean(v_sig, 4, 'omitnan');

  noise_sig = mean_sig ./ mean_sig_noise;
  noise_sig(noise_sig <= 0) = 10;

  noise_mask = (noise_sig < frames.noise_cut);
end
