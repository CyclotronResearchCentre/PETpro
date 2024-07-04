function res = crc_update_config(vals, defaults)
  % Updates missing values from config structure with
  % values from default structure
  res = vals;
  fields = fieldnames(defaults);
  for i = 1:numel(fields)
    def_str = '';
    if ~isfield(res, fields{i})
      res.(fields{i}) = defaults.(fields{i});
      def_str = ' (default)';
    end
    if isnumeric(res.(fields{i}))
      fmt = ['\t%s%s: ' repmat(' %g', 1, numel(res.(fields{i}))), '\n'];
    else
      fmt = '\t%s%s: %s\n';
    end
    fprintf(fmt, fields{i}, def_str, res.(fields{i}));
  end
end
