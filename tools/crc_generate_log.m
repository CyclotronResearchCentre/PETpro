function crc_generate_log(log_path, name)
  % An utility for copying terminal output to log file
  % Log file will be filled untill 'diary off;' is called.
  % 
  % Parameters:
  %   log_path: path to emplacements to log files
  %   name:     basename of log file to create, supposed to refelect
  %             the name of programm/script   
  %
  % Example:
  %   generate_log(log_path, 'mpm_Dartell');
  %   pre_dataset = mpm_Dartell(map_dataset, destination, ...
  %                             'subjects', args.Results.subjects, ...
  %                             'name', args.Results.name ...
  %                             );
  %

  log_name = fullfile(log_path, [name '.log']);
  if exist(log_name, 'file')
    delete(log_name)
  end
  diary(log_name);

  len = 30;
  char = '#';
  format_str = sprintf('%c %%-%ds%c\n', char, len - 3, char);
  fprintf('%s\n', repmat(char, 1, len));
  fprintf(format_str, name);
  fprintf(format_str, datestr(now(), 'dd/mm/YYYY - HH:MM:SS'));
  fprintf('%s\n', repmat(char, 1, len));
end
