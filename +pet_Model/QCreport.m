function QCreport(model_data, varargin)

  p = inputParser;
  p.addParameter('interactive', true);
  p.addParameter('mask', '');
  p.addParameter('maskCut', 0.8);
  p.addParameter('baseName', '');
  p.addParameter('path', '.');
  p.addParameter('nvox', 10);

  p.parse(varargin{:});

  vis = 'Off'; 
  if p.Results.interactive
    vis = 'On';
  end 

  data_mask = (model_data.Vt ~= 0);

  pos = [100 100];
  delta = [40 -40];

  if isempty(p.Results.mask)
    label = 'full';
    mask = data_mask;
  else
    M = spm_vol(p.Results.mask);
    fp = bids.File(M(1).fname);
    if isfield(fp.entities, 'label')
      label = fp.entities.label;
    elseif ~isempty(fp.prefix)
      label = fp.prefix;
    else
      label = 'unknown';
    end
    fprintf('Loading mask %s with label %s\n', p.Results.mask, label);
    mask = spm_read_vols(M(1));
    mask = data_mask & (mask > p.Results.maskCut);
  end

  fprintf('Overview for %s (%s)\n', p.Results.baseName, label);
  figs = plot_Overview(label,...
                       model_data.Vt, model_data.r2, model_data.s,...
                       mask, vis);
  if ~isempty(p.Results.baseName)
    fig = fieldnames(figs);
    for ifig = 1:numel(fig)
      out = gen_name(p.Results.path, p.Results.baseName,...
                     label, [], fig{ifig});
      saveas(figs.(fig{ifig}), out);
      %close(figs.(fig{ifig}));
      delete(figs.(fig{ifig}));
    end
  end

  index  = find(mask);
  select = index(randperm(length(index), p.Results.nvox));
  irnd = 1;
  vox = [0, 0, 0];

  fprintf('Logan plots for %s (%s)\n', p.Results.baseName, label);
  while (p.Results.interactive | irnd <= numel(select))
    if p.Results.interactive
      vox = get_coordinates();
    else
      % in = generate random coordinate from mask
      [vox(1), vox(2), vox(3)] = ind2sub(size(mask), select(irnd));
      irnd = irnd + 1;
    end

    if isempty(vox)
      fprintf('Quitting\n')
      break;
    end
    fprintf('\t%d: [%d, %d, %d]\n', irnd - 1, vox(1), vox(2), vox(3));

    if exist('vox_fig', 'var') && ~vox_fig.isvalid()
      clear vox_fig, a, b;
    end
    [vox_fig, a, b] = voxel_inspection(label, vis);

    try
      i = sub2ind(model_data.dim, vox(1), vox(2), vox(3));
      x = model_data.X(:, i);
      y = model_data.Y(:, i);
      yy = model_data.intercept(i) + model_data.Vt(i)*x;

      % subplot(2, 1, 1);
      ax = subplot('Position', [0.1, 0.4, 0.8, 0.5], 'Parent', vox_fig);
      % plot(ax, x,y,'ko'); hold on;
      plot(ax, x(model_data.k),y(model_data.k),'ro');
      hold on;
      plot(ax, x(model_data.k),yy(model_data.k),'r');
      ax.YAxis.Exponent = 3;
      xticklabels([]);
      ylabel(ax, '\int_0^t C_t(\tau) d\tau / C_t(t)');
      x_lim = xlim(ax);
      x_lim(1) = 0;
      xlim(ax, x_lim);
      y_lim = ylim(ax);
      y_lim(1) = 0;
      ylim(ax, y_lim);
      plot(ax, x(~model_data.k),y(~model_data.k),'ko');

      title(sprintf('Logan plot for voxel [%d, %d, %d]',...
                    vox(1), vox(2), vox(3)));
      
      set(a, 'String',...
          sprintf('Vt = %.2f;\nintercept = %.2f\nr^2 = %.2f\nS = %.2f',...
          round(model_data.Vt(i),2),...
          round(model_data.intercept(i),2),...
          round(model_data.r2(i), 2),...
          round(model_data.s(i), 2)));
      hold off;

      % subplot(2, 1, 2);
      ax = subplot('Position', [0.1, 0.18, 0.8, 0.22], 'Parent', vox_fig);
      residuals = (y(model_data.k) - yy(model_data.k)) ./ yy(model_data.k);
      plot(ax, x(model_data.k), residuals, 'ro');
      ax.YAxisLocation = 'right';
      xlim(ax, x_lim);
      xlabel(ax, '\int_0^t C_p(\tau) d\tau / C_t(t)');
      ylabel(ax, 'Residuals');
      ylim(ax, [-0.2 0.2]);

      hold on;
      plot(ax, x_lim,[0 0], 'k--');
      plot(ax, x_lim,[0.1 0.1], 'k:');
      plot(ax, x_lim,[-0.1 -0.1], 'k:');
      hold off;

      if ~isempty(p.Results.baseName)
        out = gen_name(p.Results.path, p.Results.baseName,...
                       label, vox, 'fit');
        saveas(vox_fig, out);
        %close(vox_fig);
        delete(vox_fig);
      end

    catch ME
      msg = sprintf('Can''t retrieve data from voxel [%d %d %d]:\n%s',...
                    vox(1), vox(2), vox(3), ME.message);

      if p.Results.interactive
        uiwait(msgbox(msg, 'Error','error', 'modal'));
      end
    end
  end
end

function figs = plot_Overview(label, Vt, r2, s, mask, vis)
  figs.r2 = figure('Visible', vis, 'Position', [100 100 700 300],...
                   'Name', ['r^2 ' label]);
  data = log10(1-r2(mask));
  plot_QC(figs.r2, data, Vt(mask), '1 - r^2');
  subs = get(figs.r2, 'children');
  for isub = 1:numel(subs)
    sub = subs(isub);
    if ~strcmp(get(sub,'type'), 'axes')
      continue;
    end
    set_log_axis(sub, 'X', [-4, 0]);
  end
  % S plots
  figs.S = figure('Visible', vis, 'Position', [100 100 700 300],...
                  'Name', ['S ' label]);
  data = log10(s(mask));
  plot_QC(figs.S, data, Vt(mask), 'S');
  subs = get(figs.S, 'children');
  for isub = 1:numel(subs)
    sub = subs(isub);
    if ~strcmp(get(sub,'type'), 'axes')
      continue;
    end
    set_log_axis(sub, 'X', [1, 3]);
  end
end

function plot_QC(fig, data, Vt_data, name)
  subplot('Position', [0.08 0.2 0.4 0.7], 'Parent', fig);

  histogram2(data, Vt_data,...
             [100 60], 'DisplayStyle', 'tile');
  ylabel('Vt');
  xlabel(name);
  colorbar;
  view(2);

  subplot('Position', [0.56, 0.2, 0.4, 0.7], 'Parent', fig);
  histogram(data, 100);
  xlabel(name);
  ylabel('Counts');
  fprintf('%s mean value = %0.2f\n', name, mean(data));

end

function [fig, annot_top, annot_bot] = voxel_inspection(name, vis)
  fig = figure('Position', [100 100 700 300],...
               'Name', [name ' Logan plot'],...
               'Visible', vis);
  annot_top = annotation('textbox', [0.15 0.80 0.1 0.1]);
  set(annot_top,'Color','k','LineStyle','none','FontSize',12);
      
  annot_bot = annotation('textbox', [0.15 0.30 0.1 0.1]);
  set(annot_bot,'Color','k','LineStyle','none','FontSize',12);
end

function vox = get_coordinates()
  opts.WindowStyle = 'normal';
  in = inputdlg({'Enter voxel corrdinates:'}, 'Voxel Logan plot',...
                1, {''}, opts);
  if isempty(in)
    vox = [];
    return;
  end

  try
    vox = textscan(in{1}, '%d');
    vox = vox{1};
    assert(size(vox, 1) ==3);
  catch
    msg = sprintf('Invalid coordinates: "%s"', in{1});
    uiwait(msgbox(msg, 'Error', 'error', 'modal'));
  end
end

function res = gen_name(path, base, mask, voxel, suffix)
  p = bids.File(base);
  p.extension = '.png';
  p.suffix = suffix;
  if isempty(voxel)
    p.entities.vox = '';
  else
    vox = sprintf('%03dx%03dx%03d', voxel(1), voxel(2), voxel(3));
    p.entities.vox = vox;
  end
  p.entities.mask = mask;
  res = fullfile(path, p.filename);
end
