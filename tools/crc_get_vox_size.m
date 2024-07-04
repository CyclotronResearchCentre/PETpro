function vox_size = crc_get_vox_size(M)
  % Extract the scaling parameters (voxel size) from affine transformation matrix
  vox_size = sqrt(sum(M(:, 1:3).^2));
end
