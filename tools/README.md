A small collection of scripts that streamline work with bids-matlab datasets,
and designed to work with parsed json configuration files

## BIDS related functions

### `data = crc_bids_query_data(BIDS, images, sub, id)`

Retrieves paths to files from `BIDS` dataset and satisfying
query stored in `images.query` structure (see bids-matlab doc)
for subjects cited in `sub`. 

If structure `images` have `number` field, it checks if 
number of retrieved paths is the same as `images.number`.
If it's not the case, an error will be raised.

Function returns the cellarray of found paths, and print out
number of retrieved paths prepended by `id`.


### `data = crc_bids_retrieve_data(BIDS, selection, subjects)`

Same as `crc_bids_query_data` but retrieves paths from substructures
of `selection`, if these substructures have `query` field.

Retrieved paths are stored into `data` structure, with each field
corresponds to a field name in `selection`.


###  `DERIV = crc_bids_gen_dervative(BIDS, outDir, name, selection, subjects)`

Generate a derivative dataset based on `BIDS` in `outDir/name`, and based
on queries stored in `selection` (see `crc_bids_retrieve_data`).

If Input dataset and output dataset have same path, do nothing and return a copy
of input dataset


### `crc_bids_merge_suffix(folder_path, varargin)`

Scan `folder_path` for bids-formatted files, and check for
multiple suffixes. 
If such files are found, suffixes are merged.

Optional parameter `overwrite` set to true (default is false),
will overwrite files if they already present.


### `der_json = crc_bids_create_json(base_json, img_file, varargin)`

Creates json structure based on `base_json` with fields modified
by variables contained in `varargin`.

Variables in `varargin` must be passed as optional parameters:
```matlab
crc_bids_create_json(base_json, img_file, `field1`, value1, ...
                     `field2`, value2, ...);
```

The name of parameter is interpreted as name of field to add to
json structure.
If field name ends with `-add`, then corresponding value is added
to existing field in json structure 
(works only with cellarrays and chararrays).

### `[filename, pth] = crc_create_filename(p, file)`

Saved function for managing names of bidsified files.
Outdated, better use bids.File class from bids.matlab


### `codeDir = crc_bids_make_code_dir(ds_path, procStep, conf_files)`

Function creating code directory in bidsified dataset:
`<ds_path>/code/<procStep>`, and files in `conf_files` into it.
Usefull to automise saving configuration files for pipeline

### `trunc_path = crc_bids_trunc_path(paths)`

Make given absolute path relative to bids dataset root, by
searching `sub-XXX` folder in the path.
If input is cellarray, truncates paths for all elements of array.


## General functions

### `crc_generate_log(log_path, name)`

Create a log file wich will contain all output from Matlab terminal.
Log file will be written untill command `diary off` is issued.

### `crc_compare_batch(ref_batch, test_batch)`

Compares two matlab batches structures and prints discrepency
If one of the entry is path to file, will compare the basename
and original (before bidsification) names, if sidecar json
contains field `OriginalFile`

### `res = crc_compare_images(ref_img, test_img, diff_path)`

Compare two nifti images and print out discrepancies
Compares dimentions, orientations, scaling and images
themselves, voxel-by-voxel.

If `diff_path` is defined, the difference image will
be saved in given directory

### `V = crc_read_spm_vol(files)`

Function facilitating the reading of multivolumes
nii files.
 
Input parameter `files` are either a single path to
nii, a cellarray of paths to nii, or `spm_vol` structure.

In all cases function returns a structarray of `spm_vol`,
with each separate element of structure represent a separte
volume.
