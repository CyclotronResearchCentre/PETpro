# PETpro: Automated Quantitative PET Processing Pipeline

Quantitative brain positron emission tomography (PET) relies on an accurate arterial input function to enable kinetic modelling and the estimation of quantitative parametric maps. Although arterial blood sampling remains the reference method for measuring the arterial input function (AIF), it is invasive, technically demanding, and operator-dependent.

This repository provides an automated processing pipeline for dynamic brain PET data, with a particular focus on the estimation of image-derived input functions (IDIFs) from the carotid arteries. The pipeline integrates automated carotid detection, input-function estimation and correction, partial volume correction, kinetic modelling, and spatial processing within a reproducible BIDS-compatible workflow.

The pipeline was developed and evaluated using dynamic [<sup>18</sup>F]UCB-H PET data. It supports the generation of IDIFs with corrections for partial volume effects and radiolabeled metabolites, as well as the processing of arterial blood data when available. Voxel-wise parametric maps can subsequently be estimated using kinetic modelling methods such as the Logan graphical approach.

By reducing the need for manual or semi-automated carotid delineation, this workflow aims to minimize operator dependence and facilitate reproducible quantitative PET analysis.

> **Note:** Although the pipeline was developed using [<sup>18</sup>F]UCB-H PET data, several components may be applicable to other dynamic PET datasets. Acquisition-specific and tracer-specific parameters, particularly those related to metabolite correction, partial volume correction, and kinetic modelling, should be carefully reviewed before applying the pipeline to a different tracer or dataset.

---

## User Notes

### MATLAB dependencies

Before running the pipeline, ensure that all required MATLAB toolboxes and external repositories are available on the MATLAB path.

The following dependencies are required:

* [SPM12](https://www.fil.ion.ucl.ac.uk/spm/software/spm12/)
* [bids-matlab](https://github.com/bids-standard/bids-matlab.git)
* [magia toolbox](https://github.com/tkkarjal/magia)
* `PETpro` tools

Paths are system-dependent and must be adapted to the local installation. For example:

```matlab
addpath('<path_to_spm12>');
addpath('<path_to_bids_matlab>');
addpath('<path_to_petpro>/tools');
addpath('<path_to_magia>');
```


### Dataset paths

The main processing function requires four dataset paths:

```matlab
source = '<dataset_root>';
destination = fullfile(source, 'derivatives');
seg_ds = fullfile(source, 'derivatives', 'Segmented');
anat_ds = '';
```

where:

* `source` is the root directory of the input BIDS dataset;
* `destination` is the derivatives directory where the pipeline outputs will be written;
* `seg_ds` is the directory containing the anatomical segmentation and DARTEL outputs;
* `anat_ds` can be left empty when anatomical images are queried directly from the source dataset.

A typical setup is:

```matlab
source = '<dataset_root>';
destination = fullfile(source, 'derivatives');
seg_ds = fullfile(destination, 'Segmented');
anat_ds = '';
```

The processing configuration is provided as a JSON file:

```matlab
config_path = '<path_to_configuration>/pet_PETspace.json';
```

The pipeline can then be launched using:

```matlab
outDataset = pet_Process_PETspace( ...
    source, destination, seg_ds, anat_ds, ...
    'subjects', '.*', ...
    'name', 'pet_Process', ...
    'config', config_path);

disp(['Output directory: ', outDataset]);
```

The regular expression provided through `subjects` determines which subjects are processed. The default expression `'.*'` processes all available subjects.


### Configuration file

The processing pipeline is controlled by a JSON configuration file. The configuration contains the parameters and BIDS queries used by each processing step.

The main configuration sections are:

| Section                | Description                                                               |
| ---------------------- | ------------------------------------------------------------------------- |
| `Carotides`            | Extraction and segmentation of the carotid arteries from dynamic PET data |
| `IDIF`                 | Generation and correction of the image-derived input function             |
| `AIF`                  | Generation of arterial input functions from blood measurements            |
| `brainmask`            | Creation of a brain mask in anatomical space                              |
| `brainmask_coreg`      | Creation of a brain mask after registration to PET space                  |
| `registration_pet`     | Registration of anatomical and segmentation images to PET space           |
| `PVC`                  | Partial volume correction                                                 |
| `modelling`            | Kinetic modelling using PVC-corrected PET data                            |
| `modelling_noPVC`      | Kinetic modelling without partial volume correction                       |
| `modelling_aif_blood`  | Kinetic modelling using a blood-derived input function                    |
| `modelling_aif_plasma` | Kinetic modelling using a plasma-derived input function                   |
| `registration_mri`     | Registration of PET-derived parametric images to MRI space                |
| `normalisation`        | Normalisation of MRI-space images to template/MNI space                   |

Only the configuration sections corresponding to the processing steps that are executed need to be correctly configured.


### Processing workflow

The `pet_Process_PETspace` function executes the following processing steps:

1. **Carotid extraction**
2. **IDIF extraction**
3. **Brain mask generation in anatomical space**
4. **Registration of tissue probability maps to PET space**
5. **Brain mask generation in PET space**
6. **Partial volume correction (PVC)**
7. **Kinetic modelling**
8. **Registration of parametric PET images to MRI space**
9. **Normalisation to template/MNI space**


### Optional processing steps

The main workflow includes carotid extraction, IDIF generation, brain masking, PET-space registration, PVC, kinetic modelling, MRI registration, and spatial normalisation.

Additional steps are available but disabled by default in `pet_Process_PETspace`:

* AIF extraction from blood measurements;
* kinetic modelling without PVC;
* kinetic modelling using blood-derived AIF;
* kinetic modelling using plasma-derived AIF.

These steps can be enabled by uncommenting the corresponding function calls in `pet_Process_PETspace`.


### PET point spread function

The PET point spread function (PSF) is specified in the `IDIF`, `AIF`, and `PVC` sections using the full width at half maximum (FWHM):

```json
"FWHM": [6.48, 6.58, 4.67]
```

or:

```json
"PSF": {
  "FWHM": [6.48, 6.58, 4.67]
}
```

These values are*scanner- and reconstruction-dependent and should be adapted to the characteristics of the PET acquisition.


### Partial Volume Correction (PVC)

Partial volume correction requires the [petpvc](https://github.com/UCL/PETPVC) executable.

The path is specified in the `PVC` section:

```json
"petpvc_exe_path": "<path_to_petpvc>/petpvc.exe"
```

For cross-platform compatibility, forward slashes are recommended in JSON paths:

```json
"petpvc_exe_path": "C:/path/to/PETPVC/petpvc.exe"
```

Alternatively, if the executable is expected to be located in the current MATLAB working directory, the pipeline can use a default path:

```matlab
if ~isfield(params, 'petpvc_exe_path') || isempty(params.petpvc_exe_path)
    petpvc_exe = fullfile(pwd, 'petpvc.exe');
else
    petpvc_exe = params.petpvc_exe_path;
end
```

Make sure that the PETPVC executable exists and can be executed from the local system before running the pipeline.


### IDIF and AIF metabolite correction

The configuration supports metabolite correction using a sigmoidal model.

For example, the IDIF configuration contains:

```json
"metabolite": {
  "model": "Sigmoidal",
  "offset": "injection",
  "params": {
    "d": 1,
    "a": 0.9370613291611155,
    "b": 692.1076091977601,
    "e": 2.563555105083992e-06
  }
}
```

The AIF configuration may use a different parameterisation:

```json
"metabolite": {
  "reference": "inj",
  "method": "Sigmoidal",
  "parameters": {
    "d": 1,
    "A0": 1,
    "a": 0.9588011031468416,
    "b": 396.9240848165973,
    "e": 0
  }
}
```

> **Important:** The metabolite model and its parameters are tracer-specific. The values provided in the example configuration should therefore not be considered universal and must be adapted or validated for the tracer and dataset being analysed.


### Logan kinetic modelling

The modelling sections define the input PET image, brain mask, input function, and modelling time window.

For example:

```json
"start_time": 1500,
"end_time": 0
```

The `start_time` is expressed in seconds. An `end_time` of `0` indicates that the complete remaining acquisition should be used.

The pipeline also supports quality-control output through:

```json
"qc_save": true
```

Quality-control analyses can be performed using the GM, WM, and CSF tissue probability maps.

The minimum number of voxels used for QC is controlled by:

```json
"qc_nvox": 10
```


### Image registration

#### Registration to PET space

Anatomical and tissue segmentation images are registered to PET space using the PET image as the reference.

The PET reference image may be generated from a subset of dynamic PET frames:

```json
"sum_img": [9, 22]
```

The interpolation method is defined through:

```json
"batch_overwrite": {
  "roptions": {
    "interp": 2
  }
}
```

The selected interpolation method should be appropriate for the image type being transformed. In particular, tissue probability maps should be treated differently from continuous anatomical images when necessary.


#### Registration to MRI space

PET-derived parametric images are subsequently registered to anatomical MRI space.

The configuration specifies:

```json
"space": "mri",
"resolution": "hi"
```

The anatomical T1-weighted image is used as the reference image.


### Spatial normalisation

The final normalisation step uses the subject-specific DARTEL flow field and a DARTEL template.

The configuration specifies:

```json
"template": "Template_6.nii",
"prefix": "sw"
```

The expected flow field is queried using:

```json
"prefix": "u_rc1",
"extension": ".nii"
```

The normalisation step expects the DARTEL templates and subject-specific flow fields to be available in the segmentation derivatives directory.


### Output and logs

Outputs are written to:

```text
<dataset_root>/derivatives/<pipeline_name>/
```

With the default pipeline name:

```matlab
'name', 'pet_Process'
```

the output directory is:

```text
<dataset_root>/derivatives/pet_Process/
```

Processing logs are stored in:

```text
<dataset_root>/derivatives/pet_Process/code/
```

A separate log file is generated for each processing step. These logs should be checked first when a processing step or subject fails.


### Running the pipeline

A minimal MATLAB script can be written as follows:

```matlab
close all;
clear;
clc;

%% Add required dependencies
addpath('<path_to_spm12>');
addpath('<path_to_bids_matlab>');
addpath('<path_to_petpro>/tools');
addpath('<path_to_magia>');

%% Define paths
config_path = '<path_to_configuration>/pet_PETspace.json';

source = '<dataset_root>';
destination = fullfile(source, 'derivatives');
seg_ds = fullfile(destination, 'Segmented');
anat_ds = '';

%% Run processing pipeline
outDataset = pet_Process_PETspace( ...
    source, destination, seg_ds, anat_ds, ...
    'subjects', '.*', ...
    'name', 'pet_Process', ...
    'config', config_path);

disp(['Output directory: ', outDataset]);
```

---

## Input Data Structure

The pipeline expects the input dataset to follow a BIDS-like directory structure. The dataset root directory is referred to below as `<dataset_root>`.


### Expected Dataset Overview

The expected directory structure is summarized below:

```text
<dataset_root>/
│
├── sub-<subject_id>/
│   ├── anat/
│   │   └── sub-<subject_id>_acq-mprage_T1w.nii
│   │
│   └── pet/
│       ├── sub-<subject_id>_pet.nii
│       └── sub-<subject_id>_blood.tsv              # Optional, required for AIF
│
└── derivatives/
    └── Segmented/
        └── sub-<subject_id>/
            ├── anat/
            │   └── sub-<subject_id>_acq-mprage_mask-Brain_T1w.nii
            │
            ├── Dartell/
            │   └── u_rc1sub-<subject_id>_acq-mprage_space-individual_label-Template_flow.nii
            │
            └── Segmented/
                ├── c1sub-<subject_id>_acq-mprage_space-orig_label-GM_probseg.nii
                ├── c1sub-<subject_id>_acq-mprage_space-pet_label-WM_res-lo_probseg.nii
                ├── c2sub-<subject_id>_acq-mprage_space-orig_label-WM_probseg.nii
                ├── c2sub-<subject_id>_acq-mprage_space-pet_label-WM_res-lo_probseg.nii
                ├── c3sub-<subject_id>_acq-mprage_space-orig_label-CSF_probseg.nii
                └── c3sub-<subject_id>_acq-mprage_space-pet_label-WM_res-lo_probseg.nii
```

where:

* `c1` corresponds to **grey matter (GM)**;
* `c2` corresponds to **white matter (WM)**;
* `c3` corresponds to **cerebrospinal fluid (CSF)**;
* `space-pet_*_res-lo` corresponds to resampling images to PET space at low resolution;
* `label-Template_flow` corresponds to the DARTEL flow field.


### Optional: Arterial Input Function (AIF) Data

If arterial input function (AIF)-based kinetic modelling is performed, arterial blood data must be provided for each subject.

The blood data file must be located in the subject's PET directory:

```text
<dataset_root>/
└── sub-<subject_id>/
    └── pet/
        └── sub-<subject_id>_blood.tsv
```

For example:

```text
sub-KTA001/pet/sub-KTA001_blood.tsv
```

The file must be a tab-separated values (`.tsv`) file containing the following columns:

```text
onset    whole_blood_radioactivity    plasma_radioactivity
```

* `onset`: blood sampling time, in seconds;
* `whole_blood_radioactivity`: measured radioactivity concentration in whole blood;
* `plasma_radioactivity`: measured radioactivity concentration in plasma.

An example file is shown below:

```text
onset	whole_blood_radioactivity	plasma_radioactivity
10	12	0
25	0	0
30	5987	6723
40	52351	58504
50	66326	78455
60	43577	49514
70	26782	30877
80	18295	21772
90	14630	17358
100	12291	14256
110	10275	12060
120	9507	10973
180	3167	3779
300	4560	4279
900	3826	4116
1500	3468	3984
2130	n/a	n/a
2700	3376	3961
3613	2626	3787
5400	3088	3157
5820	n/a	n/a
```

Missing measurements should be indicated as `n/a`.

> **Important:** The provided configuration should be considered an example for a specific PET acquisition and processing workflow. Parameters related to carotid extraction, IDIF/AIF correction, PET resolution, PSF, PVC, metabolite correction, and kinetic modelling must be reviewed and adapted before applying the pipeline to a different scanner, tracer, acquisition protocol, or reconstruction method.


