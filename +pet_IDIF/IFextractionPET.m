function IDIF = IFextractionPET(pet_files, ...
                                SubsetCaro, MaskCaro, ...
                                tFrames, ...
                                varargin)

%   IFextractionPET is a function implementing the Pairwise correlation 
%   method to compute the image derived input function based on the PET 
%   following the method devlopped by M.Schain [Schain, J. Cereb Blood
%   Flow Metab, 2013].
%   
%   Input:
%   pet_files:   Dynamic PET volumes, either in list (3D images) or one 4D
%   SubsetCaro:  binary mask of regions including carodtid arteries
%   MaskCaro:    binary mask of seeds representing hot part of carotid arteries
%   tFrames:     cell array of mid-times for each frame of pet_files
%   varargin:
%     PSF:       PSF of the medical imaging system for the partial volume correction,
%                (default: 6)
%     Tcorr:     Time in seconds during wich the PET data are corrected 
%                for spillover correction (default: 120)
%     thresh:    Threshold for correlation, used in Shain's method
%                (default: 0.97)
%
%   Output:
%   Extracted carotid: specified_name.nii
%   Estimated IF: specified_name.txt
%
%   Variable:
%   D = data from the PET
%   Dsub = subset of the data from the PET
%   DsubN = centered and normed subset of the data from the PET
%   Mask1 = mask from the lower part of the brain
%   Mask2 = mask of the carotid (from coregistred MRI)
%   Caro = mask of the carotid from Schain's algorithm
%   Caro3D = 3D binary mask of the carotid from Schain's algorithm
%   Caro3Dsmooth = smoothed image of Caro3D
%   tFrame = time of the frame
%   IF = input function
%
% =========================================================================
%
% M.A. Bahri, 2021.
% Cyclotron Research Centre, University of Liege, Belgium
% =========================================================================

    args = inputParser;
    args.addParameter('PSF', 6);
    args.addParameter('Tcorr', 120);
    args.addParameter('treshold', 0.97);
    args.parse(varargin{:});

    
    PSF = args.Results.PSF;
    Tcorr = args.Results.Tcorr;
    thresh = args.Results.treshold;
    
    % Loading volumes
    V = crc_read_spm_vol(pet_files);
    in_pth = fileparts(V(1).fname);
    bids_name =  bids.File(V(1).fname);

    if size(V, 1) < 5
        error('IF extraction requires at least %d images', 5);
    end

    if numel(tFrames) ~= numel(V)
        error('Number of mid-times must be same as number of volumes');
    end

    % Loading masks
    % Old name Mask1
    if ischar(SubsetCaro)
      V_mask_subset = spm_vol(SubsetCaro);
      mask_subset = spm_read_vols(V_mask_subset);
    else
      mask_subset = SubsetCaro;
    end

    % Old name Mask2
    if ischar(MaskCaro)
      V_mask_seed = spm_vol(MaskCaro);
      mask_seed = spm_read_vols(V_mask_seed);
    else
      mask_seed = MaskCaro;
    end

    % generating output path and basename
    out_pth = fullfile(in_pth, '..', 'IDIF');
    if ~exist(out_pth, 'dir')
        mkdir(out_pth);
    end

    % Variable attribution and Data initialization
    for ind = 1:numel(V)
        dat = spm_read_vols(V(ind));
        D(ind, :) = dat(:);
    end

    % Pixel spacing of the medical imaging system for the partial volume 
    % correction
    pixelspacing = [abs(V(1).mat(1, 1)) V(1).mat(2,2) V(1).mat(3,3)];
    
% =========================================================================
    %% Begining of the Schain's algorithm
    fprintf('-> Applying partial volume correction...\n');
    % Extraction of the image subset out of the PET data
    % id_subset == idx1
    % id_seed == idx2
    id_subset = find(mask_subset);
    id_seed = find(mask_seed(id_subset));
    Dsub = D(:, id_subset);

    % Calculation of the correlation matrix
    [t, nbv]= size(Dsub);
    DsubC = Dsub - ones(t, 1) * mean(Dsub); % recentering the value 
    DsubN = zeros(t, nbv); %initialisation of the normalized matrix
    for i = 1:nbv
        DsubN(:, i) = DsubC(:, i) ./ norm(DsubC(:, i));
    end

    % Extraction of the correlation matrix only for the voxel of interrest
    M = DsubN(:, id_seed)' * DsubN;
    % All autocorrelation coefficients are set to zero
    for i = 1:length(id_seed)
        M(i, id_seed(i)) = 0;
    end

    % Extraction of voxels part of the carotid
    [~, B] = find(M > thresh);
    C = union(B, B);
    fprintf('Voxels limit: %f\n', 1.1 * length(id_seed));
    while size(C, 1) < 1.1 * length(id_seed)
        thresh = thresh - 0.025;
        [~, B] = find(M > thresh);
        C = union(B, B); 
        fprintf('treshold = %f; size(C) = %d\n', thresh, size(C, 1));
        if thresh < 0
          warning(['Reached 0 treshold, ',...
                   'number of carotide voxels may be too small']);
          break;
        end
    end

    Caro = zeros(size(D, 2), 1);
    Caro(id_subset(C)) = 1;
    
% =========================================================================
    %% Partial Volume correction

    % Transfromation of the extracted carotid from vector to 3D matrix
    Caro3D = zeros(V(1).dim);
    Caro3D(:)=Caro(:);

    % Uncomment to see the extracted carotid with an other viewer than SPM
    % figure;
    % imshow3D(Caro3D) 

    % Writing tbe .nii file to verify if the extracted carotid is correct
    bids_name.entities.desc = 'IDIF';
    bids_name.suffix = 'mask';
    write_image(V(1), Caro3D, fullfile(out_pth, bids_name.filename()));

    % Computation of the GTM with one compartiment for the Tcorr first 
    % minutes
    % Smoothing of the carotid mask
    sig = fwhm2sigma(PSF); %sigma 
    sigma = [sig; sig; sig];
    % Correction of the splillover effect and computation of IF
    % idx3 = find(Caro3D);
    Caro3Dsmooth = gauss3filter(Caro3D, sigma, pixelspacing);
    idx3 = find(Caro3D);
    %Caro3Dsmooth = Caro3Dsmooth(idx3);
    tcorr = find(tFrames(:) > Tcorr, 1); 
   
    IF = zeros(numel(tFrames), 1);
    for i = 1:numel(tFrames)
        if i < tcorr
            tempIF = D(i, :) ./ Caro3Dsmooth(:)';
            IF(i) = mean(tempIF(idx3));
        else
            IF(i) = mean(D(i, idx3));
        end
    end
    
    bids_name.entities.desc = '';
    bids_name.suffix = 'IDIF';
    bids_name.extension = '.tsv';
    IDIF.fname = fullfile(out_pth, bids_name.filename());
    IDIF.mid_time = tFrames(:);
    IDIF.input_function = IF;
end
