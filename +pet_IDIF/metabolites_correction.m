function IF_corr = metabolites_correction(IF, times, method, parameters, offset)
%   Applies parent fraction correction (metabolate correction) using
%   Sigmoidal and doubleexp (biexponential) functions ith given parameters
%
%   Parameters:
%     IF: Input function to correct (array)
%     times: times corresponding to IF values
%     method: Name of the function to apply
%     parameters: Parameters for method to apply
%     offset: Offset to apply to IDIF in seconds, if nan,
%             offset will be calculated from maximum of IDIF
%             (peak of injection)
%
%   Implemented methods (see implementetions below):
%     Sigmoidal
%     DoubleExp
%
% =========================================================================
%
% M.A. Bahri, 2021.
% Cyclotron Research Centre, University of Liege, Belgium
% =========================================================================
%
    fprintf('-> Applying metabolite correction\n');
    if strcmp(method, "Sigmoidal")
      parent = @(x)Sigmoidal(x, parameters);
    elseif  strcmp(method, "DoubleExp")
      parent = @(x)DoubleExp(x, parameters);
    else
      error("Unknown parent function %s", method)
    end
    fprintf('--> Model %s with:\n', method);
    disp(parameters);

    % calculating offset
    if isnan(offset)
      [~, i] = max(IF);
      offset = times(i);
    end
    fprintf('--> Metabolite offset is %f sec\n', offset);

    % Correct IDIF for metabolite 
    parent_fraction = parent(times - offset);
    IF_corr =  IF .* parent_fraction;

    return

    % plot data 
    out_pth = fileparts(IDIF.fname);
    bids_name =  bids.File(IDIF.fname);

    % generating output path and basename
    out_pth = fullfile(out_pth, '..', 'IDIF');

    % Correct IDIF for metabolite 
    parent_fraction = parent(IDIF.mid_time);
    
    fnames = fieldnames(IDIF);
    for i = 1:numel(fnames)
      if strcmp(fnames{i}, 'mid_time')
        continue;
      end

      if ~isfloat(IDIF.(fnames{i}))
        continue;
      end

      if size(IDIF.(fnames{i}), 1) ~= size(IDIF.mid_time, 1)
        continue;
      end

      if ~isempty(regexp(fnames{i}, '_corrected$'))
        continue;
      end
      name_corrected = [fnames{i} '_corrected'];

      % plot data 
      fig = plot_results(IDIF, parent_fraction, fnames{i});
      % bids_name.entities.desc = 'IDIF';
      bids_name.entities.desc = fnames{i};
      bids_name.suffix = 'report';
      bids_name.extension = '.png';
      figname = fullfile(out_pth, bids_name.filename());
      print(fig, figname, '-dpng');
      fprintf('Report saved to %s\n', figname);
    end

end

function y = Sigmoidal(x, parameters)
  % Implementation of Sigmoidal function with time offset
  % Described here:
  % http://www.turkupetcentre.net/petanalysis/input_parent_fitting.html
  %
  % y = d                              ; if x <= e
  % y = d * (1 - a * exp(-b / (x - e))); if x > e
  %
  % Parameters:
  %   x  - imput x values(vector)
  %   parameters: struct with named parameters, should contain
  %       d - Maximum initial proportion
  %       e  - time offset
  %       a  - Value of exp at limit x -> Inf
  %       b  - exponential decay speed

  x = x - parameters.e;
  y = ones(size(x));
  for i = 1:numel(y)
    if x(i) > 0
      y(i) = 1 - parameters.a * exp(-parameters.b / x(i));
    end
  end
  y = y * parameters.d;
end

function y = DoubleExp(x, parameters)
  % Implementation of sum of exponential models
  %
  % y = a*exp(b*x)+c*exp(d*x)
  %
  % Parameters:
  %   x  - imput x values(vector)
  %   parameters: struct with named parameters, should contain
  %       a  - First exp scale
  %       b  - First exp slope
  %       c  - Second exp scale
  %       d  - Second exp slope

  y = parameters.a * exp(parameters.b * x) +...
    parameters.c * exp(parameters.d * x);
end

function fig = plot_results(IDIF, parent, input)
    %  Generates a report plot of applied metabolite correction.
    %
    %  Top plot shows corrected and uncorrected imput functions.
    %  Bottom plot show the difference between corrected and incorrected
    %  IF, and the applied parent function.
    % 
    %  Parameters:
    %     IDIF   : structure aith time points, corrected and uncorrected IF
    %     parent : pints of parent function, must corresponds to same time
    %              points as IF
    %
    %  Returns:
    %     resulting figure
    %      
    % =====================================================================

    % Plot parent frcaction
    fig = figure('Name', 'Image Derived Input Function', ...
                 'visible', 'off');

    ax1 = subplot(2, 1, 1);
    loglog(ax1, IDIF.mid_time, IDIF.(input),...
             '-r*', 'linewidth', 1, 'DisplayName','Uncorrected IDIF');
    hold on;
    name_corrected = [input '_corrected'];
    loglog(ax1, IDIF.mid_time, IDIF.(name_corrected),...
             '-b*', 'linewidth', 1, 'DisplayName','Corrected IDIF');
    legend;
    xlabel(ax1, 'Time [s]');
    xlim(ax1, [1, 1e+4]);
    ylabel(ax1, 'Count [Bq]');
    title(ax1, 'Imput function');
    hold off;

    ax2 = subplot(2, 1, 2);
    yyaxis left;
    semilogx(ax2, IDIF.mid_time, parent,...
             '-k*', 'linewidth', 1, 'DisplayName','Parent fraction');
    ax2.YColor = 'k';
    xlabel(ax2, 'Time [s]');
    ylabel(ax2, 'a.u.');
    xlim(ax2, xlim(ax1));
    ylim(ax2, [0, 1.2]);
    hold on;
    yyaxis right;
    semilogy(ax2, IDIF.mid_time,...
             IDIF.(input) - IDIF.(name_corrected),...
             '-r*', 'linewidth', 1, 'DisplayName','Correction');
    legend('Location','west');
    title('Correction');
    ax2.YColor = 'r';
    ylabel('Count [Bq]');
    hold off;
end
