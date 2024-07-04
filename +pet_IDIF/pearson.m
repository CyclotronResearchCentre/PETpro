function R = pearson(X, Y)
  x_dim = size(X);
  y_dim = size(Y);

  if size(x_dim, 2) ~= 2
    X = X(:, :);
  end

  if size(y_dim, 2) ~= 2
    Y = Y(:, :);
  end

  n = x_dim(1);
  if n ~= y_dim(1)
    error('Number of data points in X (%d) do not matches Y (%d)', ...
          n, y_dim(1));
  end

  Xc = X - ones(n, 1) * mean(X);
  for i = 1 : numel(X(1, :))
    Xn(:, i) = Xc(:, i) ./ norm(Xc(:, i));
  end

  Yc = Y - ones(n, 1) * mean(Y);
  for i = 1 : numel(Y(1, :))
    Yn(:, i) = Yc(:, i) ./ norm(Yc(:, i));
  end

  R = Yn' * Xn;

end
