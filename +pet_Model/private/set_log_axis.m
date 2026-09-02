function set_log_axis(ax, axis, limit)

  strAxis = [axis 'Axis'];
  strGrid = [axis 'Grid'];
  strLimit = [axis 'Lim'];
  strTicks = [axis 'Tick'];
  strMinorGrid = [axis 'MinorGrid'];
  if ~exist('limit', 'var') || isempty(limit)
    limit = ax.(strLimit);
  else
    if isnan(limit(1))
      limit(1) = ax.(strLimit)(1);
    end

    if isnan(limit(2))
      limit(2) = ax.(strLimit)(2);
    end
  end

  ax.(strLimit) = limit;

  ticks = ax.(strTicks);
  dticks = max(1, round(ticks(2) - ticks(1)));
  major = round(ticks(1)):dticks:limit(2);
  major(end + 1) = major(end) + dticks;
  labels = {};
  minor = [];
  minor_base = log10(0.2:0.1:0.9) * dticks;
  for m = major(1:end)
    labels{end + 1} = sprintf('10^{%d}', m);
    minor = [minor, m + minor_base];
  end

  ax.(strAxis).TickValues = major;
  ax.(strAxis).TickLabels = labels;
  ax.(strAxis).MinorTick = 'on';
  ax.(strAxis).MinorTickValues = minor;
  ax.(strGrid) = 'on';
  ax.(strMinorGrid) = 'on';

end
