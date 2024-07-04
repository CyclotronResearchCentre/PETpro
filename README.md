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
