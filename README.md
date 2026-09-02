## Input Data Structure

The pipeline expects the input dataset to follow a BIDS-like directory structure. The dataset root directory is referred to below as `<dataset_root>`.

### 1. Anatomical MRI images

For each subject, the anatomical T1-weighted image must be located in:

```text
<dataset_root>/
└── sub-<subject_id>/
    └── anat/
        └── sub-<subject_id>_acq-mprage_T1w.nii
```

For example:

```text
sub-KTA001/anat/sub-KTA001_acq-mprage_T1w.nii
```

---

### 2. PET images

For each subject, the PET image must be located in:

```text
<dataset_root>/
└── sub-<subject_id>/
    └── pet/
        └── sub-<subject_id>_pet.nii
```

For example:

```text
sub-KTA001/pet/sub-KTA001_pet.nii
```

---

### 3. DARTEL templates

The DARTEL templates must be stored in the following derivatives directory:

```text
<dataset_root>/
└── derivatives/
    └── Segmented/
        └── DartellTemplates/
```

The directory should contain the DARTEL templates generated during the anatomical segmentation and normalization procedure.

---

### 4. T1-weighted brain masks

For each subject, the T1-weighted brain masks must be located in:

```text
<dataset_root>/
└── derivatives/
    └── Segmented/
        └── sub-<subject_id>/
            └── anat/
```

The following files are expected:

```text
sub-<subject_id>_acq-mprage_mask-Brain_T1w.nii
sub-<subject_id>_acq-mprage_mask-Brain_space-pet_res-lo_T1w.nii
```

The first mask is defined in the native anatomical space, while the second mask is resampled to PET space at low resolution.

---

### 5. Subject-specific DARTEL flow fields

For each subject, the DARTEL flow field must be located in:

```text
<dataset_root>/
└── derivatives/
    └── Segmented/
        └── sub-<subject_id>/
            └── Dartell/
```

The expected file follows the naming pattern:

```text
u_rc1sub-<subject_id>_acq-mprage_space-individual_label-Template_flow.nii
```

For example:

```text
u_rc1sub-KTA001_acq-mprage_space-individual_label-Template_flow.nii
```

---

### 6. Tissue segmentation maps

For each subject, the tissue probability maps must be located in:

```text
<dataset_root>/
└── derivatives/
    └── Segmented/
        └── sub-<subject_id>/
            └── Segmented/
```

The following segmentation maps are expected:

```text
c1sub-<subject_id>_acq-mprage_space-orig_label-GM_probseg.nii
c2sub-<subject_id>_acq-mprage_space-orig_label-WM_probseg.nii
c3sub-<subject_id>_acq-mprage_space-orig_label-CSF_probseg.nii
```

where:

* `c1` corresponds to **grey matter (GM)**;
* `c2` corresponds to **white matter (WM)**;
* `c3` corresponds to **cerebrospinal fluid (CSF)**.

---

## Optional: Arterial Input Function (AIF) Data

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

---

## Expected Dataset Overview

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
        ├── DartellTemplates/
        │   └── ...
        │
        └── sub-<subject_id>/
            ├── anat/
            │   ├── sub-<subject_id>_acq-mprage_mask-Brain_T1w.nii
            │   └── sub-<subject_id>_acq-mprage_mask-Brain_space-pet_res-lo_T1w.nii
            │
            ├── Dartell/
            │   └── u_rc1sub-<subject_id>_acq-mprage_space-individual_label-Template_flow.nii
            │
            └── Segmented/
                ├── c1sub-<subject_id>_acq-mprage_space-orig_label-GM_probseg.nii
                ├── c2sub-<subject_id>_acq-mprage_space-orig_label-WM_probseg.nii
                └── c3sub-<subject_id>_acq-mprage_space-orig_label-CSF_probseg.nii
```


## Parent function for metabolite

The correction of metabolite is performed by scaling imput function
by a parent function.
This parent function is choosen from aviable ones in `pet.json`
configuration file, in section file, together with it's parameters.

#### UCB-h
For mean over 4 participants the best fit produce following parameters:

##### Sigmodal:
```
A0:  1 (fixed)
e:   76.0390292 +/- 25.2213235 (33.17%) (init = 0)
a:   0.92514893 +/- 0.02308516 (2.50%) (init = 1)
b:   230.814420 +/- 38.6266001 (16.73%) (init = 683.7752)
```

To insert into `pet.json`:
```json
    "metabolite":{
      "method": "Sigmoidal",
      "parameters": {
        "A0": 1,
        "e": 76,
        "a": 0.925,
        "b": 231
      }
    }
```

#### DoubleExp
```
General model Exp2:
fitresult(x) = a*exp(b*x) + c*exp(d*x)
Coefficients (with 95% confidence bounds):
a =      0.9538  (0.3682, 1.539)
b =   -0.001434  (-0.00326, 0.0003923)
c =      0.1069  (-0.4965, 0.7104)
d =   3.562e-05  (-0.001228, 0.0013)
```

To insert into `pet.json`:
```json
    "metabolite":{
      "method": "DoubleExp",
      "parameters": {
        "a": 0.9538,
        "b": -0.001434,
        "c": 0.1069,
        "d": 3.562e-05
      }
    }
```
#### Parent fraction:
```
x = [0, 180, 300, 900, 2100, 3600, 5400];
y = [1, 0.92, 0.76, 0.29, 0.19, 0.14, 0.12];
```

## Partial volume correction

For PVC you will need an extrnal tool [petpvc](https://github.com/UCL/PETPVC)
installed and added to path.

#### The point spread function FWMH

The FWMH was estimated by gaussian fit of point source image
using tool [pet_fwhm](https://gitlab.uliege.be/CyclotronResearchCentre/LocalResources/pet_tools/pet_fwhm).
Results where averaged between centrally placed and `z = 10`cm:
```
"FWHM": [6.48, 6.58, 4.67]

```

## Modelling

For the Logan plot, you will need a [magia toolbox](https://github.com/tkkarjal/magia)
