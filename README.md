# Preprocessing of T1/T2 data for EEG Source Imaging 

This repository provdies a bash script for batch preprocessing of

I.  T1/T2 MRI data using a mix of commands from  [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki), [Freesurfer](https://surfer.nmr.mgh.harvard.edu) and [AFNI](https://afni.nimh.nih.gov)   [10  essential steps]

II.  Building headmodels (aka. forward matrix; lead-field matrix) for the EEG source imaging via either using  
- [MNE tools](https://github.com/mne-tools) or 
- [Brainstorm](https://neuroimage.usc.edu/brainstorm/)

III.  Finding inverse matrix using either
- [MNE](https://github.com/mne-tools) and [MATLAB](www.mathworks.com)  or
- [Brainstorm](https://neuroimage.usc.edu/brainstorm/)

This repository discusses MNE tools-based head models and MNE, MATLAB tools for inverse matrix computations. For Brainstorm-based head models and inverse, please see the repository https://github.com/OliverMount/SourceImaging_Brainstorm.

In the IBS heterobrainx workstation, all the necessary software is installed, and preprocessing would begin smoothly and would take nearly 6 hours for each participant for both the steps.

## Check list

Create a directory where you would like to have all your raw anatomical scans and set the directory paths as the anatomy_path.

Inside the anatomy_path, create a directory for each participant with a name starting with "ibs" followed by four numbers. For example, if you have 25 participants, then the anatomy_path must have the following directories:
 

```
├── ibs0001
├── ibs0002
├── ibs0003 
      .
      .
	  .

├── ibs0024
└── ibs0025
```

3. Inside each ibsxxx directory, place a directory that contains raw data. For example, MRI scans from SKKU contained in a single directory that starts with the name HEAD. The HEAD directory contains raw data directories (T1/T2/DTI files). Place the HEAD directory inside the ibsXXXX directories, as shown for ibs0001 and ibs0002 below.

```
.
├── ibs0001
│   ├── HEAD_PI_CNIR_IBS_20220805_100824_145000 
├── ibs0002
│   ├── HEAD_PI_CNIR_IBS_20220805_103628_411000

```
The HEAD of ibs0001 contains the following raw data directories that would be used for preprocessing.
```
HEAD_PI_CNIR_IBS_20220805_100824_145000
├── 64CH_LOCALIZER_0001
├── DTI_SMS_64DIR_2_0ISO_0002
├── DTI_SMS_64DIR_2_0ISO_ADC_0003
├── DTI_SMS_64DIR_2_0ISO_COLFA_0006
├── DTI_SMS_64DIR_2_0ISO_FA_0005
├── DTI_SMS_64DIR_2_0ISO_TENSOR_0007
├── DTI_SMS_64DIR_2_0ISO_TRACEW_0004
├── PA_INVERT_DTI_SMS_64DIR_2_0ISO_0008
├── T1_MPRAGE_SAG_1_0ISO_0009
└── T2_SPACE_SAG_1_0MM_0010
```

3. After completing steps 1 and 2, this code initiates the preprocessing process for each participant within your anatomy folder, processing them individually. The script also includes functionality to check for previously processed participants based on the availability of processed files. Consequently, the script can be executed sequentially, allowing you to process a few users at a time. This feature enhances the flexibility of the current script.

4. Upon completion of preprocessing for a participant, the folder structure is organized as follows: the HEAD folder is relocated to the RawDicom directory, and the processed files are stored in the nifti and Standard directories, as illustrated below.

```
├── ibs0001
│   ├── nifti
│   ├── RawDicom
│   └── Standard
│       └── meshes
├── ibs0002
│   ├── nifti
│   ├── RawDicom
│   └── Standard
│       └── meshes

```
5. If you have utilized our DTIpreprocess.sh script, you will find an additional preprocessed directory for DTI within each subject, as demonstrated below.
```
├── ibs0001
│   ├── DTI
│   ├── nifti
│   ├── RawDicom
│   └── Standard
│       └── meshes
├── ibs0002
│   ├── DTI
│   ├── nifti
│   ├── RawDicom
│   └── Standard
│       └── meshes

```
## Preprocessing Steps

### I.  Processing of T1/T2 data

0. **Conversion and Data Reorientation** 
Convert the raw DICOM T1/T2 data to NIfTI format and relocate them to the NIfTI directory. All preprocessing operations proceed with the files in the NIfTI folder, preserving the integrity of the raw files in the RawDicom directory. The volumes are reoriented to the LAS (radiologist-preferred) axes. 
1. **Brain tissue extraction (BET for T1):**
 This procedure removes non-brain regions to prepare the data for analysis. 
2. **The recon-all (Segmentation, surface files and atlas projection for left and right hemisphere seperately):**
 Utilize recon-all from FreeSurfer to perform segmentation, surface file generation, and atlas projection for both the left and right hemispheres separately. Note that this step may require considerable processing time, approximately 5 hours on the heterobrainX workstation, with variations depending on computer specifications. It's important to mention that recon-all results will not be stored in the NIfTI folder; instead, they will reside in the SUBJECTS_DIR of FreeSurfer. We maintain the recon results separately to track files processed by FSL and FreeSurfer.
3. **Transfer Recon Output Files to NIfTI Directory**
 Since Step 2 does not save results in NIfTI format, preprocessed T1 files are moved to the NIfTI folder with the _fs suffix to indicate files processed by FreeSurfer.
4. **BET for T2:**
5. **Segmentation for T2 :**
 T2 segmentation (CSF/WM/GM) is perfomed via fsl (fast).
6. **Bias Correction for T2:**
7. **Registration (affine) of T2 onto T1:**
8. **Outer skull mesh generation for T2:**
 The mesh file is required for the Boundary Element Model (BEM) in Step 10.
9. **Normalization of MNI:**
 Align the T1 to the MNI152 (1mm) template.
10. **Creating skull/inskull/outskull in order to make head model (BEM)**
 These surface files are used for creating the head model (forward matrix).

### II.  MNE  head model construction (Subsequent Steps)

11. **Setting up source space (creating the dipole sources locations on the midgray surface):**
- This step specifies how many dipole sources needed. It results in the location of the sources in the midgray surface. 
12. **Setting up head-model parameters**
- Create a model using BEM surfaces and dipole information, specifying scalp, skull, and brain conductivities (0.33, 0.025, and 0.33, respectively).
13. **Making high-resolution scalp surface:**
- This step creates high resolution scalp (with no holes; if there is a hole we need to fill it up; fortunately for the freesurfer version 7.3.2 we use now (2023), we have not encountered this problem).
14. **Final head-model**
-The final head model is available as a .fif file, which can be imported into MATLAB for inverse processing. For example, the head model for ibs0001 is found in the bem folder of the SUBJECTS_DIR with the name ibs0001_fs-head.fif.

### III.  MNE and MATLAB-based inverse matrix   

15. **Marking the MRI fiducials (manually)**
- Create a VAnatomy.dat file within the NIfTI folder. Using the MATLAB script vAnatomyFiducials.m (Sperotoolbox), mark the left, right preauricular, and nasion points, and save them as a text file (e.g., ibs0001_fiducials.txt) inside the bem folder.
16. **Inverse matrix**
Before determining the inverse matrix, ensure the following:
-  Move the EEG epoched files to a directory named 4D. The directory structure of 4D should resemble the following:
```
4D2/
├── ibs0001
│   ├── Ax001.mat
│   └── Ax002.mat
└── ibs0002
    ├── Ax001.mat
    └── Ax002.mat
```
Each mat file represents a unique experimental condition.
b. Create the noise covariance matrix using the mrCurrent toolbox. The resulting directory structure will resemble the following:
```
4D2/
├── ibs0001
│   ├── Ax001.mat
│   ├── Ax002.mat
│   └── noise_covar.mat
└── ibs0002
    ├── Ax001.mat
    ├── Ax002.mat
    └── noise_covar.mat
```
c. Check the alignment of fiducials and digitized points on the high-resolution scalp. Utilize the **prepareProjectForMne.m** script from the  [alesToolbox](https://github.com/svndl/svndl_code/tree/b1b90b64451832996cc0108421fb0c4be5fe1328/alesToolbox) for MATLAB. Provide the FreeSurfer directory and the path to the 4D2 data as inputs. This script will display the fiducials (EEG and MRI) and digitized points on the scalp. If necessary, edit the elp file to align the points accurately with the scalp.

d.Compute the inverse solution by executing the **prepareInversesForMrc.m** script from the alesToolbox. Provide the FreeSurfer path as input. The resulting inverse will be saved in the FreeSurfer BEM directory, for example, as ibs0001-inv.fif.

18. **Default Cortex and associated ROIs**
- To obtain the defaultCortex.mat, run the **FS4toDefaultCortex.m** script with the argument (subject_folder, true). Save this file in the anatomy folder. The subject_folder represents the FreeSurfer subject folder.

- Execute the **FS4parc2cortex.m** script with the argument (subject_folder). Choose the FreeSurfer participant folder and select the defaultCortex.mat file. From the menu, select the "../Standard/meshes/ROIs/" directory. This action will save the 84 ROI source waveforms in this directory.
