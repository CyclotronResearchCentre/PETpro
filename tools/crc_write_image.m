function name = crc_write_image(V, data, name)
  %% Helper function to write a matrix on disc as
  %% nii image, using spm_vol structure.
  %% The scaling for float (single and double) are reset
  %% for other set to (1, 0)
  %% see help for spm_vol
  %%
  %% Parameters:
  %% -----------
  %%   V: spm_vol
  %%      spm_vol structure used for writing data
  %%   data: matrix
  %%      matrix to write
  %%   name: chararray
  %%      path to file to write
  %%
  %% Returns:
  %% --------
  %%   name: chararray
  %%      name of saved file

  V.fname = name;
  if isa(data, 'double') || isa(data, 'single')
    V = rmfield(V, 'pinfo');
  else
    V.pinfo(1) = 1;
    V.pinfo(2) = 0;
  end
  data = reshape(data, V.dim);
  spm_write_vol(V,data);
end
