function QCreport(model_data, varargin)

  p = inputParser;
  p.addParameter('interactive', true);
  p.addParameter('mask', '');
  p.addParameter('maskCut', 0.8);
  p.addParameter('baseName', '');


  p.parse(varargin{:});

  vis = 'Off'; 
  if p.Results.interactive
    vis = 'On';
  end 

  data_mask = (model_data.Vt ~= 0);
  pos = [100 100];
  delta = [50 -50];

  if isempty(p.Results.mask)
    fprintf('%s full brain\n', p.Results.baseName);
    % r2 Plots
    fig = figure('Visible', vis, 'Position', [pos 700 800],...
                 'Name', ['r^2' p.Results.baseName ' full brain']);
    pos = pos + delta;
    plot_QC(fig, model_data.r2(data_mask), model_data.Vt(data_mask), 'r^2');

    % S plots
    fig = figure('Visible', vis, 'Position', [pos 700 800],...
                 'Name', ['S' p.Results.baseName ' full brain']);
    pos = pos + delta;
    subplot(2, 1, 1);
    plot_QC(fig, model_data.s(data_mask), model_data.Vt(data_mask), 'S');
  else
    M = spm_vol(p.Results.mask);

    for i = 1:numel(M)
      fprintf('%s mask %d\n', p.Results.baseName, i);
      mask = spm_read_vols(M(i));

      data_mask = mask > p.Results.maskCut;
      
      fig = figure('Visible', vis, 'Position', [pos 700 800],...
                   'Name', sprintf('r^2 %s mask %d', p.Results.baseName, i));
      pos = pos + delta;
      plot_QC(fig, model_data.r2(data_mask), model_data.Vt(data_mask), 'r^2');

      fig = figure('Visible', vis, 'Position', [pos 700 800],...
                   'Name', sprintf('S %s mask %d', p.Results.baseName, i));
      pos = pos + delta;
      plot_QC(fig, model_data.s(data_mask), model_data.Vt(data_mask), 'S');
    end
  end

  if p.Results.interactive
    while true
      opts.WindowStyle = 'normal';
      in = inputdlg({'Enter voxel corrdinates:'}, 'Voxel Logan plot',...
                    1, {''}, opts);
      if isempty(in)
        fprintf('Quitting\n')
        break;
      end

      try
        vox = textscan(in{1}, '%d');
        vox = vox{1};

        assert(size(vox, 1) ==3);
      catch
        msg = sprintf('Invalid coordinates: "%s"', in{1});
        uiwait(msgbox(msg, 'Error', 'error', 'modal'));
        continue;
      end

      if ~exist('vox_fig', 'var') || ~vox_fig.isvalid()
        [vox_fig, a, b] = voxel_inspection(pos, p.Results.baseName);
      elseif ~vox_fig.isvalid()
        clear vox_fig, a, b;
        [vox_fig, a, b] = voxel_inspection(pos, p.Results.baseName);
      end

      try
        i = sub2ind(model_data.dim, vox(1), vox(2), vox(3));
        x = model_data.X(:, i);
        y = model_data.Y(:, i);
        yy = model_data.intercept(i) + model_data.Vt(i)*x;

        figure(vox_fig);
        subplot(2, 1, 1);
        plot(x,y,'ko'); hold on;
        plot(x(model_data.k),y(model_data.k),'ro');
        plot(x(model_data.k),yy(model_data.k),'r');
        xlabel('\int_0^t C_p(\tau) d\tau / C_t(t)');
        ylabel('\int_0^t C_t(\tau) d\tau / C_t(t)');
        title(sprintf('Logan plot for voxel [%d, %d, %d]',...
                      vox(1), vox(2), vox(3)));
        
        set(a, 'String',...
            sprintf('Vt = %.2f;\nintercept = %.2f\nr^2 = %.2f\nS = %.2f',...
            round(model_data.Vt(i),2),...
            round(model_data.intercept(i),2),...
            round(model_data.r2(i), 2),...
            round(model_data.s(i), 2)));
        hold off;

        subplot(2, 1, 2);
        residuals = yy(model_data.k) - y(model_data.k);
        pd = fitdist(residuals,'Normal');
        histfit(residuals, 5);
        xlabel('Residuals');
        ylabel('Counts');
        base_str = ['\mu = ' sprintf('%.2g\n', pd.mu())...
                    '\sigma = ' sprintf('%.2g', pd.sigma())];
        set(b, 'String', base_str);

      catch ME
        msg = sprintf('Can''t retrieve data from voxel [%d %d %d]:\n%s',...
                      vox(1), vox(2), vox(3), ME.message);
        uiwait(msgbox(msg, 'Error','error', 'modal'));
      end

    end

  end

end

function plot_QC(fig, data, Vt_data, name)
  figure(fig);
  subplot(2, 1, 1);

  histogram2(data, Vt_data,...
             [200 60], 'DisplayStyle', 'tile');
  ylabel('Vt');
  xlabel(name);
  colorbar;
  view(2);

  subplot(2, 1, 2);
  histogram(data, 200);
  set(gca, 'YScale', 'log');
  xlabel(name);
  ylabel('Counts');
  fprintf('%s mean value = %0.2f\n', name, mean(data));

end

function [fig, annot_top, annot_bot] = voxel_inspection(pos, name)
    fig = figure('Position', [pos 700 800],...
                 'Name', [name ' Logan plot']);
    annot_top = annotation('textbox', [0.15 0.80 0.1 0.1]);
    set(annot_top,'Color','k','LineStyle','none','FontSize',12);
        
    annot_bot = annotation('textbox', [0.15 0.30 0.1 0.1]);
    set(annot_bot,'Color','k','LineStyle','none','FontSize',12);

end
