function corr_mask = caro_correlate(data, core_mask, exp_mask, params)
    def_params.threshold = 0.97;
    def_params.expansion = 1.1;

    fprintf('-> Selecting carotides by correlation\n');
    params = crc_update_config(params, def_params);

    % Reorienting data
    dim = size(data);
    n_vols = dim(4);
    dim = dim(1:3);
    D = permute(data, [4, 1, 2, 3]);

    id_expanded = find(exp_mask);
    id_core = find(core_mask(id_expanded));
    Dexp = D(:, id_expanded);

    % Calculation of the correlation matrix
    [t, nbv]= size(Dexp);
    DexpC = Dexp - ones(t, 1) * mean(Dexp); % recentering the value 
    DexpN = zeros(t, nbv);
    for i = 1:nbv
        DexpN(:, i) = DexpC(:, i) ./ norm(DexpC(:, i));
    end

    % Extraction of the correlation matrix only for the voxel of interrest
    M = DexpN(:, id_core)' * DexpN;
    % All autocorrelation coefficients are set to zero
    for i = 1:length(id_core)
        M(i, id_core(i)) = 0;
    end

    % Extraction of voxels part of the carotid
    thresh = 1;
    [~, B] = find(M > thresh);
    C = union(B, B);
    fprintf('---> Expansion limit: %.0f\n', params.expansion * length(id_core));
    while true
        [~, B] = find(M > thresh);
        C = union(B, B); 
        fprintf('---> treshold = %f; size(C) = %d\n', thresh, size(C, 1));

        thresh = thresh - 0.025;
        if thresh < params.threshold
          fprintf('--> Reached correlation threshold\n');
          break;
        end
        if size(C, 1) >=  params.expansion * length(id_core)
          fprintf('--> Reached expansion threshold\n');
          break;
        end
    end

    corr_mask = zeros(dim, 'uint8');
    corr_mask(id_expanded(C)) = 1;
end
