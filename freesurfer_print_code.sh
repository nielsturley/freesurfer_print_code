#!/bin/sh

mriDataDir=/Volumes/Yorick/MriRawData
dicomLocation=ses-emdm/dicom/[Tt]1*
ORIGINAL_SUBJECTS_DIR=$SUBJECTS_DIR
#export SUBJECTS_DIR=/Volumes/Yorick/3dPrint/archived_freesurfer_subjects
export SUBJECTS_DIR=/Users/nielsturley/Desktop

read -p $'\nInput all of the subject numbers to print, separated by spaces (max 10)\n' -a subjects
while [[ ${#subjects[@]} -gt 10 ]]; do
	read -p $'Error: Please input less subjects (max 10)\n' -a subjects
done
if [[ ${#subjects[@]} == 0 ]]; then
	echo "Bro you didn't put anything..."
	exit 0
fi

read -p $'\n'"Do you need to change the mri data directory?"$'\n'"Currently set as: $mriDataDir"$'\n'"[input 'y' to change, anything else to continue]"$'\n' changeMriDir
if [[ $changeMriDir == "y" ]]; then
	read -p $'Input new mri data directory: ' mriDataDir
fi

read -p $'\n'"Do you need to change the dicom location?"$'\n'"Currently set as: $dicomLocation"$'\n'"[input 'y' to change, anything else to continue]"$'\n' changeDicomDir
if [[ $changeDicomDir == "y" ]]; then
	read -p $'Input new dicom location: ' dicomLocation
fi

read -p $'\n'"Do you need to change the freesurfer output directory?"$'\n'"Currently set as: $SUBJECTS_DIR"$'\n'"[input 'y' to change, anything else to continue]"$'\n' changeOutputDir
if [[ $changeOutputDir == "y" ]]; then
	read -p $'Input new output location: ' SUBJECTS_DIR
fi

read -p $'\n'"Final check before starting...
Subject(s): ${subjects[@]}
Mri data directory: $mriDataDir
Dicom location: $dicomLocation
Freesufer output directory: $SUBJECTS_DIR
NOTE!! This will begin the freesurfer recon-all command, which takes 5-7 hours to finish"$'\n'"[input 'y' to stop, anything else to continue]"$'\n' beginPrint
if [[ $beginPrint == "y" ]]; then
	exit 0
fi

# append 'sub-' to the subjects for convenience
subjects=( "${subjects[@]/#/sub-}" )

# check if subject folders already exist
subjects_to_skip=()
skip_prompt=false
for subject in "${subjects[@]}"; do
	folder_path="$SUBJECTS_DIR/$subject"

	if [[ -d "$folder_path" ]]; then
		if [[ "$skip_prompt" = false ]]; then
			read -p $'\n'"Folder already exists for $subject. Do you want to overwrite it?"$'\n'"'y' will PERMANENTLY DELETE the old freesurfer data for $subject"$'\n'"'n' will skip the processing for this subject"$'\n'"'all' will PERMANENTLY DELETE the old freesurfer data for all existing folders in this batch of subjects"$'\n'"(y/n/all): " choice

			case "$choice" in
				y|Y )
					rm -r "$folder_path"
					echo "Folder removed for $subject."
					;;
				n|N )
					echo "Skip processing for $subject."
					subjects_to_skip+=("$subject")
					;;
				all|ALL )
					echo "Removing all existing folders."
					rm -r "$folder_path"
					echo "Folder removed for $subject."
					skip_prompt=true
					;;
				* )
					echo "Invalid choice. Skipping removal for subject $subject."
					;;
			esac
		else
			rm -r "$folder_path"
			echo "Folder removed for $subject."
		fi
	fi
done
subjects=("${subjects[@]/${subjects_to_skip[@]}}")

echo Starting freesurfer cortical...

# moneymaker here, runs all the subjects through recon-all at one time. will output to $SUBJECTS_DIR
parallel --link -j ${#subjects[@]} recon-all -s {} -i $mriDataDir/{}/$dicomLocation/*0001.dcm -all -clean-bm ::: ${subjects[@]}

echo Starting freesurfer subcortical...

# this is for subcortical stuff
for i in ${!subjects[@]}; do
	
	# directory initialization
	mkdir $SUBJECTS_DIR/${subjects[$i]}/print
	printDir=$SUBJECTS_DIR/${subjects[$i]}/print
	
	# code for converting + merging subcortical
	mris_convert --combinesurfs $SUBJECTS_DIR/${subjects[$i]}/surf/lh.pial $SUBJECTS_DIR/${subjects[$i]}/surf/rh.pial $printDir/cortical.stl
	
	mri_convert $SUBJECTS_DIR/${subjects[$i]}/mri/aseg.mgz $printDir/subcortical.nii
	
	mri_binarize --i $printDir/subcortical.nii \
		--match 2 3 24 31 41 42 63 72 77 51 52 13 12 43 50 4 11 26 58 49 10 17 18 53 54 44 5 80 14 15 30 62 \
		--inv \
		--o $printDir/bin.nii
	
	fslmaths $printDir/subcortical.nii \
		-mul $printDir/bin.nii \
		$printDir/subcortical.nii.gz
	
	cp $printDir/subcortical.nii.gz $printDir/subcortical_tmp.nii.gz
	
	gunzip -f $printDir/subcortical_tmp.nii.gz
	
	for j in 7 8 16 28 46 47 60 251 252 253 254 255
	do
		mri_pretess $printDir/subcortical_tmp.nii \
		$j \
		$SUBJECTS_DIR/${subjects[$i]}/mri/norm.mgz \
		$printDir/subcortical_tmp.nii
	done
	
	fslmaths $printDir/subcortical_tmp.nii -bin $printDir/subcortical_bin.nii
	
	mri_tessellate $printDir/subcortical_bin.nii.gz 1 $printDir/subcortical
	
	mris_convert $printDir/subcortical $printDir/subcortical.stl

	python /Volumes/Yorick/3dPrint/freesurfer_print_code/brain_smoothing.py $printDir

done

export SUBJECTS_DIR=$ORIGINAL_SUBJECTS_DIR
