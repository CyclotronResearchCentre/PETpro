function mask = get_geom_mask(mean_im, params)
  % Generates cilindrical mask around COM of image

  fprintf('--> Creating geometrical mask\n')
  % default values
  def_params.radius = 15;       % Radius, in voxels of cilindrical mask
  def_params.z_rejection = 10;  % Number of top and bottom layer to ignore

  params = crc_update_config(params, def_params);

  [dim_x, dim_y, dim_z] = size(mean_im);
  mask = zeros(dim_x, dim_y);
  mask(com(mean_im, 1), com(mean_im, 2)) = 1;
  mask = imdilate(mask, strel("disk", params.radius, 0));
  mask = repmat(mask, 1, 1, dim_z);
  % mask(:, :, 1:params.z_rejection) = 0;
  mask(:, :, 1:com(mean_im, 3)) = 0;
  mask(:, :, end-params.z_rejection: end) = 0;
  mask = logical(mask);
end
