function model_data = QC(model_data)

  [r2, s] = r2_from_fit(model_data.Vt, model_data.intercept,...
                        model_data.X, model_data.Y, model_data.k);

  model_data.dim = size(model_data.mask);
  tot_size = prod(model_data.dim);

  base_img = zeros(model_data.dim);
  r2_full = base_img;
  r2_full(model_data.mask) = r2;
  s_full = base_img;
  s_full(model_data.mask) = s;
  model_data.r2 = r2_full;
  model_data.s = s_full;
  
  Vt = base_img;
  Vt(model_data.mask) = model_data.Vt;
  model_data.Vt = Vt;

  inter = base_img;
  inter(model_data.mask) = model_data.intercept;
  model_data.intercept = inter;

  X = zeros(size(model_data.k, 1), tot_size);
  Y = X;
  for i = 1:size(model_data.k, 1)
    x = base_img;
    x(model_data.mask) = model_data.X(i, :);
    X(i, :) = x(:); 

    y = base_img;
    y(model_data.mask) = model_data.Y(i, :);
    Y(i, :) = y(:); 
  end

  model_data.X = X;
  model_data.Y = Y;
end

function [r2, s] = r2_from_fit(Vt, intercept, X, Y, k)
  % Calculates r2 from Logan model fit
  % 
  data_mean = mean(Y(k, :));
  data_var = sum((Y(k, :) - data_mean).^2);

  model = zeros(size(X));

  for i = 1:size(X, 2)
    x = X(k, i);
    y = Y(k, i);
    model(k,i) = intercept(i) + Vt(i) * x;
  end

  dev = (Y(k, :) - model(k, :));
  num = sum(dev.^2);

  s = mean(abs(dev));

  r2 = 1 - num ./ data_var;

end
