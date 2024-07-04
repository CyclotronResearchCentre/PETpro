% This file is modified version of magia_logan_image.m function
% from magia pet toolkit
% https://github.com/tkkarjal/magia
% 
% In difference of original function, it applyes NaN mask and zero mask
% but only for frames after t*


function parametric_images = logan_image(pet_filename, input, frames, brainmask_filename, ...
                                         start_time, end_time, outputdir)
%%
%% Parameters:
%% -----------
%%  pet_filename: spm_vol or path to pet image
%%  input: matrix Nx2 representing input function values
%%  frames: matrix Mx2 representing frames start and end time
%%  brainmask_filename: path to brain mask, if empty, no brain mask applied
%%  outputdir: path to directory where logan image will be stored

V = spm_vol(pet_filename);
pet_img = spm_read_vols(V);
pet_img = reshape(pet_img,[prod(V(1).dim(1:3)) size(V,1)])';
V = V(1);

% Selecting only frames after start_time to create mask
foi = find(frames(:, 2) > start_time, 1);
non_zero_mask = reshape(~any(pet_img(foi:end, :) <= 0),V.dim);
non_nan_mask = reshape(~any(isnan(pet_img)),V.dim);
mask = non_nan_mask & non_zero_mask;

% applying brain mask
if ~isempty(brainmask_filename)
  V_mask = spm_vol(brainmask_filename);
  mask = mask  & (spm_read_vols(V_mask) > 0);
end

pet_img = pet_img(:,mask);

% Removing NaN and Inf from input function
input(isnan(input(:, 2)) | isinf(input(:, 2)), :) = [];

fprintf('Starting Logan fit to %.0f voxels...',sum(mask(:)));
[Vt, intercept, X, Y, k] = magia_fit_logan(pet_img,input,frames,start_time,end_time);
fprintf(' Ready.\n');

LoganQC.mask = mask;
LoganQC.Vt = Vt;
LoganQC.intercept = intercept;
LoganQC.X = X;
LoganQC.Y = Y;
LoganQC.k = k;
LoganQC = pet_Model.QC(LoganQC);

Vt_img = zeros(size(mask));
intercept_img = Vt_img;

Vt_img(mask) = Vt;
intercept_img(mask) = intercept;

parametric_images = cell(2,1);

p = bids.internal.parse_filename(pet_filename);
p.use_schema = false;
p.entities.rec = 'Logan';
p.entities.Tstart = int2str(start_time);
if (end_time > 0)
  p.entities.Tend = int2str(end_time);
end

V.dt = [spm_type('int16') 0];
V.pinfo = [inf inf inf]';

p.suffix = 'Vt';
niftiname = fullfile(outputdir, crc_create_filename(p));
    
V.fname = niftiname;
V.private.dat.fname = niftiname;
spm_write_vol(V,Vt_img);

parametric_images{1} = niftiname;

p.suffix = 'intersect';
niftiname = fullfile(outputdir, crc_create_filename(p));

V.fname = niftiname;
V.private.dat.fname = niftiname;  
spm_write_vol(V,intercept_img);

p.suffix = 'r2';
niftiname = fullfile(outputdir, crc_create_filename(p));

V.fname = niftiname;
V.private.dat.fname = niftiname;  
spm_write_vol(V, LoganQC.r2);

p.suffix = 'S';
niftiname = fullfile(outputdir, crc_create_filename(p));

V.fname = niftiname;
V.private.dat.fname = niftiname;  
spm_write_vol(V, LoganQC.s);

p.suffix = 'QC';
p.ext = '.mat';
fname = fullfile(outputdir, crc_create_filename(p));
save(fname, 'LoganQC');



p.suffix = 'mask';
p.ext = '.nii';
niftiname = fullfile(outputdir, crc_create_filename(p));
V.fname = niftiname;
V.private.dat.fname = niftiname;  
spm_write_vol(V,mask);

parametric_images{2} = niftiname;

end 
