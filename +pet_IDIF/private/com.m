function r = com(vv, ax)
  % Calculates center of mass of an array following dimention ax
  r = 0;
  for d = 1:numel(size(vv))
    if d == ax
      continue;
    end
    vv = sum(vv, d, 'omitnan');
  end

  vv = squeeze(vv);
  M = sum(vv, 'omitnan');

  for i = 1:numel(vv)
    r = r + vv(i) * i;
  end

  r = round(r / M);
end
