function V = crc_read_spm_vol(files)
%% Function facilitating the reading of multivolumes
%% nii files
%% 
%% Input parameter files are either a single path to
%% nii, a cellarray of paths to nii, or spm_vol structure
%%
%% In all cases function returns a structarray of spm_vol
  if iscell(files)
    % concatenating volulumes
    V = spm_vol(files{1});
    for iFile = 2:numel(files)
      V = [V; spm_vol(files{iFile}) ]; %#ok<AGROW>
    end
  else
    V = spm_vol(files);
  end

end
