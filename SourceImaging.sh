# Bash script for preprocessing of T1 and T2 anatomical images and headmodel construction using MNE
 
# Make sure the following path settings are correct in your system

anatomy_path="/Users/heterobrainx/anatomy"
SUBJECTS_DIR="/Applications/freesurfer/7.3.2/subjects"
fsl_MNI152_template_path="/Users/heterobrainx/fsl/data/linearMNI"   
MNE_path="/Volumes/Macintosh HD/Applications/MNE-2.7.4-3378-MacOSX-x86_64/bin" 
SperoToolbox="/Users/heterobrainx/MATLABtoolboxes/SperoToolbox/HeadModels"
eeg_helper_files="/Users/heterobrainx/MATLABtoolboxes/eeg_helper_files"   # Some helper files
 
 

#Begin processing from the raw data folder
cd $anatomy_path

#Get the participants folder names
echo "++ Beginning anatomical processing \n"
subs=`ls -d ibs*`
#subs="ibs0001"
echo "------------------------------------"
echo "++ The number of participants is"  `ls -d ibs* | wc -l`
echo "------------------------------------"


# Do preprocessing for each participant
for sub in $subs
do 
		 
	cd $sub               # get into the participant folder
	parti_dir=`pwd`       # store the participant directory temporaily
	
	########################################################
	# Step 0 : Create RawDicom directory to store the raw image files 
	#######################################################
	sub_folders=`ls -d *`
	if [ ! -d "RawDicom" ]; then
		echo  "++ Beginning T1 processing for " $sub
		echo  "++ Making RawDicom folder"
		mkdir RawDicom 
		cd RawDicom
		mv ../$sub_folders .
		cd ..
	else
		echo "++ RawDicom already exists for the participant $sub. If you need fresh processing, please read the README file."
	fi

	########################################################
	# Step 0 : Create nifti directory to store the nifti and other processing files 
	#######################################################
	if [ ! -d "nifti" ]; then
		echo  "++ Making  nifti folder"
		mkdir nifti 
		cd nifti
	else
		cd nifti
		echo  "++ Nifti already exists for the participant $sub. If you need fresh processing, please read the README file."
	fi
	
	nifti_dir=`pwd`

	########################################################
	# Step 0 : Converting T1 and T2 from dicom to nifti 
	#######################################################
	# Converting T1 dicom to nifti (fsl) 
	if [ ! -f ${sub}_T1.nii.gz ]; then
		echo  "++ T1 nifti does not exist. Beginning DICOM to nifti conversion."
		dcm2niix -f ${sub}_T1 -p y -z y -o . `ls -d ../RawDicom/HEAD*/T1*`
	else
		echo "++ T1 nifti exists. Skipping nifti conversion for $sub"
	fi


	# Converting T2  dicom to nifti (fsl)
	if [ ! -f ${sub}_T2.nii.gz ]; then
		echo "++ T2 folder exists. Beginning DICOM to nifti conversion."
		dcm2niix -f ${sub}_T2 -p y -z y -o . `ls -d ../RawDicom/HEAD*/T2*`
	else
		echo "++ T2 nifti exists. Skipping nifti conversion for $sub"
	fi 

	########################################################
	# Step 0 : Reorienting  T1, T2 to LAS (afni)
	#######################################################

	if [[ ! -f ${sub}_T1_LAS.nii.gz && ! -f ${sub}_T2_LAS.nii.gz ]]; then
		echo "++ Reorienting T1 and T2 to LAS using AFNI 3dresample."
		3dresample -orient LAS  -prefix ${sub}_T1_LAS.nii.gz  -inset ${sub}_T1.nii.gz
		3dresample -orient LAS  -prefix ${sub}_T2_LAS.nii.gz  -inset ${sub}_T2.nii.gz
	else
		echo "++ T1 and T2 are already reoriented to LAS for $sub."
	fi

	########################################################
	# Step 1 : BET processing (Brain Tissue Extraction)
	# this needs (cog) in voxel coordinates which can be obtainted from
	#######################################################

	if [ ! -f ${sub}_T1_LAS_brain.nii.gz ]; then
		echo "++ Beginning BET processing for T1 and T2 images"
		
		echo "++ Obtaining center of gravity (cog) in voxel coordinates and stored in cog_t1.1D cog_t2.1D txt files"
		fslstats ${sub}_T1_LAS.nii.gz -C > cog_t1.1D  # T1 cog (voxel coordinates)
		echo "++ T1 cog is"
		cat cog_t1.1D

		x_t1=`awk '{print $1}'  cog_t1.1D`     # x
		y_t1=`awk '{print $2}'  cog_t1.1D`     # y
		z_t1=`awk '{print $3}'  cog_t1.1D`     # z

		echo "++ Beginning BET for T1"

		#T1 BET
		bet2 ${sub}_T1_LAS.nii.gz ${sub}_T1_LAS_brain -f 0.3 -g 0 -c $x_t1 $y_t1 $z_t1 --mask
		echo "++ Done with BET for T1."
	
	else
		echo "++ Already done with BET processing for $sub."
	fi
	
	########################################################
	# Step 2 : 	Recon all for T1  (free surfer)
	#######################################################
	
	if [ ! -d  $SUBJECTS_DIR/${sub}_fs ]; then
		echo "---------------------------------------------------------"
		echo "++ Beginning recon-all for the participant $sub"
		echo "---------------------------------------------------------"
		recon-all -i ${sub}_T1_LAS.nii.gz  -s $SUBJECTS_DIR/${sub}_fs -all
	else
		echo "++ Recon-all already done for the participant $sub"
	fi 

	########################################################
	# Step 3: After recon-all convert the freesurfer T1 to nii.gz and orient it if not in LAS
	# and move the files to the nifti folder for subsequent processing
	#######################################################
	# We are still in the nifti folder	
	if [ !  -f ${sub}_fs_ribbon.nii.gz ]; then

		echo "++ Convering, orienting to LAS and moving necessary files from recon-all results to nifti directory..."
		mri_convert $SUBJECTS_DIR/${sub}_fs/mri/T1.mgz ${sub}_fs_T1.nii.gz
		3dresample -orient LAS  -prefix ${sub}_fs_T1_LAS.nii.gz  -inset ${sub}_fs_T1.nii.gz
		mv ${sub}_fs_T1_LAS.nii.gz ${sub}_fs_T1.nii.gz

		# Move other files from reconall to the nifti directory and orient to LAS
		mri_convert $SUBJECTS_DIR/${sub}_fs/mri/brain.finalsurfs.mgz ${sub}_fs_brain.nii.gz
		mri_convert $SUBJECTS_DIR/${sub}_fs/mri/orig.mgz ${sub}_fs_orig.nii.gz
		mri_convert $SUBJECTS_DIR/${sub}_fs/mri/nu.mgz ${sub}_fs_nu.nii.gz
		mri_convert $SUBJECTS_DIR/${sub}_fs/mri/ribbon.mgz ${sub}_fs_ribbon.nii.gz

		3dresample -orient LAS  -prefix ${sub}_fs_braintmp.nii.gz  -inset ${sub}_fs_brain.nii.gz
		mv ${sub}_fs_braintmp.nii.gz ${sub}_fs_brain.nii.gz
		
		3dresample -orient LAS  -prefix ${sub}_fs_origtmp.nii.gz  -inset ${sub}_fs_orig.nii.gz
		mv ${sub}_fs_origtmp.nii.gz ${sub}_fs_orig.nii.gz

		3dresample -orient LAS  -prefix ${sub}_fs_nutmp.nii.gz  -inset ${sub}_fs_nu.nii.gz
		mv ${sub}_fs_nutmp.nii.gz ${sub}_fs_nu.nii.gz
		
		3dresample -orient LAS  -prefix ${sub}_fs_ribbontmp.nii.gz  -inset ${sub}_fs_ribbon.nii.gz
		mv ${sub}_fs_ribbontmp.nii.gz ${sub}_fs_ribbon.nii.gz 
	
	else
		echo "++ Necessary recon-all files are moved to the Nifti folder already"

	fi

	########################################################
	# Step 4: T2 processing beings here with 
	#######################################################
	
	if [ ! -f ${sub}_T2_LAS_brain.nii.gz ]; then

		echo "++ Beginning BET for T2"  
		# BET would take a few minutes
		# BET would generate brain masks, which could be used with fslmaths
		bet ${sub}_T2_LAS.nii.gz ${sub}_T2_LAS_brain -B -f 0.3 
		
		#echo "++ Masking for brain only T2"
		fslmaths ${sub}_T2_LAS -mas ${sub}_T2_LAS_brain_mask ${sub}_T2_LAS_brain
	
	else
		echo "++ Already Done with BET for T2 and brain only T2 is obtained" 
	fi

	########################################################
	# Step 5: Segmentation of CSF/WM/CSF from T2 using FAST (fsl))
	########################################################
	
	if [ ! -f  ${sub}_T2_LAS_brain_bias.nii.gz  ]; then # fast would return bias field for T2
		echo "++ Beginning Segmentation of T2 using fsl FAST "
		# no partial volume correction (--novpe)
		# -t type of tissue # -n (four tissue types" default 3")
		#  -b  output estimated bias field
		fast -t 2 -n 4 -l 15 -b --nopve ${sub}_T2_LAS_brain
	else
		echo "++ Segmentation of T2 is already done for this participant"
	fi


	########################################################
	# Step 6:  Bias correction for T2 using fslmaths
	########################################################
	if [ ! -f ${sub}_T2_LAS_unbias.nii.gz ]; then
		echo "++ Bias correction for T2 using fslmaths" 
		fslmaths -dt float ${sub}_T2_LAS -div ${sub}_T2_LAS_brain_bias.nii.gz ${sub}_T2_LAS_unbias
	else
		echo "++ Bias correction for T2 has already been done"
	fi

	########################################################
	# Step 7a:  Affine registration of T2 onto T1
	########################################################
	if [ ! -f ${sub}_regT2toT1.txt ]; then
		echo "++ Beginning affine registration of T2 onto T1 "
		flirt -in ${sub}_T2_LAS_brain -ref ${sub}_fs_brain -dof 6 -usesqform -omat ${sub}_regT2toT1.txt
		echo "++ Tranfomation matrix for T2-T1 registration is"
		cat ${sub}_regT2toT1.txt
		echo "++ If you do not see any matrix above, there is a possible error in the pipeline; please check your script"
	else
		echo "++ Affine registration of T2 onto T1 is already done with"
		echo "++ Tranfomation matrix for T2-T1 registration is"
		cat ${sub}_regT2toT1.txt
		echo "++ If you do not see any matrix above, there is a possible error in the pipeline; please check your script"
	fi

	########################################################
	# Step 7b:  Applying transformation matrix to  T2 
	########################################################
	
	if [ ! -f ${sub}_fs_T2.nii.gz ]; then 
		echo "++ Applying tranformation matrix to T2 image"
		flirt -in ${sub}_T2_LAS_unbias.nii.gz -ref ${sub}_fs_T1 -out ${sub}_fs_T2 -applyxfm -init ${sub}_regT2toT1.txt -interp sinc
	else
		echo "++ Done with applying tranformation matrix to T2 and aligned with T1"
	fi

	########################################################
	# Step 8: Making outer skull  meshes using BEM for T2 
	########################################################

	if [ ! -f ${sub}_fs_T2_brain.nii.gz ]; then 

		echo "++ Make non-cortical meshes using BEM"
		echo "++ Extracting cog for T2"
		fslstats ${sub}_fs_T2.nii.gz -C  > cog_t2_bet.1D  # T2 cog (voxel coordinates) 
		cat cog_t2_bet.1D

    	x_t2=`awk '{print $1}'  cog_t2_bet.1D`     # x
    	y_t2=`awk '{print $2}'  cog_t2_bet.1D`     # y
   		z_t2=`awk '{print $3}'  cog_t2_bet.1D`     # z
		
		# generate binary brain mask (-m)  (-e generate skull surface as mesh in vtk format)
		# Accoring to fsl, bet calls bet2 internally
		# probably this step can be combined with the above bet for T2
		bet2 ${sub}_fs_T2 ${sub}_fs_T2_brain -e -m -c $x_t2 $y_t2 $z_t2
	
	else
		echo "++ Skull surface as mesh format from T2 is computed using BET2"
	fi

	########################################################
	# Step 9: Aligning T1 to standard MNI152 (1mm) template 
	########################################################

	if [ ! -f ${sub}_fs_T1_MNI152.nii.gz ];then
		echo "++ Aligning fsl T1 image to standard MNI152 (1mm) template"
		flirt -usesqform -ref ${fsl_MNI152_template_path}/MNI152lin_T1_1mm.nii.gz -in ${sub}_fs_T1 -omat ${sub}_regT1toMNI.txt -out ${sub}_fs_T1_MNI152.nii.gz
	else
		echo "++ Done with aligning T1 image to standard MNI152 (1mm) template"
	fi

	########################################################
	# Step 10: Creating Headmodel (skull/inskull/outskull) using betsurf
	# This creats three files one for skull/inskull/outskull surface files in vtk
	########################################################
	if [ ! -f headmodel_outskin_mesh.vtk ];then
		echo "++ Making head model for $sub"
		betsurf --mask --skullmask  ${sub}_fs_T1  ${sub}_fs_T2 ${sub}_fs_T2_brain_mesh.vtk ${sub}_regT1toMNI.txt headmodel
		echo "++ Done with making head model \n"
	else
		echo "++ Already done with making head model"
	fi

	########################################################
	# Step 12: Reading surface triangles, Midgray surface in MATALB   
	########################################################
	
	if [ ! -d ${SperoToolbox}/participants_info  ];then
		echo "++ Making participants directory for the first time"
		mkdir ${SperoToolbox}/participants_info
	else
		echo "++ Participants directory inside SperoToolbox already exixts. Nothing to create "
		echo "++ Check the path:  ${SperoToolbox}/participants_info"
	fi
	
	# Save the current working directory (it would be nifti folder of that participant)
	# and saving participants info
	
	current_dir=`pwd`/headmodel   # Store the nifti directory

 	cd 	${SperoToolbox}/participants_info/

	if [[ ! -f  ${sub}_arg1.txt &&  ! -f  ${sub}_arg2.txt &&  ! -f  ${sub}_arg3.txt ]]; then
		echo "++ Making subjects three text files inside participants_info directory"	
		echo $current_dir > ${sub}_arg1.txt
		echo ${sub}_fs  > ${sub}_arg2.txt
		echo $SUBJECTS_DIR/${sub}_fs/bem > ${sub}_arg3.txt
	else
		echo "++ Participants info text files are already available"	
	fi


	if [ ! -d $SUBJECTS_DIR/${sub}_fs/bem  ];then
		echo "++ Making bem directory inside the freesurefer sujects"
		mkdir $SUBJECTS_DIR/${sub}_fs/bem  
	else
		echo "++ bem directory already exits"
	fi
	
	cd $SUBJECTS_DIR/${sub}_fs/bem
	if [ ! -f  outer_skin.tri ];then
		cd ${SperoToolbox}  
		# The following vertex_read_write.m will be in the SperoToolbox
		# it uses FSLoff2tri_oliver(arg1,arg3) file which is also inside the toolbox
		# Also makeFreesurferMidgraySurface_oliver(arg2,fs_dir) is also inside this function
		/Applications/matlab/R2019b/bin/matlab -nodisplay -r "vertex_read_write('$sub')";
	else
		
		echo "++ Outer skin file from FSLoff2tri_oliver already exists in the bem"
	fi

	cd $SUBJECTS_DIR/${sub}_fs/bem 


	########################################################
	# Step 11:  Setting up source space   
	########################################################

	if [ ! -f ${sub}_fs-ico-5-src.fif ]; then
		echo "++ Setting up source space file using MNE's mne_setup_source_space "
		mne_setup_source_space --subject ${sub}_fs --surface midgray --ico 5 --cps   # Check if this is opened using the test.m in home folder
	else
		echo "++ Source space is already computed"
	fi

	########################################################
	# Step 12: Set up forward model 
	########################################################

	if [ ! -f  ${sub}_fs-bem-sol.fif ]; then
		echo "++ Creating the BEM solution for head geometry "
		mne_setup_forward_model --subject ${sub}_fs --scalpc 0.33 --skullc 0.025 --brainc 0.33 --noswap --model ${sub}_fs
	else
		echo "++ BEM head model solution is already available"
	fi
	
	########################################################
	# Step 13:  Setting up source space   
	########################################################
	cd $SUBJECTS_DIR/${sub}_fs/bem   # Back to bem directory of the participant
	if [[ ! -f ../mri/seghead.mgz  && ! -f ../surf/lh.seghead ]]; then
		echo "++ Making high-resolution scalp for in freesurfer "
		# Make high resolution scalp in Free surfer (maybe this can be moved after recon all)
		mkheadsurf -s ${sub}_fs -srcvol orig.mgz -thresh1 20 -thresh2 20  # These thresholds has to be adjusted
	else
		echo "++ Already done with making the high-resolution scalp for this participant"
	fi

	########################################################
	# Step 14:  Setting up source space   
	########################################################
	# 4 for outer skin (head) surface 3 for outer skull surface 1 for inner skull surface 
	if [ ! -f ${sub}_fs-head.fif ]; then  # The final file
		echo "++ Beginning  the final MNE step"
		mne_surf2bem --surf ../surf/lh.seghead --id 4 --check --fif ${sub}_fs-head.fif
	else
		echo "++ Done with the final MNE step for this participant"
	fi

	############################################################
	# Step 15: Making Vanatomy.dat file for marking the mri Fiducials 
	###########################################################
	
	cd $eeg_helper_files

	if [ ! -f ${nifti_dir}/Vanatomy.dat ]; then
		echo "++ Begin computing Vanatomy.dat for this participant"
		#echo "$nifti_dir"
	/Applications/matlab/R2019b/bin/matlab -nodisplay -r "create_vanatomy_datfile('$sub')";
		echo "+ Done with computing Vanatomy.dat; You may view the VAnatomy.dat file using vAnatomyFiducials.m (Sperotoolbox) in MATLAB"
	else
		echo "++ Vanatomy.dat is already computed and it is in $nifti_dir. You may view the VAnatomy.dat file using vAnatomyFiducials.m (Sperotoolbox) in MATLAB"
	fi

	echo "++ ========================================================="
	echo "++ THE END of T1/T2 processing for the participant  ${sub}"
	echo "++ ========================================================="

cd $anatomy_path  # go to top folder to begin processing for the next participant
done
