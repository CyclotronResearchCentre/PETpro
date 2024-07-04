function outDataset = pet_Process(source, destination, anat_ds, seg_ds, varargin)
%
% source = path to the PET scans
% destination = path to where you  want to save the results
% anat_ds = path to the anatomical data (MPM maps)
% seg_ds = path to the segmented mpm files. (hMRI results)
%
%
%
  basepath = fileparts(mfilename('fullpath'));
  args = inputParser();
  args.addParameter('subjects', '.*');
  args.addParameter('name', 'pet_Process');
  args.addParameter('config', fullfile(basepath, 'config', 'pet_MRIspace.json'));

  args.parse(varargin{:});

  if ischar(args.Results.config)
    params = spm_jsonread(args.Results.config);
  else
    params = args.Results.config;
  end

  % activating logging
  log_path = fullfile(destination, args.Results.name, 'code');
  if ~exist(log_path, 'dir')
    mkdir(log_path);
  end

  outDataset = fullfile(destination, args.Results.name);
  try
    % Extracting Carotides
    generate_log(log_path, 'pet_Carotides');
    pet_Carotides(source, destination, ...
                  'subjects', args.Results.subjects, ...
                  'name', args.Results.name, ...
                  'config', params ...
                  );

    % Extracting IDIF
    generate_log(log_path, 'pet_IDIF');
    pet_IDIF(outDataset, destination, ...
             'subjects', args.Results.subjects, ...
             'name', args.Results.name, ...
             'config', params ...
             );

    % Creating and applying brain mask
    generate_log(log_path, 'pet_makeBrainMask');
    pet_makeBrainMask(...
                      seg_ds, anat_ds, destination, ...
                      'subjects', args.Results.subjects, ...
                      'name', args.Results.name, ...
                      'config', params ...
                      );

    % Coregistering PET images to mri
    generate_log(log_path, 'pet_Coregister_MRI');
    pet_Coregister(outDataset, outDataset, '', destination, ...
                   'subjects', args.Results.subjects, ...
                   'name', args.Results.name, ...
                   'config', params ...
                   );                       

    % Partial volume correction                              
    generate_log(log_path, 'pet_PVC');
    pet_PVC(outDataset, outDataset, destination, ...
            'subjects', args.Results.subjects, ...
            'name', args.Results.name, ...
            'config', params ...
            );                       

    % Calculating Logan plot (with PVC)
    generate_log(log_path, 'pet_Modelling');
    pet_Modelling(outDataset, outDataset, outDataset, destination, ...
                  'subjects', args.Results.subjects, ...
                  'name', args.Results.name, ...
                  'config', params ...
                  );

    % Calculating Logan plot (without PVC)
    generate_log(log_path, 'pet_Modellingi_noPVC');
    pet_Modelling(outDataset, outDataset, outDataset, destination, ...
                  'subjects', args.Results.subjects, ...
                  'name', args.Results.name, ...
                  'config', params, ...
                  'configsection', 'modelling_noPVC'...
                  );

    % Normalizing to MNI space
    generate_log(log_path, 'pet_Normalisation');
    pet_Normalisation(...
                      outDataset, seg_ds, destination, ...
                      'subjects', args.Results.subjects, ...
                      'name', args.Results.name, ...
                      'config', params ...
                      );
  catch ME
    fprintf('Error:\n%s\n', ME.getReport);
    diary off;
    rethrow(ME);
  end
  diary off;

end

function generate_log(log_path, name)
  log_name = fullfile(log_path, [name '.log']);
  if exist(log_name, 'file')
    delete(log_name)
  end
  diary(log_name);

  len = 30;
  char = '#';
  format_str = sprintf('%c %%-%ds%c\n', char, len - 3, char);
  fprintf('%s\n', pad('', len, char));
  fprintf(format_str, name);
  fprintf(format_str, datestr(now(), 'dd/mm/YYYY - HH:MM:SS'));
  fprintf('%s\n', pad('', len, char));
end
