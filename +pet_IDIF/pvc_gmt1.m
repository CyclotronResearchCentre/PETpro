function data_pvc = pvc_gmt1(data, psf, frames)
  % PVC using GMT with 1 compartement
  dim = size(data);
  if frames <= 0
    frames = dim(1);
  end
  dim = dim(2:end);

  data_pvc = zeros([frames, dim]);
  for i = 1:frames
    data_pvc(i, :) = data(i, :) ./ psf(:)';
  end
end
