function  [seed_mask, caro_mask, exp_mask] = caro_search(seed_candidates, caro_candidates,...
                                                          p_seed, p_expansion)
  % Performs carotides search based on seeds candidates,
  % and expanded carotides candidates  
  def_seed.min_value = 1000;
  def_seed.candidate = 0.9;

  def_expansion.hot_carotides = 0.8;
  def_expansion.cold_carotides = 0.5;
  def_expansion.min_size = 20;
  def_expansion.max_size = 30;

  fprintf('--> Analyzing seeds...\n');
  p_seed = crc_update_config(p_seed, def_seed);
  def_expansion = crc_update_config(p_expansion, def_expansion);

  caro_mask = zeros(size(seed_candidates), 'uint8');
  exp_mask = zeros(size(seed_candidates), 'uint8');
  seed_mask = zeros(size(seed_candidates), 'uint8');

  [val_cand, index_cand] = max(seed_candidates(:));
  val_first = val_cand;

  while (seed_candidates(index_cand) > 0)
    if caro_candidates(index_cand) < p_seed.min_value
      seed_candidates(index_cand) = 0;
      [val_cand, index_cand] = max(seed_candidates(:));
      continue;
    end

    [cand_x, cand_y, cand_z] = ind2sub(size(seed_candidates), index_cand);

    % fprintf('---> Candidate %f at (%d, %d, %d): ',...
    %         val_cand, cand_x, cand_y, cand_z);
    [caro, caro_exp] = expand_carotide(caro_candidates, index_cand,...
                                       p_expansion.hot_carotides,...
                                       p_expansion.cold_carotides,...
                                       p_expansion.max_size);

    % Masking tested seed
    seed_candidates(index_cand) = 0;
    % Masking expanded hot carotide
    seed_candidates(caro_exp > 0) = 0;
    % Masking expanded carotide
    caro_candidates(caro_exp > 0) = 0;
    if nnz(caro_exp) < p_expansion.min_size
      % fprintf('---> Rejected due to size\n');
    else
      caro_mask = caro_mask | caro;
      exp_mask = exp_mask | caro_exp;
      seed_mask(index_cand) = 1;
    end
    [val_cand, index_cand] = max(seed_candidates(:));

  end
  
  n_caro = nnz(seed_mask);
  if n_caro == 0
    error('No valid carotides candidates found')
  end
  fprintf('Found %d carotides candidates of %d (core)/ %d (expanded)\n', ...
          n_caro, nnz(caro_mask), nnz(exp_mask));

end

function [caro, caro_exp] = expand_carotide(img, seed,...
                                            cutoff_core, cutoff_exp,...
                                            max_size)
  caro = zeros(size(img), 'uint8');
  cutoff_mask = (img > (img(seed) * cutoff_core));
  caro(seed) = 1;
  SE = strel('sphere', 1);
  caro_size = nnz(caro);
  d_size = caro_size;
  while d_size > 0 && caro_size < max_size
    caro = imdilate(caro, SE) & cutoff_mask;
    d_size = nnz(caro) - caro_size;
    caro_size = caro_size + d_size;
  end

  cutoff_mask = (img > (img(seed) * cutoff_exp));
  caro_exp = caro;
  for i = 1:5
    caro_exp = imdilate(caro_exp, SE) & cutoff_mask;
  end

  % fprintf('Expanded to %d (core) / %d (expanded) voxels\n', caro_size, nnz(caro_exp));
end
