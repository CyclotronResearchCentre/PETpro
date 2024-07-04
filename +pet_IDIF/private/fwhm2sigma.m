function res = fwhm2sigma(FWHM)
  % passing from width at half maximum to sigma
  res = FWHM / (2 * sqrt(2 * log(2)));
end
