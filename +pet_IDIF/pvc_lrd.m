function data_pvc = pet_lrd(data, psf, frames)
  % PVC using Lucy-Ricardson method
  dim = size(data);
  if frames <= 0
    frames = dim(1);
  end
  dim = dim(2:end);

  data_pvc = zeros([frames, dim]);
  for i = 1:frames
    fprintf('\tFrame %d: ', i);
    tempIF = squeeze(data(i, :, :, :));
    tic
    J = deconvlucy(tempIF, psf);
    data_pvc(i, :) = J(:);
    fprintf('%f seconds\n', toc);
  end
end
