function [frames, fig] = frame_estimate(vv, frames)
  % default values
  def_frames.injection_cut = 0.05;
  def_frames.signal_cut = 0.20;
  def_frames.radius = 15;
  def_frames.min_frame = 1;
  fprintf('--> Estimating injection and signal frames:\n');
  frames = crc_update_config(frames, def_frames);

  [dx, dy, dz, dt] = size(vv);

  mid_frame = vv(:, :, :, round(dt / 2));
  mx = com(mid_frame, 1);
  my = com(mid_frame, 2);
  mz = com(mid_frame, 3);

  fprintf('\tMid-frame COM: (%d, %d, %d)\n', mx, my, mz);

  mask = zeros([dx, dy]);
  mask(mx, my) = 1;
  mask = imdilate(mask, strel('disk', frames.radius, 0));

  av_sig = zeros(dt, 1);

  for i = 1:dt
    slice = vv(:, :, mz, i);
    slice(mask == 0) = NaN;
    av_sig(i) = mean(slice(:), 'omitnan');
  end

  tac_av = cumtrapz(av_sig);
  tac_av = tac_av/tac_av(end);

  frame_inj = find(tac_av >= frames.injection_cut, 1) - 1;
  fprintf('\tInjection limit frame (<%0.2f): %d\n',...
          frames.injection_cut, frame_inj);
  frames.injection = [frames.min_frame, frame_inj];
  frame_signal = find(tac_av >= frames.signal_cut, 1);
  fprintf('\tSignal limit frame (>%0.2f): %d\n',...
          frames.signal_cut, frame_signal);
  frames.signal = [frame_signal];

  fig = figure('Name', 'Central slice activity curve', ...
               'visible', 'off');
  leg = sprintf('Slice at [%d, %d, %d], r = %d', mx, my, mz, 15);
  plot(tac_av, 'Color','blue');
  legend(leg, 'Location', 'southeast');
  ylim([0, 1]);
  hold on;

  xlabel('Frames');
  ylabel('Normalized cummulative count [a.u.]');
  xl = xlim();
  line([xl(1), frame_inj, frame_inj],...
       [frames.injection_cut, frames.injection_cut, 0], ...
       'Color','black','LineStyle','-', 'DisplayName', 'Injection threshold');
  line([xl(1), frame_signal, frame_signal], ...
       [frames.signal_cut, frames.signal_cut, 0], ...
       'Color','black','LineStyle','--', 'DisplayName', 'Signal threshold');

  % Final checks
  assert(frame_inj >= frames.min_frame, ...
         'Injection limit frame lower than minimal frame');
  assert(frame_inj < frame_signal, ...
         'Injection and Signal regions overlapping');
end
